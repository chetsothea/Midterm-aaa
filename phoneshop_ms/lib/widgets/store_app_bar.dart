import 'package:flutter/material.dart';

// The store's top bar: navy to teal, rounded bottom corners and a soft shadow,
// so pages opened from the home page look like part of the same shop.
AppBar storeAppBar({required Widget title, List<Widget>? actions}) {
  return AppBar(
    foregroundColor: Colors.white,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
    ),
    flexibleSpace: Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
        gradient: LinearGradient(
          colors: [Color(0xFF0F2A5F), Color(0xFF0E7490)],
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 14,
            color: Color(0x330F2A5F),
            offset: Offset(0, 4),
          ),
        ],
      ),
    ),
    titleTextStyle: const TextStyle(
      color: Colors.white,
      fontSize: 17,
      fontWeight: FontWeight.w700,
    ),
    title: title,
    actions: actions,
  );
}
