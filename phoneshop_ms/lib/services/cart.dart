import 'package:flutter/foundation.dart';
import '../models/phone.dart';

class CartItem {
  final Phone phone;
  final String color; // '' when the phone has no colour options
  final String storage; // '' when the phone has no storage options
  int qty;

  CartItem(this.phone, this.color, this.storage, this.qty);

  // The same phone in another colour or size is a separate cart line
  String get key => Cart.keyFor(phone.id, color, storage);

  double get unitPrice => phone.priceFor(storage);
  double get subtotal => unitPrice * qty;

  // The price without the phone's discount
  double get regularPrice => phone.oldPriceFor(storage) ?? unitPrice;

  // "Blue · 512GB"
  String get options => [color, storage].where((s) => s.isNotEmpty).join(' · ');
}

// One shared cart for the whole app; screens rebuild with ListenableBuilder
class Cart extends ChangeNotifier {
  Cart._();
  static final Cart instance = Cart._();

  static String keyFor(int phoneId, [String color = '', String storage = '']) =>
      '$phoneId|$color|$storage';

  final Map<String, CartItem> _items = {};

  List<CartItem> get items => _items.values.toList();
  int get count => _items.values.fold(0, (sum, i) => sum + i.qty);
  double get total => _items.values.fold(0, (sum, i) => sum + i.subtotal);
  bool get isEmpty => _items.isEmpty;

  // The total without discounts, and how much the discounts take off it
  double get regularTotal =>
      _items.values.fold(0, (sum, i) => sum + i.regularPrice * i.qty);
  double get discount => regularTotal - total;

  // Every colour and size together, since stock is shared between them
  int qtyOf(int phoneId) => _items.values
      .where((i) => i.phone.id == phoneId)
      .fold(0, (sum, i) => sum + i.qty);

  // Returns false when there is not enough stock
  bool add(Phone phone, [int qty = 1, String color = '', String storage = '']) {
    if (qtyOf(phone.id) + qty > phone.stock) return false;
    final key = keyFor(phone.id, color, storage);
    final current = _items[key]?.qty ?? 0;
    _items[key] = CartItem(phone, color, storage, current + qty);
    notifyListeners();
    return true;
  }

  void setQty(String key, int qty) {
    final item = _items[key];
    if (item == null) return;
    if (qty <= 0) {
      _items.remove(key);
    } else if (qtyOf(item.phone.id) - item.qty + qty <= item.phone.stock) {
      item.qty = qty;
    }
    notifyListeners();
  }

  void remove(String key) {
    _items.remove(key);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }

  List<Map<String, dynamic>> toOrderItems() => items
      .map(
        (i) => {
          'product_id': i.phone.id,
          'qty': i.qty,
          if (i.color.isNotEmpty) 'color': i.color,
          if (i.storage.isNotEmpty) 'storage': i.storage,
        },
      )
      .toList();
}
