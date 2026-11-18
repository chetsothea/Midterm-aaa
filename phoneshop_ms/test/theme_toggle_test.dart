import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phoneshop_ms/main.dart';
import 'package:phoneshop_ms/hooks/theme_mode.dart';
import 'package:phoneshop_ms/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => AppThemeMode.instance.setDark(true));

  testWidgets(
    '☀️ / 🌙 switches dark and light, stays on the page, and is remembered',
    (tester) async {
      final mock = MockClient(
        (request) async => http.Response(
          jsonEncode(
            request.url.path.endsWith('/products')
                ? []
                : {'brands': [], 'categories': []},
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );
      await http.runWithClient(() async {
        await tester.pumpWidget(const MyApp(showSplash: false));
        await tester.pumpAndSettle();

        Color page() => Theme.of(
          tester.element(find.byType(Scaffold).first),
        ).scaffoldBackgroundColor;
        expect(AppThemeMode.instance.isDark, isTrue); // dark by default
        expect(page(), AppPalette.dark.page);

        await tester.tap(find.byTooltip('ប្តូរទៅពន្លឺ')); // "Light mode"
        await tester.pumpAndSettle();
        expect(AppThemeMode.instance.isDark, isFalse);
        expect(AppColors.page, AppPalette.light.page);
        expect(page(), AppPalette.light.page);
        expect(
          find.byTooltip('ប្តូរទៅងងឹត'),
          findsOneWidget,
        ); // now offers dark
        expect(tester.takeException(), isNull);

        // Saved for the next launch
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('dark_mode'), isFalse);

        await tester.tap(find.byTooltip('ប្តូរទៅងងឹត'));
        await tester.pumpAndSettle();
        expect(AppThemeMode.instance.isDark, isTrue);
        expect(page(), AppPalette.dark.page);
      }, () => mock);
    },
  );
}
