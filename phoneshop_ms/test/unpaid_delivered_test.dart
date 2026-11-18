import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phoneshop_ms/screens/admin/admin_dashboard_tab.dart';
import 'package:phoneshop_ms/data/api_service.dart';

Map<String, dynamic> stats(int count, num total) => {
  'total_products': 6,
  'low_stock': 0,
  'low_stock_threshold': 3,
  'total_customers': 2,
  'total_orders': 3,
  'pending_orders': 0,
  'verifying_payments': 0,
  'unpaid_delivered': count,
  'unpaid_delivered_total': total,
  'revenue': 100,
  'revenue_by_day': [],
  'orders_by_status': [],
  'top_products': [],
};

Map<String, dynamic> order(int id, String payment) => {
  'id': id,
  'customer_name': 'Thea',
  'total': '310.00',
  'status': 'delivered',
  'payment_method': 'cod',
  'payment_status': payment,
  'phone': '012',
  'address': 'PP',
  'created_at': '2026-11-03T04:00:00Z',
  'items': [],
  'trackings': [],
};

void main() {
  http.Response json(Object body) => http.Response(
    jsonEncode(body),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  testWidgets(
    'the warning opens only the orders still to collect, and marking one paid clears it',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(() => ApiService.token = null);

      final orders = [order(18, 'unpaid'), order(14, 'paid')];
      final mock = MockClient((request) async {
        if (request.url.path.endsWith('/dashboard')) {
          final unpaid = orders
              .where((o) => o['payment_status'] == 'unpaid')
              .length;
          return json(stats(unpaid, unpaid * 310));
        }
        if (request.method == 'PUT') {
          orders[0] = order(18, 'paid');
          return json(orders[0]);
        }
        return json(orders);
      });

      await http.runWithClient(() async {
        ApiService.token = 'test';
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: AdminDashboardTab())),
        );
        await tester.pumpAndSettle();
        expect(find.text('1 Order • \$310.00'), findsOneWidget);

        await tester.tap(find.text('បានទទួលហើយ តែមិនទាន់បង់'));
        await tester.pumpAndSettle();
        expect(find.textContaining('#18'), findsOneWidget);
        expect(find.textContaining('#14'), findsNothing); // already paid

        await tester.tap(find.textContaining('#18'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('បានទទួលសាច់ប្រាក់'));
        await tester.pumpAndSettle();
        expect(find.text('មិនមាន Order'), findsOneWidget);

        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.text('បានទទួលហើយ តែមិនទាន់បង់'), findsNothing);
      }, () => mock);
    },
  );

  testWidgets('nothing to collect: no warning', (tester) async {
    addTearDown(() => ApiService.token = null);
    await http.runWithClient(() async {
      ApiService.token = 'test';
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AdminDashboardTab())),
      );
      await tester.pumpAndSettle();
      expect(find.text('បានទទួលហើយ តែមិនទាន់បង់'), findsNothing);
    }, () => MockClient((_) async => json(stats(0, 0))));
  });
}
