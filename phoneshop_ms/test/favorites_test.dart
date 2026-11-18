import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phoneshop_ms/screens/favorites_view.dart';
import 'package:phoneshop_ms/data/api_service.dart';
import 'package:phoneshop_ms/hooks/cart.dart';
import 'package:phoneshop_ms/hooks/favorites.dart';
import 'package:phoneshop_ms/components/store_menu.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() {
    for (final id in Favorites.instance.ids) {
      Favorites.instance.toggle(id);
    }
  });

  final mock = MockClient(
    (request) async => http.Response(
      jsonEncode([
        {
          'id': 1,
          'name': 'iPhone 16',
          'brand': 'Apple',
          'price': 900,
          'stock': 3,
          'image_url': '',
        },
        {
          'id': 2,
          'name': 'Galaxy S26',
          'brand': 'Samsung',
          'price': 800,
          'stock': 0,
          'image_url': '',
        },
        {
          'id': 3,
          'name': 'Not liked',
          'brand': 'OPPO',
          'price': 300,
          'stock': 3,
          'image_url': '',
        },
      ]),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    ),
  );

  testWidgets(
    'the favourites page lists the ♥ phones, and ♥ there removes one',
    (tester) async {
      Favorites.instance.toggle(1);
      Favorites.instance.toggle(2);

      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: FavoritesScreen()));
        await tester.pumpAndSettle();
        expect(find.text('iPhone 16'), findsOneWidget);
        expect(find.text('Galaxy S26'), findsOneWidget);
        expect(find.text('អស់ស្តុក'), findsOneWidget); // its stock is shown
        expect(find.text('Not liked'), findsNothing);

        await tester.tap(find.byTooltip('ដកចេញពីចំណូលចិត្ត').first);
        await tester.pumpAndSettle();
        expect(find.text('iPhone 16'), findsNothing);
        expect(find.text('Galaxy S26'), findsOneWidget);
      }, () => mock);
    },
  );

  testWidgets('with nothing liked it explains how to add phones', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: FavoritesScreen()));
    await tester.pumpAndSettle();
    expect(find.text('មិនទាន់មានទូរស័ព្ទដែលអ្នកចូលចិត្តទេ'), findsOneWidget);
  });

  test('♥ phones are remembered for next time', () async {
    Favorites.instance.toggle(7);
    await Future<void>.delayed(Duration.zero);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('favorites'), ['7']);

    Favorites.instance.toggle(7);
    await Favorites.instance.load();
    expect(Favorites.instance.contains(7), isFalse);
  });
  testWidgets(
    "the cart button on a favourite adds it, and a sold-out one can't be added",
    (tester) async {
      Favorites.instance.toggle(1);
      Favorites.instance.toggle(2);
      Cart.instance.clear();
      ApiService.token = 'test';
      addTearDown(() {
        ApiService.token = null;
        Cart.instance.clear();
      });

      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: FavoritesScreen()));
        await tester.pumpAndSettle();

        final buttons = find.widgetWithIcon(
          FilledButton,
          Icons.add_shopping_cart,
        );
        expect(buttons, findsNWidgets(2));
        // Galaxy S26 is sold out
        expect(tester.widget<FilledButton>(buttons.last).onPressed, isNull);

        await tester.tap(buttons.first);
        await tester.pump();
        expect(Cart.instance.count, 1);
        expect(Cart.instance.items.first.phone.name, 'iPhone 16');
      }, () => mock);
    },
  );
  testWidgets('♡ in the top bar shows how many phones are liked', (
    tester,
  ) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [FavoritesButton(onPressed: () => opened = true)],
          ),
        ),
      ),
    );
    Badge heart() => tester.widget<Badge>(
      find.ancestor(
        of: find.byIcon(Icons.favorite_border),
        matching: find.byType(Badge),
      ),
    );
    expect(heart().isLabelVisible, isFalse); // nothing liked: no number

    Favorites.instance.toggle(1);
    Favorites.instance.toggle(2);
    await tester.pump();
    expect(heart().isLabelVisible, isTrue);
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.byTooltip('Favourites'));
    expect(opened, isTrue);
  });

  testWidgets('the cart sits in the bottom menu', (tester) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: StoreMenuBar(
            current: StoreFilter.home,
            onSelected: (_) {},
            onTelegram: () {},
            onAccount: () {},
            onOrders: () {},
            onCart: () => opened = true,
          ),
        ),
      ),
    );
    expect(find.text('កន្ត្រក'), findsOneWidget);
    expect(
      find.byIcon(Icons.favorite_border),
      findsNothing,
    ); // moved to the top bar

    await tester.tap(find.text('កន្ត្រក'));
    expect(opened, isTrue);
  });
}
