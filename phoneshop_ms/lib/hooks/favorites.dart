import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Phones the customer tapped ♥ on. Remembered on this phone between launches.
class Favorites extends ChangeNotifier {
  Favorites._();
  static final Favorites instance = Favorites._();

  static const _key = 'favorites';

  final Set<int> _ids = {};

  Set<int> get ids => Set.unmodifiable(_ids);
  int get count => _ids.length;

  bool contains(int phoneId) => _ids.contains(phoneId);

  // Called once before the app starts
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _ids
        ..clear()
        ..addAll((prefs.getStringList(_key) ?? []).map(int.parse));
    } catch (_) {
      // Nothing saved (or no storage, e.g. in tests): start empty
    }
  }

  // From the account at login: keeps this phone's ♥ and adds the account's
  void merge(Iterable<int> ids) {
    final before = _ids.length;
    _ids.addAll(ids);
    if (_ids.length != before) {
      notifyListeners();
      _save();
    }
  }

  // At logout: they stay on the account, not on this phone
  void clearAll() {
    _ids.clear();
    notifyListeners();
    _save();
  }

  void toggle(int phoneId) {
    if (!_ids.remove(phoneId)) _ids.add(phoneId);
    notifyListeners();
    _save();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, [for (final id in _ids) '$id']);
    } catch (_) {
      // Not saved: still kept until the app is closed
    }
  }
}
