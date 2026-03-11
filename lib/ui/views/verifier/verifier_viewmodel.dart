import 'dart:async';
import 'package:ssi/app/app.locator.dart';
import 'package:ssi/pigeon/ssi_api.g.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

enum VerifierState {
  scanning,    // auto-scanning BLE for a nearby holder
  connecting,  // holder found, BLE connecting + reading claims
  result,      // credentials received
  error,
}

class VerifierViewModel extends BaseViewModel {
  final _api = SsiApi();
  final _navigationService = locator<NavigationService>();

  VerifierState _state = VerifierState.scanning;
  VerificationResultDto? _result;
  String? _errorMessage;
  bool _holderFound = false;

  VerifierState get state => _state;
  VerificationResultDto? get result => _result;
  String? get errorMessage => _errorMessage;
  bool get holderFound => _holderFound;

  Future<void> initialize() async {
    await _startScan();
  }

  Future<void> _startScan() async {
    _state = VerifierState.scanning;
    _holderFound = false;
    _errorMessage = null;
    notifyListeners();

    try {
      final qr = await _api.scanForNearbyHolder();
      if (qr == null || qr.isEmpty) throw Exception('No holder found nearby');
      _holderFound = true;
      notifyListeners();
      // Small visual pause so user sees "Found!" message
      await Future.delayed(const Duration(milliseconds: 600));
      await _connect(qr);
    } catch (e) {
      if (_state == VerifierState.scanning) {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _state = VerifierState.error;
        notifyListeners();
      }
    }
  }

  Future<void> _connect(String qrCode) async {
    try {
      _state = VerifierState.connecting;
      _errorMessage = null;
      notifyListeners();

      final ok = await _api.startProximityVerification(qrCode);
      if (!ok) throw Exception('Failed to initialise BLE reader');

      final dto = await _api.receiveVerificationResult();
      if (dto == null) throw Exception('No response received from holder');

      _result = dto;
      _state = VerifierState.result;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _state = VerifierState.error;
      notifyListeners();
    }
  }

  /// Retry from scratch — re-scan for a holder.
  Future<void> retry() async {
    _result = null;
    _errorMessage = null;
    await _cleanupReader();
    await _startScan();
  }

  void done() => _navigationService.back();

  Future<void> cancel() async {
    _state = VerifierState.error; // prevents re-entry in _startScan catch
    await _api.stopProximityVerification().catchError((_) {});
    _navigationService.back();
  }

  Future<void> _cleanupReader() async {
    try { await _api.stopProximityVerification(); } catch (_) {}
  }

  @override
  void dispose() {
    _api.stopProximityVerification().catchError((_) {});
    super.dispose();
  }
}
