<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

// shop:check-production reads the users table (the default admin password)
class ProductionCheckTest extends TestCase
{
    use RefreshDatabase;

    public function test_production_check_lists_unsafe_settings(): void
    {
        config(['app.debug' => true, 'mail.default' => 'log']);
        $this->artisan('shop:check-production')
            ->expectsOutputToContain('APP_DEBUG=true')
            ->expectsOutputToContain('MAIL_MAILER=log')
            ->assertFailed();
    }

    public function test_production_check_passes_a_safe_setup(): void
    {
        $this->app['env'] = 'production';
        config([
            'app.debug' => false, 'app.url' => 'https://ps168.example', 'app.key' => 'base64:'.base64_encode(str_repeat('k', 32)),
            'mail.default' => 'smtp', 'cors.allowed_origins' => ['https://ps168.example'],
        ]);
        $this->artisan('shop:check-production')
            ->doesntExpectOutputToContain('✗')
            ->assertSuccessful();
    }

    public function test_production_check_catches_the_default_admin_password(): void
    {
        \App\Models\User::create(['name' => 'Admin', 'email' => 'admin', 'password' => 'admin123', 'role' => 'admin']);
        $this->artisan('shop:check-production')->expectsOutputToContain('admin123')->assertFailed();
    }
}
