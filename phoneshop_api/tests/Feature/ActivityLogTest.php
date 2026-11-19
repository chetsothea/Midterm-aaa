<?php

namespace Tests\Feature;

use App\Models\ActivityLog;
use App\Models\Category;
use App\Models\Order;
use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ActivityLogTest extends TestCase
{
    use RefreshDatabase;

    public function test_changes_by_the_team_are_written_down_with_who_and_what(): void
    {
        $admin = User::create(['name' => 'Boss', 'email' => 'boss@example.com', 'password' => 'secret123', 'role' => 'admin']);
        $staff = User::create(['name' => 'Sok', 'email' => 'sok@example.com', 'password' => 'secret123', 'role' => 'staff']);
        $buyer = User::create(['name' => 'Dara', 'email' => 'dara@example.com', 'password' => 'secret123', 'role' => 'user']);
        $category = Category::firstOrCreate(['name' => 'Smartphone']);
        $phone = Product::create(['category_id' => $category->id, 'name' => 'iPhone 17', 'brand' => 'Apple', 'price' => 999, 'stock' => 5]);
        $order = Order::create(['user_id' => $buyer->id, 'customer_name' => 'Dara', 'total' => 999,
            'payment_method' => 'cod', 'phone' => '012', 'address' => 'PP']);

        // Looking is not logged; changing is
        $this->actingAs($staff)->getJson('/api/admin/orders')->assertOk();
        $this->actingAs($staff)->putJson("/api/admin/orders/{$order->id}", ['status' => 'confirmed'])->assertOk();
        $this->actingAs($admin)->post("/api/admin/products/{$phone->id}", [
            'name' => 'iPhone 17', 'price' => 899, 'stock' => 5,
        ], ['Accept' => 'application/json'])->assertOk();
        $this->actingAs($admin)->postJson('/api/admin/staff', ['name' => 'Nita', 'email' => 'nita@example.com', 'password' => 'supersecret1'])
            ->assertCreated();
        // A refused change is not logged
        $this->actingAs($staff)->deleteJson("/api/admin/orders/{$order->id}")->assertForbidden();

        $logs = ActivityLog::orderBy('id')->get();
        $this->assertCount(3, $logs);

        $this->assertSame(['Sok', 'staff', 'កែ Order', 'Order '.$order->code], [$logs[0]->user_name, $logs[0]->role, $logs[0]->action, $logs[0]->subject]);
        $this->assertSame('confirmed', $logs[0]->details['status']);
        $this->assertSame(['កែទូរស័ព្ទ', 'iPhone 17'], [$logs[1]->action, $logs[1]->subject]);
        $this->assertEquals(899, $logs[1]->details['price']);
        $this->assertSame('បន្ថែមបុគ្គលិក', $logs[2]->action);
        $this->assertArrayNotHasKey('password', $logs[2]->details); // never written down

        // Only the admin reads it, and can filter by person
        $this->actingAs($admin)->getJson('/api/admin/activity')->assertOk()->assertJsonCount(3);
        $this->actingAs($admin)->getJson("/api/admin/activity?user_id={$staff->id}")->assertJsonCount(1);
        $this->actingAs($staff)->getJson('/api/admin/activity')->assertForbidden();
    }
}
