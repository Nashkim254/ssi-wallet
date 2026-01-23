import UIKit
import Flutter
// import ProcivisOneCore  // TODO: Add Procivis SDK framework

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    // var oneCore: OneCoreBinding?  // TODO: Uncomment when SDK is added

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
        let channel = FlutterMethodChannel(
            name: "com.ssi.wallet/procivis",
            binaryMessenger: controller.binaryMessenger
        )

        channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            switch call.method {
            case "initializeCore":
                self?.initializeCore(result: result)

            case "getVersion":
                self?.getVersion(result: result)

            case "createDid":
                guard let args = call.arguments as? [String: Any],
                      let method = args["method"] as? String,
                      let keyType = args["keyType"] as? String else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
                    return
                }
                self?.createDid(method: method, keyType: keyType, result: result)

            case "getDids":
                self?.getDids(result: result)

            case "getDid":
                guard let args = call.arguments as? [String: Any],
                      let didId = args["didId"] as? String else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
                    return
                }
                self?.getDid(didId: didId, result: result)

            case "deleteDid":
                guard let args = call.arguments as? [String: Any],
                      let didId = args["didId"] as? String else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
                    return
                }
                self?.deleteDid(didId: didId, result: result)

            case "getCredentials":
                self?.getCredentials(result: result)

            case "getCredential":
                guard let args = call.arguments as? [String: Any],
                      let credentialId = args["credentialId"] as? String else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
                    return
                }
                self?.getCredential(credentialId: credentialId, result: result)

            case "acceptCredentialOffer":
                guard let args = call.arguments as? [String: Any],
                      let offerUrl = args["offerUrl"] as? String else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
                    return
                }
                self?.acceptCredentialOffer(offerUrl: offerUrl, result: result)

            case "deleteCredential":
                guard let args = call.arguments as? [String: Any],
                      let credentialId = args["credentialId"] as? String else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
                    return
                }
                self?.deleteCredential(credentialId: credentialId, result: result)

            case "processPresentationRequest":
                guard let args = call.arguments as? [String: Any],
                      let requestUrl = args["requestUrl"] as? String else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
                    return
                }
                self?.processPresentationRequest(requestUrl: requestUrl, result: result)

            case "submitPresentation":
                guard let args = call.arguments as? [String: Any],
                      let interactionId = args["interactionId"] as? String,
                      let selectedCredentialIds = args["selectedCredentialIds"] as? [String] else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
                    return
                }
                self?.submitPresentation(interactionId: interactionId, selectedCredentialIds: selectedCredentialIds, result: result)

            case "rejectPresentationRequest":
                guard let args = call.arguments as? [String: Any],
                      let interactionId = args["interactionId"] as? String else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
                    return
                }
                self?.rejectPresentationRequest(interactionId: interactionId, result: result)

            case "getInteractionHistory":
                self?.getInteractionHistory(result: result)

            case "checkCredentialStatus":
                guard let args = call.arguments as? [String: Any],
                      let credentialId = args["credentialId"] as? String else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
                    return
                }
                self?.checkCredentialStatus(credentialId: credentialId, result: result)

            case "exportBackup":
                self?.exportBackup(result: result)

            case "importBackup":
                guard let args = call.arguments as? [String: Any],
                      let backupData = args["backupData"] as? String else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
                    return
                }
                self?.importBackup(backupData: backupData, result: result)

            case "getSupportedDidMethods":
                self?.getSupportedDidMethods(result: result)

            case "getSupportedCredentialFormats":
                self?.getSupportedCredentialFormats(result: result)

            case "uninitialize":
                guard let args = call.arguments as? [String: Any],
                      let deleteData = args["deleteData"] as? Bool else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
                    return
                }
                self?.uninitialize(deleteData: deleteData, result: result)

            default:
                result(FlutterMethodNotImplemented)
            }
        }

        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    private func initializeCore(result: @escaping FlutterResult) {
        do {
            let configJson = """
                             {
                                 "keyStorage": {
                                     "SECURE_ELEMENT": {
                                         "enabled": true
                                     }
                                 }
                             }
                             """

            let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            let dataDir = paths[0].path

            oneCore = try initializeCore(
                configJson: configJson,
                dataDirPath: dataDir,
                nativeSecureElement: SecureEnclaveKeyStorage(),
                remoteSecureElement: nil,
                bleCentral: IOSBLECentral(),
                blePeripheral: IOSBLEPeripheral()
            )

            result(true)
        } catch {
            result(FlutterError(code: "INIT_ERROR", message: error.localizedDescription, details: nil))
        }
    }

    private func getVersion(result: @escaping FlutterResult) {
        let version = oneCore?.getVersion() ?? "Unknown"
        result(version)
    }

    private func createDid(method: String, keyType: String, result: @escaping FlutterResult) {
        // Mock implementation - replace with actual Procivis call
        let did: [String: Any] = [
            "id": UUID().uuidString,
            "didString": "did:\(method):\(UUID().uuidString)",
            "method": method,
            "keyType": keyType,
            "createdAt": ISO8601DateFormatter().string(from: Date()),
            "isDefault": false
        ]
        result(did)
    }

    private func getDids(result: @escaping FlutterResult) {
        result([])
    }

    private func getDid(didId: String, result: @escaping FlutterResult) {
        result(nil)
    }

    private func deleteDid(didId: String, result: @escaping FlutterResult) {
        result(true)
    }

    private func getCredentials(result: @escaping FlutterResult) {
        result([])
    }

    private func getCredential(credentialId: String, result: @escaping FlutterResult) {
        result(nil)
    }

    private func acceptCredentialOffer(offerUrl: String, result: @escaping FlutterResult) {
        // Mock credential - replace with actual Procivis call
        let credential: [String: Any] = [
            "id": UUID().uuidString,
            "name": "Sample Credential",
            "type": "VerifiableCredential",
            "format": "JWT",
            "issuerName": "Sample Issuer",
            "issuedDate": ISO8601DateFormatter().string(from: Date()),
            "claims": [:],
            "state": "valid"
        ]
        result(credential)
    }

    private func deleteCredential(credentialId: String, result: @escaping FlutterResult) {
        result(true)
    }

    private func processPresentationRequest(requestUrl: String, result: @escaping FlutterResult) {
        result(["interactionId": UUID().uuidString])
    }

    private func submitPresentation(interactionId: String, selectedCredentialIds: [String], result: @escaping FlutterResult) {
        result(true)
    }

    private func rejectPresentationRequest(interactionId: String, result: @escaping FlutterResult) {
        result(true)
    }

    private func getInteractionHistory(result: @escaping FlutterResult) {
        result([])
    }

    private func checkCredentialStatus(credentialId: String, result: @escaping FlutterResult) {
        result([
                   "status": "valid",
                   "isRevoked": false,
                   "isSuspended": false
               ])
    }

    private func exportBackup(result: @escaping FlutterResult) {
        result("")
    }

    private func importBackup(backupData: String, result: @escaping FlutterResult) {
        result(true)
    }

    private func getSupportedDidMethods(result: @escaping FlutterResult) {
        result(["did:key", "did:web", "did:jwk"])
    }

    private func getSupportedCredentialFormats(result: @escaping FlutterResult) {
        result(["JWT", "SD-JWT", "JSON-LD", "ISO_MDOC"])
    }

    private func uninitialize(deleteData: Bool, result: @escaping FlutterResult) {
        if let core = oneCore {
            do {
                try uninitialize(oneCore: core, deleteData: deleteData)
                oneCore = nil
                result(true)
            } catch {
                result(FlutterError(code: "UNINIT_ERROR", message: error.localizedDescription, details: nil))
            }
        } else {
            result(true)
        }
    }
}