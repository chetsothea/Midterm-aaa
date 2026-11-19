import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phoneshop_ms/components/address_picker.dart';
import 'package:phoneshop_ms/data/api_service.dart';
import 'package:phoneshop_ms/data/models/phone.dart';
import 'package:phoneshop_ms/data/models/user.dart';
import 'package:phoneshop_ms/hooks/cart.dart';
import 'package:phoneshop_ms/screens/admin/admin_activity_screen.dart';
import 'package:phoneshop_ms/screens/checkout_screen.dart';

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

const _home = 'ផ្ទះ 1, រាជធានីភ្នំពេញ, កម្ពុជា';
const _work = 'ផ្ទះ 9, ខេត្តសៀមរាប, កម្ពុជា';

void main() {
  setUp(() {
    ApiService.token = 'test';
    Cart.instance.clear();
    Cart.instance.add(
      Phone(
        id: 1,
        name: 'Galaxy A55',
        brand: 'Samsung',
        price: 399,
        stock: 3,
        imageUrl: '',
      ),
    );
  });
  tearDown(() {
    ApiService.token = null;
    ApiService.currentUser = null;
    Cart.instance.clear();
  });

  testWidgets('checkout can switch to another saved address', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    ApiService.currentUser = User(
      id: 2,
      name: 'Dara',
      email: 'dara@example.com',
      phone: '012345678',
      address: _home,
      role: 'user',
    );
    Map? ordered;
    final mock = MockClient((request) async {
      final path = request.url.path;
      if (path == '/api/addresses') {
        return _json([
          {'id': 5, 'label': 'ការងារ', 'address': _work},
        ]);
      }
      if (path == '/api/orders') {
        ordered = jsonDecode(request.body);
        return _json({'message': 'stop here'}, 422);
      }
      return _json({'subtotal': 399, 'total': 399, 'shipping': {}});
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: CheckoutScreen()));
      await tester.pumpAndSettle();
      expect(find.text(_home), findsOneWidget);

      await tester.tap(find.text('ប្តូរទីតាំង'));
      await tester.pumpAndSettle();
      expect(find.byType(AddressPicker), findsOneWidget);
      await tester.tap(find.text(_work));
      await tester.pumpAndSettle();
      expect(find.text('ការងារ'), findsOneWidget); // its name above it
      expect(find.byType(AddressPicker), findsNothing);

      await tester.tap(find.text('បញ្ជាទិញ'));
      await tester.pumpAndSettle();
    }, () => mock);

    expect(ordered?['address'], _work);
  });

  testWidgets('admin reads who did what', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Uri? asked;
    final mock = MockClient((request) async {
      asked = request.url;
      return _json([
        {
          'id': 1,
          'user_name': 'Sok',
          'role': 'staff',
          'action': 'កែ Order',
          'subject': 'Order PS-ABC123',
          'details': {'status': 'shipping', 'courier': 'J&T'},
          'created_at': '2026-11-18T07:05:00Z',
        },
      ]);
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(
        const MaterialApp(home: AdminActivityScreen(userId: 7, name: 'Sok')),
      );
      await tester.pumpAndSettle();
    }, () => mock);

    expect(asked?.queryParameters['user_id'], '7');
    expect(find.textContaining('កែ Order'), findsOneWidget);
    expect(find.textContaining('Order PS-ABC123'), findsOneWidget);
    expect(find.text('status: shipping · courier: J&T'), findsOneWidget);
  });
}
