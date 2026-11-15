import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:phoneshop_ms/main.dart';
import 'package:phoneshop_ms/models/location.dart';
import 'package:phoneshop_ms/models/phone.dart';
import 'package:phoneshop_ms/screens/cart_screen.dart';
import 'package:phoneshop_ms/screens/product_detail_screen.dart';
import 'package:phoneshop_ms/services/api_service.dart';
import 'package:phoneshop_ms/services/cart.dart';
import 'package:phoneshop_ms/widgets/address_picker.dart';
import 'package:phoneshop_ms/widgets/brand_wordmark.dart';
import 'package:phoneshop_ms/widgets/common.dart';
import 'package:phoneshop_ms/widgets/product_card.dart';
import 'package:phoneshop_ms/widgets/store_menu.dart';

void main() {
  testWidgets('App opens straight into the store', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp(showSplash: false));

    expect(find.byType(BrandWordmark), findsOneWidget);
    // ☰ next to the name, at the top
    expect(find.byTooltip('Menu'), findsOneWidget);
    expect(tester.getCenter(find.byTooltip('Menu')).dy, lessThan(70));
    // Bottom menu: Home | Telegram | Account
    final screenHeight = tester.getSize(find.byType(MaterialApp)).height;
    for (final label in ['ទំព័រដើម', 'Telegram', 'គណនី']) {
      expect(find.text(label), findsOneWidget);
      expect(
        tester.getCenter(find.text(label)).dy,
        greaterThan(screenHeight - 70),
      );
    }
  });

  testWidgets('the bottom menu fits on a narrow phone', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MyApp(showSplash: false));

    expect(tester.takeException(), isNull); // no overflow
    for (final label in ['ទំព័រដើម', 'Telegram', 'គណនី']) {
      final box = tester.getRect(find.text(label));
      expect(box.left, greaterThanOrEqualTo(0));
      expect(box.right, lessThanOrEqualTo(320));
    }
  });

  testWidgets('Account takes a guest straight to the login screen', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp(showSplash: false));

    await tester.tap(find.text('គណនី'));
    await tester.pumpAndSettle();

    expect(find.text('ចូលគណនីរបស់អ្នក'), findsOneWidget);
    expect(find.text('Guest'), findsNothing); // no in-between account page
  });

  testWidgets('side menu lists categories and brands and filters by them', (
    tester,
  ) async {
    StoreFilter? picked;
    final scaffold = GlobalKey<ScaffoldState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          key: scaffold,
          drawer: StoreDrawer(
            menu: const {
              'telegram': 'phoneshop',
              'brands': ['Apple', 'Samsung'],
              'categories': [
                {
                  'id': 1,
                  'name': 'Smartphone',
                  'brands': ['Apple', 'Samsung'],
                },
                {'id': 3, 'name': '2nd Hand', 'brands': []},
              ],
            },
            current: StoreFilter.home,
            onSelected: (f) => picked = f,
          ),
        ),
      ),
    );

    Future<void> open() async {
      scaffold.currentState!.openDrawer();
      await tester.pumpAndSettle();
    }

    await open();
    for (final label in [
      'ម៉ឺនុយ',
      'មើល',
      'ទំព័រដើម',
      'ប្រភេទ',
      'Smartphone',
      '2nd Hand',
      'ម៉ាក',
      'Apple',
      'Samsung',
    ]) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.tap(find.text('2nd Hand'));
    await tester.pumpAndSettle();
    expect(picked, const StoreFilter(section: '2nd Hand', categoryId: 3));
    expect(
      scaffold.currentState!.isDrawerOpen,
      isFalse,
    ); // closes after picking

    await open();
    await tester.tap(find.text('Apple'));
    await tester.pumpAndSettle();
    expect(picked, const StoreFilter(section: 'brands', brand: 'Apple'));

    await open();
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(scaffold.currentState!.isDrawerOpen, isFalse);
  });

  testWidgets('Telegram in the bottom menu uses the Telegram logo', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp(showSplash: false));

    final logo = find.byWidgetPredicate(
      (w) =>
          w is Image &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName == 'assets/images/telegram.jpg',
    );
    expect(logo, findsOneWidget);
    expect(find.byIcon(Icons.send), findsNothing);
    expect(tester.takeException(), isNull); // the asset is bundled and loads
  });

  testWidgets('the menu button opens the side menu', (tester) async {
    await tester.pumpWidget(const MyApp(showSplash: false));

    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();

    expect(find.text('មើល'), findsOneWidget);
  });

  group('Cart', () {
    final phone = Phone(
      id: 1,
      name: 'Test',
      brand: 'X',
      price: 100,
      stock: 3,
      imageUrl: '',
    );

    setUp(Cart.instance.clear);

    test('adds items and totals them', () {
      expect(Cart.instance.add(phone, 2), isTrue);
      expect(Cart.instance.count, 2);
      expect(Cart.instance.total, 200);
    });

    test('refuses more than the stock', () {
      expect(Cart.instance.add(phone, 3), isTrue);
      expect(Cart.instance.add(phone), isFalse);
      expect(Cart.instance.count, 3);
    });

    test('setQty to 0 removes the item', () {
      Cart.instance.add(phone);
      Cart.instance.setQty(Cart.keyFor(phone.id, ''), 0);
      expect(Cart.instance.isEmpty, isTrue);
    });

    test('each colour is its own line but they share the stock', () {
      expect(Cart.instance.add(phone, 2, 'Black'), isTrue);
      expect(Cart.instance.add(phone, 1, 'Blue'), isTrue);
      expect(Cart.instance.items.length, 2);
      expect(Cart.instance.add(phone, 1, 'Black'), isFalse); // stock is 3
      expect(Cart.instance.toOrderItems().last, {
        'product_id': 1,
        'qty': 1,
        'color': 'Blue',
      });
    });
  });

  test('each storage size is its own cart line with its own price', () {
    Cart.instance.clear();
    final phone = Phone(
      id: 9,
      name: 'X',
      brand: '',
      price: 1199,
      stock: 5,
      imageUrl: '',
      storageOptions: const [
        StorageOption('256GB', 1199),
        StorageOption('512GB', 1399),
      ],
    );
    Cart.instance.add(phone, 1, '', '256GB');
    Cart.instance.add(phone, 2, '', '512GB');

    expect(Cart.instance.items.length, 2);
    expect(Cart.instance.total, 1199 + 2 * 1399);
    expect(Cart.instance.toOrderItems().last, {
      'product_id': 9,
      'qty': 2,
      'storage': '512GB',
    });
    expect(
      phone.storageOptions.join(', '),
      '256GB=1199, 512GB=1399',
    ); // admin form text
  });

  testWidgets('detail screen price follows the picked storage', (tester) async {
    ApiService.token = 'test';
    addTearDown(() => ApiService.token = null);
    Cart.instance.clear();
    final phone = Phone(
      id: 10,
      name: 'iPhone',
      brand: 'Apple',
      price: 1199,
      stock: 5,
      imageUrl: '',
      storageOptions: const [
        StorageOption('256GB', 1199),
        StorageOption('512GB', 1399),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(home: ProductDetailScreen(phone: phone)),
    );

    expect(find.text('Storage: 256GB', findRichText: true), findsOneWidget);
    expect(
      find.text('\$1199.00'),
      findsNWidgets(2),
    ); // big price + the 256GB chip

    // The choices sit lower on the page now: bring them into view first
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, '512GB'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '512GB'));
    await tester.pump();
    expect(find.text('\$1399.00'), findsNWidgets(2));

    await tester.tap(find.text('ដាក់ Cart'));
    await tester.pump();
    expect(Cart.instance.items.single.storage, '512GB');
    expect(Cart.instance.total, 1399);
  });

  testWidgets('detail screen adds the picked colour to the cart', (
    tester,
  ) async {
    Cart.instance.clear();
    ApiService.token = 'test';
    addTearDown(() => ApiService.token = null);
    final phone = Phone(
      id: 7,
      name: 'iPhone 15 Pro',
      brand: 'Apple',
      price: 999,
      stock: 5,
      color: 'Natural Titanium, Black, Blue',
      imageUrl: 'http://x/main.jpg',
      colorImageUrls: {'Blue': 'http://x/blue.jpg'},
    );
    Finder pictureOf(String url) =>
        find.byWidgetPredicate((w) => w is PhoneImage && w.url == url);

    await tester.pumpWidget(
      MaterialApp(home: ProductDetailScreen(phone: phone)),
    );

    // The first colour is picked by default; it has no picture of its own, so the main one shows
    expect(
      find.text('ពណ៌: Natural Titanium', findRichText: true),
      findsOneWidget,
    );
    expect(pictureOf('http://x/main.jpg'), findsOneWidget);

    // The choices sit lower on the page now: bring them into view first
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Blue'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Blue'));
    await tester.pumpAndSettle();
    expect(find.text('ពណ៌: Blue', findRichText: true), findsOneWidget);
    expect(pictureOf('http://x/blue.jpg'), findsOneWidget);
    expect(pictureOf('http://x/main.jpg'), findsNothing);
    await tester.tap(find.text('ដាក់ Cart'));
    await tester.pump();

    expect(Cart.instance.items.single.color, 'Blue');
  });

  testWidgets('a guest can look at a phone but must log in to buy it', (
    tester,
  ) async {
    Cart.instance.clear();
    await tester.pumpWidget(
      MaterialApp(
        home: ProductDetailScreen(
          phone: Phone(
            id: 9,
            name: 'Galaxy A55',
            brand: 'Samsung',
            price: 399,
            stock: 3,
            imageUrl: '',
          ),
        ),
      ),
    );
    expect(find.text('Galaxy A55'), findsWidgets); // browsing is open

    await tester.tap(find.text('ដាក់ Cart'));
    await tester.pumpAndSettle();

    expect(find.text('ចូលគណនីរបស់អ្នក'), findsOneWidget);
    expect(Cart.instance.isEmpty, isTrue);
  });

  testWidgets('a guest cannot reach checkout', (tester) async {
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
    await tester.pumpWidget(const MaterialApp(home: CartScreen()));

    await tester.tap(find.text('Checkout'));
    await tester.pumpAndSettle();

    expect(find.text('ចូលគណនីរបស់អ្នក'), findsOneWidget);
    expect(find.text('ព័ត៌មានអ្នកទិញ'), findsNothing);
    Cart.instance.clear();
  });

  testWidgets('checkout asks for the buyer details before ordering', (
    tester,
  ) async {
    ApiService.token = 'test';
    addTearDown(() => ApiService.token = null);
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
    await tester.pumpWidget(const MaterialApp(home: CartScreen()));

    await tester.tap(find.text('Checkout'));
    await tester.pumpAndSettle();

    expect(find.text('ព័ត៌មានអ្នកទិញ'), findsOneWidget);

    // Ordering with an empty form asks for the details first
    await tester.tap(find.text('បញ្ជាទិញ'));
    await tester.pump();
    expect(find.text('សូមបញ្ចូលឈ្មោះ'), findsOneWidget);
    expect(find.text('Email មិនត្រឹមត្រូវ'), findsOneWidget);
    expect(find.text('សូមជ្រើសខេត្ត'), findsOneWidget); // address picker
    Cart.instance.clear();
  });

  testWidgets('address picker builds the address level by level', (
    tester,
  ) async {
    // Fake place lists, so the test doesn't need the API
    const places = {
      '': [
        Location(code: '12', km: 'រាជធានីភ្នំពេញ', en: ''),
        Location(code: '17', km: 'ខេត្តសៀមរាប', en: ''),
      ],
      '12': [Location(code: '1201', km: 'ខណ្ឌចំការមន', en: '')],
      '1201': [Location(code: '120101', km: 'សង្កាត់ទន្លេបាសាក់', en: '')],
      '120101': [Location(code: '12010101', km: 'ភូមិ ១', en: '')],
      '17': [Location(code: '1710', km: 'ក្រុងសៀមរាប', en: '')],
    };
    String? address;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Form(
              child: AddressPicker(
                onChanged: (a) => address = a,
                loadLocations: (parent) async => places[parent] ?? [],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> pick(String name) async {
      await tester.tap(find.text('ជ្រើសរើស').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(name).last);
      await tester.pumpAndSettle();
    }

    expect(find.text('កម្ពុជា'), findsOneWidget); // fixed country
    await pick('រាជធានីភ្នំពេញ');
    await pick('ខណ្ឌចំការមន');
    await pick('សង្កាត់ទន្លេបាសាក់');
    expect(address, isNull); // village still missing
    await pick('ភូមិ ១');
    await tester.enterText(find.byType(TextFormField), 'ផ្ទះ 12, ផ្លូវ 271');
    expect(
      address,
      'ផ្ទះ 12, ផ្លូវ 271, ភូមិ ១, សង្កាត់ទន្លេបាសាក់, ខណ្ឌចំការមន, រាជធានីភ្នំពេញ, កម្ពុជា',
    );

    // Picking another province clears everything below it
    await tester.tap(find.text('រាជធានីភ្នំពេញ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ខេត្តសៀមរាប').last);
    await tester.pumpAndSettle();
    expect(address, isNull);
    expect(find.text('ខណ្ឌចំការមន'), findsNothing);
  });

  testWidgets('the card shows the whole phone picture, not cropped', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 190,
            height: 340,
            child: ProductCard(
              phone: Phone(
                id: 1,
                name: 'S26',
                brand: 'Samsung',
                price: 1369,
                stock: 5,
                imageUrl: 'http://x/a.png',
              ),
              onTap: () {},
              onAddToCart: () {},
            ),
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.fit, BoxFit.contain);

    // It keeps a margin inside the picture area of the card
    final card = tester.getRect(find.byType(ProductCard));
    final picture = tester.getRect(find.byType(Image));
    expect(picture.left, greaterThan(card.left + 10));
    expect(picture.right, lessThan(card.right - 10));
  });

  group('ProductCard', () {
    test('discount label keeps at most 2 decimals', () {
      expect(
        discountLabel(
          Phone(
            id: 1,
            name: 'a',
            brand: '',
            price: 10,
            oldPrice: 15,
            imageUrl: '',
          ).discountPercent,
        ),
        '%33.33',
      );
      expect(
        discountLabel(
          Phone(
            id: 1,
            name: 'a',
            brand: '',
            price: 20,
            oldPrice: 25,
            imageUrl: '',
          ).discountPercent,
        ),
        '%20',
      );
    });

    // Same height the store grid uses; a narrow phone column and a wide one
    for (final width in [170.0, 230.0]) {
      testWidgets('fits in a ${width.toInt()}px column without overflow', (
        tester,
      ) async {
        final phone = Phone(
          id: 1,
          name: 'កាសខ្សែសម្រាប់ iPhone 5 ដល់ 14 Pro Max GENUINE Apple EarPods',
          brand: 'Apple',
          price: 20,
          oldPrice: 25,
          condition: '98%',
          stock: 85,
          imageUrl: '',
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SizedBox(
                width: width,
                height: 340,
                child: ProductCard(
                  phone: phone,
                  onTap: () {},
                  onAddToCart: () {},
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull); // no RenderFlex overflow
        expect(find.text('%20'), findsOneWidget);
        expect(find.text('98%'), findsOneWidget);
        expect(find.text('នៅសល់ 85'), findsOneWidget);
      });
    }
  });
}
