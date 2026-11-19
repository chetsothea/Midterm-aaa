// One message in the customer's 🔔: an order step, a payment, a trade-in offer
class Notice {
  final int id;
  final String kind; // order, payment, trade_in, stock, price
  final String title;
  final String body;
  final int? orderId;
  final int? tradeInId;
  final int? productId; // back in stock / cheaper: opens that phone
  final bool read;
  final DateTime time;

  const Notice({
    required this.id,
    required this.kind,
    required this.title,
    this.body = '',
    this.orderId,
    this.tradeInId,
    this.productId,
    this.read = false,
    required this.time,
  });

  factory Notice.fromJson(Map<String, dynamic> json) => Notice(
    id: json['id'],
    kind: json['kind'] ?? 'order',
    title: json['title'] ?? '',
    body: json['body'] ?? '',
    orderId: json['order_id'],
    tradeInId: json['trade_in_id'],
    productId: json['product_id'],
    read: json['read_at'] != null,
    time: DateTime.parse(json['created_at']).toLocal(),
  );
}
