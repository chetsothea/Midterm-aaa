import 'package:flutter/material.dart';
import '../hooks/language.dart';
import 'language_switch.dart';
import 'motion.dart';
import 'brand_wordmark.dart';
import 'ux.dart';
import '../theme/app_theme.dart';

// Look shared by the Login and Create Account screens:
// the logo's navy-to-teal page, a white rounded card, soft pill fields and a gradient button.
const authAccent = Color(0xFF3D7BFF);
const _navy = Color(0xFF101318);
// The one accent, electric blue, on every main action (Login, Register…)
const _actionGradient = LinearGradient(
  colors: [Color(0xFF5B8CFF), Color(0xFF3D7BFF), Color(0xFF2F62D9)],
);
Color get _borderColor => AppColors.outline;
Color get _iconColor => AppColors.textSoft;
const _hintColor = Color(0xFF9CA3AF);

class AuthScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;

  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navy,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        // The language can be chosen before logging in
        actions: const [
          LanguageButton(color: Colors.white),
          SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_navy, authAccent],
              ),
            ),
          ),
          // Soft circles of light behind the card give the page some depth
          const Positioned(
            top: -90,
            right: -70,
            child: _Glow(size: 260, alpha: 0.08),
          ),
          const Positioned(
            top: 160,
            left: -60,
            child: _Glow(size: 140, alpha: 0.06),
          ),
          const Positioned(
            bottom: -120,
            left: -80,
            child: _Glow(size: 320, alpha: 0.10, color: Color(0xFF22D3EE)),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Entrance(
                  child: Column(
                    children: [
                      // The app icon with a soft glow above the card, then the name
                      Container(
                        width: 84,
                        height: 84,
                        // A thin light edge, so the navy icon stands out
                        foregroundDecoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                          border: Border.all(color: Colors.white70, width: 2),
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                          boxShadow: const [
                            BoxShadow(blurRadius: 30, color: Color(0x6622D3EE)),
                          ],
                        ),
                        child: Image.asset('assets/images/logo.png'),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Shine(child: const BrandWordmark(height: 24)),
                      const SizedBox(height: 14),
                      _card(),
                      const SizedBox(height: 18),
                      const _Perks(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(AppRadius.sheet),
        boxShadow: const [
          BoxShadow(
            blurRadius: 32,
            color: Color(0x40000000),
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _navy,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.muted),
          ),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }
}

// Three small reasons to shop here, in a row under the card
class _Perks extends StatelessWidget {
  const _Perks();

  Widget _perk(IconData icon, String text) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFFFBBF24), size: 20),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _perk(
          Icons.verified_outlined,
          trf('ទូរស័ព្ទពិត ធានា', 'Genuine phones'),
        ),
        _perk(
          Icons.local_shipping_outlined,
          trf('ដឹកដល់ផ្ទះ', 'Home delivery'),
        ),
        _perk(Icons.qr_code_2, trf('បង់តាម KHQR', 'Pay by KHQR')),
      ],
    );
  }
}

// A soft round patch of light for the background
class _Glow extends StatelessWidget {
  final double size;
  final double alpha;
  final Color color;

  const _Glow({
    required this.size,
    required this.alpha,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: alpha),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

// Pill-shaped field with an icon, an optional label above it,
// and an eye button that shows/hides the text for passwords.
class AuthField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final String? label;
  final bool password;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onSubmitted;
  // Lets the phone's password manager fill the field in
  final Iterable<String>? autofillHints;
  // "Next" moves to the following field; "Done" on the last one
  final TextInputAction? textInputAction;

  const AuthField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.label,
    this.password = false,
    this.keyboardType,
    this.validator,
    this.onSubmitted,
    this.autofillHints,
    this.textInputAction,
  });

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  late bool _hidden = widget.password;

  OutlineInputBorder _border(Color color, [double width = 1.2]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide(color: color, width: width),
      );

  @override
  Widget build(BuildContext context) {
    final field = TextFormField(
      controller: widget.controller,
      obscureText: _hidden,
      // Capitals matter at login, so the phone's keyboard must not change what's typed
      autocorrect: false,
      keyboardType: widget.keyboardType,
      autofillHints: widget.autofillHints,
      textInputAction: widget.textInputAction,
      validator: widget.validator,
      onFieldSubmitted: widget.onSubmitted,
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.surface,
        hintText: widget.hint,
        hintStyle: const TextStyle(
          color: _hintColor,
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 12, right: 4),
          child: Icon(widget.icon, color: _iconColor),
        ),
        suffixIcon: widget.password
            ? IconButton(
                tooltip: _hidden ? 'Show password' : 'Hide password',
                icon: Icon(
                  _hidden
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: _iconColor,
                ),
                onPressed: () => setState(() {
                  _hidden = !_hidden;
                }),
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
        border: _border(_borderColor),
        enabledBorder: _border(_borderColor),
        focusedBorder: _border(authAccent, 1.8),
        errorBorder: _border(Colors.red),
        focusedErrorBorder: _border(Colors.red, 1.8),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: widget.label == null
          ? field
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    widget.label!,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                field,
              ],
            ),
    );
  }
}

