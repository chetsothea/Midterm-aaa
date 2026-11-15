import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phoneshop_ms/screens/product_detail_screen.dart';

import 'home_sections_test.dart' show phone, pumpStore;

void main() {
  testWidgets(
    'a phone on sale is in two rows, and either card flies its picture to the details',
    (tester) async {
      await pumpStore(
        tester,
        [phone(1, 'iPad Pro', oldPrice: 180), phone(2, 'iPhone 17')],
        then: () async {
          // The sale phone shows in the deals row and in the list, each with its own tag
          final tags = tester
              .widgetList<Hero>(find.byType(Hero))
              .map((h) => h.tag)
              .where((t) => '$t'.startsWith('phone-'))
              .toList();
          expect(
            tags,
            containsAll(['phone-deals-1', 'phone-list-1', 'phone-list-2']),
          );
          expect(tags.toSet().length, tags.length); // no two the same

          await tester.tap(find.text('iPad Pro').first);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 150)); // mid-flight
          expect(tester.takeException(), isNull);
          await tester.pumpAndSettle();

          expect(find.byType(ProductDetailScreen), findsOneWidget);
          expect(
            find.descendant(
              of: find.byType(ProductDetailScreen),
              matching: find.byWidgetPredicate(
                (w) =>
                    w is Hero &&
                    '${w.tag}'.startsWith('phone-') &&
                    '${w.tag}'.endsWith('-1'),
              ),
            ),
            findsOneWidget,
          );
        },
      );
    },
  );
}
