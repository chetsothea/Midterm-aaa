<?php

namespace Tests\Feature;

use App\Models\Order;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class HideCancelledOrderTest extends TestCase
{
    use RefreshDatabase;

    private User $customer;

    protected function setUp(): void
    {
        parent::setUp();
        $this->customer = User::create(['name' => 'Yaya', 'email' => 'yaya@example.com', 'password' => 'secret123', 'role' => 'user']);
    }

    private function order(string $status): Order
    {
        return Order::create([
            'user_id' => $this->customer->id, 'customer_name' => 'Yaya', 'customer_email' => 'yaya@example.com',
            'total' => 126, 'status' => $status, 'payment_method' => 'khqr', 'phone' => '012', 'address' => 'PP',
        ]);
    }

    public function test_a_cancelled_order_leaves_the_customers_list_but_the_shop_keeps_it(): void
    {
        $cancelled = $this->order('cancelled');
        $active = $this->order('pending');

        $this->actingAs($this->customer)->deleteJson("/api/orders/{$cancelled->id}")->assertOk();

        $this->getJson('/api/orders')->assertOk()
            ->assertJsonCount(1)
            ->assertJsonPath('0.id', $active->id);

        $this->assertDatabaseHas('orders', ['id' => $cancelled->id]);
        $admin = User::create(['name' => 'Admin', 'email' => 'admin@example.com', 'password' => 'secret123', 'role' => 'admin']);
        $this->actingAs($admin)->getJson('/api/admin/orders')->assertJsonCount(2);
    }

    public function test_a_received_order_can_be_removed_too(): void
    {
        $received = $this->order('delivered');

        $this->actingAs($this->customer)->deleteJson("/api/orders/{$received->id}")->assertOk();
        $this->getJson('/api/orders')->assertJsonCount(0);
        $this->assertDatabaseHas('orders', ['id' => $received->id]);
    }

    public function test_orders_still_on_their_way_cannot_be_removed(): void
    {
        foreach (['pending', 'confirmed', 'shipping'] as $status) {
            $order = $this->order($status);
            $this->actingAs($this->customer)->deleteJson("/api/orders/{$order->id}")->assertStatus(422);
        }
        $this->getJson('/api/orders')->assertJsonCount(3);
    }

    public function test_someone_elses_order_cannot_be_removed(): void
    {
        $cancelled = $this->order('cancelled');
        $other = User::create(['name' => 'Sok', 'email' => 'sok@example.com', 'password' => 'secret123', 'role' => 'user']);

        $this->actingAs($other)->deleteJson("/api/orders/{$cancelled->id}")->assertNotFound();
        $this->assertNull($cancelled->fresh()->customer_hidden_at);
    }
}
