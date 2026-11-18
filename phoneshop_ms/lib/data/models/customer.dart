// A registered customer, as the admin sees them
class Customer {
  final int id;
  final String name;
  final String email;
  final String phone;
  final String address;
  final DateTime joined;
  final int orders;
  final bool blocked; // the admin disabled this account

  Customer({
    required this.id,
    required this.name,
    required this.email,
    this.phone = '',
    this.address = '',
    required this.joined,
    this.orders = 0,
    this.blocked = false,
  });

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
    id: json['id'],
    name: json['name'],
    email: json['email'],
    phone: json['phone'] ?? '',
    address: json['address'] ?? '',
    joined: DateTime.parse(json['created_at']).toLocal(),
    orders: json['orders_count'] ?? 0,
    blocked: json['blocked_at'] != null,
  );
}
