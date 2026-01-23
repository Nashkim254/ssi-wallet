import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

/// Service for communicating with Procivis One Core via platform channels
class ProcivisService {
  static const MethodChannel _channel =
      MethodChannel('com.ssi.wallet/procivis');
  final Logger _logger = Logger();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Initialize the Procivis One Core
  Future<bool> initialize() async {
    try {
      _logger.i('Initializing Procivis One Core...');
      final result = await _channel.invokeMethod('initializeCore');

      // Handle different return types from the platform
      if (result is bool) {
        _isInitialized = result;
      } else if (result is Map) {
        // If platform returns a Map, check for success key or default to true
        _isInitialized = (result['success'] as bool?) ?? true;
      } else {
        // For any other type or null, default to true (optimistic initialization)
        _isInitialized = result != null;
      }

      _logger.i('Procivis One Core initialized: $_isInitialized');
      return _isInitialized;
    } on PlatformException catch (e) {
      _logger.e('Failed to initialize Procivis Core: ${e.message}');
      return false;
    } catch (e) {
      _logger.e('Unexpected error initializing Procivis Core: $e');
      return false;
    }
  }

  /// Get the version of Procivis One Core
  Future<String?> getVersion() async {
    try {
      final version = await _channel.invokeMethod<String>('getVersion');
      _logger.d('Procivis One Core version: $version');
      return version;
    } on PlatformException catch (e) {
      _logger.e('Failed to get version: ${e.message}');
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
      final result = await _channel.invokeMethod<Map>('createDid', {
        'method': method,
        'keyType': keyType,
      });

      if (result != null) {
        return Map<String, dynamic>.from(result);
      }
      return null;
    } on PlatformException catch (e) {
      _logger.e('Failed to create DID: ${e.message}');
      return null;
    }
  }

