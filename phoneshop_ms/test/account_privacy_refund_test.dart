import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phoneshop_ms/data/api_service.dart';
import 'package:phoneshop_ms/data/models/user.dart';
import 'package:phoneshop_ms/data/policy_text.dart';
import 'package:phoneshop_ms/screens/admin/admin_orders_tab.dart';
import 'package:phoneshop_ms/screens/delete_account_screen.dart';
import 'package:phoneshop_ms/screens/privacy_screen.dart';

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

User _user({bool google = false, String role = 'user'}) => User(
  id: 2,
  name: 'Dara',
  email: 'dara@example.com',
  role: role,
  googleAccount: google,
);

void main() {
  tearDown(() {
    ApiService.token = null;
    ApiService.currentUser = null;
  });

  Future<void> openDelete(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DeleteAccountScreen()),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('deleting the account asks for the password and logs out', (
    tester,
  ) async {
    ApiService.token = 'test';
    ApiService.currentUser = _user();
    Map? sent;
    final mock = MockClient((request) async {
      sent = jsonDecode(request.body);
      expect(request.method, 'DELETE');
      return _json({'message': 'ok'});
    });

    await http.runWithClient(() async {
      await openDelete(tester);
      expect(find.textContaining('ហាងរក្សាទុក Order ចាស់ៗ'), findsOneWidget);
      await tester.tap(find.text('លុបគណនីរបស់ខ្ញុំ'));
      await tester.pumpAndSettle();
      expect(find.text('សូមបញ្ចូលពាក្យសម្ងាត់'), findsOneWidget);
      expect(sent, isNull);

      await tester.enterText(find.byType(TextFormField), 'secret123');
      await tester.tap(find.text('លុបគណនីរបស់ខ្ញុំ'));
      await tester.pumpAndSettle();
    }, () => mock);

    expect(sent, {'password': 'secret123'});
    expect(ApiService.token, isNull);
    expect(ApiService.currentUser, isNull);
    expect(find.text('open'), findsOneWidget); // back to where it started
  });

  testWidgets('a Google account types DELETE instead of a password', (
    tester,
  ) async {
    ApiService.token = 'test';
    ApiService.currentUser = _user(google: true);
    Map? sent;
    final mock = MockClient((request) async {
      sent = jsonDecode(request.body);
      return _json({'message': 'ok'});
    });
    await http.runWithClient(() async {
      await openDelete(tester);
      expect(find.text('វាយពាក្យ DELETE ដើម្បីបញ្ជាក់'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'delete');
      await tester.tap(find.text('លុបគណនីរបស់ខ្ញុំ'));
      await tester.pumpAndSettle();
    }, () => mock);
    expect(sent, {'confirm': 'delete'});
  });

  testWidgets('privacy and terms show every section', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 4000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: PrivacyScreen()));
    await tester.pumpAndSettle();
    for (final s in privacySections) {
      expect(find.text(s.km), findsOneWidget);
    }
    await tester.tap(find.text('លក្ខខណ្ឌ'));
    await tester.pumpAndSettle();
    expect(find.text(termsSections.first.km), findsOneWidget);
    expect(
      find.textContaining('ពេលចាប់ផ្តើមដឹកជញ្ជូនហើយ មិនអាចបោះបង់បានទេ'),
      findsOneWidget,
    );
  });

  testWidgets('admin sees a refund owed and marks it given back', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    ApiService.token = 'test';
    ApiService.currentUser = _user(role: 'admin');
    var state = 'due';
    Map? sent;
    Map<String, dynamic> order() => {
      'id': 9,
      'code': 'PS-ABC123',
      'customer_name': 'Dara',
      'total': 500,
      'status': 'cancelled',
      'payment_method': 'khqr',
      'payment_status': 'paid',
      'refund_status': state,
      'created_at': '2026-11-18T04:00:00Z',
      'items': [],
      'trackings': [],
    };
    final mock = MockClient((request) async {
      if (request.url.path.endsWith('/refunded')) {
        sent = jsonDecode(request.body);
        state = 'refunded';
        return _json(order());
      }
      return _json([order()]);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminOrdersTab(
              only: (o) => o.refundStatus == 'due',
              onlyStatus: 'cancelled',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('ABC123').first);
      await tester.pumpAndSettle();
      expect(find.text('ត្រូវបង្វិលប្រាក់ \$500.00'), findsOneWidget);

      await tester.tap(find.text('បានបង្វិលរួច'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'ABA');
      await tester.tap(find.widgetWithText(FilledButton, 'បានបង្វិលរួច').last);
      await tester.pumpAndSettle();
    }, () => mock);

    expect(sent, {'note': 'ABA'});
  });
}
