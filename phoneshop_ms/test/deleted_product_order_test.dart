import 'package:flutter_test/flutter_test.dart';
import 'package:phoneshop_ms/data/models/order.dart';

void main() {
  test('an order still loads after its phone was deleted', () {
    final order = Order.fromJson({
      'id': 12,
      'customer_name': 'Dara',
      'total': '799.00',
      'status': 'pending',
      'payment_method': 'cod',
      'payment_status': 'unpaid',
      'created_at': '2026-11-01T00:00:00Z',
      'items': [
        {'id': 1, 'product_id': null, 'product': null, 'qty': 1, 'price': '799.00'},
      ],
    });

    expect(order.items.single.productId, isNull);
    expect(order.items.single.productName, 'Deleted product');
  });
}
