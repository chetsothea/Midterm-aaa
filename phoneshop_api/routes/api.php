<?php

use App\Http\Controllers\Api\Admin\OrderController as AdminOrderController;
use App\Http\Controllers\Api\Admin\PaymentAccountController;
use App\Http\Controllers\Api\Admin\ReportController;
use App\Http\Controllers\Api\Admin\StaffController;
use App\Http\Controllers\Api\Admin\VoucherController;
use App\Http\Controllers\Api\Admin\WarrantyController;
use App\Http\Controllers\Api\AddressController;
use App\Http\Controllers\Api\NoticeController;
use App\Http\Controllers\Api\PasswordResetController;
use App\Http\Controllers\Api\SavedListsController;
use App\Http\Controllers\Api\StockAlertController;
use App\Http\Controllers\Api\TradeInController;
use App\Http\Controllers\Api\Admin\ProductController as AdminProductController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\LiveController;
use App\Http\Controllers\Api\LocationController;
use App\Http\Controllers\Api\OrderController;
use App\Http\Controllers\Api\ProductController;
use App\Http\Controllers\Api\ReviewController;
use App\Http\Middleware\AdminOnly;
use App\Http\Middleware\LogTeamActivity;
use App\Http\Middleware\ShopTeam;
use Illuminate\Support\Facades\Route;

Route::post('/register', [AuthController::class, 'register'])->middleware('throttle:register');
Route::post('/login', [AuthController::class, 'login'])->middleware('throttle:login');
// Forgot password: a code by e-mail, then code + new password
Route::post('/password/code', [PasswordResetController::class, 'send'])->middleware('throttle:5,10');
Route::post('/password/reset', [PasswordResetController::class, 'reset'])->middleware('throttle:10,10');
Route::get('/auth/google-config', [AuthController::class, 'googleConfig']);
Route::post('/auth/google', [AuthController::class, 'google'])->middleware('throttle:login');

// Guests can only browse the store; buying needs an account
Route::get('/products', [ProductController::class, 'index']);
Route::get('/best-sellers', [ProductController::class, 'bestSellers']);
Route::get('/products/{product}', [ProductController::class, 'show']);
Route::get('/products/{product}/reviews', [ReviewController::class, 'index']);
Route::get('/categories', [ProductController::class, 'categories']);
Route::get('/menu', [ProductController::class, 'menu']);
Route::get('/payment-info', [ProductController::class, 'paymentInfo']);
Route::get('/locations', [LocationController::class, 'index']);

// Live shopping: anyone can watch and read the comments; commenting needs an account
Route::get('/live', [LiveController::class, 'show']);
Route::get('/live/comments', [LiveController::class, 'comments']);

// Orders placed as a guest before accounts were required. Their access_token (the
// X-Order-Token header) still lets that guest see, pay and cancel that one order.
Route::get('/guest/orders/{order}', [OrderController::class, 'show']);
Route::post('/guest/orders/{order}/pay', [OrderController::class, 'pay']);
Route::get('/guest/orders/{order}/check-payment', [OrderController::class, 'checkPayment'])->middleware('throttle:40,1');
Route::post('/guest/orders/{order}/cancel', [OrderController::class, 'cancel']);
Route::post('/guest/orders/{order}/received', [OrderController::class, 'received']);

