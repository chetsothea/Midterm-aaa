import 'dart:async';

import 'package:flutter/foundation.dart';
import '../data/api_service.dart';
import '../data/models/notice.dart';

// The 🔔: unread count for the badge, checked every minute while logged in
class Notices extends ChangeNotifier {
  Notices._();
  static final Notices instance = Notices._();

  // How often to ask (shorter in tests)
  static Duration every = const Duration(minutes: 1);

  int unread = 0;
  List<Notice> items = [];
  Timer? _timer;
  bool _asking = false;

  // Started by the store page; harmless to call more than once
  void watch() {
    if (_timer != null) return;
    _timer = Timer.periodic(every, (_) => refresh());
    refresh();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> refresh() async {
    if (!ApiService.isLoggedIn || (ApiService.currentUser?.isTeam ?? false)) {
      if (unread != 0 || items.isNotEmpty) {
        unread = 0;
        items = [];
        notifyListeners();
      }
      return;
    }
    if (_asking) return;
    _asking = true;
    try {
      final (count, list) = await ApiService.fetchNotices();
      unread = count;
      items = list;
      notifyListeners();
    } catch (_) {
      // Offline: try again next minute
    } finally {
      _asking = false;
    }
  }

  Future<void> markAllRead() async {
    if (unread == 0) return;
    unread = 0;
    notifyListeners();
    try {
      await ApiService.markNoticesRead();
    } catch (_) {}
  }
}
