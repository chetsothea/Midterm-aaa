import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phoneshop_ms/data/models/phone.dart';
import 'package:phoneshop_ms/screens/cart_screen.dart';
import 'package:phoneshop_ms/hooks/cart.dart';

Phone discounted() => Phone.fromJson({
  'id': 1,
  'name': 'iPad Pro 11-inch (2018)',
  'brand': 'Apple',
  'price': 154,
  'old_price': 220,
  'stock': 3,
  'image_url': '',
  'color': 'Space Gray, Silver',
  'storage_prices': [
    {'storage': '64GB Cellular', 'price': 154, 'old_price': 220},
    {'storage': '256GB Cellular', 'price': 189, 'old_price': 270},
  ],
});

Phone plain() => Phone(
  id: 2,
  name: 'A phone with a really very long name that needs two whole lines',
  brand: 'Samsung',
  price: 100,
  stock: 1,
  imageUrl: '',
);

Future<void> pumpCart(WidgetTester tester, [double width = 360]) async {
  await tester.binding.setSurfaceSize(Size(width, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(const MaterialApp(home: CartScreen()));
  // Let the cart lines finish sliding in before tapping on them
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUp(Cart.instance.clear);
  tearDown(Cart.instance.clear);

  test('the totals count every size at its own price', () {
    Cart.instance.add(discounted(), 2, 'Silver', '64GB Cellular');
    Cart.instance.add(discounted(), 1, 'Silver', '256GB Cellular');
    Cart.instance.add(plain());

    expect(Cart.instance.regularTotal, 220 * 2 + 270 + 100);
    expect(Cart.instance.total, 154 * 2 + 189 + 100);
    expect(Cart.instance.discount, 66 * 2 + 81);
  });

  testWidgets('shows each item and the summary with the discount', (
    tester,
  ) async {
    Cart.instance.add(discounted(), 2, 'Space Gray', '64GB Cellular');
    await pumpCart(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('iPad Pro 11-inch (2018)'), findsOneWidget);
    expect(find.text('Apple'), findsOneWidget);
    expect(find.text('\$154.00'), findsOneWidget); // price of one
    expect(find.text('\$220.00'), findsOneWidget); // crossed out
    expect(find.text('\$440.00'), findsOneWidget); // before the discount
    expect(find.text('-\$132.00'), findsOneWidget);
    expect(
      find.text('\$308.00'),
      findsNWidgets(2),
    ); // to pay: summary and bottom bar
    expect(find.text('Checkout'), findsOneWidget);
  });

  testWidgets('no discount: no discount row', (tester) async {
    Cart.instance.add(plain());
    await pumpCart(tester);

    expect(find.text('បញ្ចុះតម្លៃ'), findsNothing);
    expect(
      find.text('\$100.00'),
      findsNWidgets(4),
    ); // item, before, total, bottom bar
  });

  testWidgets('the buttons change the quantity, within the stock', (
    tester,
  ) async {
    Cart.instance.add(discounted(), 1, 'Silver', '64GB Cellular');
    await pumpCart(tester);

    await tester.tap(find.byTooltip('បន្ថែម'));
    await tester.pump();
    await tester.tap(find.byTooltip('បន្ថែម'));
    await tester.pump();
    expect(Cart.instance.count, 3);

    await tester.tap(find.byTooltip('បន្ថែម')); // stock is 3
    await tester.pump();
    expect(Cart.instance.count, 3);

    await tester.tap(find.byTooltip('បន្ថយ'));
    await tester.pump();
    expect(Cart.instance.count, 2);
  });

  testWidgets('the bin removes the item and shows the empty cart', (
    tester,
  ) async {
    Cart.instance.add(plain());
    await pumpCart(tester);

    await tester.tap(find.byTooltip('ដកចេញ'));
    await tester.pump();

    expect(Cart.instance.isEmpty, isTrue);
    expect(find.text('Cart ទទេ'), findsOneWidget);
    expect(find.text('Checkout'), findsNothing);
  });

  testWidgets('swiping an item to the left takes it out', (tester) async {
    Cart.instance.add(plain());
    await pumpCart(tester);

    await tester.drag(
      find.textContaining('A phone with a really'),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();

    expect(Cart.instance.isEmpty, isTrue);
    expect(find.text('Cart ទទេ'), findsOneWidget);
  });

  testWidgets('the saving is shown in green, with the count in the bar', (
    tester,
  ) async {
    Cart.instance.add(discounted(), 2, 'Space Gray', '64GB Cellular');
    await pumpCart(tester);

    expect(find.text('អ្នកសន្សំបាន \$132.00'), findsOneWidget);
    expect(find.text('2 គ្រឿង'), findsOneWidget);
  });

  testWidgets('long names and options fit a narrow phone', (tester) async {
    Cart.instance.add(discounted(), 3, 'Space Gray', '256GB Cellular');
    Cart.instance.add(plain());
    await pumpCart(tester, 320);

    expect(tester.takeException(), isNull);
  });
}
