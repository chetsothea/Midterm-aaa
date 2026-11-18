import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'common.dart';
import '../hooks/language.dart';
import 'motion.dart';
import '../theme/app_theme.dart';

// Small UX building blocks used across the store: loading skeletons, empty /
// error states with a way out, haptic taps, a back-to-top button and numbers
// that count to their new value.

Color get _navy => AppColors.text;
const _teal = Color(0xFF3D7BFF);

// A light tap felt through the phone, for actions that succeeded.
// Silently does nothing where there is no vibration (web, desktop).
class Haptics {
  static void tap() => HapticFeedback.selectionClick();
  static void success() => HapticFeedback.lightImpact();
  static void warning() => HapticFeedback.mediumImpact();
}

// A band of light that keeps sweeping over grey placeholder shapes, so the
// page shows what is coming instead of a lone spinner.
class Shimmer extends StatefulWidget {
  final Widget child;

  const Shimmer({super.key, required this.child});

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.loops(context)) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!Motion.loops(context)) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = _controller.value * 2 - 0.5; // -0.5 .. 1.5
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.line, AppColors.surface, AppColors.line],
            stops: [
              (t - 0.25).clamp(0.0, 1.0),
              t.clamp(0.0, 1.0),
              (t + 0.25).clamp(0.0, 1.0),
            ],
          ).createShader(bounds),
          child: child,
        );
      },
    );
  }
}

// One grey block of a skeleton
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.line,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

// The store page while the phones load: banner, brand circles and cards in
// the same places they will appear, so nothing jumps when the data lands.
class StoreSkeleton extends StatelessWidget {
  const StoreSkeleton({super.key});

  Widget _card() => Container(
    decoration: BoxDecoration(
      color: AppColors.glass,
      borderRadius: BorderRadius.circular(18),
    ),
    padding: const EdgeInsets.all(10),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: SkeletonBox(height: double.infinity, radius: 12)),
        SizedBox(height: AppSpacing.sm),
        SkeletonBox(height: 14),
        SizedBox(height: 6),
        SkeletonBox(width: 90, height: 14),
        SizedBox(height: 10),
        SkeletonBox(width: 70, height: 18),
        SizedBox(height: AppSpacing.sm),
        SkeletonBox(height: 36),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: Shimmer(
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          children: [
            const AspectRatio(
              aspectRatio: 2,
              child: SkeletonBox(height: double.infinity, radius: 18),
            ),
            const SizedBox(height: AppSpacing.md),
            // As many brand circles as fit the width, never overflowing
            SizedBox(
              height: 58,
              child: ClipRect(
                child: Wrap(
                  spacing: 22,
                  clipBehavior: Clip.hardEdge,
                  children: [
                    for (var i = 0; i < 6; i++)
                      const SkeletonBox(width: 58, height: 58, radius: 29),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            const SkeletonBox(width: 180, height: 20),
            const SizedBox(height: 14),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.58,
              children: [for (var i = 0; i < 4; i++) _card()],
            ),
          ],
        ),
      ),
    );
  }
}

