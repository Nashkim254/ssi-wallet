import CoreBluetooth
import CryptoKit
import Foundation
import MdocDataModel18013
import MdocDataTransfer18013
import MdocSecurity18013
import OrderedCollections
import SwiftCBOR

/// ISO 18013-5 BLE proximity verifier (reader/Central role).
/// Scans for the holder's GATT server, establishes a session, requests mDL fields,
/// and returns the decoded claims as a plain [String: String] dictionary.
class MdocBleReader: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {

    // MARK: - BLE objects

    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var stateChar: CBCharacteristic?
    private var c2sChar: CBCharacteristic?       // client2Server – reader writes here
    private var s2cChar: CBCharacteristic?       // server2Client – reader reads here

    private let serviceUUID: CBUUID
    private let deBytes: [UInt8]                 // raw CBOR of DeviceEngagement

    // MARK: - Session state

    private var eReaderPrivKey: P256.KeyAgreement.PrivateKey?
    private var skReader: SymmetricKey?           // for encrypting DeviceRequest
    private var skDevice: SymmetricKey?           // for decrypting DeviceResponse
    private var sessionEstData: Data?            // precomputed SE to send

    // BLE recv buffer
    private var recvBuf = Data()

    // subscribe-count gate: server needs state + s2c subscriptions before connecting
    private var subCount = 0

    // Async result plumbing
    private var continuation: CheckedContinuation<[String: String], Error>?

    // MARK: - Init

    /// - Parameter qrCode: The raw string from the holder's QR code, e.g. "mdoc:Abcd…"
    init(qrCode: String) throws {
        let raw = qrCode.hasPrefix("mdoc:") ? String(qrCode.dropFirst(5)) : qrCode
        let standardB64 = raw.base64URLUnescaped()
        guard let deData = Data(base64Encoded: standardB64) else {
            throw NSError(domain: "MdocBleReader", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid base64url in QR"])
        }
        deBytes = [UInt8](deData)
        let de = try DeviceEngagement(data: deBytes)
        guard let uuid = de.ble_uuid else {
            throw NSError(domain: "MdocBleReader", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "No BLE UUID in device engagement"])
        }
        serviceUUID = CBUUID(string: uuid)
        super.init()
    }

    // MARK: - Public entry

    func readCredential() async throws -> [String: String] {
        try await withCheckedThrowingContinuation { cont in
            continuation = cont
            central = CBCentralManager(delegate: self, queue: .main)
        }
    }

    // MARK: - Crypto helpers

