import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phoneshop_ms/screens/my_orders_screen.dart';
import 'package:phoneshop_ms/data/api_service.dart';

void main() {
  final order = {
    'id': 39,
    'code': 'PS-SPNCK6',
    'user_id': 12,
    'customer_name': 'YAYA',
    'total': 364.65,
    'status': 'pending',
    'payment_method': 'khqr',
    'payment_status': 'unpaid',
    'phone': '098466765',
    'address': 'PP',
    'created_at': '2026-11-05T03:00:00Z',
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

  testWidgets(
    'cancelling asks first, shows the code whole, and only "cancel" cancels',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final cancels = <String>[];

      await http.runWithClient(
        () async {
          ApiService.token = 'test';
          await tester.pumpWidget(const MaterialApp(home: MyOrdersScreen()));
          await tester.pumpAndSettle();

          await tester.tap(find.byTooltip('បោះបង់'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('បោះបង់ Order នេះ?'), findsOneWidget);
          // The code sits on its own line, in one piece
          expect(find.text('PS-SPNCK6'), findsOneWidget);

          await tester.tap(find.text('ទេ, រក្សាទុក'));
          await tester.pumpAndSettle();
          expect(find.text('បោះបង់ Order នេះ?'), findsNothing);
          expect(cancels, isEmpty);

          await tester.tap(find.byTooltip('បោះបង់'));
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(FilledButton, 'បោះបង់'));
          await tester.pumpAndSettle();
          expect(cancels, ['/api/orders/39/cancel']);
        },
        () => MockClient((request) async {
          if (request.url.path.endsWith('/cancel')) {
            cancels.add(request.url.path);
            return http.Response(
              jsonEncode({...order, 'status': 'cancelled'}),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          return http.Response(
            jsonEncode([order]),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      ApiService.token = null;
    },
  );
}
