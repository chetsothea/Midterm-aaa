import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phoneshop_ms/data/models/order.dart';
import 'package:phoneshop_ms/screens/admin/admin_orders_tab.dart';
import 'package:phoneshop_ms/screens/order_tracking_screen.dart';
import 'package:phoneshop_ms/data/api_service.dart';

// An order as the API returns it, at [status], with tracking steps newest first
Map<String, dynamic> orderJson(
  String status,
  List<Map<String, dynamic>> trackings, {
  String courier = '',
  String number = '',
}) => {
  'id': 8,
  'user_id': 2,
  'customer_name': 'Dara',
  'customer_email': 'dara@example.com',
  'total': 1539,
  'status': status,
  'payment_method': 'cod',
  'payment_status': 'unpaid',
  'transaction_ref': null,
  'phone': '099111222',
  'address': 'ភូមិ ១, ខេត្តបាត់ដំបង, កម្ពុជា',
  'courier': courier,
  'tracking_number': number,
  'created_at': '2026-11-01T02:41:07.000000Z',
  'items': [],
  'trackings': trackings,
};

Map<String, dynamic> step(
  String status,
  String time, {
  String? location,
  String? note,
}) => {
  'status': status,
  'location': location,
  'note': note,
  'created_at': time,
};

http.Response json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  tearDown(() => ApiService.token = null);

  testWidgets('customer sees where the package is', (tester) async {
    // Tall enough for the whole page: the step list comes after the other cards
    await tester.binding.setSurfaceSize(const Size(400, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final shipped = orderJson(
      'shipping',
      [
        step(
          'shipping',
          '2026-11-02T03:00:00Z',
          location: 'សាខា បាត់ដំបង',
          note: 'ឥវ៉ាន់ដល់សាខាហើយ',
        ),
        step('shipping', '2026-11-01T08:00:00Z', location: 'ឃ្លាំង ភ្នំពេញ'),
        step('confirmed', '2026-11-01T03:00:00Z'),
        step('pending', '2026-11-01T02:41:07Z', note: 'បានទទួល Order របស់អ្នក'),
      ],
      courier: 'J&T Express',
      number: 'JT0123456789',
    );

    await http.runWithClient(() async {
      ApiService.token = 'test';
      // Opens with an older copy of the order; the screen reloads the latest from the API
      final stale = Order.fromJson(orderJson('confirmed', []));
      await tester.pumpWidget(
        MaterialApp(home: OrderTrackingScreen(order: stale)),
      );
      await tester.pumpAndSettle();

      expect(find.text('J&T Express'), findsOneWidget);
      expect(find.text('លេខតាមដាន: JT0123456789'), findsOneWidget);
      expect(find.text('សាខា បាត់ដំបង'), findsOneWidget);
      expect(find.text('ឃ្លាំង ភ្នំពេញ'), findsOneWidget);
      expect(find.text('ឥវ៉ាន់ដល់សាខាហើយ'), findsOneWidget);
      // Newest step is listed first
      expect(
        tester.getTopLeft(find.text('សាខា បាត់ដំបង')).dy,
        lessThan(tester.getTopLeft(find.text('ឃ្លាំង ភ្នំពេញ')).dy),
      );
    }, () => MockClient((request) async => json(shipped)));
  });

  testWidgets('customer confirms the parcel arrived', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var order = orderJson('shipping', [
      step('shipping', '2026-11-02T01:47:00Z', location: 'pp'),
    ]);
    final posted = <String>[];

    await http.runWithClient(
      () async {
        ApiService.token = 'test';
        await tester.pumpWidget(
          MaterialApp(home: OrderTrackingScreen(order: Order.fromJson(order))),
        );
        await tester.pumpAndSettle();

        // Changing their mind sends nothing
        await tester.tap(find.text('ខ្ញុំបានទទួលឥវ៉ាន់ហើយ'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('មិនទាន់'));
        await tester.pumpAndSettle();
        expect(posted, isEmpty);

        // Confirming updates the screen, and the button goes away
        await tester.tap(find.text('ខ្ញុំបានទទួលឥវ៉ាន់ហើយ'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('បានទទួលហើយ'));
        await tester.pumpAndSettle();

        expect(posted, ['/api/orders/8/received']);
        expect(find.text('អ្នកទិញបានបញ្ជាក់ថាទទួលឥវ៉ាន់ហើយ'), findsOneWidget);
        expect(find.text('ខ្ញុំបានទទួលឥវ៉ាន់ហើយ'), findsNothing);
        expect(tester.takeException(), isNull);
      },
      () => MockClient((request) async {
        if (request.method == 'POST') {
          posted.add(request.url.path);
          order = orderJson('delivered', [
            step(
              'delivered',
              '2026-11-02T03:00:00Z',
              note: 'អ្នកទិញបានបញ្ជាក់ថាទទួលឥវ៉ាន់ហើយ',
            ),
            ...order['trackings'],
          ]);
          order['received_at'] = '2026-11-02T03:00:00Z';
        }
        return json(order);
      }),
    );
  });

  testWidgets(
    'the received button also shows on a delivered order until confirmed',
    (tester) async {
      final delivered = orderJson('delivered', []);
      await http.runWithClient(() async {
        ApiService.token = 'test';
        await tester.pumpWidget(
          MaterialApp(
            home: OrderTrackingScreen(order: Order.fromJson(delivered)),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('ខ្ញុំបានទទួលឥវ៉ាន់ហើយ'), findsOneWidget);
      }, () => MockClient((_) async => json(delivered)));

      final confirmed = {...delivered, 'received_at': '2026-11-03T04:00:00Z'};
      await http.runWithClient(() async {
        await tester.pumpWidget(
          MaterialApp(
            key: const ValueKey('confirmed'),
            home: OrderTrackingScreen(order: Order.fromJson(confirmed)),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('ខ្ញុំបានទទួលឥវ៉ាន់ហើយ'), findsNothing);
      }, () => MockClient((_) async => json(confirmed)));
    },
  );

  testWidgets('the received button stays hidden before the parcel is sent', (
    tester,
  ) async {
    for (final status in ['pending', 'confirmed', 'cancelled']) {
      final order = orderJson(status, []);
      await http.runWithClient(() async {
        ApiService.token = 'test';
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey(status),
            home: OrderTrackingScreen(order: Order.fromJson(order)),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('ខ្ញុំបានទទួលឥវ៉ាន់ហើយ'),
          findsNothing,
          reason: status,
        );
      }, () => MockClient((_) async => json(order)));
    }
  });

  testWidgets(
    'admin starts shipping with courier, parcel number and location',
    (tester) async {
      // Tall enough for the opened order card and its buttons
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      Map<String, dynamic>? sent;
      var order = orderJson('confirmed', [
        step('confirmed', '2026-11-01T03:00:00Z'),
      ]);

      await http.runWithClient(
        () async {
          ApiService.token = 'test';
          await tester.pumpWidget(
            const MaterialApp(home: Scaffold(body: AdminOrdersTab())),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.text('#8 Dara'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('ចាប់ផ្តើមដឹក'));
          await tester.pumpAndSettle();

          await tester.tap(find.text('J&T Express')); // quick-pick chip
          await tester.enterText(
            find.widgetWithText(TextFormField, 'លេខតាមដាន (Tracking No.)'),
            'JT0123456789',
          );
          await tester.enterText(
            find.widgetWithText(TextFormField, 'ទីតាំងបច្ចុប្បន្ន'),
            'ឃ្លាំង ភ្នំពេញ',
          );
          await tester.tap(find.text('រក្សាទុក'));
          await tester.pumpAndSettle();

          expect(sent, {
            'status': 'shipping',
            'courier': 'J&T Express',
            'tracking_number': 'JT0123456789',
            'location': 'ឃ្លាំង ភ្នំពេញ',
            'note': '',
          });
          expect(tester.takeException(), isNull);
        },
        () => MockClient((request) async {
          if (request.method == 'PUT') {
            sent = Map<String, dynamic>.from(jsonDecode(request.body));
            order = orderJson(
              'shipping',
              [
                step(
                  'shipping',
                  '2026-11-01T08:00:00Z',
                  location: 'ឃ្លាំង ភ្នំពេញ',
                ),
                ...order['trackings'],
              ],
              courier: 'J&T Express',
              number: 'JT0123456789',
            );
            return json(order);
          }
          return json([order]);
        }),
      );
    },
  );
}
