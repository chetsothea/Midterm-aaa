import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phoneshop_ms/screens/admin/admin_dashboard_tab.dart';
import 'package:phoneshop_ms/services/api_service.dart';
import 'package:phoneshop_ms/widgets/dashboard_charts.dart';

Map<String, dynamic> stats({
  List<Map<String, dynamic>>? revenue,
  List<Map<String, dynamic>>? topProducts,
}) => {
  'total_products': 6,
  'low_stock': 1,
  'low_stock_threshold': 3,
  'total_customers': 2,
  'total_orders': 3,
  'pending_orders': 1,
  'verifying_payments': 0,
  'revenue': 3368,
  'revenue_by_day':
      revenue ??
      [
        for (var d = 26; d <= 31; d++) {'date': '2026-10-$d', 'total': 0},
        {'date': '2026-11-01', 'total': 3368},
      ],
  'orders_by_status': [
    {'status': 'pending', 'count': 1},
    {'status': 'confirmed', 'count': 1},
    {'status': 'shipping', 'count': 0},
    {'status': 'delivered', 'count': 1},
    {'status': 'cancelled', 'count': 0},
  ],
  'top_products':
      topProducts ??
      [
        {'name': 'iPhone 15 Pro', 'qty': 2},
        {'name': 'A phone with a really very long name indeed', 'qty': 1},
      ],
};

Future<void> pumpDashboard(
  WidgetTester tester,
  Map<String, dynamic> body,
) async {
  await http.runWithClient(
    () async {
      ApiService.token = 'test';
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AdminDashboardTab())),
      );
      await tester.pumpAndSettle();
      ApiService.token = null;
    },
    () => MockClient(
      (_) async => http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    ),
  );
}

void main() {
  test('compact money stays short for the column labels', () {
    expect(compactMoney(950), '\$950');
    expect(compactMoney(1000), '\$1k');
    expect(compactMoney(3368), '\$3.4k');
  });

  testWidgets('dashboard shows all three charts on a phone, without overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 1500));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpDashboard(tester, stats());

    expect(
      tester.takeException(),
      isNull,
    ); // no RenderFlex overflow, tiles included
    expect(find.text('ចំណូល 7 ថ្ងៃចុងក្រោយ'), findsOneWidget);
    expect(find.text('Order តាមស្ថានភាព'), findsOneWidget);
    expect(find.text('ទូរស័ព្ទលក់ដាច់បំផុត'), findsOneWidget);

    expect(
      find.text('\$3.4k'),
      findsOneWidget,
    ); // only the best day is labelled
    expect(find.text('1/11'), findsOneWidget);
    expect(find.text('បានទទួល'), findsOneWidget); // status label
    expect(find.text('iPhone 15 Pro'), findsOneWidget);
  });

  testWidgets('the low stock tile only shows the count, it cannot be edited', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 1500));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpDashboard(tester, stats());

    expect(find.text('ស្តុកជិតអស់ (≤3)'), findsOneWidget);
    expect(find.byIcon(Icons.edit), findsNothing);

    await tester.tap(find.text('ស្តុកជិតអស់ (≤3)'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('the customers tile opens the list of registered customers', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 1500));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final customers = [
      {
        'id': 3,
        'name': 'Chetsothea',
        'email': 'thea@gmail.com',
        'phone': '092838387',
        'address': 'ភូមិ ១, ខេត្តបាត់ដំបង, កម្ពុជា',
        'created_at': '2026-11-01T02:41:07.000000Z',
        'orders_count': 2,
      },
      // Signed up with Google: no phone or address yet
      {
        'id': 2,
        'name': 'Dara',
        'email': 'dara@gmail.com',
        'phone': null,
        'address': null,
        'created_at': '2026-10-21T02:57:07.000000Z',
        'orders_count': 0,
      },
    ];

    await http.runWithClient(
      () async {
        ApiService.token = 'test';
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: AdminDashboardTab())),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('អតិថិជន'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('សរុប 2 នាក់'), findsOneWidget);
        expect(find.text('Chetsothea'), findsOneWidget);
        expect(find.text('thea@gmail.com'), findsOneWidget);
        expect(find.text('092838387'), findsOneWidget);
        expect(find.text('2 Order'), findsOneWidget);
        expect(find.text('Dara'), findsOneWidget);
        expect(find.text('0 Order'), findsOneWidget);
        ApiService.token = null;
      },
      () => MockClient((request) async {
        final body = request.url.path.endsWith('/customers')
            ? customers
            : stats();
        return http.Response(
          jsonEncode(body),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
  });

  testWidgets('"what needs doing now" lists only what is waiting', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpDashboard(tester, stats()); // 1 pending, 0 to verify
    expect(tester.takeException(), isNull);
    expect(find.text('ត្រូវធ្វើឥឡូវ'), findsOneWidget);
    expect(find.text('Order ថ្មីរង់ចាំបញ្ជាក់'), findsOneWidget);
    expect(find.text('ការបង់ប្រាក់រង់ចាំផ្ទៀងផ្ទាត់'), findsNothing);
    expect(find.text('គ្មានការងារត្រូវធ្វើទេ'), findsNothing);
  });

  testWidgets('with nothing waiting it says all is done', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 1500));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpDashboard(tester, {...stats(), 'pending_orders': 0});
    expect(find.text('គ្មានការងារត្រូវធ្វើទេ'), findsOneWidget);
    expect(find.text('Order ថ្មីរង់ចាំបញ្ជាក់'), findsNothing);
  });

  testWidgets('tapping a day shows its full amount', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 1500));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpDashboard(tester, stats());

    await tester.tap(find.byTooltip('1/11: \$3368.00'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('1/11: \$3368.00'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });

  testWidgets('charts with no data say so instead of drawing empty axes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 1500));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpDashboard(
      tester,
      stats(
        revenue: [
          for (var d = 1; d <= 7; d++) {'date': '2026-11-0$d', 'total': 0},
        ],
        topProducts: [],
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('មិនទាន់មានទិន្នន័យ'), findsNWidgets(2));
  });
}
