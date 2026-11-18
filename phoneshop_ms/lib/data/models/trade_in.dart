import '../../hooks/language.dart';

// A customer's old phone offered to the shop, and where the deal stands
class TradeIn {
  final int id;
  final String brand;
  final String model;
  final String storage;
  final String condition; // like_new, good, fair, broken
  final int? batteryHealth;
  final String notes;
  final List<String> photoUrls;
  final String wantedProduct; // '' when none picked
  final String
  status; // pending offered accepted completed declined rejected cancelled
  final double? offerAmount;
  final String adminNote;
  final String voucherCode; // the credit, once completed
  final DateTime createdAt;
  // Admin list only
  final String customerName;
  final String customerPhone;

  const TradeIn({
    required this.id,
    required this.brand,
    required this.model,
    this.storage = '',
    required this.condition,
    this.batteryHealth,
    this.notes = '',
    this.photoUrls = const [],
    this.wantedProduct = '',
    required this.status,
    this.offerAmount,
    this.adminNote = '',
    this.voucherCode = '',
    required this.createdAt,
    this.customerName = '',
    this.customerPhone = '',
  });

  String get title =>
      [brand, model, storage].where((s) => s.isNotEmpty).join(' ');
  bool get isOpen => const ['pending', 'offered', 'accepted'].contains(status);

  factory TradeIn.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map?;
    return TradeIn(
      id: json['id'],
      brand: json['brand'] ?? '',
      model: json['model'] ?? '',
      storage: json['storage'] ?? '',
      condition: json['condition'] ?? 'good',
      batteryHealth: json['battery_health'],
      notes: json['notes'] ?? '',
      photoUrls: [for (final p in (json['photo_urls'] ?? []) as List) '$p'],
      wantedProduct: '${(json['wanted_product'] as Map?)?['name'] ?? ''}',
      status: json['status'],
      offerAmount: double.tryParse('${json['offer_amount'] ?? ''}'),
      adminNote: json['admin_note'] ?? '',
      voucherCode: json['voucher_code'] ?? '',
      createdAt: DateTime.parse(json['created_at']).toLocal(),
      customerName: '${user?['name'] ?? ''}',
      customerPhone: '${user?['phone'] ?? ''}',
    );
  }
}

Map<String, String> get tradeInConditions => {
  'like_new': trf('ដូចថ្មី', 'Like new'),
  'good': trf('ល្អ (ស្នាមតិចតួច)', 'Good (light marks)'),
  'fair': trf('មធ្យម (ស្នាមច្រើន)', 'Fair (visible wear)'),
  'broken': trf('ខូច (អេក្រង់/ផ្នែកណាមួយ)', 'Broken (screen or part)'),
};

Map<String, String> get tradeInStatuses => {
  'pending': trf('រង់ចាំហាងវាយតម្លៃ', 'Waiting for the shop'),
  'offered': trf('ហាងផ្តល់តម្លៃហើយ', 'Offer ready'),
  'accepted': trf('យល់ព្រម · យកទូរស័ព្ទមកហាង', 'Accepted · bring the phone'),
  'completed': trf('រួចរាល់ · មានកូដបញ្ចុះ', 'Done · credit code ready'),
  'declined': trf('អ្នកបានបដិសេធ', 'You declined'),
  'rejected': trf('ហាងមិនទទួល', 'Shop declined'),
  'cancelled': trf('បានបោះបង់', 'Cancelled'),
};
