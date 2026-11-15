<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Order;
use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CustomerOrderNumberTest extends TestCase
{
    use RefreshDatabase;

    private Product $phone;

    protected function setUp(): void
    {
        parent::setUp();
        $category = Category::create(['name' => 'Phones']);
        $this->phone = Product::create([
            'category_id' => $category->id, 'name' => 'OPPO Reno16', 'brand' => 'OPPO',
            'price' => 364.65, 'stock' => 50,
        ]);
    }

    private function customer(string $name): User
    {
        return User::create(['name' => $name, 'email' => strtolower($name).'@example.com', 'password' => 'secret123', 'role' => 'user']);
    }

    private function buy(User $user)
    {
        return $this->actingAs($user)->postJson('/api/orders', [
            'customer_name' => $user->name, 'customer_email' => $user->email, 'phone' => '012',
            'address' => 'PP', 'payment_method' => 'cod',
            'items' => [['product_id' => $this->phone->id, 'qty' => 1]],
        ])->assertCreated();
    }

    public function test_each_customer_counts_their_own_orders_without_gaps(): void
    {
        $yaya = $this->customer('Yaya');
        $dara = $this->customer('Dara');

        $this->buy($yaya)->assertJsonPath('customer_number', 1);
        $this->buy($dara)->assertJsonPath('customer_number', 1);
        $this->buy($dara)->assertJsonPath('customer_number', 2);
        $third = $this->buy($yaya)->assertJsonPath('customer_number', 2);

        // The shop-wide ID still counts everyone's orders
        $this->assertSame(4, $third->json('id'));
    }

    public function test_a_deleted_order_does_not_reuse_a_number(): void
    {
        $yaya = $this->customer('Yaya');
        $this->buy($yaya);
        $second = $this->buy($yaya)->json('id');
        $this->buy($yaya);

        Order::find($second)->delete();

        $this->buy($yaya)->assertJsonPath('customer_number', 4);
    }
}
