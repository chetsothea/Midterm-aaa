import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phoneshop_ms/screens/admin/admin_customers_screen.dart';
import 'package:phoneshop_ms/services/api_service.dart';

void main() {
  testWidgets('deleting asks first, and only yes removes the customer', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(() => ApiService.token = null);

    final customers = [
      <String, dynamic>{
        'id': 6,
        'name': 'Thea',
        'email': 'thea@gmail.com',
        'blocked_at': null,
        'created_at': '2026-10-31T02:57:07.000000Z',
        'orders_count': 4,
      },
    ];
    final deleted = <String>[];
    final mock = MockClient((request) async {
      if (request.method == 'DELETE') {
        deleted.add(request.url.path);
        customers.clear();
        return http.Response('{"message":"Deleted"}', 200);
      }
      return http.Response(
        jsonEncode(customers),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    await http.runWithClient(() async {
      ApiService.token = 'test';
      await tester.pumpWidget(const MaterialApp(home: AdminCustomersScreen()));
      await tester.pumpAndSettle();

      // "No" changes nothing
      await tester.tap(find.widgetWithText(OutlinedButton, 'លុប'));
      await tester.pumpAndSettle();
      expect(find.textContaining('មិនអាចយកមកវិញ'), findsOneWidget);
      expect(find.textContaining('Order 4'), findsOneWidget);
      await tester.tap(find.text('ទេ'));
      await tester.pumpAndSettle();
      expect(deleted, isEmpty);
      expect(find.text('thea@gmail.com'), findsOneWidget);

      // "Yes" deletes and the list refreshes
      await tester.tap(find.widgetWithText(OutlinedButton, 'លុប'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'លុប'));
      await tester.pumpAndSettle();
      expect(deleted.single, endsWith('/admin/customers/6'));
      expect(find.text('thea@gmail.com'), findsNothing);
      expect(find.text('មិនទាន់មានអតិថិជនចុះឈ្មោះទេ'), findsOneWidget);
    }, () => mock);
  });
}
