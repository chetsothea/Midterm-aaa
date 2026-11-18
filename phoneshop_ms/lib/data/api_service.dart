import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'models/customer.dart';
import 'models/live.dart';
import 'models/location.dart';
import 'models/order.dart';
import 'models/phone.dart';
import 'models/review.dart';
import 'models/user.dart';
import 'google_auth.dart';
import 'mock_backend.dart';
import 'models/payment_account.dart';
import 'session_store.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

class ApiService {
  // ទូរស័ព្ទពិត: ប្រាប់ IP របស់កុំព្យូទ័រពេល run, ឧ.
  //   flutter run --dart-define=API_HOST=http://10.1.1.236:8000
  // (10.0.2.2 ដំណើរការតែលើ Android Emulator ប៉ុណ្ណោះ)
  static const _hostFromRun = String.fromEnvironment('API_HOST');

  static String get host => _foundHost ?? _defaultHost;

  static String get _defaultHost {
    // Only for phones: Chrome on this computer always uses 127.0.0.1, so the web
    // keeps working when the Wi-Fi IP changes
    if (_hostFromRun.isNotEmpty) return _hostFromRun;
    // Android Emulator ប្រើ 10.0.2.2 ដើម្បីហៅ localhost របស់កុំព្យូទ័រ
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }

  // The address that answered when the app started (Android only)
  static String? _foundHost;

