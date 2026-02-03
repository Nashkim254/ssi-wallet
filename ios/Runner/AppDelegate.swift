import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {

    private var ssiApiImpl: EudiSsiApiImpl?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        // Set up EUDI Wallet SSI API using Pigeon with registry
        let messenger = self.registrar(forPlugin: "SsiApi")!.messenger()
        ssiApiImpl = EudiSsiApiImpl()
        SsiApiSetup.setUp(binaryMessenger: messenger, api: ssiApiImpl)

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    override func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey : Any] = [:]
    ) -> Bool {
        // Handle authorization callback from EUDI issuer
        if url.scheme == "eudi-openid4ci" && url.host == "authorize" {
            print("[AppDelegate] Received OpenID4VCI authorization callback: \(url)")

            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let code = components?.queryItems?.first(where: { $0.name == "code" })?.value
            let state = components?.queryItems?.first(where: { $0.name == "state" })?.value

            print("[AppDelegate] Authorization code: \(code?.prefix(20) ?? "")...")
            print("[AppDelegate] State: \(state ?? "")")

            // Notify the EUDI SDK about the authorization response
            ssiApiImpl?.handleAuthorizationResponse(url: url)

            return true
        }

        return super.application(app, open: url, options: options)
    }

    override func applicationWillTerminate(_ application: UIApplication) {
        // Clean up pigeon API
        ssiApiImpl = nil
        super.applicationWillTerminate(application)
    }
}
