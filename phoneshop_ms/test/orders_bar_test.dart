import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phoneshop_ms/main.dart';
import 'package:phoneshop_ms/screens/my_orders_screen.dart';
import 'package:phoneshop_ms/data/api_service.dart';

void main() {
  final mock = MockClient(
    (request) async => http.Response(
      jsonEncode(
        request.url.path.endsWith('/menu')
            ? {'brands': [], 'categories': []}
            : [],
      ),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    ),
  );

  testWidgets('five items fit a narrow phone, with Telegram in the middle', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await http.runWithClient(() async {
      await tester.pumpWidget(const MyApp(showSplash: false));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      for (final label in [
        'ទំព័រដើម',
        'កន្ត្រក',
        'Telegram',
        'ការបញ្ជាទិញ',
        'គណនី',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      final telegram = tester.getCenter(find.text('Telegram')).dx;
      expect((telegram - 160).abs(), lessThan(4)); // the middle of the screen
    }, () => mock);
  });

  testWidgets('a guest is asked to log in before seeing orders', (
    tester,
  ) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(const MyApp(showSplash: false));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ការបញ្ជាទិញ'));
      await tester.pumpAndSettle();
      expect(find.text('សូម Login ដើម្បីមើល Order របស់អ្នក'), findsOneWidget);
    }, () => mock);
  });

  testWidgets('a customer goes straight to their orders', (tester) async {
    ApiService.token = 'test';
    addTearDown(() => ApiService.token = null);
    await http.runWithClient(() async {
      await tester.pumpWidget(const MyApp(showSplash: false));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ការបញ្ជាទិញ'));
      await tester.pumpAndSettle();
      expect(find.byType(MyOrdersScreen), findsOneWidget);
    }, () => mock);
  });
}
