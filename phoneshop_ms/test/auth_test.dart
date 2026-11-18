import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phoneshop_ms/data/google_auth.dart';
import 'package:phoneshop_ms/screens/login_screen.dart';
import 'package:phoneshop_ms/screens/register_screen.dart';
import 'package:phoneshop_ms/components/auth_ui.dart';

void main() {
  testWidgets(
    'login asks for email and password, and the eye shows the password',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      // Let the card finish swinging in (3D entrance) before tapping on it
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('ចូលគណនីរបស់អ្នក'), findsOneWidget);
      await tester.ensureVisible(find.text('ចូល'));
      await tester.tap(find.text('ចូល'));
      await tester.pump();
      expect(find.text('សូមបញ្ចូល Email ឬឈ្មោះអ្នកប្រើ'), findsOneWidget);
      expect(find.text('សូមបញ្ចូលពាក្យសម្ងាត់'), findsOneWidget);

      EditableText password() => tester.widget<EditableText>(
        find.descendant(
          of: find.widgetWithText(TextFormField, 'បញ្ចូលពាក្យសម្ងាត់'),
          matching: find.byType(EditableText),
        ),
      );
      // The labels stay visible above the fields, not only as hints inside them
      expect(find.text('Email ឬឈ្មោះអ្នកប្រើ'), findsOneWidget);
      expect(find.text('ពាក្យសម្ងាត់'), findsOneWidget);
      expect(password().obscureText, isTrue);
      await tester.tap(find.byTooltip('Show password'));
      await tester.pump();
      expect(password().obscureText, isFalse);
    },
  );

  testWidgets(
    'on a normal phone the whole login card fits, Google button included',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(380, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      GoogleAuth.reset();
      await http.runWithClient(
        () async {
          await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
          await tester.pumpAndSettle();
        },
        () => MockClient((_) async => http.Response('{"client_id":null}', 200)),
      );

      expect(tester.takeException(), isNull);
      final google = tester.getRect(find.text('ចូលជាមួយ Google'));
      expect(google.bottom, lessThanOrEqualTo(800));
    },
  );

  testWidgets(
    '"Login with Google" is always shown and explains when it is not set up',
    (tester) async {
      GoogleAuth.reset();
      // The API answers that no GOOGLE_CLIENT_ID is set
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
        await tester.pumpAndSettle();

        expect(find.text('ឬបន្តជាមួយ'), findsOneWidget);
        expect(find.text('ចូលជាមួយ Google'), findsOneWidget);

        // Tapping explains instead of doing nothing
        await tester.ensureVisible(find.text('ចូលជាមួយ Google'));
        await tester.tap(find.text('ចូលជាមួយ Google'));
        await tester.pumpAndSettle();
        expect(find.textContaining('GOOGLE_CLIENT_ID'), findsOneWidget);
      }, () => MockClient((_) async => http.Response('{"client_id":""}', 200)));
    },
  );

  testWidgets('"Create an account" opens the sign-up form', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.ensureVisible(find.text('បង្កើតគណនី'));
    await tester.tap(find.text('បង្កើតគណនី'));
    await tester.pumpAndSettle();
    expect(find.text('បង្កើតគណនីរបស់អ្នក'), findsOneWidget);
  });

  testWidgets('sign-up checks email, matching passwords and phone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(
      const Size(500, 2400),
    ); // whole form on screen
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'បញ្ចូល Email'),
      'not-an-email',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'បញ្ចូលពាក្យសម្ងាត់'),
      'secret123',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'វាយពាក្យសម្ងាត់ម្តងទៀត'),
      'secret999',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '+855 12 345 678'),
      '012',
    );
    await tester.tap(find.text('បង្កើតគណនី'));
    await tester.pump();

    expect(find.text('សូមបញ្ចូល Email ឱ្យត្រឹមត្រូវ'), findsOneWidget);
    expect(find.text('សូមជ្រើសឈ្មោះអ្នកប្រើ'), findsOneWidget);
    expect(find.text('ពាក្យសម្ងាត់មិនដូចគ្នា'), findsOneWidget);
    expect(find.text('សូមបញ្ចូលលេខទូរស័ព្ទឱ្យត្រឹមត្រូវ'), findsOneWidget);
    expect(find.text('សូមជ្រើសខេត្ត'), findsOneWidget); // address picker
  });

  test(
    'password strength: short is weak, letters+digits fair, long and mixed strong',
    () {
      expect(PasswordStrength.score(''), 0);
      expect(PasswordStrength.score('abc'), 1);
      expect(PasswordStrength.score('abc123'), 2);
      expect(PasswordStrength.score('Sothea2026!x'), 3);
    },
  );

  testWidgets(
    'register shows the strength while typing, and fits a small phone',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));
        await tester.pumpAndSettle();
      }, () => MockClient((_) async => http.Response('[]', 200)));

      expect(tester.takeException(), isNull);
      expect(find.text('ខ្សោយ'), findsNothing);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'បញ្ចូលពាក្យសម្ងាត់'),
        'abc',
      );
      await tester.pump();
      expect(find.text('ខ្សោយ'), findsOneWidget);
    },
  );
}
