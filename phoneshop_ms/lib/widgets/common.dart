import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/cart.dart';
import '../services/language.dart';

String money(double value) => '\$${value.toStringAsFixed(2)}';

// Read each time, so it follows the chosen language
Map<String, String> get orderStatusLabels => {
  'pending': tr('រង់ចាំ'),
  'confirmed': tr('បានបញ្ជាក់'),
  'shipping': tr('កំពុងដឹក'),
  'delivered': tr('បានទទួល'),
  'cancelled': tr('បានបោះបង់'),
};

// Read each time, so it follows the chosen language
Map<String, String> get paymentStatusLabels => {
  'unpaid': tr('មិនទាន់បង់'),
  'verifying': tr('កំពុងផ្ទៀងផ្ទាត់'),
  'paid': tr('បានបង់'),
};

// Read each time, so it follows the chosen language
Map<String, String> get paymentMethodLabels => {
  'cod': tr('បង់ពេលទទួល (COD)'),
  'khqr': tr('KHQR / ផ្ទេរប្រាក់'),
};

Color statusColor(String status) {
  switch (status) {
    case 'paid':
    case 'delivered':
      return Colors.green;
    case 'verifying':
    case 'confirmed':
      return Colors.blue;
    case 'shipping':
      return Colors.purple;
    case 'cancelled':
    case 'unpaid':
      return Colors.red;
    default:
      return Colors.orange;
  }
}

class StatusBadge extends StatelessWidget {
  final String status;
  final String label;

  const StatusBadge({super.key, required this.status, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// The customer's picture, or the first letter of their name when they have none
class UserAvatar extends StatelessWidget {
  final User user;
  final double radius;

  const UserAvatar({super.key, required this.user, this.radius = 40});

  @override
  Widget build(BuildContext context) {
    final letter = CircleAvatar(
      radius: radius,
      child: Text(
        user.name.characters.first.toUpperCase(),
        style: TextStyle(fontSize: radius * 0.8),
      ),
    );
    if (user.avatarUrl.isEmpty) return letter;
    return ClipOval(
      child: Image.network(
        user.avatarUrl,
        // On Web, fall back to a plain <img> tag so images from the API load without CORS headers
        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => letter,
      ),
    );
  }
}

class PhoneImage extends StatelessWidget {
  final String url;
  final double size;

  const PhoneImage({super.key, required this.url, this.size = 50});

  @override
  Widget build(BuildContext context) {
    final placeholder = Icon(
      Icons.phone_android,
      size: size * 0.7,
      color: Colors.grey,
    );
    if (url.isEmpty) {
      return SizedBox(width: size, height: size, child: placeholder);
    }
    return Image.network(
      url,
      // On Web, fall back to a plain <img> tag so images from the API load without CORS headers
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) =>
          SizedBox(width: size, height: size, child: placeholder),
    );
  }
}

// Best guess at a swatch for a colour name like "Natural Titanium" or "Midnight Black".
// Unknown names get a light grey dot (the name is always shown next to it).
Color swatchFor(String name) {
  const swatches = {
    'black': Color(0xFF1F1F1F),
    'midnight': Color(0xFF1E2430),
    'graphite': Color(0xFF41424C),
    'white': Color(0xFFF7F7F7),
    'starlight': Color(0xFFF2EBDD),
    'natural': Color(0xFFBDB6AA),
    'titanium': Color(0xFF8E8C88),
    'silver': Color(0xFFD9D9DE),
    'glacier': Color(0xFFB9D3E8), // Apple's light icy blue
    'gray': Color(0xFF8A8A8E),
    'grey': Color(0xFF8A8A8E),
    'navy': Color(0xFF1F2F5A),
    'blue': Color(0xFF3B6FD8),
    'green': Color(0xFF3E8E5E),
    'mint': Color(0xFF9FD8C3),
    'purple': Color(0xFF8E6CC9),
    'violet': Color(0xFF8E6CC9),
    'pink': Color(0xFFF2A7C3),
    'red': Color(0xFFD32F2F),
    'gold': Color(0xFFD4B26A),
    'yellow': Color(0xFFF5D547),
    'orange': Color(0xFFF28C38),
    'cream': Color(0xFFF1E6CF),
  };
  final lower = name.toLowerCase();
  for (final entry in swatches.entries) {
    if (lower.contains(entry.key)) return entry.value;
  }
  return const Color(0xFFE0E0E0);
}

class ColorDot extends StatelessWidget {
  final String color;
  final double size;

  const ColorDot({super.key, required this.color, this.size = 14});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: swatchFor(color),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black26),
      ),
    );
  }
}

