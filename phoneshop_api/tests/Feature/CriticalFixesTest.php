<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Order;
use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\RateLimiter;
use Tests\TestCase;

class CriticalFixesTest extends TestCase
{
    use RefreshDatabase;

    private Product $phone;

    private User $buyer;

    protected function setUp(): void
    {
        parent::setUp();
        RateLimiter::clear('login');
        $category = Category::firstOrCreate(['name' => 'Smartphone']);
        $this->phone = Product::create([
            'category_id' => $category->id, 'name' => 'iPhone 17', 'brand' => 'Apple', 'price' => 999, 'stock' => 5,
        ]);
        $this->buyer = User::create(['name' => 'Dara', 'email' => 'dara@example.com', 'password' => 'secret123', 'role' => 'user']);
    }

    private function placeOrder(string $method): array
    {
        return $this->actingAs($this->buyer)->postJson('/api/orders', [
            'items' => [['product_id' => $this->phone->id, 'qty' => 2]],
            'payment_method' => $method,
            'customer_name' => 'Dara', 'customer_email' => 'dara@example.com',
            'phone' => '012345678', 'address' => 'Phnom Penh',
        ])->assertCreated()->json();
    }

    public function test_an_unpaid_khqr_order_is_cancelled_after_30_minutes_and_restocked(): void
    {
        $order = $this->placeOrder('khqr');
        $this->assertSame(3, $this->phone->fresh()->stock); // 2 held
        $this->assertNotNull($order['pay_before']); // the app shows the deadline

        $this->travel(29)->minutes();
        $this->assertSame(0, Order::expireUnpaid());
        $this->assertSame('pending', Order::find($order['id'])->status);

        $this->travel(2)->minutes();
        // Just reading the shop frees the stock, even without the scheduler
        $this->getJson('/api/products')->assertOk();
        $this->assertSame('cancelled', Order::find($order['id'])->status);
        $this->assertSame(5, $this->phone->fresh()->stock);
        // The customer sees why in the tracking steps
        $this->assertStringContainsString(
            'ស្វ័យប្រវត្តិ',
            Order::find($order['id'])->trackings()->first()->note,
        );
    }

    public function test_paid_waiting_and_cash_on_delivery_orders_are_never_auto_cancelled(): void
    {
        $verifying = $this->placeOrder('khqr');
        $this->actingAs($this->buyer)
            ->postJson("/api/orders/{$verifying['id']}/pay", ['transaction_ref' => 'ABA123'])
            ->assertOk();
        $cod = $this->placeOrder('cod');
        $this->assertNull($cod['pay_before']);

        $this->travel(3)->hours();
        $this->assertSame(0, Order::expireUnpaid());
        $this->assertSame('pending', Order::find($verifying['id'])->status);
        $this->assertSame('pending', Order::find($cod['id'])->status);
    }

    public function test_guessing_passwords_is_stopped_after_5_tries_a_minute(): void
    {
        for ($i = 0; $i < 5; $i++) {
            $this->postJson('/api/login', ['email' => 'dara@example.com', 'password' => 'wrong'])
                ->assertUnauthorized(); // wrong password
        }
        $this->postJson('/api/login', ['email' => 'dara@example.com', 'password' => 'secret123'])
            ->assertStatus(429)
            ->assertJsonFragment(['message' => 'ព្យាយាមច្រើនដងពេក សូមរង់ចាំ 60 វិនាទី រួចព្យាយាមម្តងទៀត']);

        // A minute later the right password works again
        $this->travel(61)->seconds();
        $this->postJson('/api/login', ['email' => 'dara@example.com', 'password' => 'secret123'])
            ->assertOk();
    }

    public function test_a_login_expires_after_30_days(): void
    {
        $token = $this->postJson('/api/login', ['email' => 'dara@example.com', 'password' => 'secret123'])
            ->assertOk()->json('token');
        $this->withToken($token)->getJson('/api/me')->assertOk();

        $this->app['auth']->forgetGuards();
        $this->travel(31)->days();
        $this->withToken($token)->getJson('/api/me')->assertUnauthorized();
    }
}
