import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phoneshop_ms/main.dart';
import 'package:phoneshop_ms/data/models/live.dart';
import 'package:phoneshop_ms/screens/live_shopping_screen.dart';
import 'package:phoneshop_ms/components/live_banner.dart';

const _phone = {
  'id': 7,
  'name': 'iPhone 17 Pro',
  'brand': 'Apple',
  'price': 1199,
  'stock': 4,
  'color': 'Silver, Blue',
  'image_url': '',
};

final _liveJson = {
  'is_live': true,
  'youtube_id': 'dQw4w9WgXcQ',
  'title': 'iPhone 17 launch',
  'products': [_phone],
};

http.Response _json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  // No browser in a test: a plain box stands in for the YouTube player
  setUp(() {
    LiveShoppingScreen.playerBuilder = (id) =>
        ColoredBox(key: ValueKey('player-$id'), color: Colors.black);
  });

  testWidgets('the live page plays the video, shows comments and pinned phones', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 860));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final mock = MockClient((request) async {
      if (request.url.path.endsWith('/live/comments')) {
        return _json([
          {'id': 1, 'name': 'Dara', 'avatar_url': '', 'message': 'Price of 256GB?'},
          {'id': 2, 'name': 'Sokha', 'avatar_url': '', 'message': 'Blue please'},
        ]);
      }
      return _json(_liveJson);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: LiveShoppingScreen(
            session: LiveSession.fromJson(_liveJson),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('player-dQw4w9WgXcQ')), findsOneWidget);
      expect(find.text('iPhone 17 launch'), findsOneWidget);
      expect(find.text('LIVE'), findsOneWidget);
      expect(find.text('Price of 256GB?'), findsOneWidget);
      expect(find.text('Blue please'), findsOneWidget);
      expect(find.text('iPhone 17 Pro'), findsOneWidget); // pinned
      expect(tester.takeException(), isNull);

      // Buy now opens the quick-buy sheet over the stream
      await tester.tap(find.text('ទិញ'));
      await tester.pumpAndSettle();
      expect(find.byType(QuickBuySheet), findsOneWidget);
      expect(find.text('Silver'), findsOneWidget); // colour choices
      expect(find.text('Blue'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, () => mock);
  });

  testWidgets('an ended live says so and still lists the phones', (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: LiveShoppingScreen(
            session: LiveSession.fromJson({
              ..._liveJson,
              'is_live': false,
              'youtube_id': '',
            }),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('ការផ្សាយផ្ទាល់បានបញ្ចប់'), findsOneWidget);
      expect(find.text('iPhone 17 Pro'), findsOneWidget);
    }, () => MockClient((_) async => _json([])));
  });

  testWidgets('the store shows a LIVE card on top while the seller is live', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final mock = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/live')) return _json(_liveJson);
      if (path.endsWith('/products')) return _json([_phone]);
      return _json({'brands': [], 'categories': []});
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(const MyApp(showSplash: false));
      await tester.pumpAndSettle();
      expect(find.byType(LiveNowCard), findsOneWidget);
      expect(find.text('iPhone 17 launch'), findsOneWidget);

      await tester.tap(find.byType(LiveNowCard));
      await tester.pumpAndSettle();
      expect(find.byType(LiveShoppingScreen), findsOneWidget);
    }, () => mock);
  });
}
