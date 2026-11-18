import 'package:flutter/material.dart';
import '../hooks/language.dart';
import '../hooks/theme_mode.dart';
import 'motion.dart';
import 'ux.dart';

// ☀️ / 🌙 in the top bar: one tap switches dark and light mode. The icon spins
// half a turn and swaps, and every screen redraws in the other colours in
// place (open pages and scroll positions stay).
class ThemeToggleButton extends StatelessWidget {
  final Color? color;

  const ThemeToggleButton({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppThemeMode.instance,
      builder: (context, _) {
        final dark = AppThemeMode.instance.isDark;
        return IconButton(
          // Says what a tap will do
          tooltip: dark
              ? trf('ប្តូរទៅពន្លឺ', 'Light mode')
              : trf('ប្តូរទៅងងឹត', 'Dark mode'),
          color: color,
          onPressed: () {
            Haptics.tap();
            AppThemeMode.instance.toggle();
          },
          icon: AnimatedSwitcher(
            duration: Motion.off(context) ? Duration.zero : Motion.slow,
            transitionBuilder: (child, animation) => RotationTransition(
              turns: Tween(begin: 0.5, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
              ),
              child: ScaleTransition(scale: animation, child: child),
            ),
            child: Icon(
              dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              key: ValueKey(dark),
            ),
          ),
        );
      },
    );
  }
}

// The same switch as a row in the side menu
class ThemeSwitchTile extends StatelessWidget {
  const ThemeSwitchTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppThemeMode.instance,
      builder: (context, _) {
        final dark = AppThemeMode.instance.isDark;
        return SwitchListTile(
          secondary: Icon(
            dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
          ),
          title: Text(trf('របៀបងងឹត', 'Dark mode')),
          value: dark,
          onChanged: (value) {
            Haptics.tap();
            AppThemeMode.instance.setDark(value);
          },
        );
      },
    );
  }
}
