package com.example.ssi

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*

class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "com.ssi.wallet/procivis"

    // In-memory storage for DIDs and credentials
    private val dids = mutableListOf<MutableMap<String, Any>>()
    private val credentials = mutableListOf<MutableMap<String, Any>>()
    private val interactions = mutableListOf<MutableMap<String, Any>>()

    // Procivis SDK will be added here when available
    // private var oneCore: OneCoreBinding? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            // Mock responses for testing UI without SDK
            when (call.method) {
                "initializeCore" -> {
                    val response = mapOf("success" to true)
                    result.success(response)
                }

                "getVersion" -> {
                    result.success("1.0.0-mock")
                }

                "createDid" -> {
                    val method = call.argument<String>("method") ?: "did:key"
                    val keyType = call.argument<String>("keyType") ?: "ES256"

                    val didId = "did-${UUID.randomUUID()}"
                    val didString = generateDidString(method)
                    val isDefault = dids.isEmpty() // First DID is default

                    // If this is set as default, unset other defaults
                    if (isDefault) {
                        dids.forEach { it["isDefault"] = false }
                    }

                    val newDid = mutableMapOf<String, Any>(
                        "id" to didId,
                        "didString" to didString,
                        "method" to method,
                        "keyType" to keyType,
                        "createdAt" to getCurrentISODateTime(),
                        "isDefault" to isDefault
                    )

                    dids.add(newDid)
                    result.success(newDid.toMap())
                }

                "getDids" -> {
                    result.success(dids.map { it.toMap() })
                }

                "getDid" -> {
                    val didId = call.argument<String>("didId")
                    val did = dids.find { it["id"] == didId }
                    if (did != null) {
                        result.success(did.toMap())
                    } else {
                        result.error("NOT_FOUND", "DID not found", null)
                    }
                }

                "deleteDid" -> {
                    val didId = call.argument<String>("didId")
                    val removed = dids.removeIf { it["id"] == didId }
                    result.success(removed)
                }

                "getCredentials" -> {
                    result.success(credentials.map { it.toMap() })
                }

                "getCredential" -> {
                    val credentialId = call.argument<String>("credentialId")
                    val credential = credentials.find { it["id"] == credentialId }
                    if (credential != null) {
                        result.success(credential.toMap())
                    } else {
                        result.error("NOT_FOUND", "Credential not found", null)
                    }
                }

                "acceptCredentialOffer" -> {
                    val offerId = call.argument<String>("offerId")
                    val holderDidId = call.argument<String>("holderDidId")

                    // Find holder DID
                    val holderDid = dids.find { it["id"] == holderDidId }?.get("didString") as? String
                        ?: dids.firstOrNull()?.get("didString") as? String
                        ?: "did:key:no-did-created"

                    val credentialId = "cred-${UUID.randomUUID()}"

                    val newCredential = mutableMapOf<String, Any>(
                        "id" to credentialId,
                        "name" to "New Credential",
                        "type" to "VerifiableCredential",
                        "format" to "JWT_VC",
                        "issuerName" to "Example Issuer",
                        "issuerDid" to "did:web:example.issuer.com",
                        "holderDid" to holderDid,
                        "issuedDate" to getCurrentISODateTime(),
                        "expiryDate" to getFutureISODateTime(365),
                        "claims" to mapOf(
                            "credentialSubject" to "Sample Data"
                        ),
                        "proofType" to "JwtProof2020",
                        "state" to "valid",
                        "backgroundColor" to "#6366F1",
                        "textColor" to "#FFFFFF"
                    )

                    credentials.add(newCredential)
                    result.success(newCredential.toMap())
                }

                "deleteCredential" -> {
                    val credentialId = call.argument<String>("credentialId")
                    val removed = credentials.removeIf { it["id"] == credentialId }
                    result.success(removed)
                }

                "checkCredentialStatus" -> {
                    result.success("valid")
                }

                "processPresentationRequest" -> {
                    val requestUrl = call.argument<String>("url")
                    val interactionId = "interaction-${UUID.randomUUID()}"

                    val interaction = mutableMapOf<String, Any>(
                        "id" to interactionId,
                        "type" to "presentation_request",
                        "verifierName" to "Example Verifier",
                        "requestedCredentials" to listOf("VerifiableCredential"),
                        "timestamp" to getCurrentISODateTime(),
                        "status" to "pending"
                    )

                    interactions.add(interaction)

                    val response = mapOf(
                        "interactionId" to interactionId,
                        "verifierName" to interaction["verifierName"],
                        "requestedCredentials" to interaction["requestedCredentials"]
                    )
                    result.success(response)
                }

                "submitPresentation" -> {
                    val interactionId = call.argument<String>("interactionId")
                    val interaction = interactions.find { it["id"] == interactionId }
                    interaction?.set("status", "accepted")
                    interaction?.set("completedAt", getCurrentISODateTime())
                    result.success(true)
                }

                "rejectPresentationRequest" -> {
                    val interactionId = call.argument<String>("interactionId")
                    val interaction = interactions.find { it["id"] == interactionId }
                    interaction?.set("status", "rejected")
                    interaction?.set("completedAt", getCurrentISODateTime())
                    result.success(true)
                }

                "getInteractionHistory" -> {
                    result.success(interactions.map { it.toMap() })
                }

                "exportBackup" -> {
                    val backup = mapOf(
                        "version" to "1.0",
                        "timestamp" to getCurrentISODateTime(),
                        "data" to "mock-backup-data"
                    )
                    result.success(backup)
                }

                "importBackup" -> {
                    result.success(true)
                }

                "getSupportedDidMethods" -> {
                    val methods = listOf("did:key", "did:web", "did:jwk")
                    result.success(methods)
                }

                "getSupportedCredentialFormats" -> {
                    val formats = listOf("JWT_VC", "SD-JWT", "ISO_MDL", "JSON-LD")
                    result.success(formats)
                }

                "uninitialize" -> {
                    result.success(true)
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun getCurrentISODateTime(): String {
        val sdf = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US)
        sdf.timeZone = TimeZone.getTimeZone("UTC")
        return sdf.format(Date())
    }

    private fun getFutureISODateTime(daysInFuture: Int): String {
        val calendar = Calendar.getInstance()
        calendar.add(Calendar.DAY_OF_YEAR, daysInFuture)
        val sdf = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US)
        sdf.timeZone = TimeZone.getTimeZone("UTC")
        return sdf.format(calendar.time)
    }

    private fun generateDidString(method: String): String {
        val randomId = UUID.randomUUID().toString().replace("-", "")
        return when (method) {
            "did:key" -> "did:key:z6Mk${randomId.substring(0, 44)}"
            "did:web" -> "did:web:example.com:user:${randomId.substring(0, 16)}"
            "did:jwk" -> "did:jwk:${randomId.substring(0, 32)}"
            else -> "did:key:z6Mk${randomId.substring(0, 44)}"
        }
    }
}