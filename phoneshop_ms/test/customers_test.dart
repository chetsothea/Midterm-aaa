import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phoneshop_ms/screens/admin/admin_customers_screen.dart';
import 'package:phoneshop_ms/data/api_service.dart';

void main() {
  testWidgets('admin edits a customer and sets a new password', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final customer = <String, dynamic>{
      'id': 6,
      'name': 'Thea',
      'email': 'thea@gmail.com',
      'phone': '09283892',
      'address': 'Battambang',
      'blocked_at': null,
      'created_at': '2026-10-31T02:57:07.000000Z',
      'orders_count': 1,
    };
    final sent = <Map>[];

    await http.runWithClient(
      () async {
        ApiService.token = 'test';
        await tester.pumpWidget(
          const MaterialApp(home: AdminCustomersScreen()),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('កែ'));
        await tester.pumpAndSettle();

        // Details are filled in; the password starts empty
        expect(
          find.widgetWithText(TextFormField, 'thea@gmail.com'),
          findsOneWidget,
        );
        final password = find.widgetWithText(TextFormField, 'ពាក្យសម្ងាត់ថ្មី');

        // Too short: nothing is sent
        await tester.enterText(password, '123');
        await tester.tap(find.text('រក្សាទុក'));
        await tester.pumpAndSettle();
        expect(find.text('យ៉ាងតិច 6 តួ'), findsOneWidget);
        expect(sent, isEmpty);

        // Details only: no password goes to the API
        await tester.enterText(password, '');
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Thea'),
          'Thea Sok',
        );
        await tester.tap(find.text('រក្សាទុក'));
        await tester.pumpAndSettle();
        expect(sent.single.containsKey('password'), isFalse);
        expect(sent.single['name'], 'Thea Sok');
        expect(find.text('Thea Sok'), findsOneWidget); // the list refreshed

        // With a new password
        await tester.tap(find.text('កែ'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextFormField, 'ពាក្យសម្ងាត់ថ្មី'),
          'newpass1',
        );
        await tester.tap(find.text('រក្សាទុក'));
        await tester.pumpAndSettle();
        expect(sent.last['password'], 'newpass1');

        expect(tester.takeException(), isNull);
        ApiService.token = null;
      },
      () => MockClient((request) async {
        if (request.method == 'PUT') {
          expect(request.url.path, '/api/admin/customers/6');
          final body = jsonDecode(request.body) as Map;
          sent.add(body);
          customer['name'] = body['name'];
          return http.Response('{"id":6}', 200);
        }
        return http.Response(
          jsonEncode([customer]),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
  });

  testWidgets(
    'the buttons fit on a narrow phone, even for a disabled account',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await http.runWithClient(
        () async {
          ApiService.token = 'test';
          await tester.pumpWidget(
            const MaterialApp(home: AdminCustomersScreen()),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('កែ'), findsOneWidget);
          expect(find.text('បើកវិញ'), findsOneWidget);
          ApiService.token = null;
        },
        () => MockClient(
          (_) async => http.Response(
            jsonEncode([
              {
                'id': 6,
                'name': 'Thea',
                'email': 'thea@gmail.com',
                'blocked_at': '2026-11-01T10:00:00.000000Z',
                'created_at': '2026-10-31T02:57:07.000000Z',
                'orders_count': 1,
              },
            ]),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );
    },
  );

  testWidgets(
    'admin disables a customer after confirming, and can re-enable them',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final customer = <String, dynamic>{
        'id': 6,
        'name': 'Thea',
        'email': 'thea@gmail.com',
        'phone': '09283892',
        'address': 'Battambang',
        'blocked_at': null,
        'created_at': '2026-10-31T02:57:07.000000Z',
        'orders_count': 1,
      };
      final sent = <Map>[];

      await http.runWithClient(
        () async {
          ApiService.token = 'test';
          await tester.pumpWidget(
            const MaterialApp(home: AdminCustomersScreen()),
          );
          await tester.pumpAndSettle();

          expect(find.text('គណនីបានបិទ'), findsNothing);

          // Changing their mind in the dialog does nothing
          await tester.tap(find.text('បិទគណនី'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('ទេ'));
          await tester.pumpAndSettle();
          expect(sent, isEmpty);

          // Confirming disables the account
          await tester.tap(find.text('បិទគណនី'));
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(FilledButton, 'បិទគណនី'));
          await tester.pumpAndSettle();
          expect(sent.single, {'blocked': true});
          expect(find.text('គណនីបានបិទ'), findsOneWidget);
          expect(find.widgetWithText(OutlinedButton, 'បើកវិញ'), findsOneWidget);

          // And it can be undone
          await tester.tap(find.widgetWithText(OutlinedButton, 'បើកវិញ'));
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(FilledButton, 'បើកវិញ'));
          await tester.pumpAndSettle();
          expect(sent.last, {'blocked': false});
          expect(find.text('គណនីបានបិទ'), findsNothing);

          expect(tester.takeException(), isNull);
          ApiService.token = null;
        },
        () => MockClient((request) async {
          if (request.method == 'PUT') {
            expect(request.url.path, '/api/admin/customers/6/blocked');
            final body = jsonDecode(request.body) as Map;
            sent.add(body);
            customer['blocked_at'] = body['blocked'] == true
                ? '2026-11-01T10:00:00.000000Z'
                : null;
            return http.Response('{"id":6}', 200);
          }
          return http.Response(
            jsonEncode([customer]),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
    },
  );
}
