import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phoneshop_ms/data/api_service.dart';
import 'package:phoneshop_ms/data/models/order.dart';
import 'package:phoneshop_ms/data/models/phone.dart';
import 'package:phoneshop_ms/data/models/user.dart';
import 'package:phoneshop_ms/data/models/voucher.dart';
import 'package:phoneshop_ms/hooks/cart.dart';
import 'package:phoneshop_ms/screens/admin/admin_vouchers_screen.dart';
import 'package:phoneshop_ms/screens/checkout_screen.dart';

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _quote({String code = '', double discount = 0}) => {
  'subtotal': 400,
  'discount': discount,
  'voucher_code': code.isEmpty ? null : code,
  'voucher_label': code.isEmpty ? null : '10%',
  'shipping_fee': 1.5,
  'shipping_zone': 'phnom_penh',
  'total': 400 - discount + 1.5,
  'shipping': {'phnom_penh': 1.5, 'province': 3, 'free_over': 500},
};

void main() {
  setUp(() {
    ApiService.token = 'test';
    ApiService.currentUser = User(
      id: 2,
      name: 'Thea',
      email: 'thea@gmail.com',
      phone: '098374883',
      address: 'ផ្ទះ 1, រាជធានីភ្នំពេញ, កម្ពុជា',
      role: 'user',
    );
    Cart.instance.clear();
    Cart.instance.add(
      Phone(
        id: 9,
        name: 'Galaxy A55',
        brand: 'Samsung',
        price: 400,
        stock: 5,
        imageUrl: '',
      ),
    );
  });

  tearDown(() {
    ApiService.token = null;
    ApiService.currentUser = null;
    Cart.instance.clear();
  });

  test('quote and order read delivery and discount', () {
    final q = Quote.fromJson(_quote(code: 'NEWYEAR10', discount: 40));
    expect(q.total, 361.5);
    expect(q.voucherCode, 'NEWYEAR10');
    expect(q.phnomPenh, isTrue);
    expect(q.moreForFreeDelivery, 140); // 500 - (400 - 40)

    final order = Order.fromJson({
      'id': 1,
      'total': '361.50',
      'subtotal': '400.00',
      'shipping_fee': '1.50',
      'discount': '40.00',
      'voucher_code': 'NEWYEAR10',
      'status': 'pending',
      'payment_method': 'cod',
      'payment_status': 'unpaid',
      'created_at': '2026-11-18T04:00:00Z',
    });
    expect(order.subtotal, 400);
    expect(order.shippingFee, 1.5);
    expect(order.discount, 40);

    // Orders from before delivery fees
    final old = Order.fromJson({
      'id': 2,
      'total': '99',
      'status': 'pending',
      'payment_method': 'cod',
      'payment_status': 'unpaid',
      'created_at': '2026-11-01T04:00:00Z',
    });
    expect(old.subtotal, isNull);
    expect(old.shippingFee, 0);
  });

  testWidgets('checkout shows delivery, applies a code and sends it with the '
      'order', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Map<String, dynamic>? ordered;
    final mock = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      if (request.url.path.endsWith('/orders/quote')) {
        final code = '${body['voucher_code'] ?? ''}';
        if (code == 'BAD') {
          return _json({
            'message': 'x',
            'errors': {
              'voucher_code': ['កូដនេះផុតកំណត់ហើយ'],
            },
          }, 422);
        }
        return _json(
          code == 'NEWYEAR10'
              ? _quote(code: 'NEWYEAR10', discount: 40)
              : _quote(),
        );
      }
      ordered = body;
      return _json({'message': 'stop here'}, 422);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: CheckoutScreen()));
      await tester.pumpAndSettle();

      expect(find.text('ថ្លៃដឹក (ភ្នំពេញ)'), findsOneWidget);
      expect(find.text('\$1.50'), findsOneWidget);
      expect(find.textContaining('ដឹកឥតគិតថ្លៃ'), findsOneWidget);

      // A dead code shows its reason under the field
      await tester.enterText(find.byType(TextField).last, 'bad');
      await tester.tap(find.text('ប្រើ'));
      await tester.pumpAndSettle();
      expect(find.text('កូដនេះផុតកំណត់ហើយ'), findsOneWidget);

      await tester.enterText(find.byType(TextField).last, 'newyear10');
      await tester.tap(find.text('ប្រើ'));
      await tester.pumpAndSettle();
      expect(find.textContaining('NEWYEAR10 · បញ្ចុះ 10%'), findsOneWidget);
      expect(find.text('-\$40.00'), findsOneWidget);
      expect(find.text('\$361.50'), findsWidgets); // summary and bottom bar

      await tester.tap(find.text('បញ្ជាទិញ'));
      await tester.pumpAndSettle();
    }, () => mock);

    expect(ordered?['voucher_code'], 'NEWYEAR10');
  });

  testWidgets('admin sees delivery prices and codes with their state', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Map<String, dynamic>? savedRates;
    int? savedKhr;
    final mock = MockClient((request) async {
      if (request.method == 'PUT') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (request.url.path.endsWith('/khr-rate')) {
          savedKhr = body['khr_rate'];
          return _json(body);
        }
        savedRates = body;
        return _json(savedRates!);
      }
      return _json({
        'vouchers': [
          {
            'id': 1,
            'code': 'NEWYEAR10',
            'type': 'percent',
            'value': 10,
            'label': '10%',
            'min_total': 300,
            'max_uses': 50,
            'used_count': 3,
            'active': true,
          },
          {
            'id': 2,
            'code': 'OLD5',
            'type': 'fixed',
            'value': 5,
            'label': '\$5',
            'min_total': 0,
            'used_count': 0,
            'expires_at': '2020-01-01T00:00:00Z',
            'active': true,
          },
        ],
        'shipping': {'phnom_penh': 1.5, 'province': 3, 'free_over': 0},
        'khr_rate': 4100,
      });
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: AdminVouchersScreen()));
      await tester.pumpAndSettle();
      expect(find.text('NEWYEAR10'), findsOneWidget);
      expect(find.textContaining('ប្រើ 3/50'), findsOneWidget);
      expect(find.text('កំពុងប្រើ'), findsOneWidget);
      expect(find.text('ផុតកំណត់'), findsOneWidget);
      expect(find.widgetWithText(TextField, '1.50'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, '3'), '4.5');
      await tester.tap(find.text('រក្សាទុកថ្លៃដឹក'));
      await tester.pumpAndSettle();
    }, () => mock);

    expect(savedRates, {'phnom_penh': 1.5, 'province': 4.5, 'free_over': 0.0});
    expect(savedKhr, 4100); // the riel rate is saved with them
  });
}
