import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phoneshop_ms/data/api_service.dart';
import 'package:phoneshop_ms/data/models/trade_in.dart';
import 'package:phoneshop_ms/screens/admin/admin_trade_ins_screen.dart';
import 'package:phoneshop_ms/screens/trade_in_screen.dart';

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _t(String status, {double? offer, String code = ''}) => {
  'id': 7,
  'brand': 'Apple',
  'model': 'iPhone 13',
  'storage': '128GB',
  'condition': 'good',
  'battery_health': 86,
  'notes': 'Small scratch',
  'photo_urls': [],
  'wanted_product': {'id': 1, 'name': 'iPhone 17'},
  'status': status,
  'offer_amount': offer,
  'admin_note': offer == null ? null : 'Battery OK',
  'voucher_code': code.isEmpty ? null : code,
  'created_at': '2026-11-18T04:00:00Z',
  'user': {'name': 'Dara', 'phone': '012345678'},
};

void main() {
  setUp(() => ApiService.token = 'test');
  tearDown(() => ApiService.token = null);

  test('a trade-in reads its offer, wish and customer', () {
    final t = TradeIn.fromJson(_t('offered', offer: 250));
    expect(t.title, 'Apple iPhone 13 128GB');
    expect(t.offerAmount, 250);
    expect(t.wantedProduct, 'iPhone 17');
    expect(t.customerName, 'Dara');
    expect(t.isOpen, isTrue);
    expect(
      TradeIn.fromJson(_t('completed', code: 'TRADE-ABC')).isOpen,
      isFalse,
    );
  });

  testWidgets('customer accepts an offer, then sees the credit code', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var state = _t('offered', offer: 250);
    final calls = <String>[];
    final mock = MockClient((request) async {
      calls.add('${request.method} ${request.url.path}');
      if (request.url.path.endsWith('/accept')) {
        state = _t('accepted', offer: 250);
        return _json(state);
      }
      return _json([state]);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: TradeInScreen()));
      await tester.pumpAndSettle();
      expect(find.text('\$250.00'), findsOneWidget);
      expect(find.text('“Battery OK”'), findsOneWidget);

      await tester.tap(find.text('យល់ព្រមតម្លៃនេះ'));
      await tester.pumpAndSettle();
      expect(find.textContaining('សូមយកទូរស័ព្ទមកហាង'), findsOneWidget);

      state = _t('completed', offer: 250, code: 'TRADE-7K3Q9A');
      await tester.drag(find.byType(ListView).first, const Offset(0, 400));
      await tester.pumpAndSettle();
    }, () => mock);

    expect(calls, contains('POST /api/trade-ins/7/accept'));
    expect(find.text('TRADE-7K3Q9A'), findsOneWidget);
  });

  testWidgets('the request form needs brand and model, then sends', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    http.MultipartRequest? sent;
    final mock = MockClient.streaming((request, body) async {
      if (request.url.path.endsWith('/products')) {
        return http.StreamedResponse(Stream.value(utf8.encode('[]')), 200);
      }
      sent = request as http.MultipartRequest;
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(_t('pending')))),
        201,
        headers: {'content-type': 'application/json'},
      );
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TradeInFormScreen()),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ផ្ញើឱ្យហាងវាយតម្លៃ'));
      await tester.pumpAndSettle();
      expect(find.text('សូមបញ្ចូលម៉ាក'), findsOneWidget);
      expect(sent, isNull);

      await tester.tap(find.text('Samsung'));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'ម៉ូដែល *'),
        'Galaxy S22',
      );
      await tester.tap(find.text('256GB'));
      await tester.tap(find.text('មធ្យម (ស្នាមច្រើន)'));
      await tester.pump();
      await tester.tap(find.text('ផ្ញើឱ្យហាងវាយតម្លៃ'));
      await tester.pumpAndSettle();
    }, () => mock);

    expect(sent?.fields, {
      'brand': 'Samsung',
      'model': 'Galaxy S22',
      'storage': '256GB',
      'condition': 'fair',
    });
  });

  testWidgets('admin makes an offer and issues the code once received', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var state = _t('pending');
    Map<String, dynamic>? offered;
    var completed = false;
    final mock = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/offer')) {
        offered = jsonDecode(request.body);
        state = _t('accepted', offer: 300); // the customer said yes meanwhile
        return _json(state);
      }
      if (path.endsWith('/complete')) {
        completed = true;
        state = _t('completed', offer: 300, code: 'TRADE-XYZ123');
        return _json(state);
      }
      return _json([state]);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: AdminTradeInsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Dara · 012345678'), findsOneWidget);

      await tester.tap(find.text('ផ្តល់តម្លៃ'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '300');
      await tester.tap(find.text('ផ្ញើតម្លៃ'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ទទួលទូរស័ព្ទ · ចេញកូដ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ចេញកូដ'));
      await tester.pumpAndSettle();
    }, () => mock);

    expect(offered?['offer_amount'], 300);
    expect(completed, isTrue);
    expect(find.text('កូដ: TRADE-XYZ123'), findsOneWidget);
  });
}
