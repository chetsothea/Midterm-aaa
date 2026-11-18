import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phoneshop_ms/screens/admin/admin_orders_tab.dart';
import 'package:phoneshop_ms/data/api_service.dart';

void main() {
  final order = {
    'id': 37,
    'customer_name': 'YAYA',
    'customer_email': 'y@example.com',
    'total': 364.65,
    'status': 'confirmed',
    'payment_method': 'khqr',
    'payment_status': 'paid',
    'phone': '012345678',
    'address': 'ភ្នំពេញ',
    'created_at': '2026-11-06T02:00:00Z',
    'courier': '',
    'tracking_number': '',
    'items': [
      {
        'product_id': 1,
        'qty': 1,
        'price': 364.65,
        'product': {'name': 'OPPO Reno16 5G'},
      },
    ],
    'trackings': [],
  };

  // Regression: on a narrow phone the two-line names ("Virak Buntham",
  // "Capitol Express") overflowed their tiles
  for (final width in [320.0, 360.0, 412.0]) {
    testWidgets('the courier tiles fit a ${width.toInt()}px phone', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await http.runWithClient(
        () async {
          ApiService.token = 'test';
          await tester.pumpWidget(
            const MaterialApp(home: Scaffold(body: AdminOrdersTab())),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('#37 YAYA'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('ចាប់ផ្តើមដឹក'));
          await tester.pumpAndSettle();

          expect(find.text('Virak Buntham'), findsOneWidget);
          await tester.tap(find.text('Capitol Express'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
        () => MockClient(
          (_) async => http.Response(
            jsonEncode([order]),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );
      ApiService.token = null;
    });
  }
}
