import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phoneshop_ms/data/api_service.dart';
import 'package:phoneshop_ms/data/models/order.dart';
import 'package:phoneshop_ms/data/models/payment_account.dart';
import 'package:phoneshop_ms/screens/admin/admin_payment_accounts_screen.dart';
import 'package:phoneshop_ms/screens/payment_screen.dart';

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

final _order = {
  'id': 21,
  'customer_name': 'Thea',
  'total': '999.00',
  'status': 'pending',
  'payment_method': 'khqr',
  'payment_status': 'unpaid',
  'created_at': '2026-11-04T04:00:00Z',
  'items': [],
};

const _aba = {
  'id': 1,
  'bank_name': 'ABA Bank',
  'account_name': 'PS168 SHOP',
  'account_number': '000 111 222',
  'qr_image_url': '',
};
const _acleda = {
  'id': 2,
  'bank_name': 'ACLEDA Bank',
  'account_name': 'PS168 ACLEDA',
  'account_number': '333 444 555',
  'qr_image_url': '',
};

void main() {
  tearDown(() => ApiService.token = null);

  test('older APIs with one bank at the top level still give one account', () {
    final list = PaymentAccount.listFromInfo({
      'bank_name': 'ABA Bank',
      'account_name': 'X',
      'account_number': '1',
      'qr_image_url': '',
    });
    expect(list.single.shortName, 'ABA');
  });

  testWidgets('the customer switches between ABA and ACLEDA', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await http.runWithClient(
      () async {
        ApiService.token = 'test';
        await tester.pumpWidget(
          MaterialApp(home: PaymentScreen(order: Order.fromJson(_order))),
        );
        await tester.pumpAndSettle();
      },
      () => MockClient(
        (_) async => _json({
          ..._aba,
          'accounts': [_aba, _acleda],
        }),
      ),
    );

    expect(find.byType(BankSwitcher), findsOneWidget);
    expect(find.text('000 111 222'), findsOneWidget); // ABA first
    await tester.tap(find.text('ACLEDA'));
    await tester.pumpAndSettle();
    expect(find.text('333 444 555'), findsOneWidget);
    expect(find.text('PS168 ACLEDA'), findsOneWidget);
    expect(find.text('000 111 222'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('with one bank there are no tabs', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await http.runWithClient(
      () async {
        ApiService.token = 'test';
        await tester.pumpWidget(
          MaterialApp(home: PaymentScreen(order: Order.fromJson(_order))),
        );
        await tester.pumpAndSettle();
      },
      () => MockClient(
        (_) async => _json({
          ..._aba,
          'accounts': [_aba],
        }),
      ),
    );
    expect(find.byType(BankSwitcher), findsNothing);
    expect(find.text('000 111 222'), findsOneWidget);
  });

  testWidgets('the admin adds ACLEDA from the bank list', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final accounts = [Map<String, dynamic>.from(_aba)];
    String? sentBank;
    final mock = MockClient((request) async {
      if (request.method == 'POST') {
        final body = request.body;
        sentBank = RegExp(
          r'name="bank_name"\r\n\r\n([^\r]+)',
        ).firstMatch(body)?.group(1);
        accounts.add(Map<String, dynamic>.from(_acleda));
        return _json(_acleda, 201);
      }
      return _json(accounts);
    });

    await http.runWithClient(() async {
      ApiService.token = 'test';
      await tester.pumpWidget(
        const MaterialApp(home: AdminPaymentAccountsScreen()),
      );
      await tester.pumpAndSettle();
      expect(find.text('ABA Bank'), findsOneWidget);
      expect(find.text('មិនទាន់មាន QR'), findsOneWidget);

      await tester.tap(find.text('បន្ថែមធនាគារ'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'ACLEDA'));
      await tester.pump();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(1), 'PS168 ACLEDA');
      await tester.enterText(fields.at(2), '333 444 555');
      await tester.tap(find.text('រក្សាទុក'));
      await tester.pumpAndSettle();
    }, () => mock);

    expect(sentBank, 'ACLEDA Bank');
    expect(find.text('ACLEDA Bank'), findsOneWidget); // list reloaded
    expect(tester.takeException(), isNull);
  });

  testWidgets('saving with empty fields shows what is missing', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PaymentAccountForm())),
    );
    await tester.tap(find.text('រក្សាទុក'));
    await tester.pump();
    expect(find.text('សូមបំពេញ'), findsNWidgets(3));
  });
}
