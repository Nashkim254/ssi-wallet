import 'package:logger/logger.dart';
import 'package:ssi/pigeon/ssi_api.g.dart';

/// Service for communicating with native SSI SDK via Pigeon API
class ProcivisService {
  final _api = SsiApi();
  final Logger _logger = Logger();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Initialize the SSI SDK
  Future<bool> initialize() async {
    try {
      _logger.i('Initializing SSI SDK...');
      final result = await _api.initialize();

      _isInitialized = result.success;

      if (!result.success && result.error != null) {
        _logger.e('Failed to initialize SSI SDK: ${result.error}');
      } else {
        _logger.i('SSI SDK initialized successfully');
      }

      return _isInitialized;
    } catch (e) {
      _logger.e('Unexpected error initializing SSI SDK: $e');
      return false;
    }
  }

  /// Get the version of the SSI SDK
  Future<String?> getVersion() async {
    try {
      final version = _api.getVersion();
      _logger.d('SSI SDK version: $version');
      return version;
    } catch (e) {
      _logger.e('Failed to get version: $e');
      return null;
    }
  }

  /// Create a new DID
  Future<Map<String, dynamic>?> createDid({
    required String method,
    required String keyType,
  }) async {
    try {
      _logger.i('Creating DID with method: $method, keyType: $keyType');
      final did = await _api.createDid(method, keyType);

      if (did != null) {
        return _didDtoToMap(did);
      }
      return null;
    } catch (e) {
      _logger.e('Failed to create DID: $e');
      return null;
    }
  }

  /// Get all DIDs
  Future<List<Map<String, dynamic>>> getDids() async {
    try {
      final dids = await _api.getDids();
      return dids.map(_didDtoToMap).toList();
    } catch (e) {
      _logger.e('Failed to get DIDs: $e');
      return [];
    }
  }

  /// Get a specific DID
  Future<Map<String, dynamic>?> getDid(String id) async {
    try {
      final did = await _api.getDid(id);
      if (did != null) {
        return _didDtoToMap(did);
      }
      return null;
    } catch (e) {
      _logger.e('Failed to get DID: $e');
      return null;
    }
  }

  /// Delete a DID
  Future<bool> deleteDid(String id) async {
    try {
      return await _api.deleteDid(id);
    } catch (e) {
      _logger.e('Failed to delete DID: $e');
      return false;
    }
  }

  /// Get all credentials
  Future<List<Map<String, dynamic>>> getCredentials() async {
    try {
      final credentials = await _api.getCredentials();
      return credentials.map(_credentialDtoToMap).toList();
    } catch (e) {
      _logger.e('Failed to get credentials: $e');
      return [];
    }
  }

  /// Get a specific credential
  Future<Map<String, dynamic>?> getCredential(String id) async {
    try {
      final credential = await _api.getCredential(id);
      if (credential != null) {
        return _credentialDtoToMap(credential);
      }
      return null;
    } catch (e) {
      _logger.e('Failed to get credential: $e');
      return null;
    }
  }

  /// Accept a credential offer
  Future<Map<String, dynamic>?> acceptCredentialOffer(
    String offerUrl, {
    String? holderDidId,
  }) async {
    try {
      final credential = await _api.acceptCredentialOffer(offerUrl, holderDidId);
      if (credential != null) {
        return _credentialDtoToMap(credential);
      }
      return null;
    } catch (e) {
      _logger.e('Failed to accept credential offer: $e');
      return null;
    }
  }

  /// Delete a credential
  Future<bool> deleteCredential(String id) async {
    try {
      return await _api.deleteCredential(id);
    } catch (e) {
      _logger.e('Failed to delete credential: $e');
      return false;
    }
  }

  /// Check credential status
  Future<Map<String, dynamic>?> checkCredentialStatus(String id) async {
    try {
      final status = await _api.checkCredentialStatus(id);
      return {'status': status};
    } catch (e) {
      _logger.e('Failed to check credential status: $e');
      return null;
    }
  }

