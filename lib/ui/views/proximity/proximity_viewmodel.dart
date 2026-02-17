import 'package:ssi/app/app.locator.dart';
import 'package:ssi/pigeon/ssi_api.g.dart';
import 'package:ssi/services/credential_service.dart';
import 'package:ssi/services/procivis_service.dart';
import 'package:ssi/ui/models/credential.dart';
import 'package:ssi/ui/models/presentation_request.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

enum ProximityState {
  initializing,
  qrReady,
  waitingForVerifier,
  requestReceived,
  submitting,
  success,
  error,
}

class ProximityViewModel extends BaseViewModel {
  final _api = SsiApi();
  final _navigationService = locator<NavigationService>();
  final _credentialService = locator<CredentialService>();
  final _procivisService = locator<ProcivisService>();

  ProximityState _state = ProximityState.initializing;
  String? _qrData;
  PresentationRequest? _request;
  List<Credential> _matchingCredentials = [];
  Credential? _selectedCredential;
  Map<String, bool> _selectedClaims = {};
  String? _errorMessage;

  ProximityState get state => _state;
  String? get qrData => _qrData;
  PresentationRequest? get request => _request;
  List<Credential> get matchingCredentials => _matchingCredentials;
  Credential? get selectedCredential => _selectedCredential;
  Map<String, bool> get selectedClaims => _selectedClaims;
  String? get errorMessage => _errorMessage;

  Future<void> initialize() async {
    await _startPresentation();
  }

  Future<void> _startPresentation() async {
    try {
      _state = ProximityState.initializing;
      notifyListeners();

      // Start BLE proximity and get QR code
      final qrString = await _api.startProximityPresentation();

      _qrData = qrString;
      _state = ProximityState.qrReady;
      notifyListeners();

      // Immediately start waiting for verifier to connect
      _waitForRequest();
    } catch (e) {
      _errorMessage = 'Failed to start BLE: $e';
      _state = ProximityState.error;
      notifyListeners();
    }
  }

  Future<void> _waitForRequest() async {
    try {
      _state = ProximityState.waitingForVerifier;
      notifyListeners();

      // Block until verifier connects and sends request
      final requestDto = await _api.receiveProximityRequest();

      if (requestDto == null) {
        _errorMessage = 'No request received from verifier';
        _state = ProximityState.error;
        notifyListeners();
        return;
      }

      _request = PresentationRequest.fromDto(requestDto);

      // Load matching credentials
      final futures = _request!.matchingCredentialIds
          .map((id) => _credentialService.getCredential(id));
      _matchingCredentials =
          (await Future.wait(futures)).whereType<Credential>().toList();

      if (_matchingCredentials.isNotEmpty) {
        _selectedCredential = _matchingCredentials.first;
      }

      // Initialize claim selection (required claims pre-selected)
      _selectedClaims = {};
      for (var claim in _request!.requestedClaims) {
        _selectedClaims[claim.claimName] = claim.required;
      }

      _state = ProximityState.requestReceived;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Connection failed: $e';
      _state = ProximityState.error;
      notifyListeners();
    }
  }

  void selectCredential(Credential credential) {
    _selectedCredential = credential;
    notifyListeners();
  }

  void toggleClaim(String claimName, bool? value) {
    // Don't allow deselecting required claims
    final claim = _request?.requestedClaims
        .firstWhere((c) => c.claimName == claimName);
    if (claim != null && claim.required) return;

    _selectedClaims[claimName] = value ?? false;
    notifyListeners();
  }

  Future<void> approve() async {
    if (_selectedCredential == null || _request == null) return;

    try {
      _state = ProximityState.submitting;
      notifyListeners();

      final selected = _selectedClaims.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList();

      final submission = PresentationSubmissionDto(
        interactionId: _request!.interactionId,
        credentialId: _selectedCredential!.id,
        selectedClaims: selected,
      );

      final success = await _api.submitPresentationWithClaims(submission);

      if (success) {
        _state = ProximityState.success;
        notifyListeners();
      } else {
        _errorMessage = 'Failed to send credentials';
        _state = ProximityState.error;
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Failed to share: $e';
      _state = ProximityState.error;
      notifyListeners();
    }
  }

  Future<void> decline() async {
    if (_request != null) {
      await _procivisService.rejectPresentationRequest(_request!.interactionId);
    }
    await _cleanup();
    _navigationService.back();
  }

  Future<void> cancel() async {
    await _cleanup();
    _navigationService.back();
  }

  Future<void> retry() async {
    _errorMessage = null;
    _qrData = null;
    _request = null;
    _matchingCredentials = [];
    _selectedCredential = null;
    _selectedClaims = {};
    await _startPresentation();
  }

  void done() {
    _navigationService.back();
  }

  Future<void> _cleanup() async {
    try {
      await _api.stopProximityPresentation();
    } catch (_) {}
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }
}
