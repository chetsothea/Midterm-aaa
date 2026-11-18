double _num(dynamic v) => v == null ? 0 : double.parse(v.toString());

// Delivery prices the admin sets: Phnom Penh, provinces, and free from this
// order amount (0 = never free)
class ShippingRates {
  final double phnomPenh;
  final double province;
  final double freeOver;

  const ShippingRates({
    this.phnomPenh = 0,
    this.province = 0,
    this.freeOver = 0,
  });

  factory ShippingRates.fromJson(Map<String, dynamic>? json) => ShippingRates(
    phnomPenh: _num(json?['phnom_penh']),
    province: _num(json?['province']),
    freeOver: _num(json?['free_over']),
  );
}

// What the order will cost, worked out by the server before placing it
class Quote {
  final double subtotal;
  final double discount;
  final String voucherCode; // '' when no code
  final String voucherLabel; // "10%" or "$20"
  final double shippingFee;
  final bool phnomPenh; // which delivery price applied
  final double total;
  final ShippingRates rates;

  const Quote({
    required this.subtotal,
    this.discount = 0,
    this.voucherCode = '',
    this.voucherLabel = '',
    this.shippingFee = 0,
    this.phnomPenh = true,
    required this.total,
    this.rates = const ShippingRates(),
  });

  factory Quote.fromJson(Map<String, dynamic> json) => Quote(
    subtotal: _num(json['subtotal']),
    discount: _num(json['discount']),
    voucherCode: '${json['voucher_code'] ?? ''}',
    voucherLabel: '${json['voucher_label'] ?? ''}',
    shippingFee: _num(json['shipping_fee']),
    phnomPenh: json['shipping_zone'] != 'province',
    total: _num(json['total']),
    rates: ShippingRates.fromJson(
      (json['shipping'] as Map?)?.cast<String, dynamic>(),
    ),
  );

  // How much more to spend for free delivery; null when it doesn't apply
  double? get moreForFreeDelivery {
    if (rates.freeOver <= 0 || shippingFee == 0) return null;
    final left = rates.freeOver - (subtotal - discount);
    return left > 0 ? left : null;
  }
}

// A discount code, as the admin manages it
class Voucher {
  final int? id;
  final String code;
  final String type; // percent or fixed
  final double value;
  final String label;
  final double minTotal;
  final double? maxDiscount;
  final int? maxUses;
  final int usedCount;
  final DateTime? expiresAt;
  final bool active;

  const Voucher({
    this.id,
    required this.code,
    required this.type,
    required this.value,
    this.label = '',
    this.minTotal = 0,
    this.maxDiscount,
    this.maxUses,
    this.usedCount = 0,
    this.expiresAt,
    this.active = true,
  });

  bool get isPercent => type == 'percent';
  bool get expired => expiresAt != null && expiresAt!.isBefore(DateTime.now());
  bool get usedUp => maxUses != null && usedCount >= maxUses!;
  bool get usable => active && !expired && !usedUp;

  factory Voucher.fromJson(Map<String, dynamic> json) => Voucher(
    id: json['id'],
    code: json['code'],
    type: json['type'],
    value: _num(json['value']),
    label: '${json['label'] ?? ''}',
    minTotal: _num(json['min_total']),
    maxDiscount: json['max_discount'] == null
        ? null
        : _num(json['max_discount']),
    maxUses: json['max_uses'],
    usedCount: json['used_count'] ?? 0,
    expiresAt: DateTime.tryParse('${json['expires_at'] ?? ''}')?.toLocal(),
    active: json['active'] ?? true,
  );

  Map<String, dynamic> toJson() => {
    'code': code,
    'type': type,
    'value': value,
    'min_total': minTotal,
    'max_discount': maxDiscount,
    'max_uses': maxUses,
    'expires_at': expiresAt?.toUtc().toIso8601String(),
    'active': active,
  };
}
