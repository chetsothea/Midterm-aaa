import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'home_sections_test.dart' show phone, pumpStore;

void main() {
  testWidgets(
    'the store has one search (the 🔍 in the top bar) and shows the count',
    (tester) async {
      await pumpStore(
        tester,
        [phone(1, 'iPad Pro', oldPrice: 180), phone(2, 'iPhone 17')],
        then: () async {
          // Popular phones show how many there are
          expect(find.text('2'), findsWidgets);
          // No second search box on the page
          expect(find.text('ស្វែងរកទូរស័ព្ទ ម៉ាក ឬម៉ូដែល'), findsNothing);
          expect(find.byType(TextField), findsNothing);

          await tester.tap(find.byTooltip('Search'));
          await tester.pumpAndSettle();
          expect(find.byType(TextField), findsOneWidget);
        },
      );
    },
  );
}
