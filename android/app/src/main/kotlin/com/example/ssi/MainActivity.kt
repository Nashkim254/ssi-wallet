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

        // Log intent for debugging, but don't handle authorization callbacks here
        // Authorization callbacks should flow through Flutter's app_links/uni_links
        // so the UI layer can properly manage state and show loading/error feedback
        val data = intent.data
        Log.d(TAG, "onNewIntent - action: ${intent.action}, data: $data")

        // Let Flutter's app_links handle all deep links including OAuth callbacks
        // Flutter will call handleAuthorizationCallback() via Pigeon when needed
    }

    override fun onDestroy() {
        super.onDestroy()
        // Clean up - Note: Pigeon APIs typically don't need explicit teardown
        ssiApiImpl = null
    }
}
