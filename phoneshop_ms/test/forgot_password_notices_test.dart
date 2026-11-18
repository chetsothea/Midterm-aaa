import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phoneshop_ms/data/api_service.dart';
import 'package:phoneshop_ms/data/models/user.dart';
import 'package:phoneshop_ms/hooks/notices.dart';
import 'package:phoneshop_ms/screens/forgot_password_screen.dart';
import 'package:phoneshop_ms/screens/notices_screen.dart';

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  tearDown(() {
    ApiService.token = null;
    ApiService.currentUser = null;
    Notices.instance.stop();
    Notices.instance.unread = 0;
    Notices.instance.items = [];
  });

  testWidgets('forgot password: e-mail, then code and new password', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final sent = <String, Map>{};
    final mock = MockClient((request) async {
      final body = jsonDecode(request.body) as Map;
      sent[request.url.path] = body;
      if (request.url.path.endsWith('/password/code')) {
        return _json({'message': 'បើ Email នេះមានគណនី យើងបានផ្ញើលេខកូដ'});
      }
      if (body['code'] == '111111') {
        return _json({'message': 'លេខកូដមិនត្រឹមត្រូវ ឬផុតកំណត់ហើយ'}, 422);
      }
      return _json({'message': 'ok'});
    });
    bool? changed;

    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => changed = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const ForgotPasswordScreen(email: 'dara@example.com'),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ផ្ញើលេខកូដ'));
      await tester.pumpAndSettle();
      expect(sent['/api/password/code'], {'email': 'dara@example.com'});
      expect(
        find.textContaining('យើងបានផ្ញើលេខកូដ 6 ខ្ទង់ទៅ dara@example.com'),
        findsOneWidget,
      );

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(1), '111111');
      await tester.enterText(fields.at(2), 'newpass1');
      await tester.enterText(fields.at(3), 'newpass2');
      await tester.tap(find.text('កំណត់ពាក្យសម្ងាត់ថ្មី'));
      await tester.pumpAndSettle();
      expect(find.text('ពាក្យសម្ងាត់ទាំងពីរមិនដូចគ្នា'), findsOneWidget);
      expect(sent.containsKey('/api/password/reset'), isFalse);

      await tester.enterText(fields.at(3), 'newpass1');
      await tester.tap(find.text('កំណត់ពាក្យសម្ងាត់ថ្មី'));
      await tester.pumpAndSettle();
      expect(find.text('លេខកូដមិនត្រឹមត្រូវ ឬផុតកំណត់ហើយ'), findsOneWidget);
      expect(changed, isNull); // still on the page

      await tester.enterText(fields.at(1), '482913');
      await tester.tap(find.text('កំណត់ពាក្យសម្ងាត់ថ្មី'));
      await tester.pumpAndSettle();
    }, () => mock);

    expect(sent['/api/password/reset'], {
      'email': 'dara@example.com',
      'code': '482913',
      'password': 'newpass1',
      'password_confirmation': 'newpass1',
    });
    expect(changed, isTrue);
  });

  testWidgets('the 🔔 shows unread, the list marks them read', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    ApiService.token = 'test';
    ApiService.currentUser = User(
      id: 2,
      name: 'Dara',
      email: 'd@e.com',
      role: 'user',
    );
    var readCalled = false;
    final mock = MockClient((request) async {
      if (request.url.path.endsWith('/notices/read')) {
        readCalled = true;
        return _json({'unread': 0});
      }
      return _json({
        'unread': 2,
        'notices': [
          {
            'id': 2,
            'kind': 'payment',
            'title': 'បានទទួលប្រាក់ · Order PS-ABC123',
            'body': 'ហាងបានទទួលការបង់ប្រាក់របស់អ្នក \$999.00',
            'order_id': 5,
            'read_at': null,
            'created_at': DateTime.now().toUtc().toIso8601String(),
          },
          {
            'id': 1,
            'kind': 'order',
            'title': 'Order PS-ABC123',
            'body': 'ឥវ៉ាន់របស់អ្នកកំពុងដឹកជញ្ជូនមក (J&T)',
            'order_id': 5,
            'read_at': null,
            'created_at': DateTime.now()
                .subtract(const Duration(hours: 3))
                .toUtc()
                .toIso8601String(),
          },
        ],
      });
    });

    await http.runWithClient(() async {
      await Notices.instance.refresh();
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(appBar: null, body: NoticesButton())),
      );
      expect(find.text('2'), findsOneWidget); // badge

      await tester.tap(find.byType(NoticesButton));
      await tester.pumpAndSettle();
      expect(find.text('បានទទួលប្រាក់ · Order PS-ABC123'), findsOneWidget);
      expect(find.textContaining('J&T'), findsOneWidget);
      expect(find.text('3 ម៉ោងមុន'), findsOneWidget);
    }, () => mock);

    expect(readCalled, isTrue);
    expect(Notices.instance.unread, 0);
  });

  test('staff and admins have no customer 🔔', () async {
    ApiService.token = 'test';
    ApiService.currentUser = User(
      id: 1,
      name: 'Boss',
      email: 'b@e.com',
      role: 'admin',
    );
    var asked = false;
    await http.runWithClient(
      () async {
        await Notices.instance.refresh();
      },
      () => MockClient((_) async {
        asked = true;
        return _json({});
      }),
    );
    expect(asked, isFalse);
  });
}
