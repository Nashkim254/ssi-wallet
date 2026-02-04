import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ssi/app/app.locator.dart';
import 'package:ssi/app/app.router.dart';
import 'package:ssi/services/credential_service.dart';
import 'package:ssi/services/did_service.dart';
import 'package:ssi/ui/models/credential.dart';
import 'package:ssi/ui/views/debug/debug_view.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

class HomeViewModel extends BaseViewModel {
  final _navigationService = locator<NavigationService>();
  final _credentialService = locator<CredentialService>();
  final _didService = locator<DidService>();

  StreamSubscription? _credentialsSubscription;
  StreamSubscription? _didsSubscription;

  List<Credential> get recentCredentials =>
      _credentialService.credentials.take(5).toList();

  int get credentialCount => _credentialService.credentials.length;
  int get didCount => _didService.dids.length;
  bool get hasNotifications => false; // TODO: Implement notifications

  String get greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Future<void> initialize() async {
    setBusy(true);

    try {
      // Subscribe to credential and DID streams for real-time updates
      _credentialsSubscription = _credentialService.credentialsStream.listen((_) {
        notifyListeners(); // Rebuild UI when credentials change
      });

      _didsSubscription = _didService.didsStream.listen((_) {
        notifyListeners(); // Rebuild UI when DIDs change
      });

      // Load credentials and DIDs
      await Future.wait([
        _credentialService.loadCredentials(),
        _didService.loadDids(),
      ]);
    } catch (e) {
      // Handle errors
      print('Failed to initialize home: $e');
    } finally {
      setBusy(false);
    }
  }

  @override
  void dispose() {
    _credentialsSubscription?.cancel();
    _didsSubscription?.cancel();
    super.dispose();
  }

  void navigateToScan() {
    _navigationService.navigateTo(Routes.scanView);
  }

  void navigateToCredentials() {
    _navigationService.navigateTo(Routes.credentialsView);
  }

  void navigateToCredentialDetail(String credentialId) {
    _navigationService.navigateTo(
      Routes.credentialDetailView,
      arguments: CredentialDetailViewArguments(credentialId: credentialId),
    );
  }

  void navigateToSettings() {
    _navigationService.navigateTo(Routes.settingsView);
  }

  void navigateToDidManagement() {
    _navigationService.navigateTo(Routes.didManagementView);
  }

  void navigateToActivity() {
    _navigationService.navigateTo(Routes.activityView);
  }

  void navigateToDebug() {
    _navigationService.navigateWithTransition(
      const DebugView(),
      transition: 'fade',
    );
  }
}
