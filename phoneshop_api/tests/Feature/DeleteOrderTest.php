<?php

namespace Tests\Feature;

use App\Models\Order;
use App\Models\OrderItem;
use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class DeleteOrderTest extends TestCase
{
    use RefreshDatabase;

    private User $admin;

    private User $customer;

    private Product $product;

    protected function setUp(): void
    {
        parent::setUp();
        $this->admin = User::create(['name' => 'Admin', 'email' => 'admin', 'password' => 'admin123', 'role' => 'admin']);
        $this->customer = User::create(['name' => 'Dara', 'email' => 'dara@example.com', 'password' => 'secret123', 'role' => 'user']);
        $this->product = Product::create(['name' => 'iPhone', 'price' => 1000, 'stock' => 5]);
    }

    private function order(string $status): Order
    {
        $order = Order::create([
            'user_id' => $this->customer->id, 'customer_name' => 'Dara', 'total' => 2000, 'status' => $status,
            'payment_method' => 'cod', 'phone' => '012', 'address' => 'PP',
        ]);
        OrderItem::create(['order_id' => $order->id, 'product_id' => $this->product->id, 'qty' => 2, 'price' => 1000]);
        $order->trackings()->create(['status' => $status]);

        return $order;
    }

    private function deleteOrder(Order $order)
    {
        return $this->actingAs($this->admin)->deleteJson("/api/admin/orders/{$order->id}");
    }

    public function test_the_order_goes_with_its_items_and_tracking_steps(): void
    {
        $order = $this->order('pending');

        $this->deleteOrder($order)->assertOk();

        $this->assertNull(Order::find($order->id));
        $this->assertSame(0, OrderItem::count());
        $this->assertSame(0, \App\Models\OrderTracking::count());
    }

    public function test_an_order_in_progress_puts_its_stock_back(): void
    {
        foreach (['pending', 'confirmed', 'shipping'] as $status) {
            $this->product->refresh()->update(['stock' => 5]);
            $this->deleteOrder($this->order($status))->assertOk();
            $this->assertSame(7, $this->product->fresh()->stock, $status);
        }
    }

    public function test_delivered_and_cancelled_orders_leave_the_stock_alone(): void
    {
        foreach (['delivered', 'cancelled'] as $status) {
            $this->deleteOrder($this->order($status))->assertOk();
            $this->assertSame(5, $this->product->fresh()->stock, $status);
        }
    }

    public function test_the_customer_keeps_their_account(): void
    {
        $this->deleteOrder($this->order('delivered'))->assertOk();

        $this->assertNotNull(User::find($this->customer->id));
    }

    public function test_an_order_whose_phone_was_deleted_can_still_be_deleted(): void
    {
        $order = $this->order('pending');
        $this->product->delete();

        $this->deleteOrder($order)->assertOk();
        $this->assertNull(Order::find($order->id));
    }

    public function test_only_the_admin_can_delete(): void
    {
        $order = $this->order('pending');

        $this->deleteJson("/api/admin/orders/{$order->id}")->assertUnauthorized();
        $this->actingAs($this->customer)->deleteJson("/api/admin/orders/{$order->id}")->assertForbidden();

        $this->assertNotNull(Order::find($order->id));
        $this->assertSame(5, $this->product->fresh()->stock);
    }
}
