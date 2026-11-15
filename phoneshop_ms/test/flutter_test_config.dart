import 'dart:async';

import 'package:phoneshop_ms/widgets/brand_row.dart';

// Runs before every test file. The brand row's endless drift would keep
// pumpAndSettle() from ever finishing, so tests see it standing still
// (test/brand_marquee_test.dart turns it back on to check it).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  BrandRow.autoScroll = false;
  await testMain();
}
