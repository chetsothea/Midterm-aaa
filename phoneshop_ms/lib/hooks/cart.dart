import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/api_service.dart';
import '../data/models/phone.dart';

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

  static const _storeKey = 'ps168_cart';
  bool _loading = false;

  // Every change is saved, so the cart is still there after the app closes
  @override
  void notifyListeners() {
    super.notifyListeners();
    if (!_loading) _save();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _storeKey,
        jsonEncode([
          for (final i in _items.values)
            {
              'id': i.phone.id,
              'color': i.color,
              'storage': i.storage,
              'qty': i.qty,
            },
        ]),
      );
    } catch (_) {
      // No storage (tests, private browsing): the cart just isn't remembered
    }
  }

  // At launch: put back the saved cart with today's prices and stock.
  // Phones that were deleted or sold out are dropped, and a quantity larger
  // than what is left is lowered to the stock.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storeKey);
      if (raw == null || raw.isEmpty) return;
      final saved = List<Map<String, dynamic>>.from(jsonDecode(raw));
      if (saved.isEmpty) return;
      final phones = {
        for (final p in await ApiService.fetchPhones().timeout(
          const Duration(seconds: 8),
        ))
          p.id: p,
      };
      _loading = true;
      _items.clear();
      for (final s in saved) {
        final phone = phones[s['id']];
        if (phone == null || phone.stock <= 0) continue;
        final left = phone.stock - qtyOf(phone.id);
        final qty = (s['qty'] as num).toInt().clamp(0, left);
        if (qty <= 0) continue;
        final item = CartItem(
          phone,
          '${s['color'] ?? ''}',
          '${s['storage'] ?? ''}',
          qty,
        );
        _items[item.key] = item;
      }
    } catch (_) {
      // Offline or bad data: start with the cart as it is
    } finally {
      final wasLoading = _loading;
      _loading = false;
      if (wasLoading) notifyListeners(); // saves the cleaned-up cart
    }
  }

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

  // The line just taken out and where it was, so it can be put back
  // (the cart's "Undo" bar listens to this)
  final lastRemoved = ValueNotifier<(CartItem, int)?>(null);

  void remove(String key) {
    final item = _items[key];
    if (item == null) return;
    final index = _items.keys.toList().indexOf(key);
    _items.remove(key);
    lastRemoved.value = (item, index);
    notifyListeners();
  }

  // Puts the last removed line back at its old place in the list
  void undoRemove() {
    final removed = lastRemoved.value;
    if (removed == null) return;
    final (item, index) = removed;
    final entries = _items.entries.toList()
      ..insert(index.clamp(0, _items.length), MapEntry(item.key, item));
    _items
      ..clear()
      ..addEntries(entries);
    lastRemoved.value = null;
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