// A friendly full-page message for "nothing here" and "something went
// wrong": a floating icon, what happened, and a button to get out of it.
class StatusView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final IconData actionIcon;
  final VoidCallback? onAction;
  final bool error;

  const StatusView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.actionIcon = Icons.refresh_rounded,
    this.onAction,
    this.error = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = error
        ? const [Color(0xFFFB7185), Color(0xFFFF453A)]
        : const [Color(0xFF38BDF8), _teal];
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: PopIn(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Floating(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: colors,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors.last.withValues(alpha: 0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(icon, size: 46, color: Colors.white),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _navy,
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.muted,
                  ),
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppSpacing.lg),
                PressScale(
                  child: FilledButton.icon(
                    onPressed: () {
                      Haptics.tap();
                      onAction!();
                    },
                    icon: Icon(actionIcon),
                    label: Text(actionLabel!),
                    style: FilledButton.styleFrom(
                      backgroundColor: error ? colors.last : _teal,
                      minimumSize: const Size(160, 48),
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Springs [child] (a badge) bigger and back whenever [value] goes up, so the
// customer sees the cart take the phone.
class BumpOnChange extends StatefulWidget {
  final int value;
  final Widget child;

  const BumpOnChange({super.key, required this.value, required this.child});

  @override
  State<BumpOnChange> createState() => _BumpOnChangeState();
}

class _BumpOnChangeState extends State<BumpOnChange>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );

  @override
  void didUpdateWidget(BumpOnChange old) {
    super.didUpdateWidget(old);
    if (widget.value > old.value && !Motion.off(context)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        if (!_controller.isAnimating) return child!;
        // Up to 1.35x, then an elastic settle; a slight wiggle on the way
        final t = _controller.value;
        final scale = 1 + 0.35 * Curves.elasticOut.transform(1 - t) * (1 - t);
        return Transform.rotate(
          angle: 0.25 * (1 - t) * (t < 0.5 ? 1 : -1) * (1 - t),
          child: Transform.scale(scale: scale, child: child),
        );
      },
    );
  }
}

// A round "back to top" button that rises in once the customer has scrolled
// a long way down, and sinks away near the top.
class BackToTop extends StatelessWidget {
  final ScrollController controller;
  final double showAfter;

  const BackToTop({super.key, required this.controller, this.showAfter = 700});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        final visible = controller.hasClients && controller.offset > showAfter;
        return IgnorePointer(
          ignoring: !visible,
          child: AnimatedSlide(
            offset: visible ? Offset.zero : const Offset(0, 1.6),
            duration: Motion.medium,
            curve: visible ? Motion.spring : Curves.easeIn,
            child: AnimatedOpacity(
              opacity: visible ? 1 : 0,
              duration: Motion.fast,
              child: child,
            ),
          ),
        );
      },
      child: PressScale(
        child: Tooltip(
          message: 'Back to top',
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            elevation: 8,
            shadowColor: AppColors.shadowStrong,
            child: Ink(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_navy, _teal],
                ),
              ),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () {
                  Haptics.tap();
                  controller.animateTo(
                    0,
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                  );
                },
                child: const Icon(
                  Icons.keyboard_arrow_up_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// A price that counts from its last value to the new one (e.g. picking a
// bigger storage size), instead of snapping. Shows the final number straight
// away in tests and when animations are off.
class CountUpMoney extends StatefulWidget {
  final double value;
  final TextStyle? style;

  const CountUpMoney(this.value, {super.key, this.style});

  @override
  State<CountUpMoney> createState() => _CountUpMoneyState();
}

class _CountUpMoneyState extends State<CountUpMoney> {
  late double _from = widget.value;

  @override
  void didUpdateWidget(CountUpMoney old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _from = old.value;
  }

  @override
  Widget build(BuildContext context) {
    if (!Motion.loops(context) || _from == widget.value) {
      return Text(money(widget.value), style: widget.style);
    }
    return TweenAnimationBuilder<double>(
      key: ValueKey(widget.value),
      tween: Tween(begin: _from, end: widget.value),
      duration: Motion.slow,
      curve: Curves.easeOutCubic,
      onEnd: () => _from = widget.value,
      builder: (context, v, _) => Text(money(v), style: widget.style),
    );
  }
}

// Rows of placeholder cards (picture on the left, lines of text) while a list
// such as the orders or favourites loads.
class ListSkeleton extends StatelessWidget {
  final int rows;

  const ListSkeleton({super.key, this.rows = 4});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: Shimmer(
        child: ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.sm),
          itemCount: rows,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (_, _) => Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.glass,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Row(
              children: [
                SkeletonBox(width: 72, height: 72, radius: 14),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(height: 14),
                      SizedBox(height: AppSpacing.xs),
                      SkeletonBox(width: 120, height: 12),
                      SizedBox(height: 14),
                      SkeletonBox(width: 80, height: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// A glass card whose body folds open and shut under its title, with a chevron
// that turns. Used for the detail page's specs and description.
class ExpandableSection extends StatefulWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final bool initiallyExpanded;

  const ExpandableSection({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.initiallyExpanded = true,
  });

  @override
  State<ExpandableSection> createState() => _ExpandableSectionState();
}

class _ExpandableSectionState extends State<ExpandableSection> {
  late bool _open = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final duration = Motion.off(context) ? Duration.zero : Motion.medium;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: Border.all(color: AppColors.glassEdge),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () {
              Haptics.tap();
              setState(() => _open = !_open);
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  Icon(widget.icon, size: 20, color: AppColors.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: duration,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _open
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: widget.child,
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

// Instead of a spinner while a button's action runs (placing an order,
// paying, saving): the button turns into a softly shimmering bar that says
// what is happening.
class BusyBar extends StatelessWidget {
  final String? label;
  final double height;

  const BusyBar({super.key, this.label, this.height = 50});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label ?? 'Working',
      child: Stack(
        alignment: Alignment.center,
        children: [
          Shimmer(
            child: Container(
              height: height,
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
            ),
          ),
          Text(
            label ?? trf('កំពុងដំណើរការ...', 'Working...'),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textSoft,
            ),
          ),
        ],
      ),
    );
  }
}

// Three dots that bounce one after another: the small "busy" sign inside a
// button or field, in place of a spinner. Still dots when animations are off.
class DotsLoader extends StatefulWidget {
  final Color? color;
  final double size;

  const DotsLoader({super.key, this.color, this.size = 7});

  @override
  State<DotsLoader> createState() => _DotsLoaderState();
}

class _DotsLoaderState extends State<DotsLoader>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.loops(context)) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.accent;
    return Semantics(
      label: 'Loading',
      // Shrinks to fit whatever small box it is put in
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) SizedBox(width: widget.size * 0.6),
                Transform.translate(
                  // Each dot rises a third of a beat after the one before
                  offset: Offset(
                    0,
                    -widget.size *
                        0.7 *
                        (0.5 -
                                0.5 *
                                    math.cos(
                                      2 * math.pi * (_controller.value - i / 3),
                                    ))
                            .clamp(0.0, 1.0),
                  ),
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
