<?php

// Shown to customers on the KHQR / bank transfer payment screen
return [
    'payment' => [
        'bank_name' => env('SHOP_BANK_NAME', 'ABA Bank'),
        'account_name' => env('SHOP_ACCOUNT_NAME', 'PHONE SHOP'),
        'account_number' => env('SHOP_ACCOUNT_NUMBER', '000 000 000'),
        // A full URL, or a file name inside public/uploads (e.g. khqr.png)
        'qr_image_url' => env('SHOP_QR_IMAGE_URL', ''),
    ],

    // Bakong KHQR: each KHQR order gets its own QR with the amount in it, and
    // the server asks Bakong whether it was paid. Off while token or account
    // ID is empty (customers then use the bank QRs and the admin checks).
    // Token: register at https://api-bakong.nbc.gov.kh (it expires; renew it).
    'bakong' => [
        'token' => env('BAKONG_TOKEN', ''),
        'account_id' => env('BAKONG_ACCOUNT_ID', ''), // e.g. ps168@aclb
        'merchant_name' => env('BAKONG_MERCHANT_NAME', 'PS168'),
        'merchant_city' => env('BAKONG_MERCHANT_CITY', 'Phnom Penh'),
        'currency' => env('BAKONG_CURRENCY', 'USD'),
        'api_url' => env('BAKONG_API_URL', 'https://api-bakong.nbc.gov.kh'),
    ],

    // Minutes a customer has to pay a KHQR order before it is cancelled and
    // its phones go back on sale
    'unpaid_minutes' => (int) env('SHOP_UNPAID_MINUTES', 30),

    // The shop's Telegram username (without @), opened by "Telegram" in the store menu
    'telegram' => env('SHOP_TELEGRAM', ''),
];
