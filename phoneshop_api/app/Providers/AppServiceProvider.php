<?php

namespace App\Providers;

use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        // Guessing passwords: 5 tries a minute per account (and 20 per
        // device), then a wait. The message says how long, in Khmer.
        $tooMany = fn (Request $request, array $headers) => response()->json([
            'message' => 'ព្យាយាមច្រើនដងពេក សូមរង់ចាំ '.($headers['Retry-After'] ?? 60).' វិនាទី រួចព្យាយាមម្តងទៀត',
        ], 429, $headers);

        RateLimiter::for('login', fn (Request $request) => [
            Limit::perMinute(5)
                ->by('login|'.strtolower(trim((string) $request->input('email'))).'|'.$request->ip())
                ->response($tooMany),
            Limit::perMinute(20)->by('login-ip|'.$request->ip())->response($tooMany),
        ]);

        // New accounts: a few per minute from one device
        RateLimiter::for('register', fn (Request $request) => Limit::perMinute(5)
            ->by('register|'.$request->ip())
            ->response($tooMany));
    }
}
