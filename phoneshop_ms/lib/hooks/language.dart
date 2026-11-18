import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/translations.dart';

// The app's language: Khmer (default) or English. Remembered between launches.
class AppLanguage extends ChangeNotifier {
  AppLanguage._();
  static final AppLanguage instance = AppLanguage._();

  static const _key = 'language';

  bool _english = false;
  bool get isEnglish => _english;

  // Called once before the app starts
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _english = prefs.getString(_key) == 'en';
    } catch (_) {
      // No saved choice (or no storage, e.g. in tests): Khmer
    }
  }

  Future<void> setEnglish(bool english) async {
    if (english == _english) return;
    _english = english;
    notifyListeners();
    _rebuildEverything();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, english ? 'en' : 'km');
    } catch (_) {
      // Not saved: it still applies until the app is closed
    }
  }

  // Texts are read with tr() while building, and many widgets are const, so Flutter
  // would keep their old text. Marking every element dirty redraws them all, in place:
  // the open pages, what was typed and the scroll positions all stay.
  static void _rebuildEverything() {
    void mark(Element element) {
      element.markNeedsBuild();
      element.visitChildren(mark);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(mark);
  }
}

// A text in the current language. The app's texts are written in Khmer (or, on the
// Login and Create Account pages, in English); the other language comes from the table.
// A text missing from the table shows as it is written.
String tr(String text) {
  final english = AppLanguage.instance.isEnglish;
  if (english) return khmerToEnglish[text] ?? text;
  return englishToKhmer[text] ?? text;
}

// A text with values in it, written in both languages at the place it's used
String trf(String khmer, String english) =>
    AppLanguage.instance.isEnglish ? english : khmer;
