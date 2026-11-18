import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phoneshop_ms/data/models/user.dart';
import 'package:phoneshop_ms/screens/account_screen.dart';
import 'package:phoneshop_ms/data/api_service.dart';

void main() {
  setUp(() {
    ApiService.token = 'test';
    ApiService.currentUser = User(
      id: 2,
      name: 'Thea',
      email: 'thea@gmail.com',
      phone: '098374883',
      address: 'ភ្នំពេញ',
      role: 'user',
    );
  });

  tearDown(() {
    ApiService.token = null;
    ApiService.currentUser = null;
  });

  Future<void> openEdit(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: AccountScreen()));
    await tester.tap(find.text('កែព័ត៌មាន'));
    await tester.pumpAndSettle();
  }

  testWidgets('the customer edits their details and the account page updates', (
    tester,
  ) async {
    final mock = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'id': 2,
          'name': 'Thea Sok',
          'email': 'thea@gmail.com',
          'phone': '012345678',
          'address': 'ភ្នំពេញ',
          'role': 'user',
          'avatar_url': '',
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    await http.runWithClient(() async {
      await openEdit(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'ឈ្មោះ *'),
        'Thea Sok',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'លេខទូរស័ព្ទ *'),
        '012345678',
      );
      await tester.tap(find.text('រក្សាទុក'));
      await tester.pumpAndSettle();
    }, () => mock);

    expect(ApiService.currentUser!.name, 'Thea Sok');
    expect(find.text('Thea Sok'), findsOneWidget); // back on the account page
    expect(find.text('012345678'), findsOneWidget);
  });

  testWidgets('a new email and password are sent, an empty password is not', (
    tester,
  ) async {
    final bodies = <String>[];
    final mock = MockClient((request) async {
      bodies.add(request.body);
      return http.Response(
        jsonEncode({
          'id': 2,
          'name': 'Thea',
          'email': 'new@gmail.com',
          'phone': '098374883',
          'address': 'ភ្នំពេញ',
          'role': 'user',
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    await http.runWithClient(() async {
      await openEdit(tester);
      await tester.tap(find.text('រក្សាទុក'));
      await tester.pumpAndSettle();
    }, () => mock);
    expect(bodies.last, isNot(contains('name="password"')));

    await http.runWithClient(() async {
      await openEdit(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email *'),
        'new@gmail.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'ពាក្យសម្ងាត់ថ្មី'),
        'abcdef',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'បញ្ជាក់ពាក្យសម្ងាត់ថ្មី'),
        'abcdef',
      );
      await tester.tap(find.text('រក្សាទុក'));
      await tester.pumpAndSettle();
    }, () => mock);
    expect(bodies.last, contains('name="password"'));
    expect(bodies.last, contains('new@gmail.com'));
    expect(ApiService.currentUser!.email, 'new@gmail.com');
  });

  testWidgets('name, email, phone and a mismatched password are all checked', (
    tester,
  ) async {
    await openEdit(tester);

    await tester.enterText(find.widgetWithText(TextFormField, 'ឈ្មោះ *'), ' ');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email *'),
      'nope',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'លេខទូរស័ព្ទ *'),
      '12',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'ពាក្យសម្ងាត់ថ្មី'),
      'abcdef',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'បញ្ជាក់ពាក្យសម្ងាត់ថ្មី'),
      'abcxyz',
    );
    await tester.ensureVisible(find.text('រក្សាទុក'));
    await tester.tap(find.text('រក្សាទុក'));
    await tester.pump();

    expect(find.text('សូមបញ្ចូលឈ្មោះ'), findsOneWidget);
    expect(find.text('Email មិនត្រឹមត្រូវ'), findsOneWidget);
    expect(find.text('លេខទូរស័ព្ទមិនត្រឹមត្រូវ'), findsOneWidget);
    expect(find.text('ពាក្យសម្ងាត់មិនដូចគ្នា'), findsOneWidget);
  });
}
