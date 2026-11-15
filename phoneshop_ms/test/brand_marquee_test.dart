import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phoneshop_ms/widgets/brand_row.dart';

const brands = ['Apple', 'HONOR', 'OPPO', 'Samsung', 'Vivo', 'Xiaomi'];

void main() {
  setUp(() => BrandRow.autoScroll = true);
  tearDown(() => BrandRow.autoScroll = false);

  Future<void> pumpRow(WidgetTester tester, double width) async {
    await tester.binding.setSurfaceSize(Size(width, 200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BrandRow(brands: brands, onSelected: (_) {}),
        ),
      ),
    );
  }

  double offset(WidgetTester tester) =>
      tester.widget<ListView>(find.byType(ListView)).controller!.offset;

  testWidgets('brands that do not fit drift along and wrap around', (
    tester,
  ) async {
    await pumpRow(tester, 320);
    await tester.pump(); // the drift starts after the first frame
    await tester.pump(const Duration(seconds: 1));
    final first = offset(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(offset(tester), greaterThan(first)); // still moving

    // Far along, the brands are still there: the row never runs out
    await tester.pump(const Duration(seconds: 30));
    expect(find.text('Apple'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a finger on the row pauses it', (tester) async {
    await pumpRow(tester, 320);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final gesture = await tester.startGesture(const Offset(160, 40));
    final held = offset(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(offset(tester), held);
    await gesture.up();
  });

  testWidgets('brands that fit stand still', (tester) async {
    await pumpRow(tester, 900);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(offset(tester), 0);
    await tester.pumpAndSettle(); // nothing left moving
  });
}
