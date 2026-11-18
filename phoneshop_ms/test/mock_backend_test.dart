import 'package:flutter_test/flutter_test.dart';
import 'package:phoneshop_ms/data/mock_backend.dart';
import 'package:phoneshop_ms/data/models/phone.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the bundled catalogue gives 20 phones shaped like the API', () async {
    final products = await MockBackend.products();
    expect(products, hasLength(20));
    final phones = products.map(Phone.fromJson).toList();
    expect(phones.map((p) => p.id).toSet(), hasLength(20));
    // Every phone has a price in USD range, sizes and colours
    for (final p in phones) {
      expect(p.price, inInclusiveRange(100, 2500), reason: p.name);
      expect(p.storageOptions, isNotEmpty, reason: p.name);
      expect(p.colors, isNotEmpty, reason: p.name);
    }
    // A discounted phone shows its sale price and the regular one
    final pro = phones.firstWhere((p) => p.name == 'iPhone 17 Pro Max');
    expect(pro.oldPrice, 1199);
    expect(pro.price, closeTo(1139.05, 0.001));
    expect(pro.imageFor('Deep Blue'), startsWith('asset:assets/data/phones/'));
  });

  test('search, brand filter, menu and best sellers answer like the API', () async {
    final found = await MockBackend.get('/products?search=galaxy') as List;
    expect(found.map((p) => p['name']), everyElement(contains('Galaxy')));

    final apple = await MockBackend.get('/products?brand=Apple') as List;
    expect(apple.map((p) => p['brand']).toSet(), {'Apple'});

    final menu = await MockBackend.get('/menu') as Map;
    expect(menu['brands'], containsAll(['Apple', 'Samsung', 'Google']));
    expect(
      (menu['categories'] as List).map((c) => c['name']),
      containsAll(['Smartphone', '2nd Hand']),
    );

    final best = await MockBackend.get('/best-sellers') as List;
    expect(best, hasLength(6));
    expect(best.every((p) => (p['stock'] as int) > 0), isTrue);

    expect(await MockBackend.get('/admin/dashboard'), isNull);
    expect(MockBackend.login('user@phoneshop.com', 'user123'), isNotNull);
    expect(MockBackend.login('user@phoneshop.com', 'wrong'), isNull);
  });
}
