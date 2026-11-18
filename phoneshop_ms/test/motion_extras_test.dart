import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phoneshop_ms/data/models/phone.dart';
import 'package:phoneshop_ms/hooks/cart.dart';
import 'package:phoneshop_ms/components/cart_flight.dart';
import 'package:phoneshop_ms/components/shop_refresh.dart';

void main() {
  testWidgets('pulling the list down far enough refreshes it', (tester) async {
    var refreshed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShopRefresh(
            onRefresh: () async => refreshed++,
            child: ListView(
              children: [for (var i = 0; i < 20; i++) Text('row $i')],
            ),
          ),
        ),
      ),
    );

    await tester.fling(find.text('row 0'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(refreshed, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a phone added to the cart flies into the cart icon', (
    tester,
  ) async {
    Cart.instance.clear();
    addTearDown(Cart.instance.clear);
    final phone = Phone(
      id: 1,
      name: 'iPhone',
      brand: 'Apple',
      price: 999,
      stock: 3,
      imageUrl: '',
    );
    late BuildContext pictureContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Builder(
                builder: (context) {
                  pictureContext = context;
                  return const SizedBox(width: 150, height: 150);
                },
              ),
              const Spacer(),
              Icon(Icons.shopping_cart, key: CartFlight.target),
            ],
          ),
        ),
      ),
    );

    CartFlight.prepare(pictureContext, phone.imageUrl);
    Cart.instance.add(phone);
    await tester.pump(); // the flight starts after this frame
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ClipOval), findsOneWidget); // the thumbnail mid-air

    await tester.pumpAndSettle();
    expect(find.byType(ClipOval), findsNothing); // landed and gone
  });

  testWidgets('no flight when the add did not go through', (tester) async {
    Cart.instance.clear();
    addTearDown(Cart.instance.clear);
    late BuildContext pictureContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Builder(
                builder: (context) {
                  pictureContext = context;
                  return const SizedBox(width: 150, height: 150);
                },
              ),
              Icon(Icons.shopping_cart, key: CartFlight.target),
            ],
          ),
        ),
      ),
    );
    CartFlight.prepare(pictureContext, '');
    // Sold out: the cart doesn't change
    Cart.instance.add(
      Phone(id: 2, name: 'X', brand: 'Y', price: 1, stock: 0, imageUrl: ''),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ClipOval), findsNothing);
    await tester.pump(const Duration(seconds: 2)); // the wait expires
  });
}
