<?php

namespace Tests\Feature;

use App\Models\Order;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class BlockCustomerTest extends TestCase
{
    use RefreshDatabase;

    private User $admin;

    private User $customer;

    protected function setUp(): void
    {
        parent::setUp();
        $this->admin = User::create(['name' => 'Admin', 'email' => 'admin', 'password' => 'admin123', 'role' => 'admin']);
        $this->customer = User::create(['name' => 'Dara', 'email' => 'dara@example.com', 'password' => 'secret123', 'role' => 'user']);
    }

    private function setBlocked(User $user, bool $blocked)
    {
        return $this->actingAs($this->admin)->putJson("/api/admin/customers/{$user->id}/blocked", ['blocked' => $blocked]);
    }

    private function login(string $password = 'secret123')
    {
        // Each login is a fresh request, not the admin session from setBlocked()
        Auth::forgetGuards();

        return $this->postJson('/api/login', ['email' => 'dara@example.com', 'password' => $password]);
    }

    public function test_a_disabled_customer_cannot_log_in_until_re_enabled(): void
    {
        $this->login()->assertOk();

        $this->setBlocked($this->customer, true)->assertOk();
        $this->login()->assertForbidden();

        $this->setBlocked($this->customer, false)->assertOk();
        $this->login()->assertOk();
    }

    public function test_the_wrong_password_on_a_disabled_account_says_nothing_about_it(): void
    {
        $this->setBlocked($this->customer, true);

        $this->login('wrong')->assertUnauthorized();
    }

    public function test_disabling_logs_the_customer_out_immediately(): void
    {
        $token = $this->login()->json('token');
        Auth::forgetGuards();
        $this->withToken($token)->getJson('/api/me')->assertOk();

        $this->assertSame(1, $this->customer->tokens()->count());
        $this->setBlocked($this->customer, true);
        $this->assertSame(0, $this->customer->tokens()->count());

        Auth::forgetGuards();
        $this->withToken($token)->getJson('/api/me')->assertUnauthorized();
    }

    public function test_a_disabled_customer_cannot_log_in_with_google_either(): void
    {
        config(['services.google.client_id' => 'client']);
        Http::fake(['oauth2.googleapis.com/*' => Http::response([
            'aud' => 'client', 'iss' => 'accounts.google.com', 'exp' => (string) (time() + 3600),
            'sub' => '123', 'email' => 'dara@example.com', 'email_verified' => 'true',
        ])]);
        $this->setBlocked($this->customer, true);
        Auth::forgetGuards();

        $this->postJson('/api/auth/google', ['id_token' => 'x'])->assertForbidden();
    }

    public function test_orders_are_kept_when_disabled(): void
    {
        Order::create([
            'user_id' => $this->customer->id, 'customer_name' => 'Dara', 'customer_email' => 'dara@example.com',
            'total' => 1, 'payment_method' => 'cod', 'phone' => '012', 'address' => 'PP',
        ]);

        $this->setBlocked($this->customer, true);

        $this->assertSame(1, $this->customer->orders()->count());
    }

    public function test_the_customer_list_shows_who_is_disabled(): void
    {
        $this->setBlocked($this->customer, true);

        $this->actingAs($this->admin)->getJson('/api/admin/customers')
            ->assertJsonPath('0.email', 'dara@example.com')
            ->assertJsonPath('0.blocked_at', fn ($value) => $value !== null);
    }

    public function test_an_admin_account_cannot_be_disabled(): void
    {
        $this->setBlocked($this->admin, true)->assertStatus(422);

        $this->assertNull($this->admin->fresh()->blocked_at);
    }

    public function test_customers_cannot_disable_anyone(): void
    {
        $this->actingAs($this->customer)
            ->putJson("/api/admin/customers/{$this->customer->id}/blocked", ['blocked' => true])
            ->assertForbidden();
    }
}
