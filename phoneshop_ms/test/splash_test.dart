import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phoneshop_ms/main.dart';
import 'package:phoneshop_ms/screens/home_screen.dart';
import 'package:phoneshop_ms/screens/splash_screen.dart';

void main() {
  testWidgets('the app opens on the launch screen, then goes to the store', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.byType(SplashScreen), findsOneWidget);
    // Already building underneath, so its phones load during the logo
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(
      find.image(const AssetImage('assets/images/logo.png')),
      findsOneWidget,
    );

    await tester.pump(SplashScreen.duration);
    await tester.pumpAndSettle();

    expect(find.image(const AssetImage('assets/images/logo.png')), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Back can't return to the launch screen: the store is the only page
    expect(Navigator.of(tester.element(find.byType(HomeScreen))).canPop(), isFalse);
  });

  testWidgets('it fits a small phone', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);

    await tester.pump(SplashScreen.duration);
    await tester.pumpAndSettle();
  });
}
