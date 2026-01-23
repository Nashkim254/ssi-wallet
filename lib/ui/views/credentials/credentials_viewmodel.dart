import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ssi/app/app.locator.dart';
import 'package:ssi/app/app.router.dart';
import 'package:ssi/services/credential_service.dart';
import 'package:ssi/ui/models/credential.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

enum CredentialSortOption {
  dateNewest,
  dateOldest,
  nameAZ,
  nameZA,
  issuer,
}

class CredentialsViewModel extends BaseViewModel {
  final _navigationService = locator<NavigationService>();
  final _credentialService = locator<CredentialService>();
  final _bottomSheetService = locator<BottomSheetService>();

  final TextEditingController searchController = TextEditingController();

  String _searchQuery = '';
  CredentialSortOption _sortOption = CredentialSortOption.dateNewest;
  bool _showExpiredOnly = false;
  bool _showValidOnly = false;
  String? _selectedFormat;

  StreamSubscription? _credentialsSubscription;

  String get searchQuery => _searchQuery;
  bool get showExpiredOnly => _showExpiredOnly;
  bool get showValidOnly => _showValidOnly;
  String? get selectedFormat => _selectedFormat;

  bool get hasActiveFilters =>
      _showExpiredOnly || _showValidOnly || _selectedFormat != null;

  List<Credential> get filteredCredentials {
    var credentials = _credentialService.credentials;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      credentials = credentials.where((c) {
        return c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            c.issuerName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            c.type.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Apply expired filter
    if (_showExpiredOnly) {
      credentials = credentials.where((c) => c.isExpired).toList();
    }

    // Apply valid filter
    if (_showValidOnly) {
      credentials = credentials
          .where((c) => !c.isExpired && c.state == CredentialState.valid)
          .toList();
    }

    // Apply format filter
    if (_selectedFormat != null) {
      credentials = credentials
          .where(
              (c) => c.format.toLowerCase() == _selectedFormat!.toLowerCase())
          .toList();
    }

    // Apply sorting
    switch (_sortOption) {
      case CredentialSortOption.dateNewest:
        credentials.sort((a, b) => b.issuedDate.compareTo(a.issuedDate));
        break;
      case CredentialSortOption.dateOldest:
        credentials.sort((a, b) => a.issuedDate.compareTo(b.issuedDate));
        break;
      case CredentialSortOption.nameAZ:
        credentials.sort((a, b) => a.name.compareTo(b.name));
        break;
      case CredentialSortOption.nameZA:
        credentials.sort((a, b) => b.name.compareTo(a.name));
        break;
      case CredentialSortOption.issuer:
        credentials.sort((a, b) => a.issuerName.compareTo(b.issuerName));
        break;
    }

    return credentials;
  }

  Future<void> initialize() async {
    setBusy(true);

    try {
      await _credentialService.loadCredentials();

      // Listen to credential updates
      _credentialsSubscription = _credentialService.credentialsStream.listen(
        (_) => notifyListeners(),
      );
    } catch (e) {
      print('Failed to initialize credentials: $e');
    } finally {
      setBusy(false);
    }
  }

  void onSearchChanged(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void clearSearch() {
    searchController.clear();
    _searchQuery = '';
    notifyListeners();
  }

  void setSortOption(CredentialSortOption option) {
    _sortOption = option;
    notifyListeners();
  }

  void toggleExpiredFilter() {
    _showExpiredOnly = !_showExpiredOnly;
    if (_showExpiredOnly) _showValidOnly = false;
    notifyListeners();
  }

  void toggleValidFilter() {
    _showValidOnly = !_showValidOnly;
    if (_showValidOnly) _showExpiredOnly = false;
    notifyListeners();
  }

  void setFormatFilter(String? format) {
    _selectedFormat = format;
    notifyListeners();
  }

  void clearFormatFilter() {
    _selectedFormat = null;
    notifyListeners();
  }

  void clearAllFilters() {
    _showExpiredOnly = false;
    _showValidOnly = false;
    _selectedFormat = null;
    notifyListeners();
  }

  Future<void> showFilterSheet() async {
    await _bottomSheetService.showBottomSheet(
      title: 'Filter Credentials',
      description: 'Choose how to filter your credentials:\n\n• Show All\n• Valid Only\n• Expired Only\n• By Format (VC, mdoc, etc.)',
      // In a real implementation, show custom filter sheet
    );
  }

  Future<void> refresh() async {
    await _credentialService.loadCredentials();
  }

  void navigateToScan() {
    _navigationService.navigateTo(Routes.scanView);
  }

  void navigateToCredentialDetail(String credentialId) {
    _navigationService.navigateTo(
      Routes.credentialDetailView,
      arguments: CredentialDetailViewArguments(credentialId: credentialId),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    _credentialsSubscription?.cancel();
    super.dispose();
  }
}
