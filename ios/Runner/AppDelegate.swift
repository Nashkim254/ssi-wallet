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
        // Log URL for debugging, but don't handle authorization callbacks here
        // In EUDI iOS SDK, authorization callbacks are handled internally by the SDK
        // via async/await when issueDocumentsByOfferUrl is called
        // The SDK uses ASWebAuthenticationSession which handles callbacks automatically
        print("[AppDelegate] Received URL: \(url)")

        // Let Flutter's app_links handle deep links
        // Flutter will manage the UI state and call native methods via Pigeon when needed
        return super.application(app, open: url, options: options)
    }

    override func applicationWillTerminate(_ application: UIApplication) {
        // Clean up pigeon API
        ssiApiImpl = nil
        super.applicationWillTerminate(application)
    }
}
