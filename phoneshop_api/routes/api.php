<?php

use App\Http\Controllers\Api\Admin\OrderController as AdminOrderController;
use App\Http\Controllers\Api\Admin\PaymentAccountController;
use App\Http\Controllers\Api\Admin\ProductController as AdminProductController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\LiveController;
use App\Http\Controllers\Api\LocationController;
use App\Http\Controllers\Api\OrderController;
use App\Http\Controllers\Api\ProductController;
use App\Http\Controllers\Api\ReviewController;
use App\Http\Middleware\AdminOnly;
use Illuminate\Support\Facades\Route;

Route::post('/register', [AuthController::class, 'register'])->middleware('throttle:register');
Route::post('/login', [AuthController::class, 'login'])->middleware('throttle:login');
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
    Route::post('/logout', [AuthController::class, 'logout']);
    // POST because PHP doesn't parse multipart bodies on PUT
    Route::post('/profile', [AuthController::class, 'updateProfile']);

    Route::get('/orders', [OrderController::class, 'index']);
    Route::post('/orders', [OrderController::class, 'store']);
    Route::get('/orders/{order}', [OrderController::class, 'show']);
    Route::post('/orders/{order}/pay', [OrderController::class, 'pay']);
    Route::get('/orders/{order}/check-payment', [OrderController::class, 'checkPayment'])->middleware('throttle:40,1');
    Route::post('/orders/{order}/cancel', [OrderController::class, 'cancel']);
    Route::delete('/orders/{order}', [OrderController::class, 'hide']);
    Route::post('/orders/{order}/received', [OrderController::class, 'received']);

    Route::post('/products/{product}/reviews', [ReviewController::class, 'store'])->middleware('throttle:10,1');
    Route::post('/live/comments', [LiveController::class, 'postComment'])->middleware('throttle:20,1');

    Route::middleware(AdminOnly::class)->prefix('admin')->group(function () {
        Route::get('/dashboard', [AdminOrderController::class, 'dashboard']);
        Route::get('/customers', [AdminOrderController::class, 'customers']);
        Route::put('/customers/{user}', [AdminOrderController::class, 'updateCustomer']);
        Route::put('/customers/{user}/blocked', [AdminOrderController::class, 'setCustomerBlocked']);
        Route::delete('/customers/{user}', [AdminOrderController::class, 'deleteCustomer']);
        Route::get('/payment-accounts', [PaymentAccountController::class, 'index']);
        Route::post('/payment-accounts', [PaymentAccountController::class, 'store']);
        Route::post('/payment-accounts/{paymentAccount}', [PaymentAccountController::class, 'update']);
        Route::delete('/payment-accounts/{paymentAccount}', [PaymentAccountController::class, 'destroy']);
        Route::put('/settings/low-stock', [AdminOrderController::class, 'updateLowStockThreshold']);

        Route::put('/live', [LiveController::class, 'update']);
        Route::delete('/live/comments/{comment}', [LiveController::class, 'deleteComment']);

        Route::post('/products', [AdminProductController::class, 'store']);
        Route::post('/products/{product}', [AdminProductController::class, 'update']);
        Route::delete('/products/{product}', [AdminProductController::class, 'destroy']);

        Route::get('/orders', [AdminOrderController::class, 'index']);
        Route::post('/orders/received-seen', [AdminOrderController::class, 'markReceivedSeen']);
        Route::get('/orders/new', [AdminOrderController::class, 'newOrders']);
        Route::put('/orders/{order}', [AdminOrderController::class, 'update']);
        Route::delete('/orders/{order}', [AdminOrderController::class, 'destroy']);
        Route::post('/orders/{order}/tracking', [AdminOrderController::class, 'addTracking']);
        Route::put('/orders/{order}/tracking/{tracking}', [AdminOrderController::class, 'updateTracking']);
    });
});
