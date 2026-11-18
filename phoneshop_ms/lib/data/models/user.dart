class User {
  final int id;
  final String name;
  final String email;
  final String phone;
  final String address;
  final String role;
  final String avatarUrl; // '' when there is no picture

  User({
    required this.id,
    required this.name,
    required this.email,
    this.phone = '',
    this.address = '',
    required this.role,
    this.avatarUrl = '',
  });

  bool get isAdmin => role == 'admin';
  // Shop worker: handles orders, but not money, prices or settings
  bool get isStaff => role == 'staff';
  // Opens the admin panel (staff see only the orders part)
  bool get isTeam => isAdmin || isStaff;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      phone: json['phone'] ?? '',
      address: json['address'] ?? '',
      role: json['role'] ?? 'user',
      avatarUrl: json['avatar_url'] ?? '',
    );
  }
}
