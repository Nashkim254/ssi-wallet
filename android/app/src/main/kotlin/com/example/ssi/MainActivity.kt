package com.example.ssi

import android.content.Intent
import android.util.Log
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity: FlutterFragmentActivity() {

    companion object {
        private const val TAG = "MainActivity"
    }

    private var ssiApiImpl: EudiSsiApiImpl? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Initialize EUDI Wallet SSI API implementation
        ssiApiImpl = EudiSsiApiImpl(applicationContext)

        // Set up pigeon-generated API
        SsiApi.setUp(flutterEngine.dartExecutor.binaryMessenger, ssiApiImpl)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        // Handle authorization callback from EUDI issuer
        val data = intent.data

        Log.d(TAG, "onNewIntent - action: ${intent.action}, data: $data")

        // Check if this is an authorization callback for OpenID4VCI
        if (data != null && data.scheme == "eudi-openid4ci" && data.host == "authorize") {
            Log.d(TAG, "Received OpenID4VCI authorization callback: $data")

            // Extract authorization parameters
            val code = data.getQueryParameter("code")
            val state = data.getQueryParameter("state")

            Log.d(TAG, "Authorization code: ${code?.substring(0, minOf(20, code.length ?: 0))}...")
            Log.d(TAG, "State: $state")

            // NOTE: Flutter now handles authorization callbacks via uni_links
            // This provides better UI feedback (loading dialogs, error messages)
            // Commenting out the old handler to prevent duplicate processing
            // ssiApiImpl?.handleAuthorizationResponse(data.toString())
            Log.d(TAG, "Deep link will be handled by Flutter layer for better UI feedback")
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        // Clean up - Note: Pigeon APIs typically don't need explicit teardown
        ssiApiImpl = null
    }
}
