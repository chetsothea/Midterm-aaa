<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Order;
use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class OrderCodeTest extends TestCase
{
    use RefreshDatabase;

    private function buy(User $user)
    {
        $category = Category::firstOrCreate(['name' => 'Phones']);
        $phone = Product::firstOrCreate(
            ['name' => 'OPPO Reno16'],
            ['category_id' => $category->id, 'brand' => 'OPPO', 'price' => 364.65, 'stock' => 50],
        );

        return $this->actingAs($user)->postJson('/api/orders', [
            'customer_name' => $user->name, 'customer_email' => $user->email, 'phone' => '012',
            'address' => 'PP', 'payment_method' => 'cod',
            'items' => [['product_id' => $phone->id, 'qty' => 1]],
        ])->assertCreated();
    }

    public function test_every_order_gets_a_random_code_that_does_not_count_orders(): void
    {
        $user = User::create(['name' => 'Yaya', 'email' => 'yaya@example.com', 'password' => 'secret123', 'role' => 'user']);

        $first = $this->buy($user)->json('code');
        $second = $this->buy($user)->json('code');

        $this->assertMatchesRegularExpression('/^PS-[A-HJ-KM-NP-Z2-9]{6}$/', $first);
        $this->assertNotSame($first, $second);
        // The shop-wide running number isn't part of it
        $this->assertNotSame(Order::first()->id, (int) substr($first, 3));
    }

    public function test_codes_never_repeat(): void
    {
        $codes = collect(range(1, 300))->map(fn () => Order::newCode());

        $this->assertSame(300, $codes->unique()->count());
    }
}