  /// Process a presentation request
  Future<Map<String, dynamic>?> processPresentationRequest(String url) async {
    try {
      final interaction = await _api.processPresentationRequest(url);
      if (interaction != null) {
        return _interactionDtoToMap(interaction);
      }
      return null;
    } catch (e) {
      _logger.e('Failed to process presentation request: $e');
      return null;
    }
  }

  /// Submit a presentation
  Future<bool> submitPresentation(
    String interactionId,
    List<String> credentialIds,
  ) async {
    try {
      return await _api.submitPresentation(interactionId, credentialIds);
    } catch (e) {
      _logger.e('Failed to submit presentation: $e');
      return false;
    }
  }

  /// Reject a presentation request
  Future<bool> rejectPresentationRequest(String interactionId) async {
    try {
      return await _api.rejectPresentationRequest(interactionId);
    } catch (e) {
      _logger.e('Failed to reject presentation request: $e');
      return false;
    }
  }

  /// Get interaction history
  Future<List<Map<String, dynamic>>> getInteractionHistory() async {
    try {
      final interactions = await _api.getInteractionHistory();
      return interactions.map(_interactionDtoToMap).toList();
    } catch (e) {
      _logger.e('Failed to get interaction history: $e');
      return [];
    }
  }

  /// Export backup
  Future<Map<String, dynamic>?> exportBackup() async {
    try {
      final backup = await _api.exportBackup();
      return Map<String, dynamic>.from(backup);
    } catch (e) {
      _logger.e('Failed to export backup: $e');
      return null;
    }
  }

  /// Import backup
  Future<bool> importBackup(String backupData) async {
    try {
      return await _api.importBackup(backupData);
    } catch (e) {
      _logger.e('Failed to import backup: $e');
      return false;
    }
  }

  /// Get supported DID methods
  Future<List<String>> getSupportedDidMethods() async {
    try {
      return await _api.getSupportedDidMethods();
    } catch (e) {
      _logger.e('Failed to get supported DID methods: $e');
      return [];
    }
  }

  /// Get supported credential formats
  Future<List<String>> getSupportedCredentialFormats() async {
    try {
      return await _api.getSupportedCredentialFormats();
    } catch (e) {
      _logger.e('Failed to get supported credential formats: $e');
      return [];
    }
  }

  /// Uninitialize the SDK
  Future<bool> uninitialize() async {
    try {
      final result = await _api.uninitialize();
      _isInitialized = !result;
      return result;
    } catch (e) {
      _logger.e('Failed to uninitialize SDK: $e');
      return false;
    }
  }

  // Helper methods to convert DTOs to Maps
  Map<String, dynamic> _didDtoToMap(DidDto did) {
    return {
      'id': did.id,
      'didString': did.didString,
      'method': did.method,
      'keyType': did.keyType,
      'createdAt': did.createdAt,
      'isDefault': did.isDefault,
      'metadata': did.metadata,
    };
  }

  Map<String, dynamic> _credentialDtoToMap(CredentialDto credential) {
    return {
      'id': credential.id,
      'name': credential.name,
      'type': credential.type,
      'format': credential.format,
      'issuerName': credential.issuerName,
      'issuerDid': credential.issuerDid,
      'holderDid': credential.holderDid,
      'issuedDate': credential.issuedDate,
      'expiryDate': credential.expiryDate,
      'claims': credential.claims,
      'proofType': credential.proofType,
      'state': credential.state,
      'backgroundColor': credential.backgroundColor,
      'textColor': credential.textColor,
    };
  }

  Map<String, dynamic> _interactionDtoToMap(InteractionDto interaction) {
    return {
      'id': interaction.id,
      'type': interaction.type,
      'verifierName': interaction.verifierName,
      'requestedCredentials': interaction.requestedCredentials,
      'timestamp': interaction.timestamp,
      'status': interaction.status,
      'completedAt': interaction.completedAt,
    };
  }
}
