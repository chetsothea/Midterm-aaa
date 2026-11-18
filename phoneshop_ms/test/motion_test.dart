import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phoneshop_ms/components/motion.dart';

void main() {
  testWidgets('the shine sweeps once, then the screen settles', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Center(child: Shine(child: Text('PS168')))),
    );

    await tester.pump(); // the animation clock starts on this frame
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byType(ShaderMask), findsOneWidget); // mid-sweep

    await tester.pumpAndSettle(); // would time out if it looped
    expect(find.byType(ShaderMask), findsNothing);

    // Tapping plays it again
    await tester.tap(find.text('PS168'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byType(ShaderMask), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('cards rise into place and end exactly where they belong', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Column(
          children: [
            Entrance(index: 0, child: SizedBox(height: 50, child: Text('a'))),
            Entrance(index: 3, child: SizedBox(height: 50, child: Text('b'))),
          ],
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final moving = tester.getTopLeft(find.text('b')).dy;

    await tester.pumpAndSettle();
    final end = tester.getTopLeft(find.text('b')).dy;
    expect(moving, greaterThan(end)); // it came up from below
    expect(end, 50); // right under the first card, nothing left over
  });

  testWidgets('nothing moves when the phone asks for no animations', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: Column(
            children: [
              Shine(child: Text('PS168')),
              Entrance(index: 2, child: Text('card')),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byType(ShaderMask), findsNothing);
    expect(find.byType(Opacity), findsNothing);
  });
}
