import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phoneshop_ms/data/api_service.dart';
import 'package:phoneshop_ms/data/models/phone.dart';
import 'package:phoneshop_ms/data/models/user.dart';
import 'package:phoneshop_ms/data/riel.dart';
import 'package:phoneshop_ms/hooks/notices.dart';
import 'package:phoneshop_ms/screens/admin/admin_reviews_screen.dart';
import 'package:phoneshop_ms/screens/notices_screen.dart';
import 'package:phoneshop_ms/screens/product_detail_screen.dart';

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _phone({int stock = 0}) => {
  'id': 16,
  'name': 'Find X10',
  'brand': 'Oppo',
  'price': 999,
  'stock': stock,
  'image_url': '',
};

void main() {
  setUp(() {
    ApiService.token = 'test';
    ApiService.currentUser = User(
      id: 2,
      name: 'Dara',
      email: 'd@e.com',
      role: 'user',
    );
  });
  tearDown(() {
    ApiService.token = null;
    ApiService.currentUser = null;
    Riel.rate.value = 4100;
    Notices.instance.items = [];
    Notices.instance.unread = 0;
  });

  test('riel is rounded to 100 and grouped', () {
    Riel.rate.value = 4100;
    expect(Riel.of(999), '៛4,095,900');
    expect(Riel.of(1.5), '៛6,200');
    Riel.rate.value = 0;
    expect(Riel.shown, isFalse);
  });

  testWidgets('a sold-out phone offers "notify me", and it can be undone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final calls = <String>[];
    final mock = MockClient((request) async {
      calls.add('${request.method} ${request.url.path}');
      if (request.url.path == '/api/stock-alerts') return _json([]);
      return _json({'product_id': 16, 'variant': ''}, 201);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(home: ProductDetailScreen(phone: Phone.fromJson(_phone()))),
      );
      await tester.pumpAndSettle();
      expect(find.text('≈ ៛4,095,900'), findsOneWidget);

      await tester.tap(find.text('ជូនដំណឹងខ្ញុំពេលមានស្តុក'));
      await tester.pumpAndSettle();
      expect(find.textContaining('នឹងជូនដំណឹងពេលមានស្តុក'), findsOneWidget);

      await tester.tap(find.textContaining('នឹងជូនដំណឹងពេលមានស្តុក'));
      await tester.pumpAndSettle();
      expect(find.text('ជូនដំណឹងខ្ញុំពេលមានស្តុក'), findsOneWidget);
    }, () => mock);

    expect(
      calls,
      containsAllInOrder([
        'GET /api/stock-alerts',
        'POST /api/products/16/stock-alert',
        'DELETE /api/products/16/stock-alert',
      ]),
    );
  });

  testWidgets('a "back in stock" notice opens that phone', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final mock = MockClient((request) async {
      final path = request.url.path;
      if (path == '/api/notices') {
        return _json({
          'unread': 1,
          'notices': [
            {
              'id': 1,
              'kind': 'stock',
              'title': 'Find X10 មានក្នុងស្តុកវិញហើយ!',
              'body': 'ចុចដើម្បីមើល',
              'product_id': 16,
              'read_at': null,
              'created_at': DateTime.now().toUtc().toIso8601String(),
            },
          ],
        });
      }
      if (path == '/api/products/16') return _json(_phone(stock: 4));
      if (path == '/api/stock-alerts') return _json([]);
      return _json({});
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: NoticesScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Find X10 មានក្នុងស្តុកវិញហើយ!'));
      await tester.pumpAndSettle();
    }, () => mock);

    expect(find.byType(ProductDetailScreen), findsOneWidget);
    expect(find.text('មានក្នុងស្តុក: 4 គ្រឿង'), findsOneWidget);
  });

  testWidgets('admin hides a review', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Map? sent;
    final mock = MockClient((request) async {
      if (request.method == 'PUT') {
        sent = jsonDecode(request.body);
        return _json({'id': 3, 'hidden': true});
      }
      return _json([
        {
          'id': 3,
          'product': 'Find X10',
          'name': 'Spammer',
          'rating': 1,
          'comment': 'buy cheap watches at ...',
          'hidden': false,
          'created_at': '2026-11-18T04:00:00Z',
        },
      ]);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: AdminReviewsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('buy cheap watches at ...'), findsOneWidget);
      await tester.tap(find.text('លាក់'));
      await tester.pumpAndSettle();
    }, () => mock);

    expect(sent, {'hidden': true});
    expect(find.text('បង្ហាញវិញ'), findsOneWidget);
  });
}
