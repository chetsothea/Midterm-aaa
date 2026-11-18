import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phoneshop_ms/screens/admin/admin_dashboard_tab.dart';
import 'package:phoneshop_ms/data/api_service.dart';

void main() {
  http.Response json(Object body) => http.Response(
    jsonEncode(body),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  testWidgets('the admin is told, sees the order, and the notice then goes away', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(() => ApiService.token = null);

    var seen = false;
    Map<String, dynamic> order(int id, String? receivedAt) => {
      'id': id,
      'customer_name': 'Thea',
      'total': '310.00',
      'status': 'delivered',
      'payment_method': 'cod',
      'payment_status': 'paid',
      'phone': '012',
      'address': 'PP',
      'created_at': '2026-11-03T04:00:00Z',
      'received_at': receivedAt,
      'received_seen_at': null,
      'items': [],
      'trackings': [],
    };

    final mock = MockClient((request) async {
      if (request.url.path.endsWith('/received-seen')) {
        seen = true;
        return json({'message': 'OK'});
      }
      if (request.url.path.endsWith('/dashboard')) {
        return json({
          'total_products': 6,
          'low_stock': 0,
          'low_stock_threshold': 3,
          'total_customers': 2,
          'total_orders': 3,
          'pending_orders': 0,
          'verifying_payments': 0,
          'new_received': seen ? 0 : 1,
          'unpaid_delivered': 0,
          'unpaid_delivered_total': 0,
          'revenue': 100,
          'revenue_by_day': [],
          'orders_by_status': [],
          'top_products': [],
        });
      }
      return json([order(18, '2026-11-03T04:02:00Z'), order(14, null)]);
    });

    await http.runWithClient(() async {
      ApiService.token = 'test';
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AdminDashboardTab())),
      );
      await tester.pumpAndSettle();
      expect(find.text('1 Order ថ្មី'), findsOneWidget);

      await tester.tap(find.text('អតិថិជនបានទទួលឥវ៉ាន់'));
      await tester.pumpAndSettle();
      expect(find.textContaining('#18'), findsOneWidget);
      expect(find.textContaining('#14'), findsNothing); // the admin marked this one

      await tester.tap(find.textContaining('#18'));
      await tester.pumpAndSettle();
      expect(find.textContaining('អតិថិជនបានបញ្ជាក់ថាទទួលឥវ៉ាន់'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(seen, isTrue);
      expect(find.text('អតិថិជនបានទទួលឥវ៉ាន់'), findsNothing);
    }, () => mock);
  });
}
