<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Order;
use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CustomerCancelTest extends TestCase
{
    use RefreshDatabase;

    private User $buyer;

    private Product $phone;

    protected function setUp(): void
    {
        parent::setUp();
        $category = Category::firstOrCreate(['name' => 'Smartphone']);
        $this->phone = Product::create(['category_id' => $category->id, 'name' => 'X', 'brand' => 'X', 'price' => 100, 'stock' => 5]);
        $this->buyer = User::create(['name' => 'Dara', 'email' => 'dara@example.com', 'password' => 'secret123', 'role' => 'user']);
    }

    private function order(string $status, string $payment = 'unpaid'): Order
    {
        $id = $this->actingAs($this->buyer)->postJson('/api/orders', [
            'items' => [['product_id' => $this->phone->id, 'qty' => 2]], 'payment_method' => 'cod',
            'customer_name' => 'Dara', 'customer_email' => 'dara@example.com', 'phone' => '012', 'address' => 'Phnom Penh',
        ])->assertCreated()->json('id');
        $order = Order::find($id);
        $order->update(['status' => $status, 'payment_status' => $payment]);

        return $order;
    }

    public function test_new_and_packing_orders_can_be_cancelled_and_restocked(): void
    {
        foreach (['pending', 'confirmed'] as $status) {
            $order = $this->order($status);
            $this->assertTrue($order->fresh()->can_cancel);
            $this->actingAs($this->buyer)->postJson("/api/orders/{$order->id}/cancel")
                ->assertOk()->assertJson(['status' => 'cancelled', 'can_cancel' => false]);
            $this->assertSame(5, $this->phone->fresh()->stock); // both phones back
        }
    }

    public function test_once_shipping_it_cannot_be_cancelled(): void
    {
        foreach (['shipping', 'delivered'] as $status) {
            $order = $this->order($status);
            $this->actingAs($this->buyer)->getJson("/api/orders/{$order->id}")->assertJsonPath('can_cancel', false);
            $this->actingAs($this->buyer)->postJson("/api/orders/{$order->id}/cancel")
                ->assertStatus(422)->assertJsonPath('message', fn ($m) => str_contains($m, 'ចាប់ផ្តើមដឹកជញ្ជូនហើយ'));
            $this->assertSame($status, $order->fresh()->status);
        }
        $this->assertSame(1, $this->phone->fresh()->stock); // nothing put back
    }

    public function test_cancelling_a_paid_order_records_the_refund(): void
    {
        $order = $this->order('confirmed', 'paid');
        $this->actingAs($this->buyer)->postJson("/api/orders/{$order->id}/cancel")->assertOk();
        $this->assertStringContainsString('ហាងត្រូវបង្វិលប្រាក់ $200.00', $order->fresh()->trackings()->first()->note);
    }

    public function test_someone_else_cannot_cancel_it(): void
    {
        $order = $this->order('pending');
        $other = User::create(['name' => 'S', 'email' => 's@example.com', 'password' => 'secret123', 'role' => 'user']);
        $this->actingAs($other)->postJson("/api/orders/{$order->id}/cancel")->assertNotFound();
    }
}
