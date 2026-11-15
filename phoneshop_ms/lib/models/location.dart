// A province, district, commune or village in Cambodia
class Location {
  final String
  code; // 2 digits for a province, 4 district, 6 commune, 8 village
  final String km; // Khmer name with its type, e.g. "ខណ្ឌចំការមន"
  final String en;

  const Location({required this.code, required this.km, required this.en});

  factory Location.fromJson(Map<String, dynamic> json) =>
      Location(code: json['code'], km: json['km'], en: json['en'] ?? '');
}
