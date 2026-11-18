import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phoneshop_ms/components/order_success.dart';
import 'package:phoneshop_ms/components/reviews.dart';
import 'package:phoneshop_ms/data/models/phone.dart';
import 'package:phoneshop_ms/hooks/cart.dart';
import 'package:phoneshop_ms/screens/cart_screen.dart';

Phone _phone(int id, String name) => Phone(
  id: id,
  name: name,
  brand: 'Apple',
  price: 500,
  stock: 5,
  imageUrl: '',
);

void main() {
  setUp(Cart.instance.clear);
  tearDown(Cart.instance.clear);

  testWidgets('a removed cart line can be put back, in its old place', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Cart.instance.add(_phone(1, 'First'));
    Cart.instance.add(_phone(2, 'Second'));
    Cart.instance.add(_phone(3, 'Third'));
    await tester.pumpWidget(const MaterialApp(home: CartScreen()));
    await tester.pump(const Duration(seconds: 1));

    Cart.instance.remove(Cart.keyFor(2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('បានដក Second'), findsOneWidget); // the undo bar
    expect(Cart.instance.items.map((i) => i.phone.name), ['First', 'Third']);

    await tester.tap(find.text('មិនធ្វើវិញ'));
    await tester.pumpAndSettle();
    expect(Cart.instance.items.map((i) => i.phone.name), [
      'First',
      'Second',
      'Third',
    ]);
    expect(find.text('បានដក Second'), findsNothing);
  });

  testWidgets('the undo bar goes away by itself after 4 seconds', (
    tester,
  ) async {
    Cart.instance.add(_phone(1, 'Only'));
    await tester.pumpWidget(const MaterialApp(home: CartScreen()));
    await tester.pump(const Duration(seconds: 1));
    Cart.instance.remove(Cart.keyFor(1));
    await tester.pump();
    expect(Cart.instance.lastRemoved.value, isNotNull);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(Cart.instance.lastRemoved.value, isNull); // too late now
    expect(Cart.instance.isEmpty, isTrue);
  });

  testWidgets('placing an order shows the ✓ celebration, then it clears', (
    tester,
  ) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            ctx = context;
            return const Scaffold(body: Text('next page'));
          },
        ),
      ),
    );
    celebrateOrder(ctx, orderRef: 'PS-0042', payNow: true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.text('បញ្ជាទិញជោគជ័យ!'), findsOneWidget);
    expect(find.text('Order PS-0042'), findsOneWidget);
    expect(find.text('បន្ទាប់៖ បង់ប្រាក់តាម KHQR'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpAndSettle();
    expect(find.text('បញ្ជាទិញជោគជ័យ!'), findsNothing);
    expect(find.text('next page'), findsOneWidget);
  });

  testWidgets('reviews show the average, the stars and verified buyers', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final mock = MockClient(
      (request) async => http.Response(
        jsonEncode({
          'average': 4.5,
          'count': 2,
          'stars': {'5': 1, '4': 1, '3': 0, '2': 0, '1': 0},
          'reviews': [
            {
              'id': 1,
              'name': 'Dara',
              'avatar_url': '',
              'rating': 5,
              'comment': 'Great camera',
              'created_at': '2026-11-10T10:00:00Z',
            },
            {
              'id': 2,
              'name': 'Sokha',
              'avatar_url': '',
              'rating': 4,
              'comment': '',
              'created_at': '2026-11-09T10:00:00Z',
            },
          ],
          'can_review': true,
          'mine': null,
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReviewsSection(phone: _phone(7, 'iPhone')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }, () => mock);

    expect(find.text('4.5'), findsOneWidget);
    expect(find.text('Great camera'), findsOneWidget);
    expect(find.text('Sokha'), findsOneWidget);
    expect(find.byIcon(Icons.verified_rounded), findsNWidgets(2));
    expect(find.text('សរសេរការវាយតម្លៃ'), findsOneWidget); // they may review
    expect(tester.takeException(), isNull);

    // The sheet: pick 4 stars and the word for it shows
    await tester.tap(find.text('សរសេរការវាយតម្លៃ'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('4'));
    await tester.pumpAndSettle();
    expect(find.text('ល្អ'), findsOneWidget);
  });

  test('a phone carries its rating from the API', () {
    final phone = Phone.fromJson({
      'id': 1,
      'name': 'X',
      'price': 1,
      'stock': 1,
      'reviews_avg_rating': '4.33',
      'reviews_count': 3,
    });
    expect(phone.ratingAverage, closeTo(4.33, 0.001));
    expect(phone.ratingCount, 3);
  });
}
