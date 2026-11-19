<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Order;
use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class VariantStockTest extends TestCase
{
    use RefreshDatabase;

    private Product $phone;

    private User $buyer;

    private User $admin;

    protected function setUp(): void
    {
        parent::setUp();
        $category = Category::firstOrCreate(['name' => 'Smartphone']);
        $this->phone = Product::create([
            'category_id' => $category->id, 'name' => 'iPhone 17', 'brand' => 'Apple', 'price' => 999, 'stock' => 0,
            'color' => 'Blue, Black',
            'storage_prices' => [['storage' => '256GB', 'price' => 999], ['storage' => '512GB', 'price' => 1199]],
            'variant_stock' => ['Blue|256GB' => 2, 'Black|512GB' => 1, 'Pink|1TB' => 9],
        ]);
        $this->buyer = User::create(['name' => 'Dara', 'email' => 'dara@example.com', 'password' => 'secret123', 'role' => 'user']);
        $this->admin = User::create(['name' => 'Boss', 'email' => 'boss@example.com', 'password' => 'secret123', 'role' => 'admin']);
    }

    private function buy(string $color, string $storage, int $qty = 1)
    {
        return $this->actingAs($this->buyer)->postJson('/api/orders', [
            'items' => [['product_id' => $this->phone->id, 'qty' => $qty, 'color' => $color, 'storage' => $storage]],
            'payment_method' => 'cod', 'customer_name' => 'Dara', 'customer_email' => 'dara@example.com',
            'phone' => '012', 'address' => 'Phnom Penh',
        ]);
    }

    public function test_stock_is_kept_per_colour_and_size_and_the_total_follows(): void
    {
        $this->phone->refresh();
        // Unknown combinations are dropped, missing ones are 0
        $this->assertSame(['Blue|256GB' => 2, 'Blue|512GB' => 0, 'Black|256GB' => 0, 'Black|512GB' => 1], $this->phone->variant_stock);
        $this->assertSame(3, $this->phone->stock);

        $this->buy('Blue', '256GB', 2)->assertCreated();
        $this->buy('Blue', '256GB')->assertStatus(422)->assertJsonPath('errors.items.0', 'iPhone 17 Blue 256GB អស់ស្តុកហើយ');
        $this->buy('Black', '512GB', 2)->assertStatus(422)->assertJsonPath('errors.items.0', 'iPhone 17 Black 512GB នៅសល់តែ 1 គ្រឿងប៉ុណ្ណោះ');
        $this->buy('Black', '256GB')->assertStatus(422); // the shop has none of these

        $this->phone->refresh();
        $this->assertSame(0, $this->phone->variant_stock['Blue|256GB']);
        $this->assertSame(1, $this->phone->stock);
    }

    public function test_cancelling_puts_it_back_in_the_same_colour_and_size(): void
    {
        $id = $this->buy('Black', '512GB')->assertCreated()->json('id');
        $this->assertSame(0, $this->phone->fresh()->variant_stock['Black|512GB']);

        Order::find($id)->cancelAndRestock();
        $this->phone->refresh();
        $this->assertSame(1, $this->phone->variant_stock['Black|512GB']);
        $this->assertSame(0, $this->phone->variant_stock['Blue|512GB']);
        $this->assertSame(3, $this->phone->stock);
    }

    public function test_admin_saves_the_grid_or_goes_back_to_one_count(): void
    {
        $this->actingAs($this->admin)->post("/api/admin/products/{$this->phone->id}", [
            'name' => 'iPhone 17', 'price' => 999, 'stock' => 0, 'color' => 'Blue, Black',
            'storage_prices' => '256GB=999, 512GB=1199',
            'variant_stock' => json_encode(['Blue|256GB' => 4, 'Blue|512GB' => 1, 'Black|256GB' => 0, 'Black|512GB' => 5]),
        ], ['Accept' => 'application/json'])->assertOk()->assertJsonPath('stock', 10)->assertJsonPath('variant_stock.Black|512GB', 5);

        $this->actingAs($this->admin)->post("/api/admin/products/{$this->phone->id}", [
            'name' => 'iPhone 17', 'price' => 999, 'stock' => 7, 'color' => 'Blue, Black',
            'storage_prices' => '256GB=999, 512GB=1199', 'variant_stock' => '',
        ], ['Accept' => 'application/json'])->assertOk()->assertJsonPath('stock', 7)->assertJsonPath('variant_stock', null);

        // One shared count again: any colour/size sells from it
        $this->buy('Black', '256GB', 7)->assertCreated();
        $this->assertSame(0, $this->phone->fresh()->stock);
    }

    public function test_phones_without_a_grid_work_as_before(): void
    {
        $plain = Product::create(['category_id' => $this->phone->category_id, 'name' => 'Case', 'brand' => 'X', 'price' => 10, 'stock' => 2]);
        $this->actingAs($this->buyer)->postJson('/api/orders', [
            'items' => [['product_id' => $plain->id, 'qty' => 3]], 'payment_method' => 'cod',
            'customer_name' => 'Dara', 'customer_email' => 'dara@example.com', 'phone' => '012', 'address' => 'Phnom Penh',
        ])->assertStatus(422)->assertJsonPath('errors.items.0', 'Case នៅសល់តែ 2 គ្រឿងប៉ុណ្ណោះ');
    }
}
