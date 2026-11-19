import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phoneshop_ms/data/models/user.dart';
import 'package:phoneshop_ms/screens/account_screen.dart';
import 'package:phoneshop_ms/data/api_service.dart';
import 'package:phoneshop_ms/hooks/language.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => AppLanguage.instance.setEnglish(false));

  testWidgets('the account page fits a small phone and switches language', (
    tester,
  ) async {
    // Narrow phone; tall enough to build the whole page (privacy and delete
    // account sit above Logout)
    await tester.binding.setSurfaceSize(const Size(320, 2000));
    addTearDown(() {
      tester.binding.setSurfaceSize(null);
      ApiService.token = null;
      ApiService.currentUser = null;
    });
    ApiService.token = 'test-token';
    ApiService.currentUser = User.fromJson({
      'id': 1,
      'name': 'Dara',
      'email': 'dara@example.com',
      'phone': '012345678',
      'address': 'ភូមិ ១, ខេត្តកោះកុង, កម្ពុជា',
      'role': 'user',
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: AccountScreen()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('ការកំណត់'), findsOneWidget);
      expect(find.text('PS168 • v1.0.0'), findsOneWidget);

      await tester.tap(find.text('EN'));
      await tester.pump();
      expect(AppLanguage.instance.isEnglish, isTrue);
    }, () => MockClient((_) async => http.Response('[]', 200)));
  });

  testWidgets('logout goes back to the store, not to a guest page', (
    tester,
  ) async {
    addTearDown(() {
      ApiService.token = null;
      ApiService.currentUser = null;
    });
    ApiService.token = 'test-token';
    ApiService.currentUser = User.fromJson({
      'id': 1,
      'name': 'Dara',
      'email': 'dara@example.com',
      'role': 'user',
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AccountScreen()),
                ),
                child: const Text('store'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('store'));
      await tester.pumpAndSettle();
      expect(find.text('Dara'), findsOneWidget);

      // Further down the page now: scroll to it
      await tester.scrollUntilVisible(find.text('Logout'), 200);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Logout'));
      await tester.pumpAndSettle();
      // It asks first; the red button confirms
      await tester.tap(find.widgetWithText(FilledButton, 'Logout'));
      await tester.pumpAndSettle();

      expect(find.text('Guest'), findsNothing);
      expect(find.byType(AccountScreen), findsNothing);
      expect(find.text('store'), findsOneWidget);
      expect(ApiService.isLoggedIn, isFalse);
    }, () => MockClient((_) async => http.Response(jsonEncode({}), 200)));
  });
}
