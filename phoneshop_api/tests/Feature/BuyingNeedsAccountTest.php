<?php

namespace Tests\Feature;

use App\Models\Order;
use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class BuyingNeedsAccountTest extends TestCase
{
    use RefreshDatabase;

    private function checkout(Product $product): array
    {
        return [
            'customer_name' => 'Dara', 'customer_email' => 'dara@example.com', 'phone' => '012', 'address' => 'PP',
            'payment_method' => 'cod', 'items' => [['product_id' => $product->id, 'qty' => 1]],
        ];
    }

    public function test_a_guest_can_browse_but_cannot_order(): void
    {
        $product = Product::create(['name' => 'iPhone', 'price' => 1000, 'stock' => 5]);

        $this->getJson('/api/products')->assertOk()->assertJsonCount(1);
        $this->postJson('/api/orders', $this->checkout($product))->assertUnauthorized();
        $this->postJson('/api/guest/orders', $this->checkout($product))->assertNotFound();

        $this->assertSame(0, Order::count());
        $this->assertSame(5, $product->fresh()->stock);
    }

    public function test_a_logged_in_customer_can_order(): void
    {
        $product = Product::create(['name' => 'iPhone', 'price' => 1000, 'stock' => 5]);
        $customer = User::create(['name' => 'Dara', 'email' => 'dara@example.com', 'password' => 'secret123', 'role' => 'user']);

        $this->actingAs($customer)->postJson('/api/orders', $this->checkout($product))->assertCreated();

        $this->assertSame(4, $product->fresh()->stock);
    }
}
