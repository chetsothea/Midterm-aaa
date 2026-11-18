<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

// Uploaded pictures with a CORS header, so Flutter web can draw them.
// Only plain file names inside public/uploads; no folders, no "..".
Route::get('media/{file}', function (Request $request, string $file) {
    $path = public_path('uploads/'.$file);
    abort_unless(is_file($path), 404);

    // Same websites as the API (config/cors.php)
    $allowed = config('cors.allowed_origins', ['*']);
    $origin = in_array('*', $allowed, true) ? '*'
        : (in_array($request->headers->get('Origin'), $allowed, true) ? $request->headers->get('Origin') : null);

    return response()->file($path, array_filter([
        'Access-Control-Allow-Origin' => $origin,
        'Vary' => $origin && $origin !== '*' ? 'Origin' : null,
        'Cache-Control' => 'public, max-age=604800',
    ]));
})->where('file', '[A-Za-z0-9][A-Za-z0-9._-]*')
    // Plain files: no session or cookies needed
    ->withoutMiddleware([
        \Illuminate\Cookie\Middleware\EncryptCookies::class,
        \Illuminate\Cookie\Middleware\AddQueuedCookiesToResponse::class,
        \Illuminate\Session\Middleware\StartSession::class,
        \Illuminate\View\Middleware\ShareErrorsFromSession::class,
        \Illuminate\Foundation\Http\Middleware\ValidateCsrfToken::class,
    ]);
