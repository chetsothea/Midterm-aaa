import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phoneshop_ms/models/phone.dart';
import 'package:phoneshop_ms/models/user.dart';
import 'package:phoneshop_ms/screens/checkout_screen.dart';
import 'package:phoneshop_ms/services/api_service.dart';
import 'package:phoneshop_ms/services/cart.dart';
import 'package:phoneshop_ms/widgets/address_picker.dart';

const savedAddress =
    'ភូមិត្រស់, ឃុំអូរតាគី, ស្រុកថ្មគោល, ខេត្តបាត់ដំបង, កម្ពុជា';

User customer(String address) => User(
  id: 2,
  name: 'Thea',
  email: 'thea@gmail.com',
  phone: '098374883',
  address: address,
  role: 'user',
);

void main() {
  setUp(() {
    Cart.instance.clear();
    Cart.instance.add(
      Phone(
        id: 9,
        name: 'Galaxy A55',
        brand: 'Samsung',
        price: 399,
        stock: 3,
        imageUrl: '',
      ),
    );
  });

  tearDown(() {
    Cart.instance.clear();
    ApiService.token = null;
    ApiService.currentUser = null;
  });

  Future<void> pumpCheckout(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: CheckoutScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'a logged-in customer orders to their saved address without picking it again',
    (tester) async {
      Map<String, dynamic>? sent;
      ApiService.token = 'test';
      ApiService.currentUser = customer(savedAddress);

      await http.runWithClient(
        () async {
          await pumpCheckout(tester);

          expect(find.text(savedAddress), findsOneWidget);
          expect(find.byType(AddressPicker), findsNothing);

          await tester.tap(find.text('បញ្ជាទិញ'));
          await tester.pump();
          expect(sent?['address'], savedAddress);
          await tester.pumpWidget(const SizedBox()); // leave the payment screen
        },
        () => MockClient((request) async {
          if (request.method == 'POST') sent = jsonDecode(request.body);
          return http.Response('{"message":"stop here"}', 422);
        }),
      );
    },
  );

  testWidgets(
    'they can change the address for this order, and go back to the saved one',
    (tester) async {
      ApiService.token = 'test';
      ApiService.currentUser = customer(savedAddress);

      await http.runWithClient(() async {
        await pumpCheckout(tester);

        await tester.tap(find.text('ប្តូរទីតាំង'));
        await tester.pumpAndSettle();
        expect(find.byType(AddressPicker), findsOneWidget);
        expect(find.text(savedAddress), findsNothing);

        // The picker now has to be completed
        await tester.tap(find.text('បញ្ជាទិញ'));
        await tester.pump();
        expect(find.text('សូមជ្រើសខេត្ត'), findsOneWidget);

        await tester.tap(find.text('ប្រើទីតាំងដែលបានរក្សាទុក'));
        await tester.pumpAndSettle();
        expect(find.text(savedAddress), findsOneWidget);
        expect(find.byType(AddressPicker), findsNothing);
      }, () => MockClient((_) async => http.Response('[]', 200)));
    },
  );

  testWidgets('without a saved address the picker is shown', (tester) async {
    await http.runWithClient(() async {
      // A guest
      await pumpCheckout(tester);
      expect(find.byType(AddressPicker), findsOneWidget);
      expect(find.text('ប្រើទីតាំងដែលបានរក្សាទុក'), findsNothing);
      await tester.pumpWidget(const SizedBox());

      // Signed up with Google: an account, but no address yet
      ApiService.token = 'test';
      ApiService.currentUser = customer('');
      await pumpCheckout(tester);
      expect(find.byType(AddressPicker), findsOneWidget);
    }, () => MockClient((_) async => http.Response('[]', 200)));
  });
}
