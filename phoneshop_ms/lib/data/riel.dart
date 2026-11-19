import 'package:flutter/foundation.dart';

// Riel next to dollars: "≈ ៛4,100,000". The rate comes from the shop (/menu);
// 0 means the shop doesn't want riel shown.
class Riel {
  Riel._();

  static final rate = ValueNotifier<int>(4100);

  static bool get shown => rate.value > 0;

  // Rounded to 100 riel, the smallest note in use
  static String of(double usd) {
    final riel = ((usd * rate.value) / 100).round() * 100;
    final digits = riel.toString();
    final out = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
      out.write(digits[i]);
    }
    return '៛$out';
  }
}
