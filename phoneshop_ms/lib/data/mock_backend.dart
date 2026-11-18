import 'dart:convert';

import 'package:flutter/services.dart';

// Mock mode: the whole store runs on the bundled 20-phone catalogue
// (assets/data/phones.json, the same file the Laravel seeder uses), with no
// server. Turn it on with:
//
//   flutter run --dart-define=MOCK_DATA=true
//
// Browsing, search, filters, best sellers, compare, favourites and the cart all
// work; logging in accepts the demo account (user@phoneshop.com / user123).
// Placing an order, payments and admin need the real API.
class MockBackend {
  static const enabled = bool.fromEnvironment('MOCK_DATA');

  static List<Map<String, dynamic>>? _products;

  // The catalogue as the API would send it: ids, discounted price with
  // old_price, storage options, and pictures as bundled assets
  static Future<List<Map<String, dynamic>>> products() async {
    if (_products != null) return _products!;
    final raw = jsonDecode(
      await rootBundle.loadString('assets/data/phones.json'),
    );
    final categories = <String, int>{};
    final list = <Map<String, dynamic>>[];
    var id = 0;
    for (final phone in (raw['phones'] as List).cast<Map<String, dynamic>>()) {
      id++;
      final categoryId = categories.putIfAbsent(
        phone['category'],
        () => categories.length + 1,
      );
      final discount = (phone['discount_percent'] as num?)?.toDouble() ?? 0;
      double sale(double p) =>
          double.parse((p * (1 - discount / 100)).toStringAsFixed(2));
      final options = [
        for (final part in (phone['storage_prices'] as String).split(','))
          if (part.contains('='))
            (
              part.split('=')[0].trim(),
              double.parse(part.split('=')[1].trim()),
            ),
      ];
      final cheapest = options.map((o) => o.$2).reduce((a, b) => a < b ? a : b);
      final images = Map<String, String>.from(phone['images'] ?? {});
      String asset(String path) =>
          'asset:assets/data/phones/${path.split('/').last.replaceAll('.png', '.webp')}';
      final colors = List<String>.from(phone['colors']);
      final main = images['_main'] ?? images[colors.first];
      list.add({
        'id': id,
        'category_id': categoryId,
        'category': phone['category'],
        'name': phone['name'],
        'brand': phone['brand'],
        'price': sale(cheapest),
        'old_price': discount > 0 ? cheapest : null,
        'condition': phone['condition'],
        'stock': phone['stock'],
        'ram': phone['ram'],
        'storage': options.map((o) => o.$1).join(', '),
        'storage_prices': [
          for (final (storage, price) in options)
            {
              'storage': storage,
              'price': sale(price),
              'old_price': discount > 0 ? price : null,
            },
        ],
        'color': colors.join(', '),
        'description': phone['description'],
        'image_url': main == null ? '' : asset(main),
        'color_image_urls': {
          for (final c in colors)
            if (images[c] != null) c: asset(images[c]!),
        },
      });
    }
    return _products = list;
  }

  // Answers a GET the way the API would; null when mock mode has no answer
  static Future<Object?> get(String path) async {
    final uri = Uri.parse(path);
    final all = await products();
    switch (uri.path) {
      case '/products':
        final q = uri.queryParameters;
        final search = (q['search'] ?? '').toLowerCase();
        return all.where((p) {
          if (search.isNotEmpty &&
              !'${p['name']} ${p['brand']}'.toLowerCase().contains(search)) {
            return false;
          }
          if ((q['brand'] ?? '').isNotEmpty && p['brand'] != q['brand']) {
            return false;
          }
          if ((q['category_id'] ?? '').isNotEmpty &&
              '${p['category_id']}' != q['category_id']) {
            return false;
          }
          return true;
        }).toList();
      case '/best-sellers':
        // No sales offline: the priciest phones in stock, like the API's fallback
        final inStock = all.where((p) => (p['stock'] as int) > 0).toList()
          ..sort(
            (a, b) => (b['old_price'] ?? b['price']).compareTo(
              a['old_price'] ?? a['price'],
            ),
          );
        return [
          for (final p in inStock.take(6)) {...p, 'sold': 0},
        ];
      case '/menu':
        final brands = {for (final p in all) p['brand'] as String}.toList()
          ..sort();
        final categories = <int, Map<String, dynamic>>{};
        for (final p in all) {
          final c = categories.putIfAbsent(
            p['category_id'],
            () => {
              'id': p['category_id'],
              'name': p['category'],
              'brands': <String>{},
            },
          );
          (c['brands'] as Set<String>).add(p['brand']);
        }
        return {
          'telegram': '',
          'brands': brands,
          'categories': [
            for (final c in categories.values)
              {...c, 'brands': (c['brands'] as Set<String>).toList()..sort()},
          ],
        };
      case '/live':
        return {
          'is_live': false,
          'youtube_id': '',
          'title': '',
          'products': [],
        };
      case '/live/comments':
      case '/orders':
        return [];
    }
    // Nobody has reviewed anything offline
    if (uri.path.endsWith('/reviews')) {
      return {
        'average': 0,
        'count': 0,
        'stars': {'5': 0, '4': 0, '3': 0, '2': 0, '1': 0},
        'reviews': [],
        'can_review': false,
        'mine': null,
      };
    }
    if (uri.path.startsWith('/products/')) {
      final id = int.tryParse(uri.path.split('/').last);
      return all.where((p) => p['id'] == id).firstOrNull;
    }
    return null;
  }

  // The demo account, so the cart can be tried offline
  static Map<String, dynamic>? login(String email, String password) {
    if (email.trim().toLowerCase() != 'user@phoneshop.com' ||
        password != 'user123') {
      return null;
    }
    return {
      'token': 'mock',
      'user': {
        'id': 2,
        'name': 'Customer',
        'email': 'user@phoneshop.com',
        'phone': '012345678',
        'address': 'Phnom Penh',
        'role': 'user',
        'avatar_url': '',
      },
    };
  }
}
