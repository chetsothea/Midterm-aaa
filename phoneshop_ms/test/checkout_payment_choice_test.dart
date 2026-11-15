import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phoneshop_ms/models/phone.dart';
import 'package:phoneshop_ms/models/user.dart';
import 'package:phoneshop_ms/screens/checkout_screen.dart';
import 'package:phoneshop_ms/services/api_service.dart';
import 'package:phoneshop_ms/services/cart.dart';

void main() {
  setUp(() {
    ApiService.token = 'test';
    ApiService.currentUser = User(
      id: 2,
      name: 'Thea',
      email: 'thea@gmail.com',
      phone: '098374883',
      address: 'ភ្នំពេញ',
      role: 'user',
    );
    Cart.instance.clear();
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
  });

  tearDown(() {
    ApiService.token = null;
    ApiService.currentUser = null;
    Cart.instance.clear();
  });

  // A small phone: the form is taller than the screen
  Future<void> pumpOnSmallPhone(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: CheckoutScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('the steps at the top show Checkout as the current one', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: CheckoutScreen()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('កន្ត្រក'), findsOneWidget);
    expect(find.text('បង់ប្រាក់'), findsOneWidget);
    expect(find.text('Checkout'), findsNWidgets(2)); // bar title and the step
  });

  testWidgets('both payment choices show without scrolling, and fit', (
    tester,
  ) async {
    await pumpOnSmallPhone(tester);

    expect(tester.takeException(), isNull);
    for (final label in [
      'KHQR / ផ្ទេរប្រាក់',
      'បង់ពេលទទួល (COD)',
      'បញ្ជាទិញ',
    ]) {
      final box = tester.getRect(find.text(label));
      expect(box.left, greaterThanOrEqualTo(0), reason: label);
      expect(box.right, lessThanOrEqualTo(360), reason: label);
      expect(box.bottom, lessThanOrEqualTo(640), reason: label);
    }
  });

  testWidgets('the order is sent with the method picked', (tester) async {
    Map<String, dynamic>? sent;
    final mock = MockClient((request) async {
      sent = jsonDecode(request.body);
      return http.Response('{"message":"stop here"}', 422);
    });

    await http.runWithClient(() async {
      await pumpOnSmallPhone(tester);
      await tester.tap(find.text('បង់ពេលទទួល (COD)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('បញ្ជាទិញ'));
      await tester.pumpAndSettle();
    }, () => mock);

    expect(sent?['payment_method'], 'cod');
  });
}
