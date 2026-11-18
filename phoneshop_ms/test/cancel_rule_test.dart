import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phoneshop_ms/data/api_service.dart';
import 'package:phoneshop_ms/data/models/order.dart';
import 'package:phoneshop_ms/screens/my_orders_screen.dart';

Map<String, dynamic> _order(
  String status, {
  String payment = 'unpaid',
  bool? canCancel,
}) => {
  'id': 39,
  'code': 'PS-SPNCK6',
  'user_id': 12,
  'customer_name': 'YAYA',
  'total': 364.65,
  'status': status,
  'payment_method': 'khqr',
  'payment_status': payment,
  'phone': '098466765',
  'address': 'PP',
  'created_at': '2026-11-05T03:00:00Z',
  'can_cancel': ?canCancel,
  'items': [
    {
      'product_id': 1,
      'qty': 1,
      'price': 364.65,
      'product': {'name': 'OPPO Reno16 5G', 'image_url': ''},
    },
  ],
  'trackings': [],
};

void main() {
  tearDown(() => ApiService.token = null);

  test('new and packing orders can be cancelled, shipping ones cannot', () {
    expect(Order.fromJson(_order('pending')).canCancel, isTrue);
    expect(Order.fromJson(_order('confirmed')).canCancel, isTrue);
    expect(Order.fromJson(_order('shipping')).canCancel, isFalse);
    expect(Order.fromJson(_order('delivered')).canCancel, isFalse);
    // The server's word wins
    expect(
      Order.fromJson(_order('confirmed', canCancel: false)).canCancel,
      isFalse,
    );
  });

  Future<void> pumpOrders(
    WidgetTester tester,
    Map<String, dynamic> order,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    ApiService.token = 'test';
    await tester.pumpWidget(const MaterialApp(home: MyOrdersScreen()));
    await tester.pumpAndSettle();
  }

  for (final (status, shown) in [
    ('pending', true),
    ('confirmed', true),
    ('shipping', false),
  ]) {
    testWidgets(
      'cancel button on a $status order: ${shown ? 'shown' : 'hidden'}',
      (tester) async {
        final order = _order(status, canCancel: shown);
        await http.runWithClient(
          () => pumpOrders(tester, order),
          () => MockClient(
            (_) async => http.Response(
              jsonEncode([order]),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            ),
          ),
        );
        expect(find.byTooltip('បោះបង់'), shown ? findsOneWidget : findsNothing);
      },
    );
  }

  testWidgets('a paid order says the shop will refund', (tester) async {
    final order = _order('confirmed', payment: 'paid', canCancel: true);
    await http.runWithClient(
      () async {
        await pumpOrders(tester, order);
        await tester.tap(find.byTooltip('បោះបង់'));
        await tester.pumpAndSettle();
      },
      () => MockClient(
        (_) async => http.Response(
          jsonEncode([order]),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    expect(
      find.textContaining('ហាងនឹងទាក់ទងអ្នក ដើម្បីបង្វិលប្រាក់ \$364.65'),
      findsOneWidget,
    );
  });
}
