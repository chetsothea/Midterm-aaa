// One size a phone is sold in, e.g. 512GB for $1399
class StorageOption {
  final String storage;
  final double price;
  final double? oldPrice; // regular price while the phone is discounted

  const StorageOption(this.storage, this.price, [this.oldPrice]);

  factory StorageOption.fromJson(Map<String, dynamic> json) => StorageOption(
    json['storage'],
    double.parse(json['price'].toString()),
    double.tryParse(json['old_price']?.toString() ?? ''),
  );

  // How the admin form writes it, always the regular price: "512GB=1399"
  @override
  String toString() {
    final regular = oldPrice ?? price;
    return '$storage=${regular == regular.roundToDouble() ? regular.toInt() : regular}';
  }
}

class Phone {
  final int id;
  final int? categoryId;
  final String name;
  final String brand;
  final double price;
  final double? oldPrice; // price before discount, if any
  final String condition; // "New", or e.g. "98%" for a used phone
  final int stock;
  final String ram;
  final String storage;
  final String color;
  final String description;
  final String imageUrl;
  final Map<String, String>
  colorImageUrls; // picture per colour, e.g. {"Blue": "http://..."}
  final List<StorageOption> storageOptions; // empty = one size at [price]
  // Stock per colour and size, {"Blue|256GB": 3}; null = one shared [stock]
  final Map<String, int>? variantStock;
  final int warrantyMonths; // 0 = sold without warranty
  final double ratingAverage; // 0 when nobody has reviewed it
  final int ratingCount;

  Phone({
    required this.id,
    this.categoryId,
    required this.name,
    required this.brand,
    required this.price,
    this.oldPrice,
    this.condition = 'New',
    this.stock = 0,
    this.ram = '',
    this.storage = '',
    this.color = '',
    this.description = '',
    required this.imageUrl,
    this.colorImageUrls = const {},
    this.storageOptions = const [],
    this.variantStock,
    this.warrantyMonths = 12,
    this.ratingAverage = 0,
    this.ratingCount = 0,
  });

  // Price of the picked size; [price] (the cheapest) when there are no sizes to pick
  double priceFor(String storage) {
    for (final option in storageOptions) {
      if (option.storage == storage) return option.price;
    }
    return price;
  }

  // Regular price of the picked size, null when there is no discount
  double? oldPriceFor(String storage) {
    for (final option in storageOptions) {
      if (option.storage == storage) return option.oldPrice;
    }
    return oldPrice;
  }

  // The colour's own picture, or the main picture when it has none
  String imageFor(String color) {
    final url = colorImageUrls[color] ?? '';
    return url.isNotEmpty ? url : imageUrl;
  }

  // Admin enters colours separated by commas: "Natural Titanium, Black, Blue"
  List<String> get colors =>
      color.split(',').map((c) => c.trim()).where((c) => c.isNotEmpty).toList();

  bool get hasDiscount => oldPrice != null && oldPrice! > price;

  // e.g. 33.33 for $10 instead of $15; 0 when there is no discount
  double get discountPercent =>
      hasDiscount ? (oldPrice! - price) / oldPrice! * 100 : 0;

  bool get hasVariantStock => variantStock != null && variantStock!.isNotEmpty;

  static String variantKey(String color, String storage) =>
      '${color.trim()}|${storage.trim()}';

  // How many of this colour and size the shop has
  int stockFor(String color, String storage) =>
      hasVariantStock ? variantStock![variantKey(color, storage)] ?? 0 : stock;

  // Any size of this colour left (for greying out a sold-out colour)
  bool colorAvailable(String color) {
    if (!hasVariantStock) return stock > 0;
    final sizes = storageOptions.isEmpty
        ? ['']
        : [for (final o in storageOptions) o.storage];
    return sizes.any((s) => stockFor(color, s) > 0);
  }

  factory Phone.fromJson(Map<String, dynamic> json) {
    return Phone(
      id: int.parse(json['id'].toString()),
      // Multipart responses can send numbers back as strings
      categoryId: int.tryParse(json['category_id']?.toString() ?? ''),
      name: json['name'],
      brand: json['brand'] ?? '',
      price: double.parse(json['price'].toString()),
      oldPrice: double.tryParse(json['old_price']?.toString() ?? ''),
      condition: (json['condition'] ?? '').toString().isEmpty
          ? 'New'
          : json['condition'],
      stock: int.tryParse(json['stock'].toString()) ?? 0,
      warrantyMonths: int.tryParse('${json['warranty_months'] ?? ''}') ?? 12,
      ram: json['ram'] ?? '',
      storage: json['storage'] ?? '',
      color: json['color'] ?? '',
      description: json['description'] ?? '',
      imageUrl: json['image_url'] ?? '',
      colorImageUrls: json['color_image_urls'] is Map
          ? Map<String, String>.from(json['color_image_urls'])
          : const {},
      variantStock: json['variant_stock'] is Map
          ? {
              for (final e in (json['variant_stock'] as Map).entries)
                '${e.key}': int.tryParse('${e.value}') ?? 0,
            }
          : null,
      storageOptions: json['storage_prices'] is List
          ? (json['storage_prices'] as List)
                .map((e) => StorageOption.fromJson(e))
                .toList()
          : const [],
      ratingAverage:
          double.tryParse('${json['reviews_avg_rating'] ?? ''}') ?? 0,
      ratingCount: int.tryParse('${json['reviews_count'] ?? ''}') ?? 0,
    );
  }
}
