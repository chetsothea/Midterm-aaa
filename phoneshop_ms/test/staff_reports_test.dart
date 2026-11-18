import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phoneshop_ms/data/api_service.dart';
import 'package:phoneshop_ms/data/models/user.dart';
import 'package:phoneshop_ms/screens/admin/admin_home_screen.dart';
import 'package:phoneshop_ms/screens/admin/admin_reports_screen.dart';
import 'package:phoneshop_ms/screens/invoice_screen.dart';

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

User _user(String role) =>
    User(id: 1, name: 'Sok', email: 'sok@example.com', role: role);

void main() {
  tearDown(() {
    ApiService.token = null;
    ApiService.currentUser = null;
  });

  test('roles: staff open the admin panel, customers do not', () {
    expect(_user('staff').isTeam, isTrue);
    expect(_user('staff').isAdmin, isFalse);
    expect(_user('admin').isTeam, isTrue);
    expect(_user('user').isTeam, isFalse);
  });

  test('the invoice PDF is a real one-page PDF', () async {
    // A 1×1 white PNG
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4//8/AAX+Av4N70a4AAAAAElFTkSuQmCC',
    );
    final pdf = await invoicePdf(Uint8List.fromList(png));
    expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
    expect(String.fromCharCodes(pdf), contains('/Count 1>>'));
  });

  testWidgets('staff see only the orders: no dashboard, products or money', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    ApiService.token = 'test';
    ApiService.currentUser = _user('staff');
    final asked = <String>[];
    final mock = MockClient((request) async {
      asked.add(request.url.path);
      if (request.url.path.endsWith('/orders/new')) {
        return _json({'latest_id': 0, 'count': 0, 'orders': []});
      }
      return _json([]);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: AdminHomeScreen()));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Staff • គ្រប់គ្រង Order'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);

      // The tools menu has the warranty check only
      await tester.tap(find.byTooltip('ការកំណត់ហាង'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('ពិនិត្យការធានា (IMEI)'), findsOneWidget);
      expect(find.text('របាយការណ៍លក់ & Excel'), findsNothing);
      expect(find.text('គណនីបង់ប្រាក់ KHQR'), findsNothing);
      await tester.pumpWidget(const SizedBox()); // stops the order check timer
    }, () => mock);

    expect(asked.any((p) => p.contains('/dashboard')), isFalse);
  });

  testWidgets('report shows the money and best sellers, and switches period', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    ApiService.token = 'test';
    final asked = <Uri>[];
    final mock = MockClient((request) async {
      asked.add(request.url);
      return _json({
        'from': '2026-11-12',
        'to': '2026-11-18',
        'orders': 4,
        'paid_orders': 3,
        'cancelled_orders': 1,
        'revenue': 2599.5,
        'phones_sold': 5,
        'discounts': 20,
        'shipping_fees': 4.5,
        'unpaid_total': 300,
        'average_order': 866.5,
        'by_day': [
          {'date': '2026-11-17', 'orders': 1, 'revenue': 1000},
          {'date': '2026-11-18', 'orders': 3, 'revenue': 1599.5},
        ],
        'top_products': [
          {'name': 'iPhone 17 Pro Max', 'qty': 2, 'revenue': 2398},
        ],
        'by_payment': [
          {'method': 'khqr', 'orders': 2, 'revenue': 2000},
        ],
      });
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: AdminReportsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('\$2599.50'), findsOneWidget);
      expect(find.text('iPhone 17 Pro Max'), findsOneWidget);
      expect(find.text('× 2'), findsOneWidget);
      expect(find.text('KHQR'), findsOneWidget);
      expect(find.textContaining('ថ្លៃដឹក \$4.50'), findsOneWidget);

      await tester.tap(find.text('ថ្ងៃនេះ'));
      await tester.pumpAndSettle();
    }, () => mock);

    expect(asked.length, 2);
    expect(
      asked.last.queryParameters['from'],
      asked.last.queryParameters['to'],
    );
  });
}
