import CoreBluetooth
import Foundation

/// Holder-side discovery beacon.
/// Advertises a well-known fixed BLE service so nearby verifier apps can
/// auto-discover the holder without needing to physically scan the QR code.
/// The full QR/device-engagement string is returned via a readable characteristic.
class MdocDiscoveryBeacon: NSObject, CBPeripheralManagerDelegate {

    // Fixed UUIDs known to both holder and verifier builds of this app
    static let serviceUUID = CBUUID(string: "DA9D6873-5A32-4B7F-B532-A2BD9B5D3E01")
    static let deCharUUID  = CBUUID(string: "DA9D6874-5A32-4B7F-B532-A2BD9B5D3E01")

    private var peripheralManager: CBPeripheralManager!
    private let qrData: Data

    init(qrString: String) {
        qrData = qrString.data(using: .utf8) ?? Data()
        super.init()
        peripheralManager = CBPeripheralManager(delegate: self, queue: .main)
    }

    func stop() {
        peripheralManager?.stopAdvertising()
        peripheralManager?.removeAllServices()
        print("[MdocDiscoveryBeacon] Stopped")
    }

    // MARK: - CBPeripheralManagerDelegate

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        guard peripheral.state == .poweredOn else { return }
        // value: nil → respond dynamically in didReceiveRead so offset works correctly
        let char = CBMutableCharacteristic(
            type: MdocDiscoveryBeacon.deCharUUID,
            properties: [.read],
            value: nil,
            permissions: [.readable]
        )
        let service = CBMutableService(type: MdocDiscoveryBeacon.serviceUUID, primary: true)
        service.characteristics = [char]
        peripheral.add(service)
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let e = error { print("[MdocDiscoveryBeacon] Add service error: \(e)"); return }
        peripheral.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [MdocDiscoveryBeacon.serviceUUID],
            CBAdvertisementDataLocalNameKey: "mDL-Holder"
        ])
        print("[MdocDiscoveryBeacon] Advertising started (\(qrData.count) bytes ready)")
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        guard request.characteristic.uuid == MdocDiscoveryBeacon.deCharUUID else {
            peripheral.respond(to: request, withResult: .attributeNotFound)
            return
        }
        guard request.offset <= qrData.count else {
            peripheral.respond(to: request, withResult: .invalidOffset)
            return
        }
        request.value = qrData.subdata(in: request.offset..<qrData.count)
        peripheral.respond(to: request, withResult: .success)
    }
}
