import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phoneshop_ms/screens/avatar_crop_screen.dart';

// A tall 2x4 PNG: the top half is red and the bottom half is blue
Future<Uint8List> tallPicture() async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder)
    ..drawRect(const Rect.fromLTWH(0, 0, 2, 2), Paint()..color = const Color(0xFFFF0000))
    ..drawRect(const Rect.fromLTWH(0, 2, 2, 2), Paint()..color = const Color(0xFF0000FF));
  final image = await recorder.endRecording().toImage(2, 4);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  return png!.buffer.asUint8List();
}

void main() {
  group('which part of the picture is kept', () {
    const tall = Size(800, 1600);

    test('not moved or zoomed: the top of the picture, full width', () {
      expect(
        avatarCropRect(picture: tall, viewport: 400, scale: 1, offset: Offset.zero),
        const Rect.fromLTWH(0, 0, 800, 800),
      );
    });

    test('moved up by half the screen: further down the picture', () {
      expect(
        avatarCropRect(
          picture: tall,
          viewport: 400,
          scale: 1,
          offset: const Offset(0, -200),
        ),
        const Rect.fromLTWH(0, 400, 800, 800),
      );
    });

    test('zoomed in twice: a part half as wide', () {
      expect(
        avatarCropRect(
          picture: tall,
          viewport: 400,
          scale: 2,
          offset: const Offset(-200, -400),
        ),
        const Rect.fromLTWH(200, 400, 400, 400),
      );
    });

    test('a wide picture fills the height', () {
      expect(
        avatarCropRect(
          picture: const Size(1600, 800),
          viewport: 400,
          scale: 1,
          offset: Offset.zero,
        ),
        const Rect.fromLTWH(0, 0, 800, 800),
      );
    });
  });

  testWidgets('dragging picks the part of the picture that is saved', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final bytes = await tester.runAsync(tallPicture);

    Uint8List? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await Navigator.push<Uint8List>(
                context,
                MaterialPageRoute(
                  builder: (_) => AvatarCropScreen(bytes: bytes!),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();

    // Decoding needs real time
    await tester.runAsync(() async {
      for (var i = 0; i < 50 && !tester.any(find.byType(InteractiveViewer)); i++) {
        await Future.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
    });
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Drag the picture all the way down, so its top (red) fills the circle
    await tester.drag(find.byType(InteractiveViewer), const Offset(0, 800));
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('ប្រើរូបនេះ'));
    await tester.runAsync(() async {
      for (var i = 0; i < 50 && result == null; i++) {
        await Future.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();
    expect(result, isNotNull);

    // The saved picture is a 512px square, all from the top half
    final saved = await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(result!);
      final image = (await codec.getNextFrame()).image;
      final pixels = await image.toByteData();
      return (image.width, image.height, pixels!);
    });
    expect(saved!.$1, AvatarCropScreen.outputSize);
    expect(saved.$2, AvatarCropScreen.outputSize);
    expect(saved.$3.getUint8(0), greaterThan(200)); // top-left is red
    expect(saved.$3.getUint8(2), lessThan(50));
    expect(base64Encode(result!), isNotEmpty);
  });
}
