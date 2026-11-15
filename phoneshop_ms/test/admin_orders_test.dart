import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phoneshop_ms/screens/admin/admin_orders_tab.dart';
import 'package:phoneshop_ms/services/api_service.dart';

void main() {
  testWidgets('admin can confirm a KHQR payment on a guest order', (tester) async {
    // Tall enough for the opened order card and its buttons
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    // Real API data: guest order #7 waiting for the admin to check the payment
    final orders = jsonDecode(File('test/fixtures/admin_orders.json').readAsStringSync()) as List;
    final requests = <String>[];

    final mock = MockClient((request) async {
      requests.add('${request.method} ${request.url.path}');
      if (request.method == 'PUT' && request.url.path == '/api/admin/orders/7') {
        final body = jsonDecode(request.body) as Map;
        final order = Map<String, dynamic>.from(orders.first)
          ..['status'] = body['status'] ?? orders.first['status']
          ..['payment_status'] = body['payment_status'] ?? orders.first['payment_status'];
        orders[0] = order;
        return http.Response(jsonEncode(order), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      }
      return http.Response(jsonEncode(orders), 200, headers: {'content-type': 'application/json; charset=utf-8'});
    });

    await http.runWithClient(() async {
      ApiService.token = 'test';
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: AdminOrdersTab())));
      await tester.pumpAndSettle();

      expect(find.text('បញ្ជាក់បានទទួលប្រាក់'), findsOneWidget);
      await tester.tap(find.text('បញ្ជាក់បានទទួលប្រាក់'));
      // Throws if the screen never settles (endless rebuilds / animations)
      await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 10));

      // Regression: refreshing used to call setState(() => _orders = …), which returns a
      // Future; Flutter throws on that, the list never refreshed and debug builds froze.
      expect(tester.takeException(), isNull);
      expect(requests, ['GET /api/admin/orders', 'PUT /api/admin/orders/7', 'GET /api/admin/orders']);
      expect(find.text('បញ្ជាក់បានទទួលប្រាក់'), findsNothing); // payment is no longer "verifying"
      expect(find.text('បានបង់'), findsWidgets);
    }, () => mock);
    ApiService.token = null;
  });
}
