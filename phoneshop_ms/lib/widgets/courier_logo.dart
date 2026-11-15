import 'package:flutter/material.dart';

// Delivery companies the admin picks from. These are simple marks in each company's
// colour, not their official logo files; the shop's own delivery uses the PS168 logo.
const shopDelivery = 'ហាងដឹកផ្ទាល់';

const couriers = {
  'J&T Express': ('J&T', Color(0xFFE60012)),
  'VET Express': ('VET', Color(0xFFF59E0B)),
  'Virak Buntham': ('VB', Color(0xFF1D4ED8)),
  'Capitol Express': ('CE', Color(0xFF7C3AED)),
  'Grab': ('Grab', Color(0xFF00B14F)),
  shopDelivery: ('', Color(0xFF0F2A5F)),
};

// A courier the admin typed themselves
const _otherCourier = Color(0xFF64748B);

Color courierColor(String name) => couriers[name]?.$2 ?? _otherCourier;

class CourierLogo extends StatelessWidget {
  final String name;
  final double size;

  const CourierLogo({super.key, required this.name, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final known = couriers[name];
    if (name == shopDelivery) {
      return Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(size * 0.28),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Image.asset('assets/images/logo.png'),
      );
    }
    final color = courierColor(name);
    final mark =
        known?.$1 ?? (name.isEmpty ? '?' : name.characters.first.toUpperCase());
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: size * 0.08),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: name.isEmpty
          ? Icon(
              Icons.local_shipping_outlined,
              color: Colors.white,
              size: size * 0.55,
            )
          : FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                mark,
                maxLines: 1,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: size * 0.36,
                  letterSpacing: -0.3,
                ),
              ),
            ),
    );
  }
}
