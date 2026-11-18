import 'package:flutter/material.dart';

// One font family for Khmer and Latin (bundled in assets/fonts) and the
// type scale: large, bold, tightly spaced headings; calm body text.
const appFontFamily = 'KantumruyPro';

class AppText {
  static const display = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.8,
  );
  static const headline = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
  );
  static const title = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.4,
  );
  static const subtitle = TextStyle(fontSize: 17, fontWeight: FontWeight.w700);
  static const body = TextStyle(fontSize: 15, height: 1.5);
  static const bodySmall = TextStyle(fontSize: 13, height: 1.45);
  static const label = TextStyle(fontSize: 12, fontWeight: FontWeight.w700);
  static const caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
  );
}
