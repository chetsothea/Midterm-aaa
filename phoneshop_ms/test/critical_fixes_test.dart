import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phoneshop_ms/data/models/order.dart';
import 'package:phoneshop_ms/data/models/phone.dart';
import 'package:phoneshop_ms/hooks/cart.dart';
import 'package:phoneshop_ms/screens/payment_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Phone _phone(int id, {int stock = 5, double price = 500}) => Phone(
  id: id,
  name: 'Phone $id',
  brand: 'Apple',
  price: price,
  stock: stock,
  imageUrl: '',
);

Map<String, dynamic> _json(int id, {int stock = 5, double price = 500}) => {
  'id': id,
  'name': 'Phone $id',
  'brand': 'Apple',
  'price': price,
  'stock': stock,
};

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Cart.instance.clear();
  });

  test(
    'the cart is remembered and comes back with fresh prices and stock',
    () async {
      Cart.instance.add(_phone(1), 2);
      Cart.instance.add(_phone(2), 3);
      Cart.instance.add(_phone(3), 1);
      await Future<void>.delayed(Duration.zero); // let the save finish
      Cart.instance.clear();
      // clear() saved the empty cart; put the earlier save back
      SharedPreferences.setMockInitialValues({
        'ps168_cart': jsonEncode([
          {'id': 1, 'color': '', 'storage': '', 'qty': 2},
          {'id': 2, 'color': '', 'storage': '', 'qty': 3},
          {'id': 3, 'color': '', 'storage': '', 'qty': 1},
        ]),
      });

      final shop = MockClient(
        (_) async => http.Response(
          jsonEncode([
            _json(1, price: 450), // price dropped
            _json(2, stock: 1), // only one left
            // phone 3 was deleted
          ]),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );
      await http.runWithClient(Cart.instance.load, () => shop);

      expect(Cart.instance.items.map((i) => (i.phone.id, i.qty)), [
        (1, 2),
        (2, 1),
      ]);
      expect(Cart.instance.total, 450 * 2 + 500);
      final saved = (await SharedPreferences.getInstance()).getString(
        'ps168_cart',
      );
      expect(jsonDecode(saved!), hasLength(2)); // the cleaned cart is saved
    },
  );

  test('offline at launch: the saved cart is kept as it was', () async {
    SharedPreferences.setMockInitialValues({
      'ps168_cart': jsonEncode([
        {'id': 1, 'color': '', 'storage': '', 'qty': 2},
      ]),
    });
    final offline = MockClient((_) async => throw Exception('offline'));
    await http.runWithClient(Cart.instance.load, () => offline);
    expect(Cart.instance.isEmpty, isTrue);
    final saved = (await SharedPreferences.getInstance()).getString(
      'ps168_cart',
    );
    expect(jsonDecode(saved!), hasLength(1)); // not wiped
  });

  test('an order carries its pay-before time from the API', () {
    final order = Order.fromJson({
      'id': 1,
      'total': '999',
      'status': 'pending',
      'payment_method': 'khqr',
      'payment_status': 'unpaid',
      'created_at': '2026-11-17T10:00:00Z',
      'pay_before': '2026-11-17T10:30:00Z',
    });
    expect(order.payBefore, DateTime.utc(2026, 11, 17, 10, 30).toLocal());
  });

  testWidgets('the pay-before banner counts down and turns red near the end', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PayBeforeBanner(
            deadline: DateTime.now().add(const Duration(minutes: 10)),
          ),
        ),
      ),
    );
    expect(find.textContaining(RegExp(r'^(10:00|09:5\d)$')), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PayBeforeBanner(
            deadline: DateTime.now().subtract(const Duration(seconds: 1)),
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.timer_off_rounded), findsOneWidget);
    expect(find.textContaining('បោះបង់'), findsOneWidget);
  });
}
