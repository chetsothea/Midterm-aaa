import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phoneshop_ms/models/order.dart';
import 'package:phoneshop_ms/screens/invoice_screen.dart';
import 'package:phoneshop_ms/screens/payment_screen.dart';
import 'package:phoneshop_ms/services/api_service.dart';

Map<String, dynamic> orderJson(String payment, [String? reference]) => {
  'id': 21,
  'customer_name': 'Thea',
  'total': '999.00',
  'status': 'pending',
  'payment_method': 'khqr',
  'payment_status': payment,
  'transaction_ref': reference,
  'phone': '012',
  'address': 'PP',
  'created_at': '2026-11-04T04:00:00Z',
  'items': [
    {
      'product_id': 1,
      'qty': 1,
      'price': '999.00',
      'product': {'name': 'iPhone 18 ProMax'},
    },
  ],
  'trackings': [],
};

http.Response json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  testWidgets(
    'after paying, the invoice opens and the caller still gets its result',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(() => ApiService.token = null);

      final mock = MockClient((request) async {
        if (request.method == 'POST') {
          expect(jsonDecode(request.body)['transaction_ref'], 'TX777');
          return json(orderJson('verifying', 'TX777'));
        }
        return json({
          'bank_name': 'ABA Bank',
          'account_name': 'PS168',
          'account_number': '000',
          'qr_image_url': '',
        });
      });

      bool? result;
      await http.runWithClient(() async {
        ApiService.token = 'test';
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PaymentScreen(
                        order: Order.fromJson(orderJson('unpaid')),
                      ),
                    ),
                  );
                },
                child: const Text('pay'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('pay'));
        await tester.pumpAndSettle();
        expect(find.byType(InvoiceScreen), findsNothing);

        await tester.enterText(find.byType(TextField), 'TX777');
        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();
      }, () => mock);

      expect(find.byType(InvoiceScreen), findsOneWidget);
      expect(find.byType(PaymentScreen), findsNothing);
      expect(find.text('iPhone 18 ProMax'), findsOneWidget);
      expect(find.text('TX777'), findsOneWidget);
      expect(
        find.text('កំពុងផ្ទៀងផ្ទាត់'),
        findsOneWidget,
      ); // not "paid" until the admin checks
      expect(result, isTrue);

      // Back goes to where the customer was
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('pay'), findsOneWidget);
    },
  );

  testWidgets('if paying fails, the customer stays to try again', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(() => ApiService.token = null);

    final mock = MockClient((request) async {
      if (request.method == 'POST') {
        return http.Response('{"message":"bad"}', 422);
      }
      return json({'bank_name': 'ABA', 'qr_image_url': ''});
    });

    await http.runWithClient(() async {
      ApiService.token = 'test';
      await tester.pumpWidget(
        MaterialApp(
          home: PaymentScreen(order: Order.fromJson(orderJson('unpaid'))),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'TX777');
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
    }, () => mock);

    expect(find.byType(InvoiceScreen), findsNothing);
    expect(find.byType(PaymentScreen), findsOneWidget);
  });

  testWidgets('the payment page fits a small phone, with the buying steps', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(() => ApiService.token = null);

    await http.runWithClient(
      () async {
        ApiService.token = 'test';
        await tester.pumpWidget(
          MaterialApp(
            home: PaymentScreen(order: Order.fromJson(orderJson('unpaid'))),
          ),
        );
        await tester.pumpAndSettle();
      },
      () => MockClient(
        (_) async => json({
          'bank_name': 'ABA Bank',
          'account_name': 'PS168',
          'account_number': '000 000 000',
          'qr_image_url': '',
        }),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Checkout'), findsOneWidget); // the step before, done
    expect(find.byIcon(Icons.check), findsNWidgets(2)); // Cart and Checkout ✓
    expect(find.text('Scan ដើម្បីបង់ប្រាក់'), findsOneWidget);
  });

  testWidgets('the transaction ID is optional: "I have paid" alone is enough', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(() => ApiService.token = null);

    Map<String, dynamic>? sent;
    final mock = MockClient((request) async {
      expect(request.url.path, isNot(contains('khqr'))); // no Bakong any more
      if (request.method == 'POST') {
        sent = Map<String, dynamic>.from(jsonDecode(request.body));
        return json(orderJson('verifying'));
      }
      return json({'bank_name': 'ABA', 'qr_image_url': ''});
    });

    await http.runWithClient(() async {
      ApiService.token = 'test';
      await tester.pumpWidget(
        MaterialApp(
          home: PaymentScreen(order: Order.fromJson(orderJson('unpaid'))),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('លេខប្រតិបត្តិការ (មិនចាំបាច់)'), findsOneWidget);
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
    }, () => mock);

    expect(sent, isNotNull);
    expect(sent!.containsKey('transaction_ref'), isFalse);
    expect(find.byType(InvoiceScreen), findsOneWidget);
  });
}