// "● Black" — the colour a customer picked, in cart / checkout / order lists
class ColorLabel extends StatelessWidget {
  final String color;

  const ColorLabel({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ColorDot(color: color, size: 12),
        const SizedBox(width: 4),
        Flexible(child: Text(color, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}

// "● Blue · 512GB" — what the customer picked for a cart line
class CartOptionsLabel extends StatelessWidget {
  final CartItem item;

  const CartOptionsLabel({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (item.color.isNotEmpty) ...[
          ColorDot(color: item.color, size: 12),
          const SizedBox(width: 4),
        ],
        Flexible(child: Text(item.options, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}

// A small rounded card that floats above the page (and its bottom buttons), in the
// shop's colours, instead of a flat dark bar across the screen
// A short message that pops up in the middle of the screen: ✓ when something worked,
// ⚠ for an error, and 👆 for a hint ([info]) such as "please choose a colour".
// It grows in with a little bounce, stays a moment, then fades away by itself.
// Taps pass straight through it, so it never gets in the way.
void showMessage(
  BuildContext context,
  String message, {
  bool error = false,
  bool info = false,
}) {
  // The icon's circle: green for done, amber for a hint, red for an error
  final (Color background, IconData icon, Color iconColor) = error
      ? (
          const Color(0xFFF87171),
          Icons.priority_high_rounded,
          const Color(0xFFDC2626),
        )
      : info
      ? (
          const Color(0xFFFBBF24),
          Icons.touch_app_rounded,
          const Color(0xFFF97316),
        )
      : (const Color(0xFF34D399), Icons.check_rounded, const Color(0xFF059669));
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  // A new message replaces the one on screen at once
  _currentMessage?.remove();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _CenterMessage(
      message: message,
      icon: icon,
      iconColor: iconColor,
      background: background,
      onDone: () {
        if (_currentMessage == entry) _currentMessage = null;
        if (entry.mounted) entry.remove();
      },
    ),
  );
  _currentMessage = entry;
  overlay.insert(entry);
}

OverlayEntry? _currentMessage;

class _CenterMessage extends StatefulWidget {
  final String message;
  final IconData icon;
  final Color iconColor;
  final Color background;
  final VoidCallback onDone;

  const _CenterMessage({
    required this.message,
    required this.icon,
    required this.iconColor,
    required this.background,
    required this.onDone,
  });

  @override
  State<_CenterMessage> createState() => _CenterMessageState();
}

class _CenterMessageState extends State<_CenterMessage>
    with TickerProviderStateMixin {
  // Comes in (with the icon popping just after the card), stays still for a
  // moment, then goes out. Standing still isn't an animation, so the screen settles.
  late final _in = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  )..forward();
  late final _out = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );
  late final Timer _stay = Timer(const Duration(milliseconds: 1900), () {
    if (mounted) _out.forward().whenComplete(widget.onDone);
  });

  // Grows in with a small overshoot
  late final _grow = CurvedAnimation(
    parent: _in,
    curve: const Interval(0, 0.55, curve: Curves.easeOutBack),
  );
  late final _pop = CurvedAnimation(
    parent: _in,
    curve: const Interval(0.2, 1, curve: Curves.elasticOut),
  );
  // Fades away, drifting up a little
  late final _leave = CurvedAnimation(parent: _out, curve: Curves.easeIn);
  late final _controller = Listenable.merge([_in, _out]);

  @override
  void initState() {
    super.initState();
    _stay; // start counting
  }

  @override
  void dispose() {
    _stay.cancel(); // gone early (replaced, or the app closed)
    _in.dispose();
    _out.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final shown = (_grow.value.clamp(0.0, 1.0)) * (1 - _leave.value);
          return Stack(
            children: [
              // A light dim over the page, so the card stands out without hiding it
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.12 * shown),
                ),
              ),
              Center(
                child: Opacity(
                  opacity: shown.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(
                      0,
                      24 * (1 - _grow.value) - 12 * _leave.value,
                    ),
                    child: Transform.scale(
                      scale: 0.85 + 0.15 * _grow.value,
                      child: child,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 260),
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: widget.iconColor.withValues(alpha: 0.25),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
                const BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: _pop,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [widget.background, widget.iconColor],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.iconColor.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(widget.icon, color: Colors.white, size: 32),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  widget.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF0F2A5F),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
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
