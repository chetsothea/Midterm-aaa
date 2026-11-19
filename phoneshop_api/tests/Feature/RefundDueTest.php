<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Notice;
use App\Models\Order;
use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class RefundDueTest extends TestCase
{
    use RefreshDatabase;

    private User $buyer;

    private User $admin;

    protected function setUp(): void
    {
        parent::setUp();
        $this->buyer = User::create(['name' => 'Dara', 'email' => 'dara@example.com', 'password' => 'secret123', 'role' => 'user']);
        $this->admin = User::create(['name' => 'Boss', 'email' => 'boss@example.com', 'password' => 'secret123', 'role' => 'admin']);
    }

    private function order(string $payment): Order
    {
        $category = Category::firstOrCreate(['name' => 'Smartphone']);
        $phone = Product::create(['category_id' => $category->id, 'name' => 'X', 'brand' => 'X', 'price' => 500, 'stock' => 5]);
        $id = $this->actingAs($this->buyer)->postJson('/api/orders', [
            'items' => [['product_id' => $phone->id, 'qty' => 1]], 'payment_method' => 'khqr',
            'customer_name' => 'Dara', 'customer_email' => 'dara@example.com', 'phone' => '012', 'address' => 'PP',
        ])->json('id');
        $order = Order::find($id);
        $order->update(['payment_status' => $payment]);

        return $order;
    }

    public function test_a_paid_order_cancelled_is_listed_until_refunded(): void
    {
        $paid = $this->order('paid');
        $unpaid = $this->order('unpaid');
        $this->actingAs($this->buyer)->postJson("/api/orders/{$paid->id}/cancel")->assertOk()->assertJsonPath('refund_status', 'due');
        $this->actingAs($this->buyer)->postJson("/api/orders/{$unpaid->id}/cancel")->assertOk()->assertJsonPath('refund_status', null);

        $this->actingAs($this->admin)->getJson('/api/admin/dashboard')
            ->assertJsonPath('refunds_due', 1)->assertJsonPath('refunds_due_total', 500);

        $this->actingAs($this->admin)->postJson("/api/admin/orders/{$unpaid->id}/refunded")->assertStatus(422);
        $this->actingAs($this->admin)->postJson("/api/admin/orders/{$paid->id}/refunded", ['note' => 'ABA'])
            ->assertOk()->assertJsonPath('refund_status', 'refunded');

        $this->actingAs($this->admin)->getJson('/api/admin/dashboard')->assertJsonPath('refunds_due', 0);
        $this->assertStringContainsString('ហាងបានបង្វិលប្រាក់ $500.00 (ABA)', $paid->fresh()->trackings()->first()->note);
        $this->assertSame(1, Notice::where('user_id', $this->buyer->id)->where('title', 'like', 'បានបង្វិលប្រាក់%')->count());
    }

    public function test_the_admin_cancelling_a_paid_order_also_owes_a_refund_and_staff_cannot_mark_it(): void
    {
        $paid = $this->order('paid');
        $this->actingAs($this->admin)->putJson("/api/admin/orders/{$paid->id}", ['status' => 'cancelled'])->assertOk();
        $this->assertSame('due', $paid->fresh()->refund_status);

        $staff = User::create(['name' => 'S', 'email' => 's@example.com', 'password' => 'secret123', 'role' => 'staff']);
        $this->actingAs($staff)->postJson("/api/admin/orders/{$paid->id}/refunded")->assertForbidden();
    }
}
