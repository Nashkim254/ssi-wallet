// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// StackedLocatorGenerator
// **************************************************************************

// ignore_for_file: public_member_api_docs, implementation_imports, depend_on_referenced_packages

import 'package:stacked_services/src/bottom_sheet/bottom_sheet_service.dart';
import 'package:stacked_services/src/dialog/dialog_service.dart';
import 'package:stacked_services/src/navigation/navigation_service.dart';
import 'package:stacked_services/src/snackbar/snackbar_service.dart';
import 'package:stacked_shared/stacked_shared.dart';

import '../services/biometric_service.dart';
import '../services/credential_service.dart';
import '../services/did_service.dart';
import '../services/procivis_service.dart';
import '../services/providers_service.dart';
import '../services/qr_scanner_service.dart';
import '../services/storage_service.dart';

final locator = StackedLocator.instance;

Future<void> setupLocator({
  String? environment,
  EnvironmentFilter? environmentFilter,
}) async {
// Register environments
  locator.registerEnvironment(
      environment: environment, environmentFilter: environmentFilter);

// Register dependencies
  locator.registerLazySingleton(() => BottomSheetService());
  locator.registerLazySingleton(() => DialogService());
  locator.registerLazySingleton(() => NavigationService());
  locator.registerLazySingleton(() => SnackbarService());
  locator.registerLazySingleton(() => ProvidersService());
  locator.registerLazySingleton(() => StorageService());
  locator.registerLazySingleton(() => BiometricService());
  locator.registerLazySingleton(() => ProcivisService());
  locator.registerLazySingleton(() => QrScannerService());
  locator.registerLazySingleton(() => DidService());
  locator.registerLazySingleton(() => CredentialService());
}
