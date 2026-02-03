package com.example.ssi

import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.util.Log
import eu.europa.ec.eudi.wallet.EudiWallet
import eu.europa.ec.eudi.wallet.EudiWalletConfig
import eu.europa.ec.eudi.wallet.document.CreateDocumentSettings
import eu.europa.ec.eudi.wallet.document.IssuedDocument
import eu.europa.ec.eudi.wallet.issue.openid4vci.IssueEvent
import eu.europa.ec.eudi.wallet.issue.openid4vci.OpenId4VciManager
import eu.europa.ec.eudi.wallet.logging.Logger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.File
import java.io.FileWriter
import java.net.URLDecoder
import java.text.SimpleDateFormat
import java.time.Instant
import java.time.temporal.ChronoUnit
import java.util.Date
import java.util.Locale

/**
 * Implementation of SsiApi using EU Digital Identity Wallet Core Library
 */
class EudiSsiApiImpl(private val context: Context) : SsiApi {

    companion object {
        private const val TAG = "EudiSsiApiImpl"
        private const val PREFS_NAME = "eudi_wallet_prefs"
        private const val PREF_PENDING_OFFER_URL = "pending_offer_url"
        private const val PREF_PENDING_ISSUER_URL = "pending_issuer_url"
        private const val LOG_FILE_NAME = "credential_issuance.log"
    }

    private val coroutineScope = CoroutineScope(Dispatchers.IO)
    private var wallet: EudiWallet? = null
    private val prefs: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    // In-memory storage for DIDs (EUDI wallet focuses on credentials/documents)
    private val dids = mutableListOf<DidDto>()
    private val interactions = mutableListOf<InteractionDto>()

    private var isInitialized = false

    // Store the active OpenId4VciManager to handle authorization callbacks
    private var activeOpenId4VciManager: OpenId4VciManager? = null
    private var activeOfferUrl: String? = null
    private var processedAuthorizationUri: String? = null

    /**
     * Log to both logcat and persistent file for debugging even when adb disconnects
     */
    private fun logToFile(level: String, message: String, throwable: Throwable? = null) {
        // Log to logcat
        when (level) {
            "D" -> Log.d(TAG, message, throwable)
            "E" -> Log.e(TAG, message, throwable)
            "W" -> Log.w(TAG, message, throwable)
            else -> Log.i(TAG, message, throwable)
        }

        // Also log to file
        try {
            val logFile = File(context.filesDir, LOG_FILE_NAME)
            val timestamp = SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.US).format(Date())
            val logEntry = "[$timestamp] $level/$TAG: $message${throwable?.let { "\n${it.stackTraceToString()}" } ?: ""}\n"

            FileWriter(logFile, true).use { writer ->
                writer.append(logEntry)
            }

            // Keep log file size reasonable (max 500KB)
            if (logFile.length() > 500_000) {
                val lines = logFile.readLines()
                logFile.writeText(lines.takeLast(1000).joinToString("\n"))
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to write to log file", e)
        }
    }

