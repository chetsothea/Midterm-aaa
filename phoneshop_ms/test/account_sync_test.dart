import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phoneshop_ms/data/api_service.dart';
import 'package:phoneshop_ms/data/models/phone.dart';
import 'package:phoneshop_ms/hooks/account_sync.dart';
import 'package:phoneshop_ms/hooks/cart.dart';
import 'package:phoneshop_ms/hooks/favorites.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _phone(int id, {int stock = 5}) => {
  'id': id,
  'name': 'Phone $id',
  'brand': 'Apple',
  'price': 100,
  'stock': stock,
};

http.Response _json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  // What the account holds on the "server"
  late List<int> serverFavorites;
  late List<Map<String, dynamic>> serverCart;
  late int saves;

  late MockClient server;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Cart.instance.clear();
    Favorites.instance.clearAll();
    serverFavorites = [2];
    serverCart = [
      {'id': 2, 'color': '', 'storage': '', 'qty': 3},
      {'id': 1, 'color': '', 'storage': '', 'qty': 1},
    ];
    saves = 0;
    server = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/products')) {
        return _json([_phone(1), _phone(2, stock: 2)]);
      }
      if (path.endsWith('/me/saved') && request.method == 'PUT') {
        saves++;
        final body = jsonDecode(request.body);
        serverFavorites = List<int>.from(body['favorites']);
        serverCart = List<Map<String, dynamic>>.from(body['cart']);
      }
      if (path.endsWith('/me/saved')) {
        return _json({'favorites': serverFavorites, 'cart': serverCart});
      }
      return _json({});
    });
    AccountSync.delay = Duration.zero;
  });

  tearDown(() {
    AccountSync.stop();
    ApiService.token = null;
    Cart.instance.clear();
    Favorites.instance.clearAll();
  });

  test('at login the account\'s ♥ and cart join what is on this phone, and '
      'the result is saved back', () async {
    // On this phone, before logging in
    Favorites.instance.toggle(1);
    Cart.instance.add(
      Phone(
        id: 1,
        name: 'Phone 1',
        brand: 'Apple',
        price: 100,
        stock: 5,
        imageUrl: '',
      ),
      2,
    );

    await http.runWithClient(() async {
      AccountSync.start();
      ApiService.token = 'test';
      await AccountSync.pull();
    }, () => server);

    expect(Favorites.instance.ids, {1, 2});
    // Phone 1: 2 here vs 1 on the account → 2. Phone 2: 3 wanted, only 2 left.
    expect(
      {for (final i in Cart.instance.items) i.phone.id: i.qty},
      {1: 2, 2: 2},
    );
    expect(serverFavorites.toSet(), {1, 2});
    expect(serverCart.length, 2);
  });

  test('changes while logged in are saved; logout saves, then forgets them '
      'on this phone', () async {
    await http.runWithClient(() async {
      ApiService.token = 'test';
      AccountSync.start();
      await AccountSync.pull();
      final before = saves;

      Favorites.instance.toggle(2); // un-♥
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(saves, before + 1);
      expect(serverFavorites, isEmpty);

      Favorites.instance.toggle(1);
      await ApiService.logout();
    }, () => server);

    expect(serverFavorites, [1]); // saved before the token was dropped
    expect(Favorites.instance.ids, isEmpty);
    expect(Cart.instance.isEmpty, isTrue);
  });

  test('offline at login: nothing on this phone is lost', () async {
    Favorites.instance.toggle(7);
    final offline = MockClient((_) async => throw Exception('offline'));
    await http.runWithClient(() async {
      ApiService.token = 'test';
      AccountSync.start();
      await AccountSync.pull();
    }, () => offline);
    expect(Favorites.instance.ids, {7});
  });
}
