import CoreBluetooth
import Foundation

/// Verifier-side BLE scanner.
/// Scans for a nearby holder advertising `MdocDiscoveryBeacon.serviceUUID`,
/// connects, reads the QR/device-engagement characteristic, and returns the string.
class MdocBleScanner: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {

    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var continuation: CheckedContinuation<String, Error>?
    private var stopped = false

    // MARK: - Public API

    func scanForHolder() async throws -> String {
        try await withCheckedThrowingContinuation { cont in
            continuation = cont
            central = CBCentralManager(delegate: self, queue: .main)
        }
    }

    func stop() {
        stopped = true
        central?.stopScan()
        if let p = peripheral { central?.cancelPeripheralConnection(p) }
        if let cont = continuation {
            continuation = nil
            cont.resume(throwing: NSError(
                domain: "MdocBleScanner", code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Scan cancelled"]))
        }
    }

    // MARK: - CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard !stopped else { return }
        switch central.state {
        case .poweredOn:
            print("[MdocBleScanner] Scanning for mDL holder beacon…")
            central.scanForPeripherals(withServices: [MdocDiscoveryBeacon.serviceUUID], options: nil)
        case .unauthorized:
            fail(NSError(domain: "MdocBleScanner", code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "Bluetooth permission denied"]))
        case .poweredOff:
            fail(NSError(domain: "MdocBleScanner", code: 2,
                         userInfo: [NSLocalizedDescriptionKey: "Bluetooth is off"]))
        default:
            break
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        print("[MdocBleScanner] Found holder beacon: \(peripheral.identifier)")
        central.stopScan()
        self.peripheral = peripheral
        peripheral.delegate = self
        central.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([MdocDiscoveryBeacon.serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        fail(error ?? NSError(domain: "MdocBleScanner", code: 3,
                              userInfo: [NSLocalizedDescriptionKey: "BLE connect failed"]))
    }

    // MARK: - CBPeripheralDelegate

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil,
              let svc = peripheral.services?.first(where: { $0.uuid == MdocDiscoveryBeacon.serviceUUID }) else {
            fail(error ?? NSError(domain: "MdocBleScanner", code: 4,
                                  userInfo: [NSLocalizedDescriptionKey: "Discovery service not found"]))
            return
        }
        peripheral.discoverCharacteristics([MdocDiscoveryBeacon.deCharUUID], for: svc)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil,
              let char = service.characteristics?.first(where: { $0.uuid == MdocDiscoveryBeacon.deCharUUID }) else {
            fail(error ?? NSError(domain: "MdocBleScanner", code: 5,
                                  userInfo: [NSLocalizedDescriptionKey: "DE characteristic not found"]))
            return
        }
        peripheral.readValue(for: char)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil,
              let data = characteristic.value,
              let qr = String(data: data, encoding: .utf8), !qr.isEmpty else {
            fail(error ?? NSError(domain: "MdocBleScanner", code: 6,
                                  userInfo: [NSLocalizedDescriptionKey: "Failed to read QR from holder"]))
            return
        }
        central.cancelPeripheralConnection(peripheral)
        succeed(qr)
    }

    // MARK: - Helpers

    private func succeed(_ qr: String) {
        guard let cont = continuation else { return }
        continuation = nil
        cont.resume(returning: qr)
    }

    private func fail(_ error: Error) {
        guard let cont = continuation else { return }
        continuation = nil
        cont.resume(throwing: error)
    }
}
