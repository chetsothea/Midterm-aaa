import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'services/api_service.dart';
import 'services/favorites.dart';
import 'services/language.dart';

// While developing on Chrome or a desktop, show the app inside a phone frame.
// Off on real phones and emulators (already phone-sized) and in release builds.
bool get _showDevicePreview =>
    !kReleaseMode &&
    (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLanguage.instance.load(); // Khmer or English, as last chosen
  await Favorites.instance.load(); // the phones tapped ♥ last time
  await ApiService.findHost(); // emulator, USB phone or Wi-Fi phone
  runApp(
    DevicePreview(
      enabled: _showDevicePreview,
      defaultDevice: Devices.android.samsungGalaxyS20,
      builder: (context) => const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool showSplash; // tests go straight to the store

  const MyApp({super.key, this.showSplash = true});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PS168',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      // So the app takes its size and look from the previewed device
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      // Open straight into the store; login is only needed to buy
      home: showSplash ? const SplashScreen() : const HomeScreen(),
    );
  }
}
