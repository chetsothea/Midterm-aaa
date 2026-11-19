import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phoneshop_ms/data/models/phone.dart';
import 'package:phoneshop_ms/hooks/cart.dart';
import 'package:phoneshop_ms/screens/product_detail_screen.dart';

// Blue 256GB: 2 · Blue 512GB: 0 · Black 256GB: 0 · Black 512GB: 1
Phone _phone({bool grid = true}) => Phone.fromJson({
  'id': 7,
  'name': 'iPhone 17',
  'brand': 'Apple',
  'price': 999,
  'stock': 3,
  'color': 'Blue, Black',
  'storage_prices': [
    {'storage': '256GB', 'price': 999},
    {'storage': '512GB', 'price': 1199},
  ],
  'variant_stock': grid
      ? {'Blue|256GB': 2, 'Blue|512GB': 0, 'Black|256GB': 0, 'Black|512GB': 1}
      : null,
  'image_url': '',
});

void main() {
  setUp(() => Cart.instance.clear());
  tearDown(() => Cart.instance.clear());

  test('stock is read per colour and size', () {
    final p = _phone();
    expect(p.hasVariantStock, isTrue);
    expect(p.stockFor('Blue', '256GB'), 2);
    expect(p.stockFor('Black', '256GB'), 0);
    expect(p.colorAvailable('Black'), isTrue); // 512GB is there
    expect(_phone(grid: false).stockFor('Black', '256GB'), 3);
  });

  test('the cart only takes what that colour/size has', () {
    final p = _phone();
    expect(Cart.instance.add(p, 2, 'Blue', '256GB'), isTrue);
    expect(Cart.instance.add(p, 1, 'Blue', '256GB'), isFalse);
    expect(Cart.instance.add(p, 1, 'Black', '256GB'), isFalse);
    expect(Cart.instance.add(p, 1, 'Black', '512GB'), isTrue);
    expect(Cart.instance.roomFor(p, 'Black', '512GB'), 0);

    // Without a grid every colour shares one count, as before
    Cart.instance.clear();
    final shared = _phone(grid: false);
    expect(Cart.instance.add(shared, 2, 'Blue', '256GB'), isTrue);
    expect(Cart.instance.add(shared, 2, 'Black', '256GB'), isFalse);
    expect(Cart.instance.add(shared, 1, 'Black', '256GB'), isTrue);
  });

  testWidgets('a sold-out colour/size is marked and cannot be added', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: ProductDetailScreen(phone: _phone())),
    );
    await tester.pumpAndSettle();

    // Opens on a combination the shop has
    expect(find.text('មានក្នុងស្តុក: 2 គ្រឿង'), findsOneWidget);

    await tester.ensureVisible(find.text('512GB'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.ancestor(of: find.text('512GB'), matching: find.byType(ChoiceChip)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Blue, 512GB អស់ស្តុក'), findsOneWidget);
    // Nothing to buy here: the bar offers to tell them when it is back
    expect(find.text('ដាក់ Cart'), findsNothing);
    expect(find.text('ជូនដំណឹងខ្ញុំពេលមានស្តុក'), findsOneWidget);

    await tester.ensureVisible(find.text('Black'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Black'));
    await tester.pumpAndSettle();
    expect(find.text('មានក្នុងស្តុក: 1 គ្រឿង'), findsOneWidget);
    expect(find.text('ដាក់ Cart'), findsOneWidget);
  });
}
