<?php

namespace Tests\Feature;

use App\Models\Order;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class UnpaidDeliveredTest extends TestCase
{
    use RefreshDatabase;

    private function order(string $status, string $payment, float $total): void
    {
        Order::create([
            'total' => $total, 'status' => $status, 'payment_status' => $payment,
            'payment_method' => 'cod', 'phone' => '012', 'address' => 'PP',
        ]);
    }

    public function test_the_dashboard_counts_only_delivered_orders_not_paid(): void
    {
        $admin = User::create(['name' => 'Admin', 'email' => 'admin', 'password' => 'admin123', 'role' => 'admin']);
        $this->order('delivered', 'unpaid', 310);
        $this->order('delivered', 'unpaid', 190);
        $this->order('delivered', 'paid', 1000);      // already collected
        $this->order('delivered', 'verifying', 1000); // being checked, has its own tile
        $this->order('shipping', 'unpaid', 1000);     // not with the customer yet
        $this->order('cancelled', 'unpaid', 1000);

        $this->actingAs($admin)->getJson('/api/admin/dashboard')->assertOk()
            ->assertJsonPath('unpaid_delivered', 2)
            ->assertJsonPath('unpaid_delivered_total', fn ($total) => (float) $total === 500.0);
    }
}
