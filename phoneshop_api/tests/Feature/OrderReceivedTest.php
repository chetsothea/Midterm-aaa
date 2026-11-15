<?php

namespace Tests\Feature;

use App\Models\Order;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class OrderReceivedTest extends TestCase
{
    use RefreshDatabase;

    private User $customer;

    protected function setUp(): void
    {
        parent::setUp();
        $this->customer = User::create(['name' => 'Dara', 'email' => 'dara@example.com', 'password' => 'secret123', 'role' => 'user']);
    }

    private function order(string $status, array $extra = []): Order
    {
        return Order::create(array_merge([
            'user_id' => $this->customer->id, 'customer_name' => 'Dara', 'customer_email' => 'dara@example.com',
            'total' => 100, 'status' => $status, 'payment_method' => 'cod', 'phone' => '012', 'address' => 'PP',
        ], $extra));
    }

    public function test_the_customer_confirms_a_shipping_order_arrived(): void
    {
        $order = $this->order('shipping');

        $response = $this->actingAs($this->customer)->postJson("/api/orders/{$order->id}/received")->assertOk();

        $response->assertJsonPath('status', 'delivered')
            ->assertJsonPath('trackings.0.status', 'delivered')
            ->assertJsonPath('trackings.0.note', 'អ្នកទិញបានបញ្ជាក់ថាទទួលឥវ៉ាន់ហើយ');
        $this->assertSame('delivered', $order->fresh()->status);
    }

    public function test_payment_is_left_for_the_admin(): void
    {
        $order = $this->order('shipping');

        $this->actingAs($this->customer)->postJson("/api/orders/{$order->id}/received")->assertOk();

        $this->assertSame('unpaid', $order->fresh()->payment_status);
    }

    public function test_a_guest_confirms_with_their_order_token(): void
    {
        $order = $this->order('shipping', ['user_id' => null, 'access_token' => 'secret-token']);

        $this->postJson("/api/guest/orders/{$order->id}/received")->assertNotFound();
        $this->postJson("/api/guest/orders/{$order->id}/received", [], ['X-Order-Token' => 'wrong'])->assertNotFound();
        $this->assertSame('shipping', $order->fresh()->status);

        $this->postJson("/api/guest/orders/{$order->id}/received", [], ['X-Order-Token' => 'secret-token'])
            ->assertOk()
            ->assertJsonPath('status', 'delivered');
    }

    public function test_a_delivered_order_can_still_be_confirmed_by_the_customer(): void
    {
        $order = $this->order('delivered');

        $this->actingAs($this->customer)->postJson("/api/orders/{$order->id}/received")->assertOk();

        $this->assertNotNull($order->fresh()->received_at);
        $this->assertSame('delivered', $order->fresh()->status);
        $this->assertSame('អ្នកទិញបានបញ្ជាក់ថាទទួលឥវ៉ាន់ហើយ', $order->trackings()->first()->note);
    }

    public function test_the_admin_is_told_once_until_they_have_looked(): void
    {
        $admin = User::create(['name' => 'Admin', 'email' => 'admin', 'password' => 'admin123', 'role' => 'admin']);
        $order = $this->order('shipping');
        $this->order('delivered'); // marked by the admin: nobody to tell

        $this->actingAs($admin)->getJson('/api/admin/dashboard')->assertJsonPath('new_received', 0);

        $this->actingAs($this->customer)->postJson("/api/orders/{$order->id}/received")->assertOk();
        $this->actingAs($admin)->getJson('/api/admin/dashboard')->assertJsonPath('new_received', 1);

        $this->postJson('/api/admin/orders/received-seen')->assertOk();
        $this->getJson('/api/admin/dashboard')->assertJsonPath('new_received', 0);
        $this->assertNotNull($order->fresh()->received_at); // still recorded
    }

    public function test_only_the_admin_can_mark_notices_as_seen(): void
    {
        $this->actingAs($this->customer)->postJson('/api/admin/orders/received-seen')->assertForbidden();
    }

    public function test_orders_not_sent_yet_or_cancelled_cannot_be_confirmed(): void
    {
        foreach (['pending', 'confirmed', 'cancelled'] as $status) {
            $order = $this->order($status);

            $this->actingAs($this->customer)->postJson("/api/orders/{$order->id}/received")->assertStatus(422);

            $this->assertSame($status, $order->fresh()->status);
        }
    }

    public function test_another_customer_cannot_confirm_it(): void
    {
        $order = $this->order('shipping');
        $other = User::create(['name' => 'Other', 'email' => 'other@example.com', 'password' => 'secret123', 'role' => 'user']);

        $this->actingAs($other)->postJson("/api/orders/{$order->id}/received")->assertNotFound();

        $this->assertSame('shipping', $order->fresh()->status);
    }

    public function test_confirming_twice_adds_only_one_step(): void
    {
        $order = $this->order('shipping');

        $this->actingAs($this->customer)->postJson("/api/orders/{$order->id}/received")->assertOk();
        $this->postJson("/api/orders/{$order->id}/received")->assertStatus(422);

        $this->assertSame(1, $order->trackings()->where('status', 'delivered')->count());
    }
}
