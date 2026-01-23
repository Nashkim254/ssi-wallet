import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ssi/app/app.bottomsheets.dart';
import 'package:ssi/app/app.dialogs.dart';
import 'package:ssi/app/app.locator.dart';
import 'package:ssi/app/app.router.dart';
import 'package:ssi/services/procivis_service.dart';
import 'package:ssi/services/storage_service.dart';
import 'package:ssi/ui/theme/app_theme.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for local storage
  await Hive.initFlutter();

  // Open Hive boxes for caching DIDs and credentials
  await Hive.openBox('dids');
  await Hive.openBox('credentials');

  // Setup dependency injection
  await setupLocator();

  // Setup UI services (dialogs, bottom sheets, snackbars)
  setupDialogUi();
  setupBottomSheetUi();

  // Initialize StorageService
  final storageService = locator<StorageService>();
  await storageService.initialize();

  // Initialize Procivis SDK (suppress errors gracefully)
  try {
    final procivisService = locator<ProcivisService>();
    await procivisService.initialize();
  } catch (e) {
    // Log error but don't block app launch
    print('Warning: Procivis SDK initialization failed: $e');
  }

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const SSIWalletApp());
}

class SSIWalletApp extends StatelessWidget {
  const SSIWalletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SSI Wallet',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      navigatorKey: StackedService.navigatorKey,
      onGenerateRoute: StackedRouter().onGenerateRoute,
      initialRoute: Routes.splashView,
    );
  }
}
