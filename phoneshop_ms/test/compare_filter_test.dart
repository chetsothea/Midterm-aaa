import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phoneshop_ms/data/models/phone.dart';
import 'package:phoneshop_ms/screens/compare_screen.dart';
import 'package:phoneshop_ms/components/product_filter.dart';
import 'package:phoneshop_ms/components/ux.dart';

Phone _phone(
  int id,
  String name,
  String brand,
  double price, {
  String ram = '8GB',
  String storage = '128GB',
  List<StorageOption> sizes = const [],
}) => Phone(
  id: id,
  name: name,
  brand: brand,
  price: price,
  stock: 3,
  ram: ram,
  storage: storage,
  imageUrl: '',
  storageOptions: sizes,
);

void main() {
  final phones = [
    _phone(1, 'iPhone 17', 'Apple', 999, storage: '256GB'),
    _phone(
      2,
      'Galaxy S26',
      'Samsung',
      799,
      ram: '12GB',
      sizes: const [StorageOption('256GB', 799), StorageOption('512GB', 899)],
    ),
    _phone(3, 'Redmi 15', 'Xiaomi', 299),
  ];

  test('the filter narrows by brand, price and storage', () {
    expect(ProductFilter.none.apply(phones), hasLength(3));
    expect(
      const ProductFilter(brands: {'Apple'}).apply(phones).map((p) => p.id),
      [1],
    );
    expect(const ProductFilter(maxPrice: 800).apply(phones).map((p) => p.id), [
      2,
      3,
    ]);
    // A size picked among a phone's options counts too
    expect(
      const ProductFilter(storages: {'512GB'}).apply(phones).map((p) => p.id),
      [2],
    );
    expect(
      const ProductFilter(brands: {'Apple'}, storages: {'512GB'}).count,
      2,
    );
  });

  testWidgets('compare shows both phones side by side, cheaper price wins', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: CompareScreen(phones: phones, first: phones[0]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('iPhone 17'), findsOneWidget);
    expect(
      find.text('Galaxy S26'),
      findsOneWidget,
    ); // the next one, on the right
    expect(find.text('\$999.00'), findsOneWidget);
    expect(find.text('\$799.00'), findsOneWidget);
    expect(find.text('12GB'), findsOneWidget); // RAM
    expect(find.text('512GB'), findsOneWidget); // its biggest size
    expect(tester.takeException(), isNull);

    // Swap the right phone for the Redmi
    await tester.tap(find.text('Galaxy S26'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Redmi 15').last);
    await tester.pumpAndSettle();
    expect(find.text('Galaxy S26'), findsNothing);
    expect(find.text('\$299.00'), findsOneWidget);
  });

  testWidgets('an expandable section folds shut and opens again', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ExpandableSection(
            title: 'Specs',
            icon: Icons.memory,
            child: Text('8GB RAM'),
          ),
        ),
      ),
    );
    expect(find.text('8GB RAM'), findsOneWidget);
    await tester.tap(find.text('Specs'));
    await tester.pumpAndSettle();
    expect(find.text('8GB RAM'), findsNothing);
    await tester.tap(find.text('Specs'));
    await tester.pumpAndSettle();
    expect(find.text('8GB RAM'), findsOneWidget);
  });
}
