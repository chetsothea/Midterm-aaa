import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:phoneshop_ms/components/brand_row.dart';
import 'package:phoneshop_ms/components/motion.dart';
import 'package:phoneshop_ms/hooks/live.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Runs before every test file. The brand row's endless drift would keep
// pumpAndSettle() from ever finishing, so tests see it standing still
// (test/brand_marquee_test.dart turns it back on to check it).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  BrandRow.autoScroll = false;
  Motion.ambient = false; // floating pictures, pulsing badges, title gleams
  Live.enabled = false; // no background refresh timers left pending
  // In-memory storage, so the saved cart and login work like on a phone
  SharedPreferences.setMockInitialValues({});
  FlutterSecureStorage.setMockInitialValues({});
  await testMain();
}
