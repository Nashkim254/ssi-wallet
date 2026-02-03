import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/pigeon/ssi_api.g.dart',
  dartOptions: DartOptions(),
  kotlinOut: 'android/app/src/main/kotlin/com/example/ssi/SsiApi.kt',
  kotlinOptions: KotlinOptions(
    package: 'com.example.ssi',
    suspend: true,
  ),
  swiftOut: 'ios/Runner/SsiApi.swift',
  swiftOptions: SwiftOptions(),
  dartPackageName: 'ssi',
))

/// DID data transfer object
class DidDto {
  DidDto({
    required this.id,
    required this.didString,
    required this.method,
    required this.keyType,
    required this.createdAt,
    required this.isDefault,
    this.metadata,
  });

  final String id;
  final String didString;
  final String method;
  final String keyType;
  final String createdAt;
  final bool isDefault;
  final Map<String?, Object?>? metadata;
}

/// Credential data transfer object
class CredentialDto {
  CredentialDto({
    required this.id,
    required this.name,
    required this.type,
    required this.format,
    required this.issuerName,
    this.issuerDid,
    this.holderDid,
    required this.issuedDate,
    this.expiryDate,
    required this.claims,
    this.proofType,
    required this.state,
    this.backgroundColor,
    this.textColor,
  });

  final String id;
  final String name;
  final String type;
  final String format;
  final String issuerName;
  final String? issuerDid;
  final String? holderDid;
  final String issuedDate;
  final String? expiryDate;
  final Map<String?, Object?> claims;
  final String? proofType;
  final String state;
  final String? backgroundColor;
  final String? textColor;
}

/// Interaction data transfer object
class InteractionDto {
  InteractionDto({
    required this.id,
    required this.type,
    required this.verifierName,
    required this.requestedCredentials,
    required this.timestamp,
    required this.status,
    this.completedAt,
  });

  final String id;
  final String type;
  final String verifierName;
  final List<String?> requestedCredentials;
  final String timestamp;
  final String status;
  final String? completedAt;
}

/// Result wrapper for operations
class OperationResult {
  OperationResult({
    required this.success,
    this.error,
    this.data,
  });

  final bool success;
  final String? error;
  final Map<String?, Object?>? data;
}

/// Main SSI API for native platform communication
@HostApi()
abstract class SsiApi {
  /// Initialize the SSI SDK
  @async
  OperationResult initialize();

  /// Get SDK version
  String getVersion();

  /// Create a new DID
  @async
  DidDto? createDid(String method, String keyType);

  /// Get all DIDs
  @async
  List<DidDto> getDids();

  /// Get a specific DID by ID
  @async
  DidDto? getDid(String didId);

  /// Delete a DID
  @async
  bool deleteDid(String didId);

  /// Get all credentials
  @async
  List<CredentialDto> getCredentials();

  /// Get a specific credential by ID
  @async
  CredentialDto? getCredential(String credentialId);

  /// Accept a credential offer
  @async
  CredentialDto? acceptCredentialOffer(String offerId, String? holderDidId);

  /// Delete a credential
  @async
  bool deleteCredential(String credentialId);

  /// Check credential status
  @async
  String checkCredentialStatus(String credentialId);

  /// Process a presentation request
  @async
  InteractionDto? processPresentationRequest(String url);

  /// Submit a presentation
  @async
  bool submitPresentation(String interactionId, List<String> credentialIds);

  /// Reject a presentation request
  @async
  bool rejectPresentationRequest(String interactionId);

  /// Get interaction history
  @async
  List<InteractionDto> getInteractionHistory();

  /// Export backup
  @async
  Map<String?, Object?> exportBackup();

  /// Import backup
  @async
  bool importBackup(String backupData);

  /// Get supported DID methods
  @async
  List<String> getSupportedDidMethods();

  /// Get supported credential formats
  @async
  List<String> getSupportedCredentialFormats();

  /// Uninitialize SDK
  @async
  bool uninitialize();

  /// Handle authorization response from EUDI issuer
  /// Called when the app receives the authorization callback deep link
  @async
  bool handleAuthorizationCallback(String authorizationResponseUri);

  /// Get debug logs from the native SDK
  /// Returns the last 1000 lines of logs for debugging
  @async
  String getDebugLogs();
}