    private func extractDevicePublicKey() throws -> P256.KeyAgreement.PublicKey {
        // DeviceEngagement CBOR: {0: version, 1: [cipherSuiteId, tagged(24,CoseKey)], ...}
        guard let cborObj = try? CBOR.decode(deBytes),
              case let .map(m) = cborObj,
              let secCbor = m[1],
              case let .array(secArr) = secCbor,
              secArr.count > 1,
              let keyBytes = secArr[1].decodeTaggedBytes() else {
            throw NSError(domain: "MdocBleReader", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "Cannot extract device key from engagement"])
        }
        let coseKey = try CoseKey(data: keyBytes)
        return try P256.KeyAgreement.PublicKey(x963Representation: coseKey.getx963Representation())
    }

    private func buildSessionKeys() throws -> (se: Data, sessionEstCBOR: Data) {
        let privKey = P256.KeyAgreement.PrivateKey()
        eReaderPrivKey = privKey
        let devicePub = try extractDevicePublicKey()
        let sharedSecret = try privKey.sharedSecretFromKeyAgreement(with: devicePub)

        // Build eReaderKey CoseKey (public, P-256)
        let x963 = privKey.publicKey.x963Representation  // 0x04 || x(32) || y(32)
        let x = [UInt8](x963[1..<33])
        let y = [UInt8](x963[33..<65])
        let eReaderCoseKey = CoseKey(x: x, y: y, crv: .P256)
        let eReaderKeyBytes = eReaderCoseKey.encode(options: CBOROptions())

        // Session transcript (QR handover = null)
        // Must use taggedEncoded (tag 24 wrapper) then encode — matches SessionEncryption.sessionTranscriptBytes
        let st = SessionTranscript(devEngRawData: deBytes, eReaderRawData: eReaderKeyBytes,
                                   handOver: BleTransferMode.QRHandover)
        let stBytes = st.taggedEncoded.encode(options: CBOROptions())

        // Derive session keys via HKDF
        skReader = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self, salt: stBytes,
            sharedInfo: "SKReader".data(using: .utf8)!, outputByteCount: 32)
        skDevice = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self, salt: stBytes,
            sharedInfo: "SKDevice".data(using: .utf8)!, outputByteCount: 32)

        // Build DeviceRequest
        let dr = DeviceRequest(mdl: [
            .familyName, .givenName, .birthDate, .documentNumber,
            .issuingCountry, .expiryDate, .issueDate, .portrait
        ], agesOver: [18, 21], intentToRetain: false)
        let drBytes = dr.encode(options: CBOROptions())

        // Encrypt DeviceRequest: AES-GCM with SKReader
        // Nonce = IDENTIFIER0(8 bytes) + counter as byteArrayLittleEndian (SDK name; actually MSB-first)
        let identifier0: [UInt8] = [0,0,0,0,0,0,0,0]
        var nonceData = Data(identifier0)
        let counter1: UInt32 = 1
        nonceData.append(contentsOf: [UInt8((counter1 & 0xFF000000) >> 24), UInt8((counter1 & 0x00FF0000) >> 16), UInt8((counter1 & 0x0000FF00) >> 8), UInt8(counter1 & 0x000000FF)])
        let nonce = try AES.GCM.Nonce(data: nonceData)
        let sealed = try AES.GCM.seal(drBytes, using: skReader!, nonce: nonce)
        // Encrypted bytes = ciphertext + tag (no nonce prefix stored)
        let encryptedDr = [UInt8](sealed.ciphertext) + [UInt8](sealed.tag)

        // Build SessionEstablishment CBOR
        var seMap = OrderedDictionary<CBOR, CBOR>()
        seMap[.utf8String("eReaderKey")] = eReaderKeyBytes.taggedEncoded
        seMap[.utf8String("data")] = .byteString(encryptedDr)
        let seBytes = CBOR.map(seMap).encode(options: CBOROptions())

        return (Data(seBytes), Data(seBytes))
    }

    private func decryptResponse(_ cipherData: [UInt8]) throws -> [UInt8] {
        guard let key = skDevice else {
            throw NSError(domain: "MdocBleReader", code: 4,
                          userInfo: [NSLocalizedDescriptionKey: "No SKDevice key"])
        }
        guard cipherData.count >= 16 else {
            throw NSError(domain: "MdocBleReader", code: 5,
                          userInfo: [NSLocalizedDescriptionKey: "Ciphertext too short"])
        }
        // Nonce = IDENTIFIER1(8 bytes) + counter=1 as byteArrayLittleEndian (MSB-first)
        let identifier1: [UInt8] = [0,0,0,0,0,0,0,1]
        var nonceData = Data(identifier1)
        let counter1: UInt32 = 1
        nonceData.append(contentsOf: [UInt8((counter1 & 0xFF000000) >> 24), UInt8((counter1 & 0x00FF0000) >> 16), UInt8((counter1 & 0x0000FF00) >> 8), UInt8(counter1 & 0x000000FF)])
        let nonce = try AES.GCM.Nonce(data: nonceData)
        let rawCT = Array(cipherData.dropLast(16))
        let tag = Array(cipherData.suffix(16))
        let box = try AES.GCM.SealedBox(nonce: nonce, ciphertext: rawCT, tag: tag)
        return [UInt8](try AES.GCM.open(box, using: key))
    }

    private func parseClaims(from responseBytes: [UInt8]) -> [String: String] {
        var claims: [String: String] = [:]
        guard let dr = try? DeviceResponse(data: responseBytes),
              let docs = dr.documents else { return claims }
        for doc in docs {
            guard let ns = doc.issuerSigned.issuerNameSpaces else { continue }
            for (_, items) in ns.nameSpaces {
                for item in items {
                    if item.elementIdentifier == "portrait" { continue } // skip binary portrait
                    claims[item.elementIdentifier] = item.elementValue.debugDescription
                }
            }
        }
        return claims
    }

    // MARK: - BLE send helpers

    private func sendData(_ data: Data, to characteristic: CBCharacteristic) {
        guard let p = peripheral else { return }
        let mtu = p.maximumWriteValueLength(for: .withoutResponse) - 1
        let maxChunk = max(mtu, 1)
        var offset = 0
        while offset < data.count {
            let end = min(offset + maxChunk, data.count)
            let chunk = data.subdata(in: offset..<end)
            let isLast = (end == data.count)
            var block = Data()
            block.append(isLast ? 0x00 : 0x01)
            block.append(chunk)
            p.writeValue(block, for: characteristic, type: .withoutResponse)
            offset = end
        }
    }

    private func sendStart() {
        guard let p = peripheral, let c = stateChar else { return }
        p.writeValue(Data([0x01]), for: c, type: .withoutResponse)
    }

    private func sendEnd() {
        guard let p = peripheral, let c = stateChar else { return }
        p.writeValue(Data([0x02]), for: c, type: .withoutResponse)
    }

    // MARK: - CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central.state == .poweredOn else {
            if central.state == .unauthorized || central.state == .unsupported {
                fail(NSError(domain: "MdocBleReader", code: 6,
                             userInfo: [NSLocalizedDescriptionKey: "BLE not available: \(central.state.rawValue)"]))
            }
            return
        }
        print("[MdocBleReader] Scanning for service \(serviceUUID)")
        central.scanForPeripherals(withServices: [serviceUUID], options: nil)
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        print("[MdocBleReader] Discovered peripheral \(peripheral.identifier)")
        central.stopScan()
        self.peripheral = peripheral
        peripheral.delegate = self
        central.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("[MdocBleReader] Connected to holder")
        peripheral.discoverServices([serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        fail(error ?? NSError(domain: "MdocBleReader", code: 7,
                              userInfo: [NSLocalizedDescriptionKey: "BLE connect failed"]))
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if continuation != nil {
            fail(error ?? NSError(domain: "MdocBleReader", code: 8,
                                  userInfo: [NSLocalizedDescriptionKey: "BLE disconnected unexpectedly"]))
        }
    }

    // MARK: - CBPeripheralDelegate

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil, let service = peripheral.services?.first(where: { $0.uuid == serviceUUID }) else {
            fail(error ?? NSError(domain: "MdocBleReader", code: 9,
                                  userInfo: [NSLocalizedDescriptionKey: "Service not found"]))
            return
        }
        peripheral.discoverCharacteristics([
            CBUUID(string: MdocServiceCharacteristic.state.rawValue),
            CBUUID(string: MdocServiceCharacteristic.client2Server.rawValue),
            CBUUID(string: MdocServiceCharacteristic.server2Client.rawValue),
        ], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else { fail(error!); return }
        for c in service.characteristics ?? [] {
            switch MdocServiceCharacteristic(rawValue: c.uuid.uuidString.uppercased()) {
            case .state:           stateChar = c
            case .client2Server:   c2sChar = c
            case .server2Client:   s2cChar = c
            case .none: break
            }
        }
        // Subscribe to state and server2Client so holder counts 2 subscriptions
        if let s = stateChar  { peripheral.setNotifyValue(true, for: s) }
        if let s = s2cChar    { peripheral.setNotifyValue(true, for: s) }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else { fail(error!); return }
        subCount += 1
        print("[MdocBleReader] Subscribed (\(subCount)/2) to \(characteristic.uuid)")
        guard subCount >= 2 else { return }

        // Both subscriptions done → holder is now .connected → send SessionEstablishment
        do {
            let (seData, _) = try buildSessionKeys()
            sessionEstData = seData
            sendStart()
            guard let c2s = c2sChar else {
                fail(NSError(domain: "MdocBleReader", code: 10,
                             userInfo: [NSLocalizedDescriptionKey: "client2Server char missing"]))
                return
            }
            sendData(seData, to: c2s)
            print("[MdocBleReader] Sent SessionEstablishment (\(seData.count) bytes)")
        } catch {
            fail(error)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, let data = characteristic.value, !data.isEmpty else {
            if let e = error { fail(e) }
            return
        }
        let header = data[0]
        if data.count > 1 {
            recvBuf.append(data.advanced(by: 1))
        }
        guard header == 0x00 else { return } // 0x01 = more chunks coming

        // Full message received
        print("[MdocBleReader] Received response (\(recvBuf.count) bytes)")
        sendEnd()
        do {
            // Decode SessionData wrapper
            let sd = try SessionData(data: [UInt8](recvBuf))
            guard let cipherData = sd.data else {
                throw NSError(domain: "MdocBleReader", code: 11,
                              userInfo: [NSLocalizedDescriptionKey: "Empty session data from holder"])
            }
            let plainBytes = try decryptResponse(cipherData)
            let claims = parseClaims(from: plainBytes)
            succeed(claims)
        } catch {
            fail(error)
        }
    }

    // MARK: - Result helpers

    private func succeed(_ claims: [String: String]) {
        guard let cont = continuation else { return }
        continuation = nil
        central?.cancelPeripheralConnection(peripheral!)
        cont.resume(returning: claims)
    }

    private func fail(_ error: Error) {
        guard let cont = continuation else { return }
        continuation = nil
        if let p = peripheral { central?.cancelPeripheralConnection(p) }
        cont.resume(throwing: error)
    }
}
