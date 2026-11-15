import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phoneshop_ms/main.dart';
import 'package:phoneshop_ms/widgets/banner_carousel.dart' hide MyApp;

const banners = [
  'assets/images/banner_1.jpg',
  'assets/images/banner_2.jpg',
  'assets/images/banner_3.jpg',
];

// The picture currently built by the carousel's PageView
String? shownBanner(WidgetTester tester) {
  final image = tester.widget<Image>(
    find
        .descendant(of: find.byType(PageView), matching: find.byType(Image))
        .first,
  );
  return (image.image as AssetImage).assetName;
}

void main() {
  testWidgets('banners slide by themselves and loop back to the first', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: BannerCarousel(images: banners)),
      ),
    );
    expect(shownBanner(tester), banners[0]);

    for (final expected in [banners[1], banners[2], banners[0]]) {
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(shownBanner(tester), expected);
    }
    expect(
      tester.takeException(),
      isNull,
    ); // all three pictures are bundled and load
  });

  // It stays alive under other pages. With a LayoutBuilder, Device Preview's own
  // LayoutBuilder rebuilding it there gives a red "was mutated" screen.
  testWidgets('the banner is 2:1, capped, and has no LayoutBuilder', (
    tester,
  ) async {
    Future<Size> sizeAt(double width) async {
      await tester.binding.setSurfaceSize(Size(width, 800));
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [BannerCarousel(images: banners)],
            ),
          ),
        ),
      );
      return tester.getSize(find.byType(BannerCarousel));
    }

    addTearDown(() => tester.binding.setSurfaceSize(null));
    expect(await sizeAt(360), const Size(360, 180));
    expect(await sizeAt(1000), const Size(1000, 280));
    expect(
      find.descendant(
        of: find.byType(BannerCarousel),
        matching: find.byType(LayoutBuilder),
      ),
      findsNothing,
    );
  });

  testWidgets('store shows the banner above the products, only on Home', (
    tester,
  ) async {
    final mock = MockClient((request) async {
      final body = request.url.path.endsWith('/products')
          ? [
              {
                'id': 1,
                'name': 'iPhone 15',
                'brand': 'Apple',
                'price': 799,
                'stock': 5,
                'image_url': '',
              },
            ]
          : <String, dynamic>{
              'brands': ['Apple'],
              'categories': [
                {
                  'id': 1,
                  'name': 'Smartphone',
                  'brands': ['Apple'],
                },
              ],
            };
      return http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(MyApp(showSplash: false));
      await tester.pumpAndSettle();

      expect(find.byType(BannerCarousel), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(BannerCarousel)).dy,
        lessThan(tester.getTopLeft(find.text('ទូរស័ព្ទពេញនិយម')).dy),
      );

      // Choosing a category hides it
      await tester.tap(find.byTooltip('Menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Smartphone'));
      await tester.pumpAndSettle();
      expect(find.byType(BannerCarousel), findsNothing);

      // Back to Home brings it back
      await tester.tap(find.text('ទំព័រដើម'));
      await tester.pumpAndSettle();
      expect(find.byType(BannerCarousel), findsOneWidget);
    }, () => mock);
  });

  testWidgets('search sits next to the cart and closing it clears the search', (
    tester,
  ) async {
    final searches = <String?>[];
    final mock = MockClient((request) async {
      final isProducts = request.url.path.endsWith('/products');
      if (isProducts) searches.add(request.url.queryParameters['search']);
      return http.Response(
        jsonEncode(
          isProducts ? [] : {'brands': [], 'categories': []},
        ),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(MyApp(showSplash: false));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);
      final search = tester.getCenter(find.byTooltip('Search'));
      final cart = tester.getCenter(find.byTooltip('Favourites'));
      expect(search.dy, cart.dy);
      expect(cart.dx - search.dx, lessThan(60));

      await tester.tap(find.byTooltip('Search'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'iPhone');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(searches.last, 'iPhone');

      await tester.tap(find.byTooltip('Close search'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(searches.last ?? '', isEmpty);
    }, () => mock);
  });
}
