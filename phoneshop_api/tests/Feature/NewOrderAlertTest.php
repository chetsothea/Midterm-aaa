<?php

namespace Tests\Feature;

use App\Models\Order;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class NewOrderAlertTest extends TestCase
{
    use RefreshDatabase;

    private User $admin;

    protected function setUp(): void
    {
        parent::setUp();
        $this->admin = User::create(['name' => 'Admin', 'email' => 'admin@example.com', 'password' => 'secret123', 'role' => 'admin']);
    }

    private function order(string $name): Order
    {
        return Order::create([
            'customer_name' => $name, 'customer_email' => 'c@example.com', 'total' => 364.65,
            'status' => 'pending', 'payment_method' => 'khqr', 'phone' => '012', 'address' => 'PP',
        ]);
    }

    public function test_without_a_starting_point_only_the_newest_id_is_given(): void
    {
        $this->order('Dara');
        $last = $this->order('Sok');

        $this->actingAs($this->admin)->getJson('/api/admin/orders/new')
            ->assertOk()
            ->assertExactJson(['latest_id' => $last->id, 'count' => 0, 'orders' => []]);
    }

    public function test_orders_after_the_last_seen_one_are_listed_newest_first(): void
    {
        $seen = $this->order('Dara');
        $this->order('Sok');
        $this->order('YAYA');

        $this->actingAs($this->admin)->getJson("/api/admin/orders/new?after={$seen->id}")
            ->assertOk()
            ->assertJsonPath('count', 2)
            ->assertJsonPath('orders.0.customer_name', 'YAYA')
            ->assertJsonPath('orders.1.customer_name', 'Sok')
            ->assertJsonMissingPath('orders.0.phone');
    }

    public function test_only_the_admin_can_ask(): void
    {
        $customer = User::create(['name' => 'Dara', 'email' => 'dara@example.com', 'password' => 'secret123', 'role' => 'user']);

        $this->actingAs($customer)->getJson('/api/admin/orders/new')->assertForbidden();
    }
}