  // On Android the same build may run on the emulator or on a real phone, and they
  // reach the computer differently. Ask every address at once and keep the first
  // that answers:
  //   - API_HOST from `flutter run --dart-define` (a phone on the same Wi-Fi)
  //   - 127.0.0.1: a phone on USB after `adb reverse tcp:8000 tcp:8000`
  //   - 10.0.2.2: the Android Emulator
  static Future<void> findHost() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final candidates = {
      if (_hostFromRun.isNotEmpty) _hostFromRun,
      'http://127.0.0.1:8000',
      'http://10.0.2.2:8000',
    };
    final winner = Completer<String?>();
    var left = candidates.length;
    for (final candidate in candidates) {
      http
          .get(Uri.parse('$candidate/api/menu'))
          .timeout(const Duration(seconds: 3))
          .then((r) => r.statusCode == 200, onError: (_) => false)
          .then((ok) {
            left--;
            if (ok && !winner.isCompleted) winner.complete(candidate);
            if (left == 0 && !winner.isCompleted) winner.complete(null);
          });
    }
    // None answered: keep the default, so the error shown names a real address
    _foundHost = await winner.future;
  }

  static String get baseUrl => '$host/api';

  static String? token;
  static User? currentUser;

  static Map<String, String> get _headers => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  // Decodes the body and turns Laravel error responses into a readable message
  static dynamic _handle(http.Response response) {
    final body = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }
    // Logged in, but the server no longer accepts the token (it expired after
    // 30 days, or was revoked): forget it, so the app shows a guest again
    if (response.statusCode == 401 && token != null) {
      _forgetSession();
      throw ApiException(
        'សូម Login ម្តងទៀត (Session ផុតកំណត់) / Please log in again',
      );
    }
    if (body is Map) {
      final errors = body['errors'];
      if (errors is Map && errors.isNotEmpty) {
        throw ApiException((errors.values.first as List).first.toString());
      }
      if (body['message'] != null) throw ApiException(body['message']);
    }
    throw ApiException('Server error (${response.statusCode})');
  }

  static Future<dynamic> _get(
    String path, {
    Map<String, String> extra = const {},
  }) async {
    // Mock mode answers from the bundled catalogue (data/mock_backend.dart)
    if (MockBackend.enabled) {
      final data = await MockBackend.get(path);
      if (data == null) throw ApiException(_mockOnly);
      return data;
    }
    return _handle(
      await http.get(
        Uri.parse('$baseUrl$path'),
        headers: {..._headers, ...extra},
      ),
    );
  }

  static Future<dynamic> _post(
    String path, [
    Map<String, dynamic>? data,
    Map<String, String> extra = const {},
  ]) async {
    if (MockBackend.enabled) {
      if (path == '/login') {
        final session = MockBackend.login(
          '${data?['email'] ?? ''}',
          '${data?['password'] ?? ''}',
        );
        if (session != null) return session;
        throw ApiException('Mock mode: use user@phoneshop.com / user123');
      }
      throw ApiException(_mockOnly);
    }
    return _handle(
      await http.post(
        Uri.parse('$baseUrl$path'),
        headers: {..._headers, ...extra},
        body: jsonEncode(data ?? {}),
      ),
    );
  }

  static const _mockOnly =
      'Mock mode: this needs the real shop server (run without MOCK_DATA)';

  static Future<dynamic> _put(String path, Map<String, dynamic> data) async =>
      _handle(
        await http.put(
          Uri.parse('$baseUrl$path'),
          headers: _headers,
          body: jsonEncode(data),
        ),
      );

  // ---------- Auth ----------

  static Future<User> _saveSession(Map<String, dynamic> data) async {
    token = data['token'];
    currentUser = User.fromJson(data['user']);
    // Remembered securely, so the next launch is already logged in
    await SessionStore.save(token!, Map<String, dynamic>.from(data['user']));
    return currentUser!;
  }

  static void _forgetSession() {
    token = null;
    currentUser = null;
    SessionStore.clear();
  }

  // Called once at launch: logs back in with the saved token (instantly,
  // from the saved details), then checks it with the server in the
  // background; an expired token is forgotten.
  static Future<void> restoreSession() async {
    if (MockBackend.enabled) return;
    final saved = await SessionStore.read();
    if (saved == null) return;
    token = saved.$1;
    try {
      currentUser = User.fromJson(saved.$2);
    } catch (_) {
      _forgetSession();
      return;
    }
    // Fresh details (name, picture…) without holding up the launch
    _get('/me')
        .then((data) {
          if (token == null || data is! Map) return;
          currentUser = User.fromJson(Map<String, dynamic>.from(data));
          SessionStore.saveUser(Map<String, dynamic>.from(data));
        })
        .catchError((_) {});
  }

  static Future<User> login(String email, String password) async =>
      _saveSession(
        await _post('/login', {'email': email, 'password': password}),
      );

  static bool get isLoggedIn => token != null;

  // The logged-in customer's own details, password (kept when empty) and picture
  static Future<User> updateProfile({
    required String name,
    required String email,
    required String phone,
    required String address,
    String password = '',
    XFile? avatar,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/profile'),
    );
    request.headers.addAll({
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    });
    request.fields.addAll({
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      if (password.isNotEmpty) 'password': password,
    });
    if (avatar != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'avatar',
          await avatar.readAsBytes(),
          filename: avatar.name,
        ),
      );
    }
    final response = await http.Response.fromStream(await request.send());
    final data = Map<String, dynamic>.from(_handle(response));
    await SessionStore.saveUser(data);
    return currentUser = User.fromJson(data);
  }

  // '' when the shop hasn't set up Google login (GOOGLE_CLIENT_ID in the API's .env)
  static Future<String> fetchGoogleClientId() async =>
      ((await _get('/auth/google-config'))['client_id'] ?? '') as String;

  // The API checks the Google ID token, then logs in (or creates) the matching account
  static Future<User> loginWithGoogle(String idToken) async =>
      _saveSession(await _post('/auth/google', {'id_token': idToken}));

  static Future<User> register(
    String name,
    String email,
    String phone,
    String address,
    String password,
  ) async => _saveSession(
    await _post('/register', {
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'password': password,
    }),
  );

  static Future<void> logout() async {
    try {
      await _post('/logout');
    } catch (_) {
      // Token may already be invalid; log out locally anyway
    }
    _forgetSession();
    await GoogleAuth.signOut();
  }

  // ---------- Products ----------

  static Future<List<Phone>> fetchPhones({
    String search = '',
    String brand = '',
    int? categoryId,
  }) async {
    final query = Uri(
      queryParameters: {
        if (search.isNotEmpty) 'search': search,
        if (brand.isNotEmpty) 'brand': brand,
        if (categoryId != null) 'category_id': '$categoryId',
      },
    ).query;
    final List data = await _get('/products${query.isEmpty ? '' : '?$query'}');
    return data.map((e) => Phone.fromJson(e)).toList();
  }

  // The best-selling phones in stock with how many were sold, best first
  // (topped up with featured phones, sold = 0, while there are few sales)
  static Future<List<(Phone, int)>> fetchBestSellers() async {
    final List data = await _get('/best-sellers');
    return [
      for (final e in data)
        (Phone.fromJson(e), int.tryParse('${e['sold'] ?? 0}') ?? 0),
    ];
  }

  // {brands: [...], categories: [{id, name, brands: [...]}]} for the store menu
  static Future<Map<String, dynamic>> fetchMenu() async =>
      Map<String, dynamic>.from(await _get('/menu'));

  // Cambodia's provinces ('') → districts → communes → villages, one level per call.
  // Cached: place names don't change while the app is open.
  static final Map<String, List<Location>> _locationCache = {};

  static Future<List<Location>> fetchLocations([String parent = '']) async {
    final cached = _locationCache[parent];
    if (cached != null) return cached;
    final List data = await _get(
      '/locations${parent.isEmpty ? '' : '?parent=$parent'}',
    );
    return _locationCache[parent] = data
        .map((e) => Location.fromJson(e))
        .toList();
  }

  static Future<List<Map<String, dynamic>>> fetchCategories() async {
    final List data = await _get('/categories');
    return data.cast<Map<String, dynamic>>();
  }

  // ---------- Orders (customer) ----------

  // Orders placed without logging in: order id → its access token.
  // Kept while the app is open, so the guest can still see, pay and cancel them.
  static final Map<int, String> guestOrderTokens = {};

  // Guest orders go through /guest/... with the order's own token
  static String _orderPath(int orderId) => guestOrderTokens.containsKey(orderId)
      ? '/guest/orders/$orderId'
      : '/orders/$orderId';

  static Map<String, String> _orderHeaders(int orderId) => {
    if (guestOrderTokens[orderId] != null)
      'X-Order-Token': guestOrderTokens[orderId]!,
  };

  static Future<Order> placeOrder({
    required List<Map<String, dynamic>> items,
    required String paymentMethod,
    required String customerName,
    required String customerEmail,
    required String phone,
    required String address,
  }) async {
    final data = await _post('/orders', {
      'customer_name': customerName,
      'customer_email': customerEmail,
      'phone': phone,
      'address': address,
      'payment_method': paymentMethod,
      'items': items,
    });
    return Order.fromJson(data);
  }

  // The account's orders, plus any placed as a guest in this session (newest first)
  static Future<List<Order>> fetchMyOrders() async {
    final orders = <Order>[];
    if (isLoggedIn) {
      final List data = await _get('/orders');
      orders.addAll(data.map((e) => Order.fromJson(e)));
    }
    for (final id in guestOrderTokens.keys) {
      orders.add(
        Order.fromJson(await _get(_orderPath(id), extra: _orderHeaders(id))),
      );
    }
    orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return orders;
  }

  // "I have paid": the admin then checks the shop's bank app and confirms it.
  // The transaction ID is optional; it only helps the admin find the payment.
  static Future<Order> submitPayment(
    int orderId, [
    String transactionRef = '',
  ]) async => Order.fromJson(
    await _post('${_orderPath(orderId)}/pay', {
      if (transactionRef.trim().isNotEmpty)
        'transaction_ref': transactionRef.trim(),
    }, _orderHeaders(orderId)),
  );

  // Asks the server to check with Bakong. Returns the order (paid once the
  // money arrived) and whether Bakong could not be reached just now.
  static Future<(Order, bool)> checkPayment(int orderId) async {
    final data = Map<String, dynamic>.from(
      await _get(
        '${_orderPath(orderId)}/check-payment',
        extra: _orderHeaders(orderId),
      ),
    );
    return (Order.fromJson(data), data['bakong_down'] == true);
  }

  // One order with its latest tracking (the customer's own, or a guest order via its token)
  static Future<Order> fetchOrder(int orderId) async => Order.fromJson(
    await _get(_orderPath(orderId), extra: _orderHeaders(orderId)),
  );

  // The customer confirms the parcel arrived
  static Future<Order> confirmReceived(int orderId) async => Order.fromJson(
    await _post(
      '${_orderPath(orderId)}/received',
      null,
      _orderHeaders(orderId),
    ),
  );

  static Future<Order> cancelOrder(int orderId) async => Order.fromJson(
    await _post('${_orderPath(orderId)}/cancel', null, _orderHeaders(orderId)),
  );

  // Takes a cancelled order off the customer's own list (the shop keeps it)
  static Future<void> hideOrder(int orderId) async => _handle(
    await http.delete(Uri.parse('$baseUrl/orders/$orderId'), headers: _headers),
  );

  static Future<Map<String, dynamic>> fetchPaymentInfo() async =>
      Map<String, dynamic>.from(await _get('/payment-info'));

  // ---------- Admin ----------

  // Stock level the admin is warned at; kept up to date by the dashboard,
  // which is the first thing an admin sees
  static int lowStockThreshold = 3;

  static Future<Map<String, dynamic>> fetchDashboard() async {
    final stats = Map<String, dynamic>.from(await _get('/admin/dashboard'));
    lowStockThreshold = stats['low_stock_threshold'] ?? lowStockThreshold;
    return stats;
  }

  static Future<List<Customer>> fetchCustomers() async {
    final List data = await _get('/admin/customers');
    return data.map((e) => Customer.fromJson(e)).toList();
  }

  // [password] empty = keep the customer's current password
  static Future<void> updateCustomer(
    int customerId, {
    required String name,
    required String email,
    required String phone,
    required String address,
    String password = '',
  }) async {
    await _put('/admin/customers/$customerId', {
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      if (password.isNotEmpty) 'password': password,
    });
  }

  // Disable or re-enable a customer's account
  static Future<void> setCustomerBlocked(int customerId, bool blocked) async {
    await _put('/admin/customers/$customerId/blocked', {'blocked': blocked});
  }

  static Future<void> deleteCustomer(int customerId) async => _handle(
    await http.delete(
      Uri.parse('$baseUrl/admin/customers/$customerId'),
      headers: _headers,
    ),
  );

  static Future<void> deleteOrder(int orderId) async => _handle(
    await http.delete(
      Uri.parse('$baseUrl/admin/orders/$orderId'),
      headers: _headers,
    ),
  );

  // Orders placed after [after]: {latest_id, count, orders (newest 5)}.
  // Without [after], only latest_id, as a starting point.
  static Future<Map<String, dynamic>> fetchNewOrders({int? after}) async =>
      Map<String, dynamic>.from(
        await _get('/admin/orders/new${after == null ? '' : '?after=$after'}'),
      );

  static Future<List<Order>> fetchAllOrders({String status = ''}) async {
    final List data = await _get(
      '/admin/orders${status.isEmpty ? '' : '?status=$status'}',
    );
    return data.map((e) => Order.fromJson(e)).toList();
  }

  // [location] and [note] describe the tracking step a status change creates
  static Future<Order> updateOrder(
    int orderId, {
    String? status,
    String? paymentStatus,
    String? courier,
    String? trackingNumber,
    String? location,
    String? note,
  }) async => Order.fromJson(
    await _put('/admin/orders/$orderId', {
      'status': ?status,
      'payment_status': ?paymentStatus,
      'courier': ?courier,
      'tracking_number': ?trackingNumber,
      'location': ?location,
      'note': ?note,
    }),
  );

  // A delivery update without a status change, e.g. "ដល់សាខា បាត់ដំបង"
  static Future<Order> addTracking(
    int orderId, {
    String location = '',
    String note = '',
  }) async => Order.fromJson(
    await _post('/admin/orders/$orderId/tracking', {
      if (location.isNotEmpty) 'location': location,
      if (note.isNotEmpty) 'note': note,
    }),
  );

  static Future<void> markReceivedSeen() async {
    await _post('/admin/orders/received-seen');
  }

  // Corrects a step typed wrongly; an empty value clears that field
  static Future<Order> updateTracking(
    int orderId,
    int stepId, {
    String location = '',
    String note = '',
  }) async => Order.fromJson(
    await _put('/admin/orders/$orderId/tracking/$stepId', {
      'location': location,
      'note': note,
    }),
  );

  // Create when id is null, otherwise update. Sent as multipart so an image can be attached.
  static Future<Phone> saveProduct(
    Map<String, String> fields, {
    int? id,
    XFile? image,
    Map<String, XFile> colorImages = const {},
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/admin/products${id == null ? '' : '/$id'}'),
    );
    request.headers.addAll({
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    });
    request.fields.addAll(fields);
    if (image != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          await image.readAsBytes(),
          filename: image.name,
        ),
      );
    }
    // One picture per colour: color_images[Blue], color_images[Red], ...
    for (final entry in colorImages.entries) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'color_images[${entry.key}]',
          await entry.value.readAsBytes(),
          filename: entry.value.name,
        ),
      );
    }
    final response = await http.Response.fromStream(await request.send());
    return Phone.fromJson(_handle(response));
  }

  static Future<void> deleteProduct(int id) async => _handle(
    await http.delete(
      Uri.parse('$baseUrl/admin/products/$id'),
      headers: _headers,
    ),
  );

  // ---------- Bank accounts for KHQR payment ----------

  static Future<List<PaymentAccount>> fetchPaymentAccounts() async {
    final List data = await _get('/admin/payment-accounts');
    return [
      for (final e in data)
        PaymentAccount.fromJson(Map<String, dynamic>.from(e)),
    ];
  }

  // Create when id is null, otherwise update. Multipart, so a QR can be attached.
  static Future<PaymentAccount> savePaymentAccount(
    Map<String, String> fields, {
    int? id,
    XFile? qr,
    bool removeQr = false,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/admin/payment-accounts${id == null ? '' : '/$id'}'),
    );
    request.headers.addAll({
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    });
    request.fields.addAll(fields);
    if (removeQr) request.fields['remove_qr'] = '1';
    if (qr != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'qr_image',
          await qr.readAsBytes(),
          filename: qr.name,
        ),
      );
    }
    final response = await http.Response.fromStream(await request.send());
    return PaymentAccount.fromJson(
      Map<String, dynamic>.from(_handle(response)),
    );
  }

  static Future<void> deletePaymentAccount(int id) async => _handle(
    await http.delete(
      Uri.parse('$baseUrl/admin/payment-accounts/$id'),
      headers: _headers,
    ),
  );

  // ---------- Live shopping ----------

  static Future<LiveSession> fetchLive() async =>
      LiveSession.fromJson(Map<String, dynamic>.from(await _get('/live')));

  // Comments, oldest first; [after] = the last id already shown, to get only new ones
  static Future<List<LiveComment>> fetchLiveComments({int after = 0}) async {
    final data = await _get(
      '/live/comments${after > 0 ? '?after=$after' : ''}',
    );
    return [
      for (final c in data as List)
        LiveComment.fromJson(Map<String, dynamic>.from(c)),
    ];
  }

  static Future<LiveComment> postLiveComment(String message) async =>
      LiveComment.fromJson(
        Map<String, dynamic>.from(
          await _post('/live/comments', {'message': message}),
        ),
      );

  // Admin: start / update the live (empty [youtube] ends it)
  static Future<LiveSession> updateLive({
    required String youtube,
    required String title,
    required List<int> productIds,
  }) async => LiveSession.fromJson(
    Map<String, dynamic>.from(
      await _put('/admin/live', {
        'youtube': youtube,
        'title': title,
        'product_ids': productIds,
      }),
    ),
  );

  static Future<void> deleteLiveComment(int id) async => _handle(
    await http.delete(
      Uri.parse('$baseUrl/admin/live/comments/$id'),
      headers: _headers,
    ),
  );

  // ---------- Reviews ----------

  static Future<ReviewSummary> fetchReviews(int productId) async =>
      ReviewSummary.fromJson(
        Map<String, dynamic>.from(await _get('/products/$productId/reviews')),
      );

  // Only works for a customer who received this phone; writing again edits it
  static Future<Review> postReview(
    int productId, {
    required int rating,
    String comment = '',
  }) async => Review.fromJson(
    Map<String, dynamic>.from(
      await _post('/products/$productId/reviews', {
        'rating': rating,
        'comment': comment,
      }),
    ),
  );
}
