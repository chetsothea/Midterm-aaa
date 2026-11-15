import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phoneshop_ms/screens/admin/admin_home_screen.dart';
import 'package:phoneshop_ms/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  // The shop's orders as the server sees them; tests add to it
  late List<Map<String, dynamic>> orders;

  MockClient server() => MockClient((request) async {
    if (request.url.path == '/api/admin/orders/new') {
      final after = int.tryParse(request.url.queryParameters['after'] ?? '');
      final latest = orders.isEmpty ? 0 : orders.last['id'] as int;
      if (after == null) return json({'latest_id': latest, 'count': 0, 'orders': []});
      final newer = orders.where((o) => (o['id'] as int) > after).toList().reversed.toList();
      return json({'latest_id': latest, 'count': newer.length, 'orders': newer.take(5).toList()});
    }
    if (request.url.path == '/api/admin/orders') return json([]);
    return http.Response("{\"message\":\"not in this test\"}", 500);
  });

  Map<String, dynamic> order(int id, String name) =>
      {'id': id, 'customer_name': name, 'total': '364.65', 'payment_method': 'khqr'};

  setUp(() {
    orders = [order(35, 'YAYA')];
    ApiService.token = 'test';
  });
  tearDown(() => ApiService.token = null);

  Future<void> pumpAdmin(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: AdminHomeScreen()));
    await tester.pump();
    await tester.pump();
  }

  Future<void> nextCheck(WidgetTester tester) async {
    await tester.pump(newOrderCheckInterval);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500)); // the pop-up slides in
  }

  Finder badge(String count) => find.descendant(of: find.byType(Badge), matching: find.text(count));

  testWidgets('a new order pops up with who and how much, and the badge counts it', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await http.runWithClient(() async {
      await pumpAdmin(tester);
      expect(find.byType(SnackBar), findsNothing); // old orders are not news

      orders.add(order(36, 'Dara'));
      await nextCheck(tester);

      expect(find.text('Order ថ្មី #36 • Dara • \$364.65'), findsOneWidget);
      expect(badge('1'), findsNWidgets(2)); // the bell and the Orders tab

      // "មើល" opens the orders and clears the count
      await tester.tap(find.text('មើល'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Admin • គ្រប់គ្រង Order'), findsOneWidget);
      expect(find.byType(Badge).evaluate().where((e) => (e.widget as Badge).isLabelVisible), isEmpty);

      await tester.pumpWidget(const SizedBox());
    }, () => server());

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('admin_seen_order_id'), 36);
  });

  testWidgets('orders placed while the admin was away are on the badge, without a pop-up', (tester) async {
    SharedPreferences.setMockInitialValues({'admin_seen_order_id': 35});
    orders.addAll([order(36, 'Dara'), order(37, 'Sok')]);

    await http.runWithClient(() async {
      await pumpAdmin(tester);
      expect(badge('2'), findsNWidgets(2));
      expect(find.byType(SnackBar), findsNothing);

      // Nothing new since: no pop-up either
      await nextCheck(tester);
      expect(find.byType(SnackBar), findsNothing);

      await tester.pumpWidget(const SizedBox());
    }, () => server());
  });

  testWidgets('several orders at once say how many', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await http.runWithClient(() async {
      await pumpAdmin(tester);
      orders.addAll([order(36, 'Dara'), order(37, 'Sok')]);
      await nextCheck(tester);

      expect(find.text('Order ថ្មី 2 • ចុងក្រោយ #37 Sok'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    }, () => server());
  });
}
