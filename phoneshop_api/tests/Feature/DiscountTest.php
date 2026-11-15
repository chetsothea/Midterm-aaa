<?php

namespace Tests\Feature;

use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class DiscountTest extends TestCase
{
    use RefreshDatabase;

    private function product(array $extra = []): Product
    {
        return Product::create(array_merge(['name' => 'iPhone', 'price' => 1000, 'stock' => 5], $extra));
    }

    public function test_the_store_shows_the_discounted_price_of_every_size(): void
    {
        $this->product([
            'discount_percent' => 10,
            'storage_prices' => [['storage' => '256GB', 'price' => 1000], ['storage' => '512GB', 'price' => 1200]],
        ]);

        $this->getJson('/api/products')->assertOk()
            ->assertJsonPath('0.price', 900)
            ->assertJsonPath('0.old_price', 1000)
            ->assertJsonPath('0.storage_prices.1.price', 1080)
            ->assertJsonPath('0.storage_prices.1.old_price', 1200);
    }

    public function test_a_product_without_discount_keeps_its_price(): void
    {
        $this->product();

        $this->getJson('/api/products')->assertOk()
            ->assertJsonPath('0.price', 1000)
            ->assertJsonPath('0.old_price', null);
    }

    public function test_orders_charge_the_discounted_price(): void
    {
        $plain = $this->product(['discount_percent' => 25]);
        $sized = $this->product(['discount_percent' => 10, 'storage_prices' => [['storage' => '512GB', 'price' => 1200]]]);

        $customer = User::create(['name' => 'Dara', 'email' => 'dara@example.com', 'password' => 'secret123', 'role' => 'user']);

        $this->actingAs($customer)->postJson('/api/orders', [
            'customer_name' => 'Dara', 'customer_email' => 'dara@example.com', 'phone' => '012', 'address' => 'PP',
            'payment_method' => 'cod',
            'items' => [
                ['product_id' => $plain->id, 'qty' => 2],
                ['product_id' => $sized->id, 'qty' => 1, 'storage' => '512GB'],
            ],
        ])->assertCreated()->assertJsonPath('total', fn ($total) => (float) $total === 2580.0);
    }

    public function test_the_admin_sets_and_clears_a_discount_and_the_regular_price_stays(): void
    {
        $admin = User::create(['name' => 'Admin', 'email' => 'a@example.com', 'password' => 'secret123', 'role' => 'admin']);
        $product = $this->product();
        $save = fn (array $data) => $this->actingAs($admin)->postJson("/api/admin/products/{$product->id}", array_merge(
            ['name' => 'iPhone', 'price' => 1000, 'stock' => 5], $data
        ));

        $save(['discount_percent' => 15])->assertOk();
        $this->assertSame(1000.0, $product->fresh()->price);
        $this->assertSame(850.0, $product->fresh()->salePrice());

        $save(['discount_percent' => null])->assertOk();
        $this->assertSame(1000.0, $product->fresh()->salePrice());

        $save(['discount_percent' => 100])->assertUnprocessable();
    }
}
