import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Keeps the customer logged in between launches. The login token goes into
// the phone's secure storage (Keychain on iPhone, Keystore on Android,
// encrypted storage on the web), never into plain preferences.
class SessionStore {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'ps168_token';
  static const _userKey = 'ps168_user';

  static Future<void> save(String token, Map<String, dynamic> user) async {
    try {
      await _storage.write(key: _tokenKey, value: token);
      await _storage.write(key: _userKey, value: jsonEncode(user));
    } catch (e) {
      // No secure storage: the login lasts until the app closes
      debugPrint('SessionStore.save: $e');
    }
  }

  static Future<void> saveUser(Map<String, dynamic> user) async {
    try {
      await _storage.write(key: _userKey, value: jsonEncode(user));
    } catch (_) {}
  }

  // The saved token and user, or null when nobody is logged in
  static Future<(String, Map<String, dynamic>)?> read() async {
    try {
      final token = await _storage.read(key: _tokenKey);
      final user = await _storage.read(key: _userKey);
      if (token == null || token.isEmpty || user == null) return null;
      return (token, Map<String, dynamic>.from(jsonDecode(user)));
    } catch (e) {
      debugPrint('SessionStore.read: $e');
      return null;
    }
  }

  static Future<void> clear() async {
    try {
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _userKey);
    } catch (_) {}
  }
}
