import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phoneshop_ms/screens/my_orders_screen.dart';
import 'package:phoneshop_ms/screens/payment_screen.dart';
import 'package:phoneshop_ms/services/api_service.dart';

Map<String, dynamic> order(
  int number,
  String status,
  String payment, {
  int items = 1,
}) => {
  'id': 30 + number,
  'customer_number': number,
  'user_id': 12,
  'customer_name': 'YAYA',
  'total': 364.65,
  'status': status,
  'payment_method': 'khqr',
  'payment_status': payment,
  'phone': '098466765',
  'address': 'ភូមិកៀនក្រឡាញ់, ខេត្តកោះកុង',
  'created_at': '2026-11-05T03:00:00Z',
  'items': [
    for (var i = 0; i < items; i++)
      {
        'product_id': 1,
        'qty': 1,
        'price': 364.65,
        'color': 'Twilight Violet',
        'storage': '12GB + 256GB',
        'product': {'name': 'OPPO Reno16 5G', 'image_url': ''},
      },
  ],
  'trackings': [
    if (status == 'shipping')
      {
        'id': 1,
        'status': 'shipping',
        'location': 'សាខា បាត់ដំបង',
        'note': '',
        'created_at': '2026-11-06T03:00:00Z',
      },
  ],
};

void main() {
  final orders = [
    order(5, 'pending', 'unpaid', items: 2),
    order(4, 'shipping', 'paid'),
    order(3, 'cancelled', 'unpaid'),
  ];

  for (final width in [320.0, 412.0]) {
    testWidgets(
      'order cards fit a ${width.toInt()}px phone and show what matters',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await http.runWithClient(
          () async {
            ApiService.token = 'test';
            await tester.pumpWidget(const MaterialApp(home: MyOrdersScreen()));
            await tester.pumpAndSettle();

            expect(tester.takeException(), isNull);
            // The customer's own numbers, the phone bought and the extra item
            expect(find.text('Order #5'), findsOneWidget);
            expect(find.text('OPPO Reno16 5G'), findsNWidgets(3));
            expect(find.text('+ 1 ទៀត'), findsOneWidget);
            // Where the parcel is, on the shipping one
            expect(find.text('សាខា បាត់ដំបង'), findsOneWidget);
            // Only the unpaid, not cancelled order can be paid or cancelled
            expect(find.text('បង់ប្រាក់'), findsOneWidget);
            expect(find.byTooltip('បោះបង់'), findsOneWidget);

            await tester.tap(find.text('បង់ប្រាក់'));
            await tester.pump();
            await tester.pump();
            expect(find.byType(PaymentScreen), findsOneWidget);
            await tester.pumpWidget(const SizedBox());
          },
          () => MockClient((request) async {
            if (request.url.path.endsWith('/khqr')) {
              return http.Response(
                '{"enabled": false}',
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            if (request.url.path.endsWith('/payment-info')) {
              return http.Response(
                '{"bank_name": "ABA"}',
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            return http.Response(
              jsonEncode(orders),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        );
        ApiService.token = null;
      },
    );
  }
}
