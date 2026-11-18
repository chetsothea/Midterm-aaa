import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phoneshop_ms/screens/admin/admin_orders_tab.dart';
import 'package:phoneshop_ms/data/api_service.dart';

void main() {
  testWidgets('deleting an order asks first, and only yes removes it', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(() => ApiService.token = null);

    final orders = [
      <String, dynamic>{
        'id': 13,
        'customer_name': 'Thea',
        'total': '1539.00',
        'status': 'cancelled',
        'payment_method': 'cod',
        'payment_status': 'unpaid',
        'phone': '012',
        'address': 'PP',
        'created_at': '2026-11-01T00:00:00Z',
        'items': [],
        'trackings': [],
      },
    ];
    final deleted = <String>[];
    final mock = MockClient((request) async {
      if (request.method == 'DELETE') {
        deleted.add(request.url.path);
        orders.clear();
        return http.Response('{"message":"Deleted"}', 200);
      }
      return http.Response(
        jsonEncode(orders),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    await http.runWithClient(() async {
      ApiService.token = 'test';
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AdminOrdersTab())),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('#13'));
      await tester.pumpAndSettle();

      // "No" changes nothing
      await tester.tap(find.text('លុប Order'));
      await tester.pumpAndSettle();
      expect(find.textContaining('មិនអាចយកមកវិញ'), findsOneWidget);
      await tester.tap(find.text('ទេ'));
      await tester.pumpAndSettle();
      expect(deleted, isEmpty);

      // "Yes" deletes and the list refreshes
      await tester.tap(find.text('លុប Order'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'លុប'));
      await tester.pumpAndSettle();
      expect(deleted.single, endsWith('/admin/orders/13'));
      expect(find.textContaining('#13 Thea'), findsNothing);
    }, () => mock);
  });
}
