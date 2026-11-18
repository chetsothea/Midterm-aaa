import 'package:flutter/material.dart';

// "PS168" set in type: "PS" in white and "168" in the gold of the logo's bag,
// so the name matches the icon. Drawn as text, so it stays sharp at any size.
class BrandWordmark extends StatelessWidget {
  final double height; // roughly the height of the capital letters

  const BrandWordmark({super.key, required this.height});

  static const gold = [Color(0xFFFCD34D), Color(0xFFF59E0B), Color(0xFF3D7BFF)];

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: height * 1.3,
      height: 1,
      fontWeight: FontWeight.w900,
      letterSpacing: height * 0.06,
      color: Colors.white,
      shadows: [
        Shadow(
          color: Colors.black.withValues(alpha: 0.25),
          blurRadius: height * 0.3,
          offset: Offset(0, height * 0.08),
        ),
      ],
    );
    return Semantics(
      label: 'PS168',
      excludeSemantics: true,
      // Shrinks rather than overflowing where there's little room
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('PS', style: style),
            // The number in a top-to-bottom gold blend
            ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (rect) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: gold,
              ).createShader(rect),
              child: Text('168', style: style),
            ),
          ],
        ),
      ),
    );
  }
}
