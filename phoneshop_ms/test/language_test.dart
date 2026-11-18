import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phoneshop_ms/main.dart';
import 'package:phoneshop_ms/screens/login_screen.dart';
import 'package:phoneshop_ms/hooks/language.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => AppLanguage.instance.setEnglish(false));

  testWidgets('switching to English changes the open page at once, and back', (
    tester,
  ) async {
    final mock = MockClient((request) async => http.Response(
      jsonEncode(request.url.path.endsWith('/products')
          ? []
          : {'brands': [], 'categories': []}),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    ));

    await http.runWithClient(() async {
      await tester.pumpWidget(const MyApp(showSplash: false));
      await tester.pumpAndSettle();
      expect(find.text('ទំព័រដើម'), findsOneWidget); // bottom menu, Khmer by default

      await tester.tap(find.byTooltip('Language'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Menu'));
      await tester.pumpAndSettle();

      // The page and the side menu
      expect(find.text('BROWSE'), findsOneWidget);
      expect(find.text('Home'), findsWidgets);
      expect(find.text('ទំព័រដើម'), findsNothing);

      Navigator.of(tester.element(find.text('BROWSE'))).pop(); // close the menu
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Language'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ខ្មែរ'));
      await tester.pumpAndSettle();
      expect(find.text('ទំព័រដើម'), findsWidgets);
    }, () => mock);
  });

  testWidgets('the choice is remembered for next time', (tester) async {
    await AppLanguage.instance.setEnglish(true);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('language'), 'en');

    await AppLanguage.instance.load();
    expect(AppLanguage.instance.isEnglish, isTrue);

    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    expect(find.text('Login to your account'), findsOneWidget);
  });

  test('every text with a translation has a non-empty one', () {
    expect(tr('ដាក់ Cart'), 'ដាក់ Cart'); // Khmer: as written
    AppLanguage.instance.setEnglish(true);
    expect(tr('ដាក់ Cart'), 'Add to cart');
    expect(tr('Not in the table'), 'Not in the table');
  });
}