  /// Get all DIDs
  Future<List<Map<String, dynamic>>> getDids() async {
    try {
      final result = await _channel.invokeMethod<List>('getDids');
      if (result != null) {
        return result.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } on PlatformException catch (e) {
      _logger.e('Failed to get DIDs: ${e.message}');
      return [];
    }
  }

  /// Get a specific DID by ID
  Future<Map<String, dynamic>?> getDid(String didId) async {
    try {
      final result =
          await _channel.invokeMethod<Map>('getDid', {'didId': didId});
      if (result != null) {
        return Map<String, dynamic>.from(result);
      }
      return null;
    } on PlatformException catch (e) {
      _logger.e('Failed to get DID: ${e.message}');
      return null;
    }
  }

  /// Delete a DID
  Future<bool> deleteDid(String didId) async {
    try {
      final result =
          await _channel.invokeMethod<bool>('deleteDid', {'didId': didId});
      return result ?? false;
    } on PlatformException catch (e) {
      _logger.e('Failed to delete DID: ${e.message}');
      return false;
    }
  }

  /// Get all credentials
  Future<List<Map<String, dynamic>>> getCredentials() async {
    try {
      final result = await _channel.invokeMethod<List>('getCredentials');
      if (result != null) {
        return result.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } on PlatformException catch (e) {
      _logger.e('Failed to get credentials: ${e.message}');
      return [];
    }
  }

  /// Get a specific credential by ID
  Future<Map<String, dynamic>?> getCredential(String credentialId) async {
    try {
      final result = await _channel.invokeMethod<Map>('getCredential', {
        'credentialId': credentialId,
      });
      if (result != null) {
        return Map<String, dynamic>.from(result);
      }
      return null;
    } on PlatformException catch (e) {
      _logger.e('Failed to get credential: ${e.message}');
      return null;
    }
  }

  /// Accept a credential offer
  Future<Map<String, dynamic>?> acceptCredentialOffer(String offerUrl) async {
    try {
      _logger.i('Accepting credential offer: $offerUrl');
      final result = await _channel.invokeMethod<Map>('acceptCredentialOffer', {
        'offerUrl': offerUrl,
      });
      if (result != null) {
        return Map<String, dynamic>.from(result);
      }
      return null;
    } on PlatformException catch (e) {
      _logger.e('Failed to accept credential offer: ${e.message}');
      return null;
    }
  }

  /// Delete a credential
  Future<bool> deleteCredential(String credentialId) async {
    try {
      final result = await _channel.invokeMethod<bool>('deleteCredential', {
        'credentialId': credentialId,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      _logger.e('Failed to delete credential: ${e.message}');
      return false;
    }
  }

  /// Process a presentation request
  Future<Map<String, dynamic>?> processPresentationRequest(
      String requestUrl) async {
    try {
      _logger.i('Processing presentation request: $requestUrl');
      final result =
          await _channel.invokeMethod<Map>('processPresentationRequest', {
        'requestUrl': requestUrl,
      });
      if (result != null) {
        return Map<String, dynamic>.from(result);
      }
      return null;
    } on PlatformException catch (e) {
      _logger.e('Failed to process presentation request: ${e.message}');
      return null;
    }
  }

  /// Submit a presentation
  Future<bool> submitPresentation({
    required String interactionId,
    required List<String> selectedCredentialIds,
  }) async {
    try {
      _logger.i('Submitting presentation for interaction: $interactionId');
      final result = await _channel.invokeMethod<bool>('submitPresentation', {
        'interactionId': interactionId,
        'selectedCredentialIds': selectedCredentialIds,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      _logger.e('Failed to submit presentation: ${e.message}');
      return false;
    }
  }

  /// Reject a presentation request
  Future<bool> rejectPresentationRequest(String interactionId) async {
    try {
      final result =
          await _channel.invokeMethod<bool>('rejectPresentationRequest', {
        'interactionId': interactionId,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      _logger.e('Failed to reject presentation request: ${e.message}');
      return false;
    }
  }

  /// Get interaction history
  Future<List<Map<String, dynamic>>> getInteractionHistory() async {
    try {
      final result = await _channel.invokeMethod<List>('getInteractionHistory');
      if (result != null) {
        return result.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } on PlatformException catch (e) {
      _logger.e('Failed to get interaction history: ${e.message}');
      return [];
    }
  }

  /// Check credential status (revoked, suspended, etc.)
  Future<Map<String, dynamic>?> checkCredentialStatus(
      String credentialId) async {
    try {
      final result = await _channel.invokeMethod<Map>('checkCredentialStatus', {
        'credentialId': credentialId,
      });
      if (result != null) {
        return Map<String, dynamic>.from(result);
      }
      return null;
    } on PlatformException catch (e) {
      _logger.e('Failed to check credential status: ${e.message}');
      return null;
    }
  }

  /// Export backup data
  Future<String?> exportBackup() async {
    try {
      _logger.i('Exporting backup...');
      final result = await _channel.invokeMethod<String>('exportBackup');
      return result;
    } on PlatformException catch (e) {
      _logger.e('Failed to export backup: ${e.message}');
      return null;
    }
  }

  /// Import backup data
  Future<bool> importBackup(String backupData) async {
    try {
      _logger.i('Importing backup...');
      final result = await _channel.invokeMethod<bool>('importBackup', {
        'backupData': backupData,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      _logger.e('Failed to import backup: ${e.message}');
      return false;
    }
  }

  /// Get supported DID methods
  Future<List<String>> getSupportedDidMethods() async {
    try {
      final result =
          await _channel.invokeMethod<List>('getSupportedDidMethods');
      if (result != null) {
        return result.map((e) => e.toString()).toList();
      }
      return [];
    } on PlatformException catch (e) {
      _logger.e('Failed to get supported DID methods: ${e.message}');
      return [];
    }
  }

  /// Get supported credential formats
  Future<List<String>> getSupportedCredentialFormats() async {
    try {
      final result =
          await _channel.invokeMethod<List>('getSupportedCredentialFormats');
      if (result != null) {
        return result.map((e) => e.toString()).toList();
      }
      return [];
    } on PlatformException catch (e) {
      _logger.e('Failed to get supported credential formats: ${e.message}');
      return [];
    }
  }

  /// Uninitialize the core (cleanup)
  Future<bool> uninitialize({bool deleteData = false}) async {
    try {
      _logger
          .i('Uninitializing Procivis One Core (deleteData: $deleteData)...');
      final result = await _channel.invokeMethod<bool>('uninitialize', {
        'deleteData': deleteData,
      });
      _isInitialized = false;
      return result ?? false;
    } on PlatformException catch (e) {
      _logger.e('Failed to uninitialize: ${e.message}');
      return false;
    }
  }
}
