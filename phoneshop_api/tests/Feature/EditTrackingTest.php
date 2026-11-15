<?php

namespace Tests\Feature;

use App\Models\Order;
use App\Models\OrderTracking;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class EditTrackingTest extends TestCase
{
    use RefreshDatabase;

    private User $admin;

    private User $customer;

    private Order $order;

    private OrderTracking $step;

    protected function setUp(): void
    {
        parent::setUp();
        $this->admin = User::create(['name' => 'Admin', 'email' => 'admin', 'password' => 'admin123', 'role' => 'admin']);
        $this->customer = User::create(['name' => 'Dara', 'email' => 'dara@example.com', 'password' => 'secret123', 'role' => 'user']);
        $this->order = $this->order();
        $this->step = $this->order->trackings()->create(['status' => 'shipping', 'location' => 'សាខា ខុស', 'note' => 'ចំណាំ']);
    }

    private function order(): Order
    {
        return Order::create([
            'user_id' => $this->customer->id, 'total' => 100, 'status' => 'shipping',
            'payment_method' => 'cod', 'phone' => '012', 'address' => 'PP',
        ]);
    }

    private function url(?OrderTracking $step = null, ?Order $order = null): string
    {
        return '/api/admin/orders/'.($order ?? $this->order)->id.'/tracking/'.($step ?? $this->step)->id;
    }

    public function test_the_admin_corrects_a_step_and_its_status_and_time_stay(): void
    {
        $created = $this->step->created_at;

        $this->actingAs($this->admin)->putJson($this->url(), ['location' => 'សាខា បាត់ដំបង', 'note' => 'ថ្មី'])
            ->assertOk()
            ->assertJsonPath('trackings.0.location', 'សាខា បាត់ដំបង')
            ->assertJsonPath('trackings.0.note', 'ថ្មី');

        $fresh = $this->step->fresh();
        $this->assertSame('shipping', $fresh->status);
        $this->assertEquals($created, $fresh->created_at);
        $this->assertSame(1, $this->order->trackings()->count()); // corrected, not added
    }

    public function test_the_customer_sees_the_corrected_location(): void
    {
        $this->actingAs($this->admin)->putJson($this->url(), ['location' => 'សាខា បាត់ដំបង'])->assertOk();

        $this->actingAs($this->customer)->getJson("/api/orders/{$this->order->id}")
            ->assertOk()->assertJsonPath('trackings.0.location', 'សាខា បាត់ដំបង');
    }

    public function test_an_empty_value_clears_the_field(): void
    {
        $this->actingAs($this->admin)->putJson($this->url(), ['location' => '', 'note' => 'ថ្មី'])->assertOk();

        $this->assertNull($this->step->fresh()->location);
    }

    public function test_a_step_of_another_order_is_refused(): void
    {
        $this->actingAs($this->admin)->putJson($this->url(order: $this->order()), ['location' => 'x'])->assertNotFound();

        $this->assertSame('សាខា ខុស', $this->step->fresh()->location);
    }

    public function test_the_status_cannot_be_changed_here(): void
    {
        $this->actingAs($this->admin)->putJson($this->url(), ['location' => 'x', 'status' => 'delivered'])->assertOk();

        $this->assertSame('shipping', $this->step->fresh()->status);
        $this->assertSame('shipping', $this->order->fresh()->status);
    }

    public function test_only_the_admin_can_correct(): void
    {
        $this->putJson($this->url(), ['location' => 'x'])->assertUnauthorized();
        $this->actingAs($this->customer)->putJson($this->url(), ['location' => 'x'])->assertForbidden();

        $this->assertSame('សាខា ខុស', $this->step->fresh()->location);
    }
}
