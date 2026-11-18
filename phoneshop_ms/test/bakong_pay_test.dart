import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phoneshop_ms/components/bakong_pay_card.dart';
import 'package:phoneshop_ms/data/api_service.dart';
import 'package:phoneshop_ms/data/models/order.dart';
import 'package:phoneshop_ms/screens/invoice_screen.dart';
import 'package:phoneshop_ms/screens/payment_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';

const _qr =
    '00020101021229180014ps168@aclb52045999530384054059995802KH5905PS1686010Phnom Penh6304ABCD';

Map<String, dynamic> _order(String payment) => {
  'id': 21,
  'customer_name': 'Thea',
  'total': '999.50',
  'status': 'pending',
  'payment_method': 'khqr',
  'payment_status': payment,
  'created_at': '2026-11-04T04:00:00Z',
  'bakong_qr': _qr,
  'items': [],
  'trackings': [],
};

http.Response _json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  tearDown(() => ApiService.token = null);

  test('an order carries its Bakong QR', () {
    expect(Order.fromJson(_order('unpaid')).bakongQr, _qr);
    expect(
      Order.fromJson({..._order('unpaid'), 'bakong_qr': null}).bakongQr,
      '',
    );
  });

  testWidgets('the KHQR shows, and the invoice opens by itself once Bakong '
      'has the payment', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var checks = 0;
    final mock = MockClient((request) async {
      if (request.url.path.endsWith('/check-payment')) {
        checks++;
        // Not paid the first time, paid the second
        return _json({
          ..._order(checks < 2 ? 'unpaid' : 'paid'),
          'bakong_down': false,
        });
      }
      return _json({'bank_name': 'ABA', 'accounts': [], 'bakong': true});
    });

    await http.runWithClient(() async {
      ApiService.token = 'test';
      await tester.pumpWidget(
        MaterialApp(
          home: PaymentScreen(order: Order.fromJson(_order('unpaid'))),
        ),
      );
      await tester.pump(); // payment info arrives
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('KHQR'), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('\$999.50'), findsWidgets);
      // No "I have paid" main button: Bakong decides
      expect(find.text('ខ្ញុំបានបង់ប្រាក់រួចហើយ'), findsNothing);

      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(find.byType(InvoiceScreen), findsNothing); // not paid yet
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    }, () => mock);

    expect(checks, 2);
    expect(find.byType(InvoiceScreen), findsOneWidget);
  });

  testWidgets('when Bakong is slow the customer is told it is still trying', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final mock = MockClient(
      (_) async => _json({..._order('unpaid'), 'bakong_down': true}),
    );
    await http.runWithClient(() async {
      ApiService.token = 'test';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BakongPayCard(
                order: Order.fromJson(_order('unpaid')),
                onPaid: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
    }, () => mock);
    expect(find.textContaining('Bakong យឺតបន្តិច'), findsOneWidget);
    await tester.pumpWidget(const SizedBox()); // stops the timer
  });

  testWidgets('once the order is cancelled the QR is crossed out and '
      'checking stops', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var checks = 0;
    final mock = MockClient((_) async {
      checks++;
      return _json({
        ..._order('unpaid'),
        'status': 'cancelled',
        'bakong_down': false,
      });
    });
    await http.runWithClient(() async {
      ApiService.token = 'test';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BakongPayCard(
                order: Order.fromJson(_order('unpaid')),
                onPaid: (_) => fail('a cancelled order is never paid'),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(seconds: 9)); // no more asking
    }, () => mock);
    expect(checks, 1);
    expect(find.textContaining('ត្រូវបានបោះបង់'), findsOneWidget);
    expect(find.byIcon(Icons.block_rounded), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('without a Bakong QR the bank QR page is shown as before', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await http.runWithClient(
      () async {
        ApiService.token = 'test';
        await tester.pumpWidget(
          MaterialApp(
            home: PaymentScreen(
              order: Order.fromJson({..._order('unpaid'), 'bakong_qr': null}),
            ),
          ),
        );
        await tester.pumpAndSettle();
      },
      () => MockClient(
        (_) async => _json({
          'bank_name': 'ABA Bank',
          'account_name': 'PS168',
          'account_number': '000',
          'qr_image_url': '',
        }),
      ),
    );
    expect(find.byType(BakongPayCard), findsNothing);
    expect(find.text('ខ្ញុំបានបង់ប្រាក់រួចហើយ'), findsOneWidget);
  });
}
