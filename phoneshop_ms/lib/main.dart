import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'data/api_service.dart';
import 'hooks/favorites.dart';
import 'hooks/cart.dart';
import 'hooks/language.dart';
import 'hooks/theme_mode.dart';
import 'theme/app_theme.dart';

// While developing on Chrome or a desktop, show the app inside a phone frame.
// Off on real phones and emulators (already phone-sized) and in release builds.
// A release web build can turn it on with --dart-define=DEVICE_PREVIEW=true.
bool get _showDevicePreview =>
    const bool.fromEnvironment('DEVICE_PREVIEW') ||
    (!kReleaseMode &&
        (kIsWeb ||
            defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux));

// device_preview has no iPhone 17 Pro Max yet; it has the same 6.9" screen
// (440x956 points, Dynamic Island) as the 16 Pro Max, so reuse that frame.
final _iPhone17ProMax = Devices.ios.iPhone16ProMax.copyWith(
  name: 'iPhone 17 Pro Max',
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLanguage.instance.load(); // Khmer or English, as last chosen
  await AppThemeMode.instance.load(); // dark or light, as last chosen
  await Favorites.instance.load(); // the phones tapped ♥ last time
  await ApiService.findHost(); // emulator, USB phone or Wi-Fi phone
  await ApiService.restoreSession(); // still logged in from last time
  await Cart.instance.load(); // and the phones left in the cart
  runApp(
    DevicePreview(
      enabled: _showDevicePreview,
      defaultDevice: _iPhone17ProMax,
      devices: [_iPhone17ProMax, ...Devices.all],
      builder: (context) => const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool showSplash; // tests go straight to the store

  const MyApp({super.key, this.showSplash = true});

  @override
  Widget build(BuildContext context) {
    // Rebuilt with the other theme when ☀️ / 🌙 is tapped
    return ListenableBuilder(
      listenable: AppThemeMode.instance,
      builder: (context, _) => _app(context),
    );
  }

  Widget _app(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PS168',
      // Colours, buttons, fields, cards, dialogs… (lib/theme.dart), in the
      // mode the customer picked; the colours fade into each other
      theme: appTheme(AppThemeMode.instance.brightness),
      themeAnimationDuration: const Duration(milliseconds: 350),
      // So the app takes its size and look from the previewed device
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      // Open straight into the store; login is only needed to buy
      home: showSplash ? const SplashScreen() : const HomeScreen(),
    );
  }
}
