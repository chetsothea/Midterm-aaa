<?php

namespace App\Providers;

use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Middleware\TrustProxies;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Facades\URL;
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
        // Live, every link the API builds (pictures, QR images) is https,
        // even behind a proxy such as nginx or Cloudflare
        if ($this->app->isProduction() || str_starts_with((string) config('app.url'), 'https://')) {
            URL::forceScheme('https');
        }
        // Behind nginx / Cloudflare: trust the proxy so https and the customer's
        // real IP (used by the login limits) are seen correctly (TRUSTED_PROXIES)
        TrustProxies::at(config('app.trusted_proxies', '127.0.0.1'));

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
