import 'dart:async';

import 'package:flutter/widgets.dart';

// Quiet background refreshes, so prices, stock and order status stay up to
// date while a page is open, without the customer pulling to refresh.
class Live {
  // Off in widget tests (test/flutter_test_config.dart): a repeating timer
  // would still be pending when a test ends
  static bool enabled = true;

  static const interval = Duration(seconds: 20);

  // Calls [refresh] every [every] while [context]'s page is the one on top.
  // Returns null when live updates are off; cancel the timer in dispose().
  static Timer? poll(
    BuildContext Function() context,
    VoidCallback refresh, {
    Duration every = interval,
  }) {
    if (!enabled) return null;
    return Timer.periodic(every, (_) {
      final c = context();
      if (!c.mounted) return;
      // Not while another page covers this one
      if (ModalRoute.of(c)?.isCurrent == false) return;
      refresh();
    });
  }
}
