import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:ssi/app/app.locator.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:ssi/services/providers_service.dart';
import 'package:ssi/services/storage_service.dart';
import 'package:ssi/services/biometric_service.dart';
import 'package:ssi/services/did_service.dart';
import 'package:ssi/services/qr_scanner_service.dart';
import 'package:ssi/services/credential_service.dart';
import 'package:ssi/services/procivis_service.dart';
// @stacked-import

import 'test_helpers.mocks.dart';

@GenerateMocks(
  [],
  customMocks: [
    MockSpec<NavigationService>(onMissingStub: OnMissingStub.returnDefault),
    MockSpec<BottomSheetService>(onMissingStub: OnMissingStub.returnDefault),
    MockSpec<DialogService>(onMissingStub: OnMissingStub.returnDefault),
    MockSpec<ProvidersService>(onMissingStub: OnMissingStub.returnDefault),
    MockSpec<StorageService>(onMissingStub: OnMissingStub.returnDefault),
    MockSpec<BiometricService>(onMissingStub: OnMissingStub.returnDefault),
    MockSpec<DidService>(onMissingStub: OnMissingStub.returnDefault),
    MockSpec<QrScannerService>(onMissingStub: OnMissingStub.returnDefault),
    MockSpec<CredentialService>(onMissingStub: OnMissingStub.returnDefault),
    MockSpec<ProcivisService>(onMissingStub: OnMissingStub.returnDefault),
// @stacked-mock-spec
  ],
)
void registerServices() {
  getAndRegisterNavigationService();
  getAndRegisterBottomSheetService();
  getAndRegisterDialogService();
  getAndRegisterProvidersService();
  getAndRegisterStorageService();
  getAndRegisterBiometricService();
  getAndRegisterDidService();
  getAndRegisterQrScannerService();
  getAndRegisterCredentialService();
  getAndRegisterProcivisService();
// @stacked-mock-register
}

MockNavigationService getAndRegisterNavigationService() {
  _removeRegistrationIfExists<NavigationService>();
  final service = MockNavigationService();
  locator.registerSingleton<NavigationService>(service);
  return service;
}

MockBottomSheetService getAndRegisterBottomSheetService<T>({
  SheetResponse<T>? showCustomSheetResponse,
}) {
  _removeRegistrationIfExists<BottomSheetService>();
  final service = MockBottomSheetService();

  when(
    service.showCustomSheet<T, T>(
      enableDrag: anyNamed('enableDrag'),
      enterBottomSheetDuration: anyNamed('enterBottomSheetDuration'),
      exitBottomSheetDuration: anyNamed('exitBottomSheetDuration'),
      ignoreSafeArea: anyNamed('ignoreSafeArea'),
      isScrollControlled: anyNamed('isScrollControlled'),
      barrierDismissible: anyNamed('barrierDismissible'),
      additionalButtonTitle: anyNamed('additionalButtonTitle'),
      variant: anyNamed('variant'),
      title: anyNamed('title'),
      hasImage: anyNamed('hasImage'),
      imageUrl: anyNamed('imageUrl'),
      showIconInMainButton: anyNamed('showIconInMainButton'),
      mainButtonTitle: anyNamed('mainButtonTitle'),
      showIconInSecondaryButton: anyNamed('showIconInSecondaryButton'),
      secondaryButtonTitle: anyNamed('secondaryButtonTitle'),
      showIconInAdditionalButton: anyNamed('showIconInAdditionalButton'),
      takesInput: anyNamed('takesInput'),
      barrierColor: anyNamed('barrierColor'),
      barrierLabel: anyNamed('barrierLabel'),
      customData: anyNamed('customData'),
      data: anyNamed('data'),
      description: anyNamed('description'),
    ),
  ).thenAnswer(
    (realInvocation) =>
        Future.value(showCustomSheetResponse ?? SheetResponse<T>()),
  );

  locator.registerSingleton<BottomSheetService>(service);
  return service;
}

MockDialogService getAndRegisterDialogService() {
  _removeRegistrationIfExists<DialogService>();
  final service = MockDialogService();
  locator.registerSingleton<DialogService>(service);
  return service;
}

MockProvidersService getAndRegisterProvidersService() {
  _removeRegistrationIfExists<ProvidersService>();
  final service = MockProvidersService();
  locator.registerSingleton<ProvidersService>(service);
  return service;
}

MockStorageService getAndRegisterStorageService() {
  _removeRegistrationIfExists<StorageService>();
  final service = MockStorageService();
  locator.registerSingleton<StorageService>(service);
  return service;
}

MockBiometricService getAndRegisterBiometricService() {
  _removeRegistrationIfExists<BiometricService>();
  final service = MockBiometricService();
  locator.registerSingleton<BiometricService>(service);
  return service;
}

MockDidService getAndRegisterDidService() {
  _removeRegistrationIfExists<DidService>();
  final service = MockDidService();
  locator.registerSingleton<DidService>(service);
  return service;
}

MockQrScannerService getAndRegisterQrScannerService() {
  _removeRegistrationIfExists<QrScannerService>();
  final service = MockQrScannerService();
  locator.registerSingleton<QrScannerService>(service);
  return service;
}

MockCredentialService getAndRegisterCredentialService() {
  _removeRegistrationIfExists<CredentialService>();
  final service = MockCredentialService();
  locator.registerSingleton<CredentialService>(service);
  return service;
}

MockProcivisService getAndRegisterProcivisService() {
  _removeRegistrationIfExists<ProcivisService>();
  final service = MockProcivisService();
  locator.registerSingleton<ProcivisService>(service);
  return service;
}
// @stacked-mock-create

void _removeRegistrationIfExists<T extends Object>() {
  if (locator.isRegistered<T>()) {
    locator.unregister<T>();
  }
}
