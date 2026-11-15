import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phoneshop_ms/main.dart';
import 'package:phoneshop_ms/widgets/brand_row.dart';
import 'package:phoneshop_ms/widgets/product_card.dart';

const dealsTitle = 'កំពុងបញ្ចុះតម្លៃ';

Map<String, dynamic> phone(int id, String name, {num? oldPrice, int stock = 5}) => {
  'id': id,
  'name': name,
  'brand': 'Apple',
  'price': 100,
  'old_price': oldPrice,
  'stock': stock,
  'image_url': '',
};

Future<List<String>> pumpStore(
  WidgetTester tester,
  List<Map<String, dynamic>> phones, {
  List<String> brands = const ['Apple', 'Samsung'],
  required Future<void> Function() then,
}) async {
  await tester.binding.setSurfaceSize(const Size(400, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final asked = <String>[];
  final mock = MockClient((request) async {
    final isProducts = request.url.path.endsWith('/products');
    if (isProducts) asked.add(request.url.queryParameters['brand'] ?? '');
    return http.Response(
      jsonEncode(
        isProducts
            ? phones
            : {'brands': brands, 'categories': <Object>[]},
      ),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
  await http.runWithClient(() async {
    await tester.pumpWidget(const MyApp(showSplash: false));
    await tester.pumpAndSettle();
    await then();
  }, () => mock);
  return asked;
}

void main() {
  testWidgets('tapping a brand shows that brand and hides the shortcuts', (
    tester,
  ) async {
    final asked = await pumpStore(
      tester,
      [phone(1, 'iPhone')],
      then: () async {
        expect(find.byType(BrandRow), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(find.descendant(
          of: find.byType(BrandRow),
          matching: find.text('Samsung'),
        ));
        await tester.pumpAndSettle();

        expect(find.byType(BrandRow), findsNothing);
        expect(find.text('SAMSUNG'), findsOneWidget);
      },
    );
    expect(asked.last, 'Samsung');
  });

  testWidgets('deals show the biggest discount first, and not when sold out', (
    tester,
  ) async {
    await pumpStore(
      tester,
      [
        phone(1, 'Small deal', oldPrice: 110),
        phone(2, 'Big deal', oldPrice: 200),
        phone(3, 'Sold out deal', oldPrice: 300, stock: 0),
        phone(4, 'No deal'),
      ],
      then: () async {
        expect(find.text(dealsTitle), findsOneWidget);
        expect(tester.takeException(), isNull); // cards fit the row

        final row = find.ancestor(
          of: find.text(dealsTitle),
          matching: find.byType(CustomScrollView),
        );
        final deals = tester
            .widgetList<ProductCard>(find.descendant(
              of: find.byWidgetPredicate(
                (w) => w is ListView && w.scrollDirection == Axis.horizontal,
              ).last,
              matching: find.byType(ProductCard),
            ))
            .map((card) => card.phone.name)
            .toList();
        expect(row, findsOneWidget);
        expect(deals, ['Big deal', 'Small deal']);

        // Still in the full list too
        expect(find.text('No deal'), findsOneWidget);
      },
    );
  });

  testWidgets('no discounts: no deals row', (tester) async {
    await pumpStore(
      tester,
      [phone(4, 'No deal')],
      then: () async {
        expect(find.text(dealsTitle), findsNothing);
      },
    );
  });

  testWidgets('known brands show their logo, others their first letter', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(500, 200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BrandRow(
            brands: const ['Apple', 'SAMSUNG', 'OPPO', 'HONOR', 'vivo', 'Nokia'],
            onSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull); // every logo file is bundled
    expect(find.byType(SvgPicture), findsNWidgets(5));
    expect(find.text('N'), findsOneWidget);
    expect(find.text('A'), findsNothing);
  });

  test('each brand has its own colour, whatever the capitals', () {
    final colours = ['Apple', 'SAMSUNG', 'OPPO', 'HONOR', 'Vivo', 'Nokia'].map(brandColor);
    expect(colours.toSet().length, 6);
    expect(brandColor('samsung'), brandColor('SAMSUNG'));
  });

  testWidgets('no brands yet: no empty row', (tester) async {
    await pumpStore(
      tester,
      [phone(4, 'No deal')],
      brands: const [],
      then: () async {
        expect(find.byType(BrandRow), findsNothing);
      },
    );
  });
}
