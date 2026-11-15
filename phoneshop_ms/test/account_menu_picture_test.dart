import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phoneshop_ms/models/user.dart';
import 'package:phoneshop_ms/widgets/common.dart';
import 'package:phoneshop_ms/widgets/store_menu.dart';

void main() {
  Future<void> pumpMenu(WidgetTester tester, User? user) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        bottomNavigationBar: StoreMenuBar(
          current: StoreFilter.home,
          user: user,
          onSelected: (_) {},
          onTelegram: () {},
          onAccount: () {},
          onOrders: () {},
          onCart: () {},
        ),
      ),
    ),
  );

  User customer(String avatarUrl) => User(
    id: 2,
    name: 'YAYA',
    email: 'yaya@gmail.com',
    role: 'user',
    avatarUrl: avatarUrl,
  );

  testWidgets('Account shows the customer\'s picture once they have one', (
    tester,
  ) async {
    await pumpMenu(tester, customer('http://x/me.png'));

    expect(find.byType(UserAvatar), findsOneWidget);
    expect(find.byIcon(Icons.account_circle_outlined), findsNothing);
    expect(find.text('គណនី'), findsOneWidget);
    expect(tester.getSize(find.byType(UserAvatar)), const Size(26, 26));
  });

  testWidgets('Account keeps the icon without a picture or when logged out', (
    tester,
  ) async {
    await pumpMenu(tester, customer(''));
    expect(find.byIcon(Icons.account_circle_outlined), findsOneWidget);
    expect(find.byType(UserAvatar), findsNothing);

    await pumpMenu(tester, null);
    expect(find.byIcon(Icons.account_circle_outlined), findsOneWidget);
    expect(find.byType(UserAvatar), findsNothing);
  });
}