Route::middleware('auth:sanctum')->group(function () {
    Route::get('/me', [AuthController::class, 'me']);
    Route::delete('/me', [AuthController::class, 'deleteAccount'])->middleware('throttle:5,1');
    Route::get('/me/saved', [SavedListsController::class, 'show']);
    Route::put('/me/saved', [SavedListsController::class, 'update'])->middleware('throttle:60,1');
    Route::post('/logout', [AuthController::class, 'logout']);
    // POST because PHP doesn't parse multipart bodies on PUT
    Route::post('/profile', [AuthController::class, 'updateProfile']);

    Route::get('/orders', [OrderController::class, 'index']);
    Route::post('/orders', [OrderController::class, 'store']);
    Route::get('/orders/{order}', [OrderController::class, 'show']);
    Route::post('/orders/{order}/pay', [OrderController::class, 'pay']);
    Route::get('/orders/{order}/check-payment', [OrderController::class, 'checkPayment'])->middleware('throttle:40,1');
    Route::post('/orders/{order}/cancel', [OrderController::class, 'cancel']);
    Route::post('/orders/quote', [OrderController::class, 'quote'])->middleware('throttle:60,1');
    Route::delete('/orders/{order}', [OrderController::class, 'hide']);
    Route::post('/orders/{order}/received', [OrderController::class, 'received']);

    Route::post('/products/{product}/reviews', [ReviewController::class, 'store'])->middleware('throttle:10,1');

    // Delivery addresses besides the account's own
    Route::get('/addresses', [AddressController::class, 'index']);
    Route::post('/addresses', [AddressController::class, 'store'])->middleware('throttle:20,1');
    Route::delete('/addresses/{address}', [AddressController::class, 'destroy']);

    // "Tell me when it's back in stock"
    Route::get('/stock-alerts', [StockAlertController::class, 'index']);
    Route::post('/products/{product}/stock-alert', [StockAlertController::class, 'store'])->middleware('throttle:30,1');
    Route::delete('/products/{product}/stock-alert', [StockAlertController::class, 'destroy']);

    // The 🔔 inbox
    Route::get('/notices', [NoticeController::class, 'index']);
    Route::post('/notices/read', [NoticeController::class, 'readAll']);

    // Trade-in: the customer's own requests
    Route::get('/trade-ins', [TradeInController::class, 'mine']);
    Route::post('/trade-ins', [TradeInController::class, 'store'])->middleware('throttle:10,1');
    Route::post('/trade-ins/{tradeIn}/accept', [TradeInController::class, 'accept']);
    Route::post('/trade-ins/{tradeIn}/decline', [TradeInController::class, 'decline']);
    Route::post('/trade-ins/{tradeIn}/cancel', [TradeInController::class, 'cancel']);
    Route::post('/live/comments', [LiveController::class, 'postComment'])->middleware('throttle:20,1');

    // Admin and staff: the day-to-day work on orders
    Route::middleware([ShopTeam::class, LogTeamActivity::class])->prefix('admin')->group(function () {
        Route::get('/orders', [AdminOrderController::class, 'index']);
        Route::post('/orders/received-seen', [AdminOrderController::class, 'markReceivedSeen']);
        Route::get('/orders/new', [AdminOrderController::class, 'newOrders']);
        Route::put('/orders/{order}', [AdminOrderController::class, 'update']);
        Route::post('/orders/{order}/tracking', [AdminOrderController::class, 'addTracking']);
        Route::put('/orders/{order}/tracking/{tracking}', [AdminOrderController::class, 'updateTracking']);
        Route::put('/order-items/{item}/imeis', [WarrantyController::class, 'setImeis']);
        Route::get('/warranty/{imei}', [WarrantyController::class, 'lookup']);
        Route::put('/live', [LiveController::class, 'update']);
        Route::delete('/live/comments/{comment}', [LiveController::class, 'deleteComment']);
    });

    // Admin only: money, prices, settings and accounts
    Route::middleware([AdminOnly::class, LogTeamActivity::class])->prefix('admin')->group(function () {
        Route::get('/activity', [StaffController::class, 'activity']);
        Route::get('/dashboard', [AdminOrderController::class, 'dashboard']);
        Route::get('/reports/sales', [ReportController::class, 'sales']);
        Route::get('/reports/sales.csv', [ReportController::class, 'salesCsv']);
        Route::get('/customers', [AdminOrderController::class, 'customers']);
        Route::put('/customers/{user}', [AdminOrderController::class, 'updateCustomer']);
        Route::put('/customers/{user}/blocked', [AdminOrderController::class, 'setCustomerBlocked']);
        Route::delete('/customers/{user}', [AdminOrderController::class, 'deleteCustomer']);
        Route::get('/staff', [StaffController::class, 'index']);
        Route::post('/staff', [StaffController::class, 'store']);
        Route::put('/staff/{user}', [StaffController::class, 'update']);
        Route::delete('/staff/{user}', [StaffController::class, 'destroy']);
        Route::get('/payment-accounts', [PaymentAccountController::class, 'index']);
        Route::post('/payment-accounts', [PaymentAccountController::class, 'store']);
        Route::post('/payment-accounts/{paymentAccount}', [PaymentAccountController::class, 'update']);
        Route::delete('/payment-accounts/{paymentAccount}', [PaymentAccountController::class, 'destroy']);
        Route::put('/settings/low-stock', [AdminOrderController::class, 'updateLowStockThreshold']);
        Route::get('/vouchers', [VoucherController::class, 'index']);
        Route::post('/vouchers', [VoucherController::class, 'store']);
        Route::put('/vouchers/{voucher}', [VoucherController::class, 'update']);
        Route::delete('/vouchers/{voucher}', [VoucherController::class, 'destroy']);
        Route::put('/settings/shipping', [VoucherController::class, 'updateShipping']);
        Route::put('/settings/khr-rate', [VoucherController::class, 'updateKhrRate']);
        Route::get('/reviews', [ReviewController::class, 'adminIndex']);
        Route::put('/reviews/{review}/hidden', [ReviewController::class, 'setHidden']);
        Route::get('/trade-ins', [TradeInController::class, 'index']);
        Route::put('/trade-ins/{tradeIn}/offer', [TradeInController::class, 'offer']);
        Route::post('/trade-ins/{tradeIn}/reject', [TradeInController::class, 'reject']);
        Route::post('/trade-ins/{tradeIn}/complete', [TradeInController::class, 'complete']);

        Route::post('/products', [AdminProductController::class, 'store']);
        Route::post('/products/{product}', [AdminProductController::class, 'update']);
        Route::delete('/products/{product}', [AdminProductController::class, 'destroy']);

        Route::delete('/orders/{order}', [AdminOrderController::class, 'destroy']);
        Route::post('/orders/{order}/refunded', [AdminOrderController::class, 'markRefunded']);
    });
});
