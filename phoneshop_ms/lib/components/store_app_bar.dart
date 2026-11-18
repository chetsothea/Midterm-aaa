import 'package:flutter/material.dart';
import 'effects.dart';
import '../theme/app_theme.dart';

// The store's top bar: a moving navy / teal aurora, rounded bottom corners and a soft shadow,
// so pages opened from the home page look like part of the same shop.
AppBar storeAppBar({required Widget title, List<Widget>? actions}) {
  return AppBar(
    foregroundColor: Colors.white,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
    ),
    // A living aurora (navy, teal, indigo) drifting behind the title
    flexibleSpace: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            blurRadius: 14,
            color: AppColors.shadow,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: AuroraBackground(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
      ),
    ),
    // The bar's title style replaces the theme's, so it names the Khmer font
    titleTextStyle: const TextStyle(
      fontFamily: appFontFamily,
      color: Colors.white,
      fontSize: 20,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.3,
    ),
    title: title,
    actions: actions,
  );
}
