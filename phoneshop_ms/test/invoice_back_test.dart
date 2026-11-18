import 'dart:convert';

import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phoneshop_ms/main.dart';
import 'package:phoneshop_ms/data/models/phone.dart';
import 'package:phoneshop_ms/data/models/user.dart';
import 'package:phoneshop_ms/screens/checkout_screen.dart';
import 'package:phoneshop_ms/screens/home_screen.dart';
import 'package:phoneshop_ms/screens/invoice_screen.dart';
import 'package:phoneshop_ms/screens/my_orders_screen.dart';
import 'package:phoneshop_ms/data/api_service.dart';
import 'package:phoneshop_ms/hooks/cart.dart';

Map<String, dynamic> orderJson(String method, String payment) => {
  'id': 21,
  'user_id': 2,
  'customer_name': 'Thea',
  'total': '999.00',
  'status': 'pending',
  'payment_method': method,
  'payment_status': payment,
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
  for (final device in [
    Devices.ios.iPhone13,
    Devices.android.samsungGalaxyS20,
  ]) {
    testWidgets(
      'back from the invoice inside Device Preview (${device.name})',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1500, 1100));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        addTearDown(() {
          ApiService.token = null;
          ApiService.currentUser = null;
          Cart.instance.clear();
        });
        ApiService.token = 'test';
        ApiService.currentUser = User(
          id: 2,
          name: 'Thea',
          email: 'thea@gmail.com',
          phone: '098374883',
          address: 'ភ្នំពេញ',
          role: 'user',
        );
        Cart.instance.add(
          Phone(
            id: 9,
            name: 'Galaxy A55',
            brand: 'Samsung',
            price: 399,
            stock: 3,
            imageUrl: '',
          ),
        );

        final mock = MockClient((request) async {
          final path = request.url.path;
          if (request.method == 'POST') return json(orderJson('cod', 'unpaid'));
          if (path.endsWith('/products')) return json([]);
          if (path.endsWith('/orders')) {
            return json([orderJson('cod', 'unpaid')]);
          }
          return json({'brands': [], 'categories': []});
        });

        await http.runWithClient(() async {
          await tester.pumpWidget(
            DevicePreview(
              enabled: true,
              defaultDevice: device,
              storage: DevicePreviewStorage.none(),
              builder: (context) => const MyApp(),
            ),
          );
          // Through the launch screen, like a real start
          for (var i = 0; i < 5; i++) {
            await tester.pump(const Duration(seconds: 1));
          }

          Navigator.of(
            tester.element(find.byType(HomeScreen)),
          ).push(MaterialPageRoute(builder: (_) => const CheckoutScreen()));
          await tester.pump(const Duration(seconds: 1));
          await tester.pump(const Duration(seconds: 1));

          await tester.tap(find.text('បង់ពេលទទួល (COD)'));
          await tester.pump(const Duration(seconds: 1));
          await tester.tap(find.text('បញ្ជាទិញ'));
          await tester.pump(const Duration(seconds: 1));
          await tester.pump(const Duration(seconds: 1));
          await tester.pump(const Duration(seconds: 1));
          expect(find.byType(InvoiceScreen), findsOneWidget);

          // Back to the orders, then back to the store
          Navigator.of(tester.element(find.byType(InvoiceScreen))).pop();
          for (var i = 0; i < 10; i++) {
            await tester.pump(const Duration(milliseconds: 200));
          }
          expect(tester.takeException(), isNull);

          Navigator.of(tester.element(find.byType(MyOrdersScreen))).pop();
          for (var i = 0; i < 10; i++) {
            await tester.pump(const Duration(milliseconds: 200));
          }
          expect(tester.takeException(), isNull);
          expect(find.byType(MyOrdersScreen), findsNothing);
        }, () => mock);
      },
    );
  }
}
