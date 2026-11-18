import 'dart:async';

import 'package:flutter/foundation.dart';
import '../data/api_service.dart';
import 'cart.dart';
import 'favorites.dart';

// Keeps the ♥ phones and the cart on the customer's account, so they follow
// them to another phone or browser:
// - at login (and at launch when still logged in) the account's lists are
//   added to what is on this phone, then the result is saved back;
// - while logged in, every change is saved a moment later;
// - at logout the last changes are saved, then this phone forgets them.
class AccountSync {
  AccountSync._();

  static bool _started = false;
  static bool _applying = false; // our own merge, not a customer change
  static Timer? _debounce;

  // How long to wait after a change before saving (shorter in tests)
  static Duration delay = const Duration(milliseconds: 1200);

  static void start() {
    if (_started) return;
    _started = true;
    Cart.instance.addListener(_changed);
    Favorites.instance.addListener(_changed);
    ApiService.loggedIn.addListener(pull);
    ApiService.beforeLogout = flush;
    ApiService.afterLogout = () {
      _debounce?.cancel();
      _applying = true;
      Cart.instance.clear();
      Favorites.instance.clearAll();
      _applying = false;
    };
    if (ApiService.isLoggedIn) pull();
  }

  @visibleForTesting
  static void stop() {
    Cart.instance.removeListener(_changed);
    Favorites.instance.removeListener(_changed);
    ApiService.loggedIn.removeListener(pull);
    ApiService.beforeLogout = null;
    ApiService.afterLogout = null;
    _debounce?.cancel();
    _started = false;
  }

  static void _changed() {
    if (_applying || !ApiService.isLoggedIn) return;
    _debounce?.cancel();
    _debounce = Timer(delay, flush);
  }

  // Brings the account's lists over and saves the merged result back
  static Future<void> pull() async {
    if (!ApiService.isLoggedIn) return;
    try {
      final (favorites, cart) = await ApiService.fetchSaved();
      _applying = true;
      try {
        Favorites.instance.merge(favorites);
        await Cart.instance.mergeSaved(cart);
      } finally {
        _applying = false;
      }
      await flush();
    } catch (_) {
      // Offline or an admin account: lists stay on this phone for now
    }
  }

  // Saves now (also used just before logging out)
  static Future<void> flush() async {
    _debounce?.cancel();
    if (!ApiService.isLoggedIn) return;
    try {
      await ApiService.saveSaved(
        Favorites.instance.ids.toList(),
        Cart.instance.toSaved(),
      );
    } catch (_) {
      // Tried again with the next change
    }
  }
}
