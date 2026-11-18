import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phoneshop_ms/screens/admin/admin_products_tab.dart';
import 'package:phoneshop_ms/data/api_service.dart';

Map<String, dynamic> phone(
  int id,
  String name,
  String brand,
  int stock, {
  num discount = 0,
}) => {
  'id': id,
  'name': name,
  'brand': brand,
  'price': discount > 0 ? '900.00' : '1000.00',
  'old_price': discount > 0 ? '1000.00' : null,
  'discount_percent': discount,
  'stock': stock,
  'image_url': '',
  'condition': 'New',
};

void main() {
  final phones = [
    phone(1, 'iPhone 18 ProMax', 'Apple', 7, discount: 10),
    phone(2, 'OPPO Reno16 5G', 'OPPO', 2),
    phone(3, 'Galaxy S26', 'Samsung', 0),
  ];

  Future<void> pumpTab(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    ApiService.lowStockThreshold = 3;
    await tester.pumpWidget(const MaterialApp(home: AdminProductsTab()));
    await tester.pumpAndSettle();
  }

  http.Client mock() => MockClient(
    (_) async => http.Response(
      jsonEncode(phones),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    ),
  );

  testWidgets('cards show price, discount and stock, and fit a narrow phone', (
    tester,
  ) async {
    await http.runWithClient(() async {
      await pumpTab(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('%10'), findsOneWidget);
      expect(find.text('ស្តុក: 7'), findsOneWidget);
      expect(find.text('អស់ស្តុក'), findsOneWidget);
      expect(find.byTooltip('កែ'), findsNWidgets(3));
    }, mock);
  });

  testWidgets('search and the low-stock chip narrow the list straight away', (
    tester,
  ) async {
    await http.runWithClient(() async {
      await pumpTab(tester);

      await tester.enterText(find.byType(TextField), 'oppo');
      await tester.pump();
      expect(find.text('OPPO Reno16 5G'), findsOneWidget);
      expect(find.text('iPhone 18 ProMax'), findsNothing);

      await tester.enterText(find.byType(TextField), '');
      await tester.tap(find.text('ស្តុកជិតអស់  2'));
      await tester.pump();
      expect(find.text('OPPO Reno16 5G'), findsOneWidget);
      expect(find.text('Galaxy S26'), findsOneWidget);
      expect(find.text('iPhone 18 ProMax'), findsNothing);

      // The brand chips come after the first two; slide the chip row to reach them
      await tester.drag(find.text('ទាំងអស់  3'), const Offset(-200, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apple  1'));
      await tester.pump();
      expect(find.text('iPhone 18 ProMax'), findsOneWidget);
      expect(find.text('Galaxy S26'), findsNothing);
    }, mock);
  });
}
