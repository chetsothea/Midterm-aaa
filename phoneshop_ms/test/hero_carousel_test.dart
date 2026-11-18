import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phoneshop_ms/data/models/phone.dart';
import 'package:phoneshop_ms/components/hero_phone.dart';

Phone _phone(int id, String name) => Phone(
  id: id,
  name: name,
  brand: 'Apple',
  price: 999,
  stock: 3,
  imageUrl: '',
);

void main() {
  testWidgets('the top carousel shows the best sellers, ranked, and swipes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Phone? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HeroCarousel(
            phones: [
              (_phone(1, 'Galaxy S26'), 12),
              (_phone(2, 'iPhone 17'), 7),
              (_phone(3, 'Redmi 15'), 0),
            ],
            onOpen: (p) => opened = p,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Galaxy S26'), findsOneWidget);
    expect(find.text('#1 លក់ដាច់ · លក់បាន 12'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Swipe to the second best seller
    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(find.text('iPhone 17'), findsOneWidget);
    expect(find.text('#2 លក់ដាច់ · លក់បាន 7'), findsOneWidget);

    await tester.tap(find.text('iPhone 17'));
    expect(opened?.id, 2);

    // A phone with no sales yet is "Featured"
    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(find.text('ពិសេស'), findsOneWidget);
  });
}
