import 'package:ssi/ui/bottom_sheets/notice/notice_sheet.dart';
import 'package:ssi/ui/dialogs/info_alert/info_alert_dialog.dart';
import 'package:ssi/ui/views/home/home_view.dart';
import 'package:ssi/ui/views/startup/startup_view.dart';
import 'package:stacked/stacked_annotations.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:ssi/ui/views/splash/splash_view.dart';
import 'package:ssi/services/providers_service.dart';
import 'package:ssi/services/storage_service.dart';
import 'package:ssi/services/biometric_service.dart';
import 'package:ssi/services/did_service.dart';
import 'package:ssi/services/qr_scanner_service.dart';
import 'package:ssi/services/credential_service.dart';
import 'package:ssi/services/procivis_service.dart';
import 'package:ssi/ui/views/onboarding/onboarding_view.dart';
import 'package:ssi/ui/views/credentials/credentials_view.dart';
import 'package:ssi/ui/views/settings/settings_view.dart';
import 'package:ssi/ui/views/scan/scan_view.dart';
import 'package:ssi/ui/views/credential_detail/credential_detail_view.dart';
import 'package:ssi/ui/views/did_management/did_management_view.dart';
import 'package:ssi/ui/views/security/security_view.dart';
import 'package:ssi/ui/views/backup/backup_view.dart';
import 'package:ssi/ui/views/activity/activity_view.dart';
// @stacked-import

@StackedApp(
  routes: [
    MaterialRoute(page: HomeView),
    MaterialRoute(page: StartupView),
    MaterialRoute(page: SplashView, path: '/'),
    MaterialRoute(page: OnboardingView),
    MaterialRoute(page: CredentialsView),
    MaterialRoute(page: SettingsView),
    MaterialRoute(page: ScanView),
    MaterialRoute(page: CredentialDetailView),
    MaterialRoute(page: DidManagementView),
    MaterialRoute(page: SecurityView),
    MaterialRoute(page: BackupView),
    MaterialRoute(page: ActivityView),
// @stacked-route
  ],
  dependencies: [
    LazySingleton(classType: BottomSheetService),
    LazySingleton(classType: DialogService),
    LazySingleton(classType: NavigationService),
    LazySingleton(classType: SnackbarService),
    LazySingleton(classType: ProvidersService),
    LazySingleton(classType: StorageService),
    LazySingleton(classType: BiometricService),
    LazySingleton(classType: ProcivisService),
    LazySingleton(classType: QrScannerService),
    LazySingleton(classType: DidService),
    LazySingleton(classType: CredentialService),
// @stacked-service
  ],
  bottomsheets: [
    StackedBottomsheet(classType: NoticeSheet),
    // @stacked-bottom-sheet
  ],
  dialogs: [
    StackedDialog(classType: InfoAlertDialog),
    // @stacked-dialog
  ],
)
class App {}