    override fun initialize(callback: (Result<OperationResult>) -> Unit) {
        coroutineScope.launch {
            try {
                Log.d(TAG, "Initializing EUDI Wallet...")

                // Configure storage directory
                val storageDir = File(context.noBackupFilesDir, "eudi_documents")
                if (!storageDir.exists()) {
                    storageDir.mkdirs()
                }
                val storageFile = File(storageDir, "eudi_wallet.db")

                // Build EUDI Wallet configuration
                // Note: OpenId4Vci configuration is done per-offer, not globally
                val config = EudiWalletConfig()
                    .configureDocumentManager(
                        storagePath = storageFile.absolutePath,
                        identifier = null
                    )
                    .configureLogging(level = Logger.LEVEL_DEBUG)

                // Initialize wallet
                wallet = EudiWallet(context, config)
                isInitialized = true

                Log.d(TAG, "EUDI Wallet initialized successfully")

                withContext(Dispatchers.Main) {
                    callback(Result.success(
                        OperationResult(
                            success = true,
                            error = null,
                            data = mapOf(
                                "initialized" to true,
                                "version" to "EUDI Wallet v0.23.0",
                                "storageDir" to storageDir.absolutePath
                            )
                        )
                    ))
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to initialize EUDI Wallet", e)
                withContext(Dispatchers.Main) {
                    callback(Result.success(
                        OperationResult(
                            success = false,
                            error = "Initialization failed: ${e.message}",
                            data = null
                        )
                    ))
                }
            }
        }
    }

    override fun getVersion(): String {
        return "EU Digital Identity Wallet v0.23.0"
    }

    override fun createDid(method: String, keyType: String, callback: (Result<DidDto?>) -> Unit) {
        coroutineScope.launch {
            try {
                val didId = "did-${java.util.UUID.randomUUID()}"
                val didString = generateDidString(method)
                val isDefault = dids.isEmpty()

                // If this is the default, unset other defaults
                if (isDefault) {
                    dids.forEachIndexed { index, did ->
                        dids[index] = did.copy(isDefault = false)
                    }
                }

                val newDid = DidDto(
                    id = didId,
                    didString = didString,
                    method = method,
                    keyType = keyType,
                    createdAt = getCurrentISODateTime(),
                    isDefault = isDefault,
                    metadata = null
                )

                dids.add(newDid)

                withContext(Dispatchers.Main) {
                    callback(Result.success(newDid))
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to create DID", e)
                withContext(Dispatchers.Main) {
                    callback(Result.failure(e))
                }
            }
        }
    }

    override fun getDids(callback: (Result<List<DidDto>>) -> Unit) {
        coroutineScope.launch {
            withContext(Dispatchers.Main) {
                callback(Result.success(dids.toList()))
            }
        }
    }

    override fun getDid(didId: String, callback: (Result<DidDto?>) -> Unit) {
        coroutineScope.launch {
            val did = dids.find { it.id == didId }
            withContext(Dispatchers.Main) {
                callback(Result.success(did))
            }
        }
    }

    override fun deleteDid(didId: String, callback: (Result<Boolean>) -> Unit) {
        coroutineScope.launch {
            val removed = dids.removeIf { it.id == didId }
            withContext(Dispatchers.Main) {
                callback(Result.success(removed))
            }
        }
    }

    override fun getCredentials(callback: (Result<List<CredentialDto>>) -> Unit) {
        coroutineScope.launch {
            try {
                val eudiWallet = wallet
                if (eudiWallet == null) {
                    Log.w(TAG, "Wallet not initialized when getting credentials")
                    withContext(Dispatchers.Main) {
                        callback(Result.success(emptyList()))
                    }
                    return@launch
                }

                val documents = eudiWallet.getDocuments()
                val credentials = documents.mapNotNull { document ->
                    when (document) {
                        is IssuedDocument -> documentToCredentialDto(document)
                        else -> null
                    }
                }

                Log.d(TAG, "Retrieved ${credentials.size} credentials from wallet")

                withContext(Dispatchers.Main) {
                    callback(Result.success(credentials))
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to get credentials", e)
                withContext(Dispatchers.Main) {
                    callback(Result.success(emptyList()))
                }
            }
        }
    }

    override fun getCredential(credentialId: String, callback: (Result<CredentialDto?>) -> Unit) {
        coroutineScope.launch {
            try {
                val eudiWallet = wallet
                if (eudiWallet == null) {
                    withContext(Dispatchers.Main) {
                        callback(Result.success(null))
                    }
                    return@launch
                }

                val document = eudiWallet.getDocumentById(credentialId)
                val credential = when (document) {
                    is IssuedDocument -> documentToCredentialDto(document)
                    else -> null
                }

                withContext(Dispatchers.Main) {
                    callback(Result.success(credential))
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to get credential: $credentialId", e)
                withContext(Dispatchers.Main) {
                    callback(Result.success(null))
                }
            }
        }
    }

    override fun acceptCredentialOffer(
        offerUrl: String,
        holderDidId: String?,
        callback: (Result<CredentialDto?>) -> Unit
    ) {
        coroutineScope.launch {
            try {
                logToFile("I", "=========================================")
                logToFile("I", "acceptCredentialOffer() called")
                logToFile("I", "Processing credential offer: $offerUrl")

                val eudiWallet = wallet
                if (eudiWallet == null) {
                    Log.e(TAG, "Wallet not initialized")
                    withContext(Dispatchers.Main) {
                        callback(Result.failure(Exception("Wallet not initialized")))
                    }
                    return@launch
                }

                // Extract issuer URL from the credential offer
                val issuerUrl = extractIssuerUrl(offerUrl)
                Log.d(TAG, "Extracted issuer URL: $issuerUrl")

                // Store offer URL and issuer URL for later retrieval (in case app is killed)
                prefs.edit().apply {
                    putString(PREF_PENDING_OFFER_URL, offerUrl)
                    putString(PREF_PENDING_ISSUER_URL, issuerUrl)
                    apply()
                }
                activeOfferUrl = offerUrl

                // Create OpenID4VCI configuration for this offer
                val openId4VciConfig = OpenId4VciManager.Config(
                    issuerUrl = issuerUrl,
                    clientAuthenticationType = OpenId4VciManager.ClientAuthenticationType.None("wallet-dev"),
                    authFlowRedirectionURI = "eudi-openid4ci://authorize"
                )

                // Use EUDI Wallet's OpenID4VCI manager to handle the credential offer
                val openId4VciManager = eudiWallet.createOpenId4VciManager(openId4VciConfig)

                // Store the manager instance to handle authorization callback
                activeOpenId4VciManager = openId4VciManager

                var issuedCredential: CredentialDto? = null
                val deferredResult = CompletableDeferred<Result<CredentialDto?>>()

                logToFile("I", "========== STARTING CREDENTIAL ISSUANCE ==========")
                logToFile("I", "Offer URL: $offerUrl")
                logToFile("I", "Issuer URL: $issuerUrl")
                logToFile("I", "Calling issueDocumentByOfferUri...")

                openId4VciManager.issueDocumentByOfferUri(
                    offerUri = offerUrl,
                    txCode = null,
                    executor = null,
                    onIssueEvent = object : OpenId4VciManager.OnIssueEvent {
                        override fun onResult(event: IssueEvent) {
                            logToFile("I", "========== ISSUE EVENT: ${event.javaClass.simpleName} ==========")
                            logToFile("I", "Thread: ${Thread.currentThread().name}")
                            logToFile("I", "Event details: $event")
                            when (event) {
                                is IssueEvent.DocumentIssued -> {
                                    try {
                                        issuedCredential = documentToCredentialDto(event.document)
                                        logToFile("I", "SUCCESS: Credential issued - ID: ${issuedCredential?.id}, Name: ${issuedCredential?.name}")
                                    } catch (e: Exception) {
                                        logToFile("E", "Failed to convert document to credential", e)
                                        deferredResult.completeExceptionally(e)
                                    }
                                }
                                is IssueEvent.Finished -> {
                                    logToFile("I", "SUCCESS: Finished issuing documents: ${event.issuedDocuments.size} issued")
                                    event.issuedDocuments.forEachIndexed { index, doc ->
                                        try {
                                            when (doc) {
                                                is IssuedDocument -> logToFile("I", "  Document $index: ID=${doc.id}, Name=${doc.name}")
                                                else -> logToFile("I", "  Document $index: ${doc.javaClass.simpleName}")
                                            }
                                        } catch (e: Exception) {
                                            logToFile("W", "  Document $index: Unable to get details")
                                        }
                                    }
                                    // Clean up state
                                    clearPendingOffer()
                                    deferredResult.complete(Result.success(issuedCredential))
                                }
                                is IssueEvent.Failure -> {
                                    logToFile("E", "FAILURE: Issuance failed", event.cause)
                                    // Clean up state
                                    clearPendingOffer()
                                    deferredResult.completeExceptionally(event.cause)
                                }
                                is IssueEvent.DocumentFailed -> {
                                    logToFile("E", "FAILURE: Document failed", event.cause)
                                    // Clean up state
                                    clearPendingOffer()
                                    deferredResult.completeExceptionally(event.cause)
                                }
                                is IssueEvent.DocumentRequiresUserAuth -> {
                                    logToFile("I", "Document requires user authentication")
                                    val unlockData = event.keysRequireAuth.mapKeys { it.key }
                                        .mapValues { null }
                                    event.resume(unlockData)
                                }
                                is IssueEvent.DocumentRequiresCreateSettings -> {
                                    logToFile("I", "Document requires create settings - using Android Keystore defaults")
                                    // Resume with default settings using Android Keystore
                                    // The EUDI SDK uses "AndroidKeystoreSecureArea" by default
                                    try {
                                        @OptIn(kotlin.time.ExperimentalTime::class)
                                        val settings = CreateDocumentSettings(
                                            secureAreaIdentifier = "AndroidKeystoreSecureArea",
                                            createKeySettings = org.multipaz.securearea.CreateKeySettings()
                                        )
                                        logToFile("I", "Created document settings, resuming issuance")
                                        event.resume(settings)
                                    } catch (e: Exception) {
                                        logToFile("E", "Failed to create document settings", e)
                                        deferredResult.completeExceptionally(e)
                                    }
                                }
                                else -> {
                                    logToFile("D", "Unhandled issue event: ${event.javaClass.simpleName}")
                                }
                            }
                        }
                    }
                )

                logToFile("I", "issueDocumentByOfferUri() returned, now waiting for events...")
                logToFile("I", "This will block until IssueEvent.Finished or Failure is received")

                val result = deferredResult.await()

                logToFile("I", "deferredResult.await() completed!")
                logToFile("I", "Result success: ${result.isSuccess}, Credential: ${result.getOrNull()?.id}")

                withContext(Dispatchers.Main) {
                    callback(result)
                }
            } catch (e: Exception) {
                logToFile("E", "Failed to accept credential offer", e)
                clearPendingOffer()
                withContext(Dispatchers.Main) {
                    callback(Result.failure(Exception("Failed to accept offer: ${e.message}")))
                }
            }
        }
    }

    override fun deleteCredential(credentialId: String, callback: (Result<Boolean>) -> Unit) {
        coroutineScope.launch {
            try {
                val eudiWallet = wallet
                if (eudiWallet == null) {
                    withContext(Dispatchers.Main) {
                        callback(Result.success(false))
                    }
                    return@launch
                }

                val deleted = eudiWallet.deleteDocumentById(credentialId).isSuccess
                Log.d(TAG, "Delete credential $credentialId: $deleted")

                withContext(Dispatchers.Main) {
                    callback(Result.success(deleted))
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to delete credential: $credentialId", e)
                withContext(Dispatchers.Main) {
                    callback(Result.success(false))
                }
            }
        }
    }

    override fun checkCredentialStatus(credentialId: String, callback: (Result<String>) -> Unit) {
        coroutineScope.launch {
            try {
                // EUDI wallet doesn't have explicit status check method in basic API
                // Would need to implement via credential status list or revocation registry
                withContext(Dispatchers.Main) {
                    callback(Result.success("valid"))
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to check credential status: $credentialId", e)
                withContext(Dispatchers.Main) {
                    callback(Result.success("unknown"))
                }
            }
        }
    }

    override fun processPresentationRequest(url: String, callback: (Result<InteractionDto?>) -> Unit) {
        coroutineScope.launch {
            try {
                val interactionId = "interaction-${java.util.UUID.randomUUID()}"

                // Parse the presentation request
                // In EUDI wallet, this would be done via OpenId4VpManager
                val interaction = InteractionDto(
                    id = interactionId,
                    type = "presentation_request",
                    verifierName = "Verifier",
                    requestedCredentials = listOf("VerifiableCredential"),
                    timestamp = getCurrentISODateTime(),
                    status = "pending",
                    completedAt = null
                )

                interactions.add(interaction)

                withContext(Dispatchers.Main) {
                    callback(Result.success(interaction))
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to process presentation request", e)
                withContext(Dispatchers.Main) {
                    callback(Result.failure(e))
                }
            }
        }
    }

    override fun submitPresentation(
        interactionId: String,
        credentialIds: List<String>,
        callback: (Result<Boolean>) -> Unit
    ) {
        coroutineScope.launch {
            try {
                // Find the interaction
                val interaction = interactions.find { it.id == interactionId }
                if (interaction != null) {
                    val index = interactions.indexOf(interaction)
                    interactions[index] = interaction.copy(
                        status = "accepted",
                        completedAt = getCurrentISODateTime()
                    )

                    withContext(Dispatchers.Main) {
                        callback(Result.success(true))
                    }
                } else {
                    withContext(Dispatchers.Main) {
                        callback(Result.success(false))
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to submit presentation", e)
                withContext(Dispatchers.Main) {
                    callback(Result.success(false))
                }
            }
        }
    }

    override fun rejectPresentationRequest(interactionId: String, callback: (Result<Boolean>) -> Unit) {
        coroutineScope.launch {
            try {
                val interaction = interactions.find { it.id == interactionId }
                if (interaction != null) {
                    val index = interactions.indexOf(interaction)
                    interactions[index] = interaction.copy(
                        status = "rejected",
                        completedAt = getCurrentISODateTime()
                    )

                    withContext(Dispatchers.Main) {
                        callback(Result.success(true))
                    }
                } else {
                    withContext(Dispatchers.Main) {
                        callback(Result.success(false))
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to reject presentation request", e)
                withContext(Dispatchers.Main) {
                    callback(Result.success(false))
                }
            }
        }
    }

    override fun getInteractionHistory(callback: (Result<List<InteractionDto>>) -> Unit) {
        coroutineScope.launch {
            withContext(Dispatchers.Main) {
                callback(Result.success(interactions.toList()))
            }
        }
    }

    override fun exportBackup(callback: (Result<Map<String?, Any?>>) -> Unit) {
        coroutineScope.launch {
            try {
                val eudiWallet = wallet
                if (eudiWallet == null) {
                    withContext(Dispatchers.Main) {
                        callback(Result.success(mapOf("error" to "Wallet not initialized")))
                    }
                    return@launch
                }

                val documents = eudiWallet.getDocuments()
                val backup = mapOf<String?, Any?>(
                    "version" to "1.0",
                    "timestamp" to getCurrentISODateTime(),
                    "dids" to dids.size,
                    "credentials" to documents.size,
                    "walletType" to "EUDI"
                )

                withContext(Dispatchers.Main) {
                    callback(Result.success(backup))
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to export backup", e)
                withContext(Dispatchers.Main) {
                    callback(Result.success(mapOf("error" to e.message)))
                }
            }
        }
    }

    override fun importBackup(backupData: String, callback: (Result<Boolean>) -> Unit) {
        coroutineScope.launch {
            try {
                // Backup/restore functionality would need custom implementation
                // EUDI wallet doesn't have built-in backup/restore
                withContext(Dispatchers.Main) {
                    callback(Result.success(true))
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to import backup", e)
                withContext(Dispatchers.Main) {
                    callback(Result.success(false))
                }
            }
        }
    }

    override fun getSupportedDidMethods(callback: (Result<List<String>>) -> Unit) {
        coroutineScope.launch {
            withContext(Dispatchers.Main) {
                callback(Result.success(listOf("did:key", "did:web", "did:jwk", "did:ebsi")))
            }
        }
    }

    override fun getSupportedCredentialFormats(callback: (Result<List<String>>) -> Unit) {
        coroutineScope.launch {
            withContext(Dispatchers.Main) {
                callback(Result.success(listOf("mso_mdoc", "sd-jwt-vc", "JWT_VC", "JSON-LD")))
            }
        }
    }

    override fun uninitialize(callback: (Result<Boolean>) -> Unit) {
        coroutineScope.launch {
            try {
                isInitialized = false
                wallet = null
                dids.clear()
                interactions.clear()

                withContext(Dispatchers.Main) {
                    callback(Result.success(true))
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to uninitialize", e)
                withContext(Dispatchers.Main) {
                    callback(Result.success(false))
                }
            }
        }
    }

    // Helper functions
    private fun documentToCredentialDto(document: IssuedDocument): CredentialDto {
        return CredentialDto(
            id = document.id,
            name = document.name,
            type = "VerifiableCredential",
            format = when {
                document.name.contains("mdoc", ignoreCase = true) -> "mso_mdoc"
                document.name.contains("sd-jwt", ignoreCase = true) -> "sd-jwt-vc"
                document.name.contains("pid", ignoreCase = true) -> "mso_mdoc"
                else -> "mso_mdoc"
            },
            issuerName = "EU Issuer",
            issuerDid = "did:web:issuer.europa.eu",
            holderDid = dids.firstOrNull()?.didString ?: "did:key:holder",
            issuedDate = document.createdAt.toString(),
            expiryDate = getFutureISODateTime(365),
            claims = mapOf(
                "documentType" to document.name,
                "documentId" to document.id
            ),
            proofType = "ECDSA",
            state = "valid",
            backgroundColor = "#003399",
            textColor = "#FFCC00"
        )
    }

    private fun generateDidString(method: String): String {
        val randomId = java.util.UUID.randomUUID().toString().replace("-", "")
        return when (method) {
            "did:key" -> "did:key:z6Mk${randomId.substring(0, 44)}"
            "did:web" -> "did:web:example.com:user:${randomId.substring(0, 16)}"
            "did:jwk" -> "did:jwk:${randomId.substring(0, 32)}"
            "did:ebsi" -> "did:ebsi:${randomId.substring(0, 32)}"
            else -> "did:key:z6Mk${randomId.substring(0, 44)}"
        }
    }

    private fun getCurrentISODateTime(): String {
        return Instant.now().toString()
    }

    private fun getFutureISODateTime(daysInFuture: Int): String {
        return Instant.now().plus(daysInFuture.toLong(), ChronoUnit.DAYS).toString()
    }

    /**
     * Handle authorization response from EUDI issuer (called from MainActivity)
     * This method is for when MainActivity.onNewIntent captures the deep link
     */
    fun handleAuthorizationResponse(responseUri: String) {
        coroutineScope.launch {
            try {
                Log.d(TAG, "Handling authorization response (from MainActivity): $responseUri")

                // Check if we've already processed this exact URI to prevent duplicate processing
                if (processedAuthorizationUri == responseUri) {
                    Log.w(TAG, "Authorization URI already processed, ignoring duplicate")
                    return@launch
                }
                processedAuthorizationUri = responseUri

                val manager = activeOpenId4VciManager

                if (manager == null) {
                    Log.e(TAG, "No active OpenId4VciManager - SDK lost state due to app restart")
                    Log.e(TAG, "Authorization flow cannot be recovered. User must restart credential offer.")

                    // Clear any stale state
                    clearPendingOffer()
                    return@launch
                }

                // Parse the response URI
                val uri = Uri.parse(responseUri)

                Log.d(TAG, "Resuming authorization with URI: $uri")

                // Resume the authorization flow with the callback URI
                // This will trigger the SDK to exchange the authorization code for tokens
                // and continue with credential issuance
                manager.resumeWithAuthorization(uri)

                Log.d(TAG, "Authorization resumed successfully - SDK will complete token exchange")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to handle authorization response", e)
                clearPendingOffer()
            }
        }
    }

    /**
     * Handle authorization callback from Flutter/Pigeon
     * This is called when Flutter's AppLinks intercepts the deep link before MainActivity
     */
    override fun handleAuthorizationCallback(
        authorizationResponseUri: String,
        callback: (Result<Boolean>) -> Unit
    ) {
        coroutineScope.launch {
            try {
                logToFile("I", "========== AUTHORIZATION CALLBACK START ==========")
                logToFile("I", "Handling authorization callback (from Flutter): $authorizationResponseUri")

                val manager = activeOpenId4VciManager

                if (manager == null) {
                    logToFile("E", "CRITICAL: No active OpenId4VciManager - SDK lost state due to app restart")
                    logToFile("E", "Authorization flow cannot be recovered. User must restart credential offer.")
                    logToFile("E", "This happens when Android kills the app during browser authorization")

                    // Don't mark as processed since we couldn't actually process it
                    // Clear any stale state including the processed URI marker
                    clearPendingOffer()

                    withContext(Dispatchers.Main) {
                        callback(Result.success(false))
                    }
                    return@launch
                }

                // Check if we've already processed this exact URI to prevent duplicate processing
                // Only check this AFTER we've confirmed there's an active manager
                if (processedAuthorizationUri == authorizationResponseUri) {
                    logToFile("W", "Authorization URI already processed by active manager, ignoring duplicate")
                    withContext(Dispatchers.Main) {
                        callback(Result.success(true))
                    }
                    return@launch
                }

                // Mark as processed now that we're actually going to process it
                processedAuthorizationUri = authorizationResponseUri
                logToFile("I", "Marked authorization URI as processed, proceeding with resumeWithAuthorization")

                // Parse the response URI
                val uri = Uri.parse(authorizationResponseUri)

                logToFile("I", "Parsed URI - Code present: ${uri.getQueryParameter("code") != null}, State: ${uri.getQueryParameter("state")}")
                logToFile("I", "Active manager exists: ${activeOpenId4VciManager != null}")
                logToFile("I", "Active offer URL: $activeOfferUrl")
                logToFile("I", "Calling resumeWithAuthorization...")

                // Resume the authorization flow with the callback URI
                // This will trigger the SDK to exchange the authorization code for tokens
                // and continue with credential issuance
                try {
                    manager.resumeWithAuthorization(uri)
                    logToFile("I", "resumeWithAuthorization() call completed successfully")
                    logToFile("I", "Now waiting for SDK to fire IssueEvent callbacks...")
                    logToFile("I", "If no ISSUE EVENT appears below, the SDK may not be triggering callbacks")
                } catch (e: Exception) {
                    logToFile("E", "resumeWithAuthorization() threw exception", e)
                    throw e
                }

                logToFile("I", "Authorization callback handled - returning to Flutter")

                withContext(Dispatchers.Main) {
                    callback(Result.success(true))
                }
            } catch (e: Exception) {
                logToFile("E", "FATAL: Failed to handle authorization callback", e)
                clearPendingOffer()
                withContext(Dispatchers.Main) {
                    callback(Result.success(false))
                }
            }
        }
    }

    /**
     * Extract issuer URL from credential offer URL
     * Handles both HAIP scheme and OpenID4VCI scheme URLs
     */
    private fun extractIssuerUrl(offerUrl: String): String {
        try {
            val uri = Uri.parse(offerUrl)

            // Get the credential_offer parameter
            val credentialOfferParam = uri.getQueryParameter("credential_offer")

            if (credentialOfferParam != null) {
                // Parse the JSON credential offer
                val credentialOfferJson = JSONObject(credentialOfferParam)
                val issuerUrl = credentialOfferJson.getString("credential_issuer")
                Log.d(TAG, "Extracted issuer URL from credential_offer parameter: $issuerUrl")
                return issuerUrl
            }

            // Fallback: try to get credential_offer_uri and fetch it
            val credentialOfferUri = uri.getQueryParameter("credential_offer_uri")
            if (credentialOfferUri != null) {
                Log.d(TAG, "Found credential_offer_uri, but fetching not implemented. Falling back to default.")
            }

            // Default fallback
            Log.w(TAG, "Could not extract issuer URL from offer, using default")
            return "https://issuer.eudiw.dev"
        } catch (e: Exception) {
            Log.e(TAG, "Error extracting issuer URL from offer", e)
            return "https://issuer.eudiw.dev"
        }
    }

    /**
     * Clear pending offer state from SharedPreferences
     */
    private fun clearPendingOffer() {
        prefs.edit().apply {
            remove(PREF_PENDING_OFFER_URL)
            remove(PREF_PENDING_ISSUER_URL)
            apply()
        }
        activeOpenId4VciManager = null
        activeOfferUrl = null
        processedAuthorizationUri = null
        logToFile("I", "Cleared pending offer state")
    }

    override fun getDebugLogs(callback: (Result<String>) -> Unit) {
        coroutineScope.launch {
            try {
                val logFile = File(context.filesDir, LOG_FILE_NAME)
                val logs = if (logFile.exists()) {
                    logFile.readText()
                } else {
                    "No logs available yet."
                }

                withContext(Dispatchers.Main) {
                    callback(Result.success(logs))
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    callback(Result.success("Error reading logs: ${e.message}"))
                }
            }
        }
    }
}
