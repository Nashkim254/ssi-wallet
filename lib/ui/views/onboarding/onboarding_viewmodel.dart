import 'package:flutter/material.dart';
import 'package:ssi/app/app.locator.dart';
import 'package:ssi/app/app.router.dart';
import 'package:ssi/services/storage_service.dart';
import 'package:ssi/ui/theme/app_theme.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

class OnboardingViewModel extends BaseViewModel {
  final _navigationService = locator<NavigationService>();
  final _storageService = locator<StorageService>();

  final PageController pageController = PageController();
  int _currentPage = 0;

  int get currentPage => _currentPage;
  bool get isLastPage => _currentPage == pages.length - 1;

  final List<OnboardingPageData> pages = [
    OnboardingPageData(
      icon: Icons.account_balance_wallet_rounded,
      title: 'Your Digital Identity Wallet',
      description:
          'Store and manage your verifiable credentials securely in one place.',
      gradient: AppColors.primaryGradient,
    ),
    OnboardingPageData(
      icon: Icons.security_rounded,
      title: 'Secure & Private',
      description:
          'Your credentials are encrypted and stored only on your device. You\'re in complete control.',
      gradient: AppColors.successGradient,
    ),
    OnboardingPageData(
      icon: Icons.qr_code_scanner_rounded,
      title: 'Easy to Use',
      description:
          'Simply scan QR codes to receive credentials and share them instantly when needed.',
      gradient: AppColors.accentGradient,
    ),
    OnboardingPageData(
      icon: Icons.verified_user_rounded,
      title: 'Industry Standards',
      description:
          'Built with W3C Verifiable Credentials, ISO mdoc, and OpenID4VC protocols.',
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
      ),
    ),
  ];

  void onPageChanged(int page) {
    _currentPage = page;
    notifyListeners();
  }

  void nextPage() {
    if (_currentPage < pages.length - 1) {
      pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void previousPage() {
    if (_currentPage > 0) {
      pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> complete() async {
    await _storageService.setOnboardingCompleted(true);
    await _storageService.setFirstLaunchComplete();
    await _navigationService.replaceWith(Routes.homeView);
  }

  Future<void> skip() async {
    await complete();
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }
}

class OnboardingPageData {
  final IconData icon;
  final String title;
  final String description;
  final Gradient gradient;

  OnboardingPageData({
    required this.icon,
    required this.title,
    required this.description,
    required this.gradient,
  });
}
