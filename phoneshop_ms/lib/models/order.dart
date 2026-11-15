class OrderItem {
  final int? productId; // null once the phone has been deleted
  final String productName;
  final String imageUrl;
  final int qty;
  final String color; // '' when the phone had no colour options
  final String storage; // '' when the phone had no storage options
  final double price;

  OrderItem({
    this.productId,
    required this.productName,
    required this.imageUrl,
    required this.qty,
    this.color = '',
    this.storage = '',
    required this.price,
  });

  // "iPhone 15 Pro (Black, 512GB)"
  String get label {
    final options = [color, storage].where((s) => s.isNotEmpty).join(', ');
    return options.isEmpty ? productName : '$productName ($options)';
  }

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    final product = json['product'] as Map<String, dynamic>?;
    return OrderItem(
      productId: json['product_id'],
      productName: product?['name'] ?? 'Deleted product',
      imageUrl: product?['image_url'] ?? '',
      qty: json['qty'],
      color: json['color'] ?? '',
      storage: json['storage'] ?? '',
      price: double.parse(json['price'].toString()),
    );
  }
}

// One step of the delivery: the order's status then, where the package was, and a note
class TrackingStep {
  final int? id;
  final String status;
  final String location;
  final String note;
  final DateTime time;

  TrackingStep({
    this.id,
    required this.status,
    this.location = '',
    this.note = '',
    required this.time,
  });

  factory TrackingStep.fromJson(Map<String, dynamic> json) => TrackingStep(
    id: json['id'],
    status: json['status'],
    location: json['location'] ?? '',
    note: json['note'] ?? '',
    time: DateTime.parse(json['created_at']).toLocal(),
  );
}

class Order {
  final int id; // shop-wide, used by the admin and the API
  final int?
  customerNumber; // this customer's 1st, 2nd, ... order; null for guests
  final String code; // random reference like "PS-7K3Q9A"
  final String customerName;
  final String customerEmail;
  final bool isGuest; // placed without an account
  final double total;
  final String status; // pending, confirmed, shipping, delivered, cancelled
  final String paymentMethod; // cod, khqr
  final String paymentStatus; // unpaid, verifying, paid
  final String? transactionRef;
  final String address;
  final String phone;
  final DateTime createdAt;
  final List<OrderItem> items;
  final String courier; // delivery company, e.g. "J&T Express"
  final String trackingNumber; // the courier's parcel number
  final List<TrackingStep> trackings; // newest first
  final DateTime? receivedAt; // when the customer said they got the parcel
  final bool receivedSeen; // the admin has seen that notice

  Order({
    required this.id,
    this.customerNumber,
    this.code = '',
    required this.customerName,
    this.customerEmail = '',
    this.isGuest = false,
    required this.total,
    required this.status,
    required this.paymentMethod,
    required this.paymentStatus,
    this.transactionRef,
    required this.address,
    required this.phone,
    required this.createdAt,
    required this.items,
    this.courier = '',
    this.trackingNumber = '',
    this.trackings = const [],
    this.receivedAt,
    this.receivedSeen = false,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    return Order(
      id: json['id'],
      customerNumber: json['customer_number'],
      code: json['code'] ?? '',
      // Name/email typed at checkout; older orders only have the account's
      customerName: json['customer_name'] ?? user?['name'] ?? '',
      customerEmail: json['customer_email'] ?? user?['email'] ?? '',
      isGuest: json['user_id'] == null,
      receivedAt: DateTime.tryParse(json['received_at'] ?? '')?.toLocal(),
      receivedSeen: json['received_seen_at'] != null,
      total: double.parse(json['total'].toString()),
      status: json['status'],
      paymentMethod: json['payment_method'],
      paymentStatus: json['payment_status'],
      transactionRef: json['transaction_ref'],
      address: json['address'] ?? '',
      phone: json['phone'] ?? '',
      createdAt: DateTime.parse(json['created_at']).toLocal(),
      items: ((json['items'] ?? []) as List)
          .map((e) => OrderItem.fromJson(e))
          .toList(),
      courier: json['courier'] ?? '',
      trackingNumber: json['tracking_number'] ?? '',
      trackings: ((json['trackings'] ?? []) as List)
          .map((e) => TrackingStep.fromJson(e))
          .toList(),
    );
  }

  // The number the customer sees: their own count, so it never jumps over
  // other people's orders (#4 → #5, not #21 → #32)
  int get number => customerNumber ?? id;

  // What customers and bills show: the random code, which gives away nothing about
  // how many orders or customers the shop has. "#5" only for an order without one.
  String get ref => code.isNotEmpty ? code : '#$number';
}
