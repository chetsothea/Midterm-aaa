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

    // The shop's Telegram username (without @), opened by "Telegram" in the store menu
    'telegram' => env('SHOP_TELEGRAM', ''),
];