class AuthButton extends StatelessWidget {
  final String text;
  final bool loading;
  final VoidCallback onPressed;

  const AuthButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: loading ? 0.7 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: _actionGradient,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40F97316),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: SizedBox(
          height: 50,
          child: FilledButton(
            onPressed: loading ? null : onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.transparent,
              disabledBackgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              textStyle: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: DotsLoader(color: Colors.white, size: 5),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(text),
                      const SizedBox(width: AppSpacing.xs),
                      const Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// "Don't have an account?  Create an account"
class AuthSwitchLink extends StatelessWidget {
  final String question;
  final String action;
  final VoidCallback onTap;

  const AuthSwitchLink({
    super.key,
    required this.question,
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(question, style: const TextStyle(fontSize: 15)),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(foregroundColor: authAccent),
          child: Text(
            action,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

// ───────── or continue with ─────────
class AuthDivider extends StatelessWidget {
  final String text;

  const AuthDivider({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0xFFB0B0B0))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, color: Color(0xFF444444)),
          ),
        ),
        const Expanded(child: Divider(color: Color(0xFFB0B0B0))),
      ],
    );
  }
}

// White pill button with Google's four-colour "G"
class GoogleButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const GoogleButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.text3,
          side: BorderSide(color: _borderColor, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => const SweepGradient(
                colors: [
                  Color(0xFFEA4335),
                  Color(0xFFFBBC05),
                  Color(0xFF34A853),
                  Color(0xFF4285F4),
                  Color(0xFFEA4335),
                ],
                stops: [0.0, 0.3, 0.55, 0.8, 1.0],
              ).createShader(bounds),
              child: const Text(
                'G',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Shrinks rather than running past the button on a narrow phone
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  tr('Login with Google'),
                  maxLines: 1,
                  style: const TextStyle(fontSize: 17),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Three bars under a new password: weak (red), fair (amber), strong (green),
// with the word next to them. Empty password: nothing shown.
class PasswordStrength extends StatelessWidget {
  final TextEditingController controller;

  const PasswordStrength({super.key, required this.controller});

  // 0 none, 1 weak, 2 fair, 3 strong
  static int score(String p) {
    if (p.isEmpty) return 0;
    var points = 0;
    if (p.length >= 6) points++;
    if (p.length >= 10) points++;
    if (RegExp(r'[0-9]').hasMatch(p) && RegExp(r'[A-Za-z]').hasMatch(p)) {
      points++;
    }
    if (RegExp(r'[A-Z]').hasMatch(p) || RegExp(r'[^A-Za-z0-9]').hasMatch(p)) {
      points++;
    }
    return points <= 1 ? 1 : (points == 2 ? 2 : 3);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final s = score(value.text);
        if (s == 0) return const SizedBox.shrink();
        const colors = [
          Color(0xFFFF453A),
          Color(0xFFF59E0B),
          Color(0xFF30D158),
        ];
        final labels = [
          trf('ខ្សោយ', 'Weak'),
          trf('មធ្យម', 'Fair'),
          trf('ខ្លាំង', 'Strong'),
        ];
        final color = colors[s - 1];
        return Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
          child: Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 5,
                    decoration: BoxDecoration(
                      color: i < s ? color : AppColors.line,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xxs),
              ],
              const SizedBox(width: AppSpacing.xxs),
              Text(
                labels[s - 1],
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
