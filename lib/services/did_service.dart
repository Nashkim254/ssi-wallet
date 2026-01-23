import 'package:hive_flutter/hive_flutter.dart';
import 'package:logger/logger.dart';
import 'package:rxdart/rxdart.dart';
import 'package:ssi/app/app.locator.dart';
import 'package:ssi/services/procivis_service.dart';
import 'package:ssi/services/storage_service.dart';
import 'package:ssi/ui/models/did.dart';

class DidService {
  final _procivisService = locator<ProcivisService>();
  final _storageService = locator<StorageService>();
  final Logger _logger = Logger();

  late final Box _didsBox;

  final BehaviorSubject<List<Did>> _didsSubject =
      BehaviorSubject<List<Did>>.seeded([]);

  Stream<List<Did>> get didsStream => _didsSubject.stream;
  List<Did> get dids => _didsSubject.value;

  DidService() {
    _didsBox = Hive.box('dids');
  }

  /// Initialize service and sync cached data with native side
  Future<void> initialize() async {
    try {
      _logger.i('Initializing DID service...');

      // Load from cache first (instant UI feedback)
      await _loadFromCache();

      // Then sync with native side
      await loadDids();
    } catch (e) {
      _logger.e('Failed to initialize DID service: $e');
    }
  }

  /// Load all DIDs from cache first, then sync with native
  Future<void> loadDids() async {
    try {
      _logger.i('Loading DIDs...');

      // First, load from cache
      await _loadFromCache();

      // Then sync with native side
      final didsData = await _procivisService.getDids();
      final didsList = didsData.map((data) => Did.fromJson(data)).toList();

      // Save to cache
      await _saveToCache(didsList);

      _didsSubject.add(didsList);
      _logger.i('Loaded ${didsList.length} DIDs');
    } catch (e) {
      _logger.e('Failed to load DIDs: $e');
      // If native fails, use cached data
      await _loadFromCache();
      _didsSubject.addError(e);
    }
  }

  /// Load DIDs from Hive cache
  Future<void> _loadFromCache() async {
    try {
      final cachedDids = _didsBox.values
          .map((json) => Did.fromJson(Map<String, dynamic>.from(json as Map)))
          .toList();

      if (cachedDids.isNotEmpty) {
        _didsSubject.add(cachedDids);
        _logger.i('Loaded ${cachedDids.length} DIDs from cache');
      }
    } catch (e) {
      _logger.e('Failed to load DIDs from cache: $e');
    }
  }

  /// Save DIDs to Hive cache
  Future<void> _saveToCache(List<Did> dids) async {
    try {
      await _didsBox.clear();
      for (final did in dids) {
        await _didsBox.put(did.id, did.toJson());
      }
      _logger.d('Saved ${dids.length} DIDs to cache');
    } catch (e) {
      _logger.e('Failed to save DIDs to cache: $e');
    }
  }

  /// Create a new DID
  Future<Did?> createDid({
    required String method,
    required String keyType,
  }) async {
    try {
      _logger.i('Creating DID with method: $method, keyType: $keyType');
      final result = await _procivisService.createDid(
        method: method,
        keyType: keyType,
      );

      if (result != null) {
        final did = Did.fromJson(result);

        // Save to cache immediately
        await _didsBox.put(did.id, did.toJson());

        await loadDids(); // Refresh list

        // Set as default if it's the first DID
        if (dids.length == 1) {
          await setDefaultDid(did.id);
        }

        return did;
      }
      return null;
    } catch (e) {
      _logger.e('Failed to create DID: $e');
      return null;
    }
  }

  /// Get a specific DID
  Future<Did?> getDid(String id) async {
    try {
      final didData = await _procivisService.getDid(id);
      if (didData != null) {
        return Did.fromJson(didData);
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
      _logger.i('Deleting DID: $id');

      // Don't allow deletion of default DID
      final defaultDidId = await _storageService.getDefaultDid();
      if (defaultDidId == id) {
        _logger.w('Cannot delete default DID');
        return false;
      }

      final success = await _procivisService.deleteDid(id);

      if (success) {
        // Remove from cache
        await _didsBox.delete(id);
        await loadDids(); // Refresh list
      }

      return success;
    } catch (e) {
      _logger.e('Failed to delete DID: $e');
      return false;
    }
  }

  /// Get the default DID
  Future<Did?> getDefaultDid() async {
    try {
      final defaultDidId = await _storageService.getDefaultDid();
      if (defaultDidId != null) {
        return getDid(defaultDidId);
      }

      // If no default DID set, return the first one
      if (dids.isNotEmpty) {
        await setDefaultDid(dids.first.id);
        return dids.first;
      }

      return null;
    } catch (e) {
      _logger.e('Failed to get default DID: $e');
      return null;
    }
  }

  /// Set the default DID
  Future<void> setDefaultDid(String didId) async {
    try {
      await _storageService.setDefaultDid(didId);
      _logger.i('Default DID set to: $didId');
    } catch (e) {
      _logger.e('Failed to set default DID: $e');
    }
  }

  /// Get supported DID methods
  Future<List<String>> getSupportedMethods() async {
    try {
      return await _procivisService.getSupportedDidMethods();
    } catch (e) {
      _logger.e('Failed to get supported DID methods: $e');
      return ['did:key', 'did:web', 'did:jwk']; // Fallback defaults
    }
  }

  void dispose() {
    _didsSubject.close();
  }
}
