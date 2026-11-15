import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phoneshop_ms/main.dart';

Map<String, dynamic> phone(int id, String name, {num? old, int stock = 5}) => {
  'id': id,
  'name': name,
  'brand': 'Apple',
  'price': 100,
  'old_price': old,
  'stock': stock,
  'image_url': '',
};

void main() {
  testWidgets('"See all" on the sale row lists every discounted phone, biggest first', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final mock = MockClient((request) async => http.Response(
      jsonEncode(request.url.path.endsWith('/products')
          ? [
              phone(1, 'Small deal', old: 110),
              phone(2, 'No deal'),
              phone(3, 'Big deal', old: 200),
              phone(4, 'Sold-out deal', old: 150, stock: 0),
            ]
          : {'brands': [], 'categories': []}),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    ));

    await http.runWithClient(() async {
      await tester.pumpWidget(const MyApp(showSplash: false));
      await tester.pumpAndSettle();

      await tester.tap(find.text('មើលទាំងអស់'));
      await tester.pumpAndSettle();

      expect(find.text('No deal'), findsNothing);
      expect(find.text('Sold-out deal'), findsOneWidget); // shown here, just not in the row
      // Reading order: Big (50%) first, Small (10%) last, a row below
      expect(
        tester.getTopLeft(find.text('Big deal')).dy,
        lessThan(tester.getTopLeft(find.text('Small deal')).dy),
      );
      expect(find.text('មើលទាំងអស់'), findsNothing); // the row itself is gone

      // The chip at the top brings everything back
      tester.widget<InputChip>(find.byType(InputChip)).onDeleted!();
      await tester.pumpAndSettle();
      expect(find.text('No deal'), findsOneWidget);
    }, () => mock);
  });
}
