import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phoneshop_ms/main.dart';
import 'package:phoneshop_ms/services/api_service.dart';

Map<String, dynamic> order(int id, String status) => {
  'id': id,
  'customer_name': 'Thea',
  'user_id': 2,
  'total': '100.00',
  'status': status,
  'payment_method': 'cod',
  'payment_status': 'unpaid',
  'created_at': '2026-11-03T04:00:00Z',
  'items': [],
  'trackings': [],
};

void main() {
  final mock = MockClient((request) async {
    final path = request.url.path;
    final body = path.endsWith('/menu')
        ? {'brands': [], 'categories': []}
        : path.endsWith('/orders')
        ? [
            order(1, 'pending'),
            order(2, 'shipping'),
            order(3, 'delivered'),
            order(4, 'cancelled'),
          ]
        : [];
    return http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });

  Badge orderBadge(WidgetTester tester) => tester.widget<Badge>(
    find.ancestor(
      of: find.byIcon(Icons.receipt_long_outlined),
      matching: find.byType(Badge),
    ),
  );

  testWidgets('Order shows how many orders are still on their way', (
    tester,
  ) async {
    ApiService.token = 'test';
    addTearDown(() => ApiService.token = null);
    await http.runWithClient(() async {
      await tester.pumpWidget(const MyApp(showSplash: false));
      await tester.pumpAndSettle();
      expect(orderBadge(tester).isLabelVisible, isTrue);
      // Pending and shipping; not the delivered or cancelled ones
      expect(
        find.descendant(of: find.byType(Badge), matching: find.text('2')),
        findsOneWidget,
      );
    }, () => mock);
  });

  testWidgets('a guest has no number', (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(const MyApp(showSplash: false));
      await tester.pumpAndSettle();
      expect(orderBadge(tester).isLabelVisible, isFalse);
    }, () => mock);
  });
}
