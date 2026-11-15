<?php

namespace Tests\Feature;

use App\Models\Order;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AdminCustomersTest extends TestCase
{
    use RefreshDatabase;

    private function user(string $email, string $role = 'user'): User
    {
        return User::create(['name' => $email, 'email' => $email, 'password' => 'secret123', 'phone' => '012', 'address' => 'PP', 'role' => $role]);
    }

    public function test_admin_sees_customers_with_their_order_counts_newest_first(): void
    {
        $admin = $this->user('admin', 'admin');
        $first = $this->user('first@example.com');
        $this->user('second@example.com');

        foreach ([1, 2] as $_) {
            Order::create([
                'user_id' => $first->id, 'customer_name' => 'A', 'customer_email' => 'a@example.com',
                'total' => 1, 'payment_method' => 'cod', 'phone' => '012', 'address' => 'PP',
            ]);
        }

        $rows = $this->actingAs($admin)->getJson('/api/admin/customers')->assertOk()->json();

        // The admin account isn't a customer
        $this->assertSame(['second@example.com', 'first@example.com'], array_column($rows, 'email'));
        $this->assertSame([0, 2], array_column($rows, 'orders_count'));
    }

    public function test_the_list_never_exposes_passwords_or_login_details(): void
    {
        $admin = $this->user('admin', 'admin');
        $this->user('first@example.com');

        $row = $this->actingAs($admin)->getJson('/api/admin/customers')->json()[0];

        foreach (['password', 'remember_token', 'google_id'] as $secret) {
            $this->assertArrayNotHasKey($secret, $row);
        }

        // Only what the list shows
        $this->assertEqualsCanonicalizing(
            ['id', 'name', 'email', 'phone', 'address', 'blocked_at', 'created_at', 'orders_count'],
            array_keys($row),
        );
    }

    public function test_customers_cannot_see_the_list(): void
    {
        $customer = $this->user('first@example.com');

        $this->actingAs($customer)->getJson('/api/admin/customers')->assertForbidden();
    }

    public function test_guests_cannot_see_the_list(): void
    {
        $this->getJson('/api/admin/customers')->assertUnauthorized();
    }
}
