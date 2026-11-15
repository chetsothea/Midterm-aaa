import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phoneshop_ms/screens/my_orders_screen.dart';
import 'package:phoneshop_ms/services/api_service.dart';

Map<String, dynamic> order(int id, String code, String status) => {
  'id': id,
  'code': code,
  'user_id': 12,
  'customer_name': 'YAYA',
  'total': 126,
  'status': status,
  'payment_method': 'khqr',
  'payment_status': 'unpaid',
  'phone': '012',
  'address': 'PP',
  'created_at': '2026-11-09T03:00:00Z',
  'items': [
    {
      'product_id': 1,
      'qty': 1,
      'price': 126,
      'product': {'name': 'iPad Pro 11-inch (2018)', 'image_url': ''},
    },
  ],
  'trackings': [],
};

void main() {
  testWidgets('a cancelled order can be removed from the list, after asking', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final orders = [
      order(41, 'PS-G2QB9A', 'cancelled'),
      order(40, 'PS-C4ECGF', 'pending'),
    ];
    final deleted = <String>[];

    await http.runWithClient(
      () async {
        ApiService.token = 'test';
        await tester.pumpWidget(const MaterialApp(home: MyOrdersScreen()));
        await tester.pumpAndSettle();

        // Only the cancelled one offers removal
        expect(find.text('លុបចេញពីបញ្ជី'), findsOneWidget);

        await tester.tap(find.text('លុបចេញពីបញ្ជី'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('ទេ'));
        await tester.pumpAndSettle();
        expect(deleted, isEmpty);

        await tester.tap(find.text('លុបចេញពីបញ្ជី'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'លុបចេញ'));
        await tester.pumpAndSettle();

        expect(deleted, ['/api/orders/41']);
        expect(find.text('Order PS-G2QB9A'), findsNothing);
        expect(find.text('Order PS-C4ECGF'), findsOneWidget);
      },
      () => MockClient((request) async {
        if (request.method == 'DELETE') {
          deleted.add(request.url.path);
          orders.removeWhere((o) => request.url.path.endsWith('/${o['id']}'));
          return http.Response('{"message":"OK"}', 200);
        }
        return http.Response(
          jsonEncode(orders),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    ApiService.token = null;
  });

  testWidgets('a received order can be removed too, from its delete icon', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final orders = [
      order(52, 'PS-RUFE3W', 'delivered'),
      order(51, 'PS-NEBQD9', 'shipping'),
    ];
    final deleted = <String>[];

    await http.runWithClient(
      () async {
        ApiService.token = 'test';
        await tester.pumpWidget(const MaterialApp(home: MyOrdersScreen()));
        await tester.pumpAndSettle();

        // Only the received one has the delete icon
        expect(find.byTooltip('លុបចេញពីបញ្ជី'), findsOneWidget);

        await tester.tap(find.byTooltip('លុបចេញពីបញ្ជី'));
        await tester.pumpAndSettle();
        expect(find.textContaining('អ្នកបានទទួលឥវ៉ាន់រួចហើយ'), findsOneWidget);
        await tester.tap(find.widgetWithText(FilledButton, 'លុបចេញ'));
        await tester.pumpAndSettle();

        expect(deleted, ['/api/orders/52']);
        expect(find.text('Order PS-RUFE3W'), findsNothing);
        expect(find.text('Order PS-NEBQD9'), findsOneWidget);
      },
      () => MockClient((request) async {
        if (request.method == 'DELETE') {
          deleted.add(request.url.path);
          orders.removeWhere((o) => request.url.path.endsWith('/${o['id']}'));
          return http.Response('{"message":"OK"}', 200);
        }
        return http.Response(
          jsonEncode(orders),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    ApiService.token = null;
  });

  testWidgets('the chips at the top show one kind of order at a time', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final orders = [
      order(63, 'PS-AAAAAA', 'shipping'),
      order(62, 'PS-BBBBBB', 'delivered'),
      order(61, 'PS-CCCCCC', 'cancelled'),
    ];

    await http.runWithClient(
      () async {
        ApiService.token = 'test';
        await tester.pumpWidget(const MaterialApp(home: MyOrdersScreen()));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('ទាំងអស់  3'), findsOneWidget);
        expect(find.text('Order PS-AAAAAA'), findsOneWidget);
        expect(find.text('Order PS-BBBBBB'), findsOneWidget);

        // The chips scroll sideways on a narrow phone
        await tester.scrollUntilVisible(
          find.text('បានទទួល  1'),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('បានទទួល  1'));
        await tester.pumpAndSettle();
        expect(find.text('Order PS-BBBBBB'), findsOneWidget);
        expect(find.text('Order PS-AAAAAA'), findsNothing);
        expect(find.text('Order PS-CCCCCC'), findsNothing);
      },
      () => MockClient(
        (_) async => http.Response(
          jsonEncode(orders),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    ApiService.token = null;
  });
}
