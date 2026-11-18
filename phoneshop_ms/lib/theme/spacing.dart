// Spacing and corner sizes on a 4-point grid, so gaps and roundness stay
// consistent across every screen. Use these instead of raw numbers:
//   EdgeInsets.all(AppSpacing.md), SizedBox(height: AppSpacing.sm),
//   BorderRadius.circular(AppRadius.xl)
class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;

  // The usual gap at the left and right of a page
  static const double page = md;
}

class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16; // buttons, fields
  static const double xl = 20;
  static const double xxl = 24; // cards, glass panels
  static const double sheet = 28; // dialogs, bottom sheets
  static const double pill = 999;
}

// How long motion lasts (see components/motion.dart for the shared curves)
class AppDuration {
  static const fast = Duration(milliseconds: 180);
  static const medium = Duration(milliseconds: 320);
  static const slow = Duration(milliseconds: 520);
}
