import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phoneshop_ms/models/phone.dart';
import 'package:phoneshop_ms/screens/admin/product_form_screen.dart';
import 'package:phoneshop_ms/screens/product_detail_screen.dart';
import 'package:phoneshop_ms/widgets/product_card.dart';

Phone discounted() => Phone.fromJson({
  'id': 1,
  'name': 'iPhone',
  'brand': 'Apple',
  'price': 900,
  'old_price': 1000,
  'stock': 5,
  'image_url': '',
  'storage_prices': [
    {'storage': '256GB', 'price': 900, 'old_price': 1000},
    {'storage': '512GB', 'price': 1080, 'old_price': 1200},
  ],
});

void main() {
  test('each size knows its discounted and regular price', () {
    final phone = discounted();
    expect(phone.priceFor('512GB'), 1080);
    expect(phone.oldPriceFor('512GB'), 1200);
    expect(phone.discountPercent, closeTo(10, 0.001));
  });

  testWidgets('the detail page shows the badge on the picture and the regular price', (tester) async {
    await tester.pumpWidget(MaterialApp(home: ProductDetailScreen(phone: discounted())));
    await tester.pump();
    expect(find.widgetWithText(DiscountBadge, '%10'), findsOneWidget);
    expect(find.text('\$1000.00'), findsOneWidget);
  });

  testWidgets('the store card shows the badge over the picture', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: SizedBox(
          width: 200,
          height: 340,
          child: ProductCard(phone: discounted(), onTap: () {}, onAddToCart: () {}),
        ),
      ),
    ));
    final badge = tester.getCenter(find.widgetWithText(DiscountBadge, '%10'));
    final name = tester.getCenter(find.text('iPhone'));
    expect(badge.dy, lessThan(name.dy));
  });

  testWidgets('the admin form edits regular prices and the discount %', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(home: ProductFormScreen(phone: discounted())));
      await tester.pumpAndSettle();
    }, () => MockClient((_) async => http.Response('[]', 200)));

    String field(String label) => tester
        .widget<TextFormField>(find.widgetWithText(TextFormField, label))
        .controller!
        .text;
    expect(field('Discount (%)'), '10');
    expect(field('តម្លៃ (\$) *'), '1000.0');
    expect(field('Storage ជាមួយតម្លៃ (ជម្រើស)'), '256GB=1000, 512GB=1200');
  });
}
