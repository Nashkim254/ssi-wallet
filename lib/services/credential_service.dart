import 'package:hive_flutter/hive_flutter.dart';
import 'package:logger/logger.dart';
import 'package:rxdart/rxdart.dart';
import 'package:ssi/app/app.locator.dart';
import 'package:ssi/services/procivis_service.dart';
import 'package:ssi/ui/models/credential.dart';

class CredentialService {
  final _procivisService = locator<ProcivisService>();
  final Logger _logger = Logger();

  late final Box _credentialsBox;

  final BehaviorSubject<List<Credential>> _credentialsSubject =
      BehaviorSubject<List<Credential>>.seeded([]);

  Stream<List<Credential>> get credentialsStream => _credentialsSubject.stream;
  List<Credential> get credentials => _credentialsSubject.value;

  CredentialService() {
    _credentialsBox = Hive.box('credentials');
  }

  /// Initialize service and sync cached data with native side
  Future<void> initialize() async {
    try {
      _logger.i('Initializing Credential service...');

      // Load from cache first (instant UI feedback)
      await _loadFromCache();

      // Then sync with native side
      await loadCredentials();
    } catch (e) {
      _logger.e('Failed to initialize Credential service: $e');
    }
  }

  /// Load all credentials from cache first, then sync with native
  Future<void> loadCredentials() async {
    try {
      _logger.i('Loading credentials...');

      // First, load from cache
      await _loadFromCache();

      // Then sync with native side
      final credentialsData = await _procivisService.getCredentials();
      final credentialsList =
          credentialsData.map((data) => Credential.fromJson(data)).toList();

      // Save to cache
      await _saveToCache(credentialsList);

      _credentialsSubject.add(credentialsList);
      _logger.i('Loaded ${credentialsList.length} credentials');
    } catch (e) {
      _logger.e('Failed to load credentials: $e');
      // If native fails, use cached data
      await _loadFromCache();
      _credentialsSubject.addError(e);
    }
  }

  /// Load credentials from Hive cache
  Future<void> _loadFromCache() async {
    try {
      final cachedCredentials = _credentialsBox.values
          .map((json) =>
              Credential.fromJson(Map<String, dynamic>.from(json as Map)))
          .toList();

      if (cachedCredentials.isNotEmpty) {
        _credentialsSubject.add(cachedCredentials);
        _logger.i('Loaded ${cachedCredentials.length} credentials from cache');
      }
    } catch (e) {
      _logger.e('Failed to load credentials from cache: $e');
    }
  }

  /// Save credentials to Hive cache
  Future<void> _saveToCache(List<Credential> credentials) async {
    try {
      await _credentialsBox.clear();
      for (final credential in credentials) {
        await _credentialsBox.put(credential.id, credential.toJson());
      }
      _logger.d('Saved ${credentials.length} credentials to cache');
    } catch (e) {
      _logger.e('Failed to save credentials to cache: $e');
    }
  }

  /// Get a specific credential by ID
  Future<Credential?> getCredential(String id) async {
    try {
      final credentialData = await _procivisService.getCredential(id);
      if (credentialData != null) {
        return Credential.fromJson(credentialData);
      }
      return null;
    } catch (e) {
      _logger.e('Failed to get credential: $e');
      return null;
    }
  }

  /// Accept a credential offer via QR code or URL
  Future<Credential?> acceptOffer(String offerUrl) async {
    try {
      _logger.i('Accepting credential offer...');
      final result = await _procivisService.acceptCredentialOffer(offerUrl);

      if (result != null) {
        final credential = Credential.fromJson(result);

        // Save to cache immediately
        await _credentialsBox.put(credential.id, credential.toJson());

        await loadCredentials(); // Refresh list
        return credential;
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
      _logger.i('Deleting credential: $id');
      final success = await _procivisService.deleteCredential(id);

      if (success) {
        // Remove from cache
        await _credentialsBox.delete(id);
        await loadCredentials(); // Refresh list
      }

      return success;
    } catch (e) {
      _logger.e('Failed to delete credential: $e');
      return false;
    }
  }

  /// Check if a credential is valid (not expired, not revoked)
  Future<CredentialStatus> checkStatus(String id) async {
    try {
      final statusData = await _procivisService.checkCredentialStatus(id);

      if (statusData != null) {
        final status = statusData['status'] as String?;
        final isRevoked = statusData['isRevoked'] as bool? ?? false;
        final isSuspended = statusData['isSuspended'] as bool? ?? false;

        if (isRevoked) return CredentialStatus.revoked;
        if (isSuspended) return CredentialStatus.suspended;
        return CredentialStatus.valid;
      }

      return CredentialStatus.unknown;
    } catch (e) {
      _logger.e('Failed to check credential status: $e');
      return CredentialStatus.unknown;
    }
  }

  /// Get credentials by type
  List<Credential> getCredentialsByType(String type) {
    return credentials.where((c) => c.type == type).toList();
  }

  /// Search credentials
  List<Credential> searchCredentials(String query) {
    final lowerQuery = query.toLowerCase();
    return credentials.where((c) {
      return c.name.toLowerCase().contains(lowerQuery) ||
          c.issuerName.toLowerCase().contains(lowerQuery) ||
          c.type.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  /// Get expired credentials
  List<Credential> getExpiredCredentials() {
    final now = DateTime.now();
    return credentials.where((c) {
      return c.expiryDate != null && c.expiryDate!.isBefore(now);
    }).toList();
  }

  /// Get credentials expiring soon (within 30 days)
  List<Credential> getExpiringSoonCredentials() {
    final now = DateTime.now();
    final thirtyDaysFromNow = now.add(const Duration(days: 30));

    return credentials.where((c) {
      return c.expiryDate != null &&
          c.expiryDate!.isAfter(now) &&
          c.expiryDate!.isBefore(thirtyDaysFromNow);
    }).toList();
  }

  void dispose() {
    _credentialsSubject.close();
  }
}

enum CredentialStatus {
  valid,
  expired,
  revoked,
  suspended,
  unknown,
}
