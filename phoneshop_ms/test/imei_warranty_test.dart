import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phoneshop_ms/data/api_service.dart';
import 'package:phoneshop_ms/data/models/order.dart';
import 'package:phoneshop_ms/screens/admin/warranty_screens.dart';
import 'package:phoneshop_ms/screens/invoice_screen.dart';

const _a = '490154203237518';
const _b = '356938035643809';

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _order({
  String? deliveredAt,
  String? until,
  List<String> imeis = const [],
}) => {
  'id': 5,
  'code': 'PS-ABC123',
  'customer_name': 'Dara',
  'total': '999',
  'status': deliveredAt == null ? 'shipping' : 'delivered',
  'payment_method': 'cod',
  'payment_status': 'paid',
  'created_at': '2026-11-10T04:00:00Z',
  'delivered_at': deliveredAt,
  'items': [
    {
      'id': 9,
      'product_id': 1,
      'qty': 2,
      'price': '499.50',
      'warranty_months': 12,
      'warranty_until': until,
      'imeis': imeis,
      'product': {'name': 'iPhone 17', 'image_url': ''},
    },
  ],
  'trackings': [],
};

void main() {
  tearDown(() => ApiService.token = null);

  test('IMEI check digit catches typos', () {
    expect(imeiLooksRight(_a), isTrue);
    expect(imeiLooksRight(_b), isTrue);
    expect(imeiLooksRight('490154203237519'), isFalse); // last digit wrong
    expect(imeiLooksRight('12345'), isFalse);
  });

  test('an order line reads its IMEIs and warranty', () {
    final until = DateTime.now().add(const Duration(days: 30, hours: 2));
    final item = Order.fromJson(
      _order(
        deliveredAt: '2026-11-01T00:00:00Z',
        until: until.toUtc().toIso8601String(),
        imeis: [_a],
      ),
    ).items.first;
    expect(item.id, 9);
    expect(item.imeis, [_a]);
    expect(item.warrantyMonths, 12);
    expect(item.warrantyDaysLeft, 30);
  });

  Future<void> pumpInvoice(
    WidgetTester tester,
    Map<String, dynamic> json,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: InvoiceScreen(order: Order.fromJson(json))),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'before delivery the invoice says how long the warranty will be',
    (tester) async {
      await pumpInvoice(tester, _order());
      expect(find.text('ធានា 12 ខែ ចាប់ពីថ្ងៃទទួលឥវ៉ាន់'), findsOneWidget);
    },
  );

  testWidgets('after delivery it shows the IMEIs and the days left', (
    tester,
  ) async {
    final until = DateTime.now().add(const Duration(days: 100, hours: 2));
    await pumpInvoice(
      tester,
      _order(
        deliveredAt: '2026-11-01T00:00:00Z',
        until: until.toUtc().toIso8601String(),
        imeis: [_a, _b],
      ),
    );
    expect(find.text('IMEI $_a'), findsOneWidget);
    expect(find.text('IMEI $_b'), findsOneWidget);
    expect(find.textContaining('នៅសល់ 100 ថ្ងៃ'), findsOneWidget);
  });

  testWidgets(
    'admin types one IMEI per phone; a typo is caught before saving',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      Map<String, dynamic>? sent;
      final mock = MockClient((request) async {
        sent = jsonDecode(request.body);
        return _json({'imeis': sent!['imeis']});
      });
      final item = Order.fromJson(_order()).items.first;
      List<String>? result;

      await http.runWithClient(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async =>
                      result = await showImeiSheet(context, item),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.byType(TextFormField), findsNWidgets(2)); // qty 2

        await tester.enterText(
          find.byType(TextFormField).at(0),
          '490154203237519',
        );
        await tester.tap(find.text('រក្សាទុក'));
        await tester.pumpAndSettle();
        expect(
          find.text('លេខនេះមិនត្រឹមត្រូវ សូមពិនិត្យម្តងទៀត'),
          findsOneWidget,
        );
        expect(sent, isNull);

        await tester.enterText(find.byType(TextFormField).at(0), _a);
        await tester.tap(find.text('រក្សាទុក'));
        await tester.pumpAndSettle();
      }, () => mock);

      expect(sent, {
        'imeis': [_a],
      }); // the second phone can be added later
      expect(result, [_a]);
    },
  );

  testWidgets('warranty desk finds who bought a phone by its IMEI', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final mock = MockClient((request) async {
      if (request.url.path.endsWith(_a)) {
        return _json({
          'imei': _a,
          'product': 'iPhone 17',
          'color': 'Blue',
          'storage': '256GB',
          'order_id': 5,
          'order_code': 'PS-ABC123',
          'customer_name': 'Dara',
          'phone': '012345678',
          'sold_at': '2026-11-10T04:00:00Z',
          'delivered_at': '2026-11-12T04:00:00Z',
          'warranty_months': 12,
          'warranty_until': '2027-11-12T04:00:00Z',
          'under_warranty': true,
        });
      }
      return _json({'message': 'រកមិនឃើញ IMEI នេះក្នុងការលក់របស់ហាងទេ'}, 404);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: WarrantyLookupScreen()));
      await tester.enterText(find.byType(TextField), _b);
      await tester.tap(find.text('ស្វែងរក'));
      await tester.pumpAndSettle();
      expect(
        find.text('រកមិនឃើញ IMEI នេះក្នុងការលក់របស់ហាងទេ'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField), _a);
      await tester.tap(find.text('ស្វែងរក'));
      await tester.pumpAndSettle();
    }, () => mock);

    expect(find.text('នៅក្នុងការធានា'), findsOneWidget);
    expect(find.text('iPhone 17 (Blue, 256GB)'), findsOneWidget);
    expect(find.text('Dara · 012345678'), findsOneWidget);
    expect(find.text('12/11/2027'), findsOneWidget);
  });
}
