import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phoneshop_ms/data/models/order.dart';
import 'package:phoneshop_ms/screens/admin/admin_orders_tab.dart';
import 'package:phoneshop_ms/data/api_service.dart';
import 'package:phoneshop_ms/components/order_tracking.dart';

void main() {
  testWidgets('the admin corrects a wrong location from the timeline', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(() => ApiService.token = null);

    final step = <String, dynamic>{
      'id': 5,
      'status': 'shipping',
      'location': 'សាខា ខុស',
      'note': 'ចំណាំ',
      'created_at': '2026-11-02T13:17:00Z',
    };
    final order = <String, dynamic>{
      'id': 17,
      'customer_name': 'ya',
      'total': '769.50',
      'status': 'shipping',
      'payment_method': 'cod',
      'payment_status': 'unpaid',
      'phone': '012',
      'address': 'PP',
      'created_at': '2026-11-02T13:17:00Z',
      'items': [],
      'trackings': [step],
    };
    final sent = <String, dynamic>{};
    String? path;
    final mock = MockClient((request) async {
      if (request.method == 'PUT') {
        path = request.url.path;
        sent.addAll(jsonDecode(request.body));
        step['location'] = sent['location'];
        step['note'] = sent['note'];
        return http.Response(
          jsonEncode(order),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response(
        jsonEncode([order]),
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
      await tester.tap(find.textContaining('#17'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('ការតាមដានឥវ៉ាន់'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull); // the pencil fits a narrow phone

      await tester.tap(find.byTooltip('កែទីតាំង'));
      await tester.pumpAndSettle();

      // The dialog starts from what is there now
      final location = find.widgetWithText(TextFormField, 'សាខា ខុស');
      expect(location, findsOneWidget);
      await tester.enterText(location, 'សាខា បាត់ដំបង');
      await tester.tap(find.text('រក្សាទុក'));
      await tester.pumpAndSettle();

      expect(path, endsWith('/admin/orders/17/tracking/5'));
      expect(sent, {'location': 'សាខា បាត់ដំបង', 'note': 'ចំណាំ'});
    }, () => mock);
  });

  testWidgets('customers see the timeline without any pencil', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrackingTimeline(
            steps: [
              TrackingStep(id: 5, status: 'shipping', time: DateTime(2026, 11, 2)),
            ],
          ),
        ),
      ),
    );

    expect(find.byTooltip('កែទីតាំង'), findsNothing);
  });
}
