import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phoneshop_ms/data/models/phone.dart';
import 'package:phoneshop_ms/components/product_card.dart';

Phone phone({
  String color = 'Blue, Red, Black',
  Map<String, String> pictures = const {
    'Blue': 'http://x/blue.png',
    'Red': 'http://x/red.png',
    'Black': 'http://x/black.png',
  },
}) => Phone(
  id: 1,
  name: 'iPhone',
  brand: 'Apple',
  price: 100,
  stock: 5,
  color: color,
  imageUrl: 'http://x/main.png',
  colorImageUrls: pictures,
);

Future<void> pumpCard(WidgetTester tester, Phone phone) => tester.pumpWidget(
  MaterialApp(
    home: Center(
      child: SizedBox(
        width: 200,
        height: 340,
        child: ProductCard(phone: phone, onTap: () {}, onAddToCart: () {}),
      ),
    ),
  ),
);

// The picture currently fading in, which is the last one built
String shown(WidgetTester tester) {
  final image = tester.widgetList<Image>(find.byType(Image)).last.image;
  // Cards decode at a smaller size, which wraps the network image
  final provider = image is ResizeImage ? image.imageProvider : image;
  return (provider as NetworkImage).url;
}

void main() {
  testWidgets('the picture moves through the colours and starts over', (
    tester,
  ) async {
    await pumpCard(tester, phone());
    expect(shown(tester), 'http://x/blue.png');

    for (final url in ['http://x/red.png', 'http://x/black.png', 'http://x/blue.png']) {
      await tester.pump(cardColorInterval);
      await tester.pump();
      expect(shown(tester), url);
    }
    tester.takeException(); // pictures can't load in a test
  });

  testWidgets('a phone with one picture stays on it', (tester) async {
    await pumpCard(tester, phone(color: 'Blue', pictures: const {'Blue': 'http://x/blue.png'}));
    await tester.pump(cardColorInterval * 3);
    await tester.pump(const Duration(seconds: 1));
    expect(shown(tester), 'http://x/blue.png');
    tester.takeException();
  });

  testWidgets('colours sharing a picture do not repeat it', (tester) async {
    await pumpCard(
      tester,
      phone(
        color: 'Blue, Navy',
        pictures: const {'Blue': 'http://x/blue.png', 'Navy': 'http://x/blue.png'},
      ),
    );
    await tester.pump(cardColorInterval);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(Image), findsOneWidget);
    expect(shown(tester), 'http://x/blue.png');
    tester.takeException();
  });

  testWidgets('no colour pictures: the main picture', (tester) async {
    await pumpCard(tester, phone(color: '', pictures: const {}));
    expect(shown(tester), 'http://x/main.png');
    tester.takeException();
  });
}
