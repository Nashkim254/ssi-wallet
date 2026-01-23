import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';

class StorageService {
  final Logger _logger = Logger();
  late final SharedPreferences _prefs;
  final _secureStorage = const FlutterSecureStorage();

  static const String _keyFirstLaunch = 'first_launch';
  static const String _keyOnboardingCompleted = 'onboarding_completed';
  static const String _keyBiometricsEnabled = 'biometrics_enabled';
  static const String _keyDefaultDid = 'default_did';
  static const String _keyPinHash = 'pin_hash';

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _logger.i('Storage service initialized');
  }

  // First launch
  Future<bool> isFirstLaunch() async {
    return !_prefs.containsKey(_keyFirstLaunch);
  }

  Future<void> setFirstLaunchComplete() async {
    await _prefs.setBool(_keyFirstLaunch, false);
  }

  // Onboarding
  Future<bool> isOnboardingCompleted() async {
    return _prefs.getBool(_keyOnboardingCompleted) ?? false;
  }

  Future<void> setOnboardingCompleted(bool value) async {
    await _prefs.setBool(_keyOnboardingCompleted, value);
  }

  // Biometrics
  Future<bool> isBiometricsEnabled() async {
    return _prefs.getBool(_keyBiometricsEnabled) ?? false;
  }

  Future<void> setBiometricsEnabled(bool value) async {
    await _prefs.setBool(_keyBiometricsEnabled, value);
  }

  // Default DID
  Future<String?> getDefaultDid() async {
    return _prefs.getString(_keyDefaultDid);
  }

  Future<void> setDefaultDid(String didId) async {
    await _prefs.setString(_keyDefaultDid, didId);
  }

  // Secure Storage (for sensitive data)
  Future<void> saveSecureData(String key, String value) async {
    try {
      await _secureStorage.write(key: key, value: value);
    } catch (e) {
      _logger.e('Failed to save secure data: $e');
    }
  }

  Future<String?> getSecureData(String key) async {
    try {
      return await _secureStorage.read(key: key);
    } catch (e) {
      _logger.e('Failed to get secure data: $e');
      return null;
    }
  }

  Future<void> deleteSecureData(String key) async {
    try {
      await _secureStorage.delete(key: key);
    } catch (e) {
      _logger.e('Failed to delete secure data: $e');
    }
  }

  Future<void> clearAllSecureData() async {
    try {
      await _secureStorage.deleteAll();
    } catch (e) {
      _logger.e('Failed to clear all secure data: $e');
    }
  }

  // PIN Management
  Future<void> savePinHash(String hash) async {
    await saveSecureData(_keyPinHash, hash);
  }

  Future<String?> getPinHash() async {
    return await getSecureData(_keyPinHash);
  }

  Future<bool> hasPinSet() async {
    final hash = await getPinHash();
    return hash != null && hash.isNotEmpty;
  }

  // Clear all data
  Future<void> clearAll() async {
    await _prefs.clear();
    await clearAllSecureData();
    _logger.i('All storage cleared');
  }

  // Generic methods
  Future<void> setString(String key, String value) async {
    await _prefs.setString(key, value);
  }

  String? getString(String key) {
    return _prefs.getString(key);
  }

  Future<void> setBool(String key, bool value) async {
    await _prefs.setBool(key, value);
  }

  bool? getBool(String key) {
    return _prefs.getBool(key);
  }

  Future<void> setInt(String key, int value) async {
    await _prefs.setInt(key, value);
  }

  int? getInt(String key) {
    return _prefs.getInt(key);
  }

  Future<void> remove(String key) async {
    await _prefs.remove(key);
  }

  bool containsKey(String key) {
    return _prefs.containsKey(key);
  }
}
