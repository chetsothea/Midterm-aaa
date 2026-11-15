import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phoneshop_ms/models/order.dart';
import 'package:phoneshop_ms/screens/invoice_screen.dart';

Map<String, dynamic> orderJson({
  String status = 'delivered',
  String payment = 'paid',
  List<Map<String, dynamic>>? items,
}) => {
  'id': 18,
  'customer_name': 'Thea',
  'customer_email': 'thea@gmail.com',
  'total': '1609.00',
  'status': status,
  'payment_method': 'khqr',
  'payment_status': payment,
  'transaction_ref': 'TX123',
  'phone': '098374883',
  'address': 'ភ្នំពេញ',
  'created_at': '2026-11-03T04:00:00Z',
  'items':
      items ??
      [
        {
          'product_id': 1,
          'qty': 2,
          'price': '769.50',
          'storage': '256GB',
          'color': 'Silver',
          'product': {'name': 'iPhone 16 Pro Max'},
        },
        {'product_id': null, 'product': null, 'qty': 1, 'price': '70.00'},
      ],
  'trackings': [],
};

Future<void> pumpInvoice(WidgetTester tester, Map<String, dynamic> json) async {
  await tester.binding.setSurfaceSize(const Size(360, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(home: InvoiceScreen(order: Order.fromJson(json))),
  );
}

void main() {
  test(
    'the invoice number comes from the random code, not the running number',
    () {
      final coded = Order.fromJson({...orderJson(), 'code': 'PS-7K3Q9A'});
      expect(invoiceNumber(coded), 'INV-7K3Q9A');
      expect(coded.ref, 'PS-7K3Q9A');
      // Only an order without a code falls back to its number
      expect(invoiceNumber(Order.fromJson(orderJson())), 'INV-000018');
    },
  );

  testWidgets('a coded order shows its code, never its running number', (
    tester,
  ) async {
    await pumpInvoice(tester, {...orderJson(), 'code': 'PS-7K3Q9A'});
    expect(find.text('PS-7K3Q9A'), findsOneWidget);
    expect(find.text('INV-7K3Q9A'), findsOneWidget);
    expect(find.textContaining('18'), findsNothing);
  });

  testWidgets('shows the buyer, each item at the price paid, and the total', (
    tester,
  ) async {
    await pumpInvoice(tester, orderJson());

    expect(tester.takeException(), isNull); // fits a narrow phone
    expect(find.text('INV-000018'), findsOneWidget);
    expect(find.text('Thea'), findsOneWidget);
    expect(find.text('098374883'), findsOneWidget);
    expect(find.text('thea@gmail.com'), findsOneWidget);
    expect(find.text('ភ្នំពេញ'), findsOneWidget);

    expect(find.text('iPhone 16 Pro Max (Silver, 256GB)'), findsOneWidget);
    expect(find.text('\$769.50 × 2'), findsOneWidget);
    expect(find.text('\$1539.00'), findsOneWidget);

    // A phone removed from the shop later doesn't break the invoice
    expect(find.text('Deleted product'), findsOneWidget);

    expect(find.text('\$1609.00'), findsOneWidget);
    expect(find.text('បានបង់'), findsOneWidget);
    expect(find.text('TX123'), findsOneWidget);
    expect(find.text('Order នេះត្រូវបានបោះបង់'), findsNothing);
  });

  testWidgets('says so when not paid yet, or cancelled', (tester) async {
    await pumpInvoice(tester, orderJson(status: 'pending', payment: 'unpaid'));
    expect(find.text('មិនទាន់បង់'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        key: const ValueKey('cancelled'),
        home: InvoiceScreen(
          order: Order.fromJson(
            orderJson(status: 'cancelled', payment: 'unpaid'),
          ),
        ),
      ),
    );
    expect(find.text('Order នេះត្រូវបានបោះបង់'), findsOneWidget);
  });

  testWidgets('a long address and long names do not overflow', (tester) async {
    final json = orderJson(
      items: [
        {
          'product_id': 1,
          'qty': 1,
          'price': '100.00',
          'product': {'name': 'A phone with a really very long name ' * 4},
        },
      ],
    );
    json['address'] = 'ភូមិ ឃុំ ស្រុក ខេត្ត ' * 10;
    await pumpInvoice(tester, json);

    expect(tester.takeException(), isNull);
  });
}
