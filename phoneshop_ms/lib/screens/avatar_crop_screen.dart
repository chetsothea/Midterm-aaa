import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../components/ux.dart';
import '../theme/theme.dart';
import '../hooks/language.dart';

// Which part of the picture shows in a square [viewport], when the picture is laid out
// covering it, then zoomed by [scale] and moved by [offset]. In the picture's own pixels.
Rect avatarCropRect({
  required Size picture,
  required double viewport,
  required double scale,
  required Offset offset,
}) {
  final perPixel = viewport / min(picture.width, picture.height);
  final side = viewport / scale / perPixel;
  return Rect.fromLTWH(
    -offset.dx / scale / perPixel,
    -offset.dy / scale / perPixel,
    side,
    side,
  );
}

// The customer moves and zooms their picture inside a circle.
// Returns the chosen square as PNG bytes, or null when cancelled.
class AvatarCropScreen extends StatefulWidget {
  final Uint8List bytes;

  const AvatarCropScreen({super.key, required this.bytes});

  // Size of the saved picture
  static const outputSize = 512;

  @override
  State<AvatarCropScreen> createState() => _AvatarCropScreenState();
}

class _AvatarCropScreenState extends State<AvatarCropScreen> {
  static const _maxZoom = 4.0;

  final _transform = TransformationController();
  ui.Image? _picture;
  double _viewport = 0;
  bool _placed = false;
  bool _isSaving = false;

  double get _zoom => _transform.value.getMaxScaleOnAxis();

  @override
  void initState() {
    super.initState();
    _decode();
  }

  Future<void> _decode() async {
    try {
      final codec = await ui.instantiateImageCodec(widget.bytes);
      final picture = (await codec.getNextFrame()).image;
      if (mounted) {
        setState(() {
          _picture = picture;
        });
      } else {
        picture.dispose();
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('មិនអាចបើករូបនេះបានទេ សូមជ្រើសរូបផ្សេង'))),
      );
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _transform.dispose();
    _picture?.dispose();
    super.dispose();
  }

  Size get _pictureSize =>
      Size(_picture!.width.toDouble(), _picture!.height.toDouble());

  // The picture's size on screen before zooming: just big enough to cover the circle
  Size get _contentSize {
    final perPixel = _viewport / min(_pictureSize.width, _pictureSize.height);
    return _pictureSize * perPixel;
  }

  // Sets the zoom and position, never leaving a gap beside the picture
  void _place(double zoom, Offset centre) {
    final content = _contentSize * zoom;
    final x = (_viewport / 2 - centre.dx * zoom).clamp(
      _viewport - content.width,
      0.0,
    );
    final y = (_viewport / 2 - centre.dy * zoom).clamp(
      _viewport - content.height,
      0.0,
    );
    _transform.value = Matrix4.identity()
      ..translateByDouble(x, y, 0, 1)
      ..scaleByDouble(zoom, zoom, zoom, 1);
  }

  void _setZoom(double zoom) {
    final move = _transform.value.getTranslation();
    final old = _zoom;
    _place(
      zoom,
      Offset((_viewport / 2 - move.x) / old, (_viewport / 2 - move.y) / old),
    );
  }

  Future<void> _use() async {
    setState(() {
      _isSaving = true;
    });
    final move = _transform.value.getTranslation();
    final source = avatarCropRect(
      picture: _pictureSize,
      viewport: _viewport,
      scale: _zoom,
      offset: Offset(move.x, move.y),
    );
    const size = AvatarCropScreen.outputSize;
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawImageRect(
      _picture!,
      source,
      const Rect.fromLTWH(0, 0, size + 0.0, size + 0.0),
      Paint()..filterQuality = FilterQuality.high,
    );
    final cropped = await recorder.endRecording().toImage(size, size);
    final png = await cropped.toByteData(format: ui.ImageByteFormat.png);
    cropped.dispose();
    if (mounted) Navigator.pop(context, png!.buffer.asUint8List());
  }

  Widget _editor() {
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewport = min(constraints.maxWidth, 400.0);
        // First time: centred, like the picture shows without any adjusting
        if (!_placed) {
          _placed = true;
          final content = _contentSize;
          _transform.value = Matrix4.identity()
            ..translateByDouble(
              (_viewport - content.width) / 2,
              (_viewport - content.height) / 2,
              0,
              1,
            );
          // Only from here on: this first placement happens during a build.
          // Keeps the zoom slider following the customer's fingers.
          _transform.addListener(() => setState(() {}));
        }
        return Center(
          child: SizedBox.square(
            dimension: _viewport,
            child: Stack(
              children: [
                InteractiveViewer(
                  transformationController: _transform,
                  constrained: false,
                  minScale: 1,
                  maxScale: _maxZoom,
                  boundaryMargin: EdgeInsets.zero,
                  child: SizedBox.fromSize(
                    size: _contentSize,
                    child: RawImage(image: _picture, fit: BoxFit.fill),
                  ),
                ),
                IgnorePointer(
                  child: CustomPaint(
                    size: Size.square(_viewport),
                    painter: _CircleShade(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(tr('តម្រឹមរូប')),
      ),
      body: _picture == null
          ? const Shimmer(
              child: Center(
                child: SkeletonBox(width: 280, height: 280, radius: 140),
              ),
            )
          : Column(
              children: [
                Expanded(child: _editor()),
                Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    tr('អូសរូបដើម្បីតម្រឹម ហើយទាញខាងក្រោមដើម្បីពង្រីក'),
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.zoom_out, color: Colors.white70),
                      Expanded(
                        child: Slider(
                          min: 1,
                          max: _maxZoom,
                          value: _zoom.clamp(1.0, _maxZoom),
                          onChanged: _setZoom,
                        ),
                      ),
                      const Icon(Icons.zoom_in, color: Colors.white70),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: FilledButton(
            onPressed: _picture == null || _isSaving ? null : _use,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            child: Text(tr('ប្រើរូបនេះ')),
          ),
        ),
      ),
    );
  }
}

// Darkens everything outside the circle that will show as the customer's picture
class _CircleShade extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final whole = Offset.zero & size;
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(whole)
        ..addOval(whole),
      Paint()..color = Colors.black.withValues(alpha: 0.6),
    );
    canvas.drawOval(
      whole.deflate(1),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_CircleShade oldDelegate) => false;
}
