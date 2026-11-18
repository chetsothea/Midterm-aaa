import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

// Dark (default) or light mode, switched with the ☀️ / 🌙 button and
// remembered between launches.
class AppThemeMode extends ChangeNotifier {
  AppThemeMode._();
  static final AppThemeMode instance = AppThemeMode._();

  static const _key = 'dark_mode';

  bool _dark = true;
  bool get isDark => _dark;
  Brightness get brightness => _dark ? Brightness.dark : Brightness.light;

  // Called once before the app starts
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _dark = prefs.getBool(_key) ?? true;
    } catch (_) {
      // No saved choice (or no storage, e.g. in tests): dark
    }
    AppColors.current = _dark ? AppPalette.dark : AppPalette.light;
  }

  Future<void> setDark(bool dark) async {
    if (dark == _dark) return;
    _dark = dark;
    AppColors.current = dark ? AppPalette.dark : AppPalette.light;
    notifyListeners(); // MaterialApp swaps its theme
    _rebuildEverything();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, dark);
    } catch (_) {
      // Not saved: it still applies until the app is closed
    }
  }

  Future<void> toggle() => setDark(!_dark);

  // Screens read AppColors while they build, and many widgets are const, so
  // Flutter would keep their old colours. Marking every element dirty redraws
  // them all in place: open pages, what was typed and scroll positions stay.
  static void _rebuildEverything() {
    void mark(Element element) {
      element.markNeedsBuild();
      element.visitChildren(mark);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(mark);
  }
}
