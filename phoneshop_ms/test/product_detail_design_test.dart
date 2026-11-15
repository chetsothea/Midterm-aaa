import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phoneshop_ms/models/phone.dart';
import 'package:phoneshop_ms/screens/product_detail_screen.dart';
import 'package:phoneshop_ms/services/favorites.dart';

Phone reno() => Phone.fromJson({
  'id': 20,
  'name': 'OPPO Reno16 5G',
  'brand': 'OPPO',
  'price': 364.65,
  'old_price': 429,
  'stock': 8,
  'ram': '12GB',
  'storage': '12GB + 256GB, 12GB + 512GB',
  'color': 'Twilight Violet, Starry White',
  'condition': 'New',
  'image_url': '',
  'storage_prices': [
    {'storage': '12GB + 256GB', 'price': 364.65, 'old_price': 429},
    {'storage': '12GB + 512GB', 'price': 407.15, 'old_price': 479},
  ],
});

void main() {
  testWidgets('the detail page fits a small phone, specs as tiles', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(home: ProductDetailScreen(phone: reno())),
    );
    await tester.pump();

    expect(tester.takeException(), isNull); // nothing runs past the edge
    expect(find.text('លក្ខណៈពិសេស'), findsOneWidget);
    expect(find.text('RAM'), findsOneWidget);
    expect(find.text('ដាក់ Cart'), findsOneWidget);
    expect(find.text('ទិញឥឡូវ'), findsOneWidget);
  });

  testWidgets('the heart in the bar saves the phone to favourites', (
    tester,
  ) async {
    final wasSaved = Favorites.instance.contains(20);
    addTearDown(() {
      if (Favorites.instance.contains(20) != wasSaved) {
        Favorites.instance.toggle(20);
      }
    });

    await tester.pumpWidget(
      MaterialApp(home: ProductDetailScreen(phone: reno())),
    );
    await tester.pump();

    await tester.tap(
      find.byIcon(wasSaved ? Icons.favorite : Icons.favorite_border),
    );
    await tester.pumpAndSettle();
    expect(Favorites.instance.contains(20), !wasSaved);
  });
}
