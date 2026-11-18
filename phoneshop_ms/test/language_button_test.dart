import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phoneshop_ms/main.dart';
import 'package:phoneshop_ms/hooks/language.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => AppLanguage.instance.setEnglish(false));

  testWidgets(
    'the language button sits at the right end, after the cart and switches the app',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));
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

        final language = tester.getCenter(find.byTooltip('Language'));
        final cart = tester.getCenter(find.byTooltip('Favourites'));
        expect(language.dy, cart.dy); // same row, right after the ♥
        expect(language.dx, greaterThan(cart.dx));
        expect(language.dx - cart.dx, lessThan(60));
        expect(tester.takeException(), isNull); // still fits a narrow phone

        await tester.tap(find.byTooltip('Language'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('English'));
        await tester.pumpAndSettle();
        expect(find.text('Home'), findsOneWidget);

        await tester.tap(find.byTooltip('Language'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('ខ្មែរ'));
        await tester.pumpAndSettle();
        expect(find.text('ទំព័រដើម'), findsOneWidget);
      }, () => mock);
    },
  );
}
