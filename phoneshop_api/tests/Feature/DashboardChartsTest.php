<?php

namespace Tests\Feature;

use App\Models\Order;
use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Tests\TestCase;

class DashboardChartsTest extends TestCase
{
    use RefreshDatabase;

    private function order(string $utcTime, float $total, string $status, string $payment, Product $product, int $qty): void
    {
        $order = Order::create([
            'customer_name' => 'A', 'customer_email' => 'a@example.com', 'total' => $total,
            'status' => $status, 'payment_method' => 'cod', 'payment_status' => $payment,
            'phone' => '012', 'address' => 'PP',
        ]);
        $order->forceFill(['created_at' => Carbon::parse($utcTime, 'UTC')])->save();
        $order->items()->create(['product_id' => $product->id, 'qty' => $qty, 'price' => $total / $qty]);
    }

    private function dashboard(): array
    {
        $admin = User::create(['name' => 'Admin', 'email' => 'admin@example.com', 'password' => 'secret123', 'role' => 'admin']);

        return $this->actingAs($admin)->getJson('/api/admin/dashboard')->assertOk()->json();
    }

    public function test_revenue_is_grouped_by_cambodia_day_and_only_counts_paid_orders(): void
    {
        // 10:00 on Nov 2 in Phnom Penh
        Carbon::setTestNow(Carbon::parse('2026-11-02 03:00:00', 'UTC'));
        $phone = Product::create(['name' => 'iPhone', 'price' => 100, 'stock' => 9]);

        $this->order('2026-11-01 18:00:00', 100, 'delivered', 'paid', $phone, 1);   // Nov 2, 01:00 in Cambodia
        $this->order('2026-11-01 16:00:00', 40, 'delivered', 'paid', $phone, 1);    // Nov 1, 23:00 in Cambodia
        $this->order('2026-11-02 01:00:00', 999, 'pending', 'unpaid', $phone, 1);   // not paid
        $this->order('2026-10-20 01:00:00', 777, 'delivered', 'paid', $phone, 1);   // too old

        $days = $this->dashboard()['revenue_by_day'];

        $this->assertCount(7, $days);
        $this->assertSame('2026-10-27', $days[0]['date']);
        $this->assertSame(['date' => '2026-11-01', 'total' => 40], $days[5]);
        $this->assertSame(['date' => '2026-11-02', 'total' => 100], $days[6]);
    }

    public function test_admin_can_change_the_low_stock_threshold(): void
    {
        Product::create(['name' => 'A', 'price' => 1, 'stock' => 2]);
        Product::create(['name' => 'B', 'price' => 1, 'stock' => 5]);
        Product::create(['name' => 'C', 'price' => 1, 'stock' => 20]);
        $admin = User::create(['name' => 'Admin', 'email' => 'admin@example.com', 'password' => 'secret123', 'role' => 'admin']);

        // Default: 3 or fewer
        $this->actingAs($admin)->getJson('/api/admin/dashboard')
            ->assertJsonPath('low_stock_threshold', 3)
            ->assertJsonPath('low_stock', 1);

        // Raised to 5: the phone with exactly 5 now counts, and it stays saved
        $this->putJson('/api/admin/settings/low-stock', ['threshold' => 5])
            ->assertOk()
            ->assertJsonPath('low_stock_threshold', 5)
            ->assertJsonPath('low_stock', 2);
        $this->getJson('/api/admin/dashboard')->assertJsonPath('low_stock', 2);

        foreach ([-1, 'abc', null] as $bad) {
            $this->putJson('/api/admin/settings/low-stock', ['threshold' => $bad])->assertStatus(422);
        }
    }

    public function test_only_admins_can_change_the_low_stock_threshold(): void
    {
        $customer = User::create(['name' => 'C', 'email' => 'c@example.com', 'password' => 'secret123', 'role' => 'user']);

        $this->actingAs($customer)->putJson('/api/admin/settings/low-stock', ['threshold' => 5])->assertForbidden();
    }

    public function test_orders_by_status_lists_every_status_in_workflow_order(): void
    {
        $phone = Product::create(['name' => 'iPhone', 'price' => 100, 'stock' => 9]);
        $this->order('2026-11-01 01:00:00', 100, 'shipping', 'paid', $phone, 1);
        $this->order('2026-11-01 02:00:00', 100, 'shipping', 'paid', $phone, 1);

        $this->assertSame([
            ['status' => 'pending', 'count' => 0],
            ['status' => 'confirmed', 'count' => 0],
            ['status' => 'shipping', 'count' => 2],
            ['status' => 'delivered', 'count' => 0],
            ['status' => 'cancelled', 'count' => 0],
        ], $this->dashboard()['orders_by_status']);
    }

    public function test_top_products_sums_units_and_ignores_cancelled_orders(): void
    {
        $iphone = Product::create(['name' => 'iPhone', 'price' => 100, 'stock' => 9]);
        $galaxy = Product::create(['name' => 'Galaxy', 'price' => 100, 'stock' => 9]);

        $this->order('2026-11-01 01:00:00', 300, 'delivered', 'paid', $galaxy, 3);
        $this->order('2026-11-01 02:00:00', 100, 'pending', 'unpaid', $iphone, 1);
        $this->order('2026-11-01 03:00:00', 900, 'cancelled', 'unpaid', $iphone, 9);

        $this->assertSame([
            ['name' => 'Galaxy', 'qty' => 3],
            ['name' => 'iPhone', 'qty' => 1],
        ], $this->dashboard()['top_products']);
    }
}
