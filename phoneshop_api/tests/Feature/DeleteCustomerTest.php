<?php

namespace Tests\Feature;

use App\Models\Order;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class DeleteCustomerTest extends TestCase
{
    use RefreshDatabase;

    private User $admin;

    private User $customer;

    protected function setUp(): void
    {
        parent::setUp();
        $this->admin = User::create(['name' => 'Admin', 'email' => 'admin', 'password' => 'admin123', 'role' => 'admin']);
        $this->customer = User::create(['name' => 'Dara', 'email' => 'dara@example.com', 'password' => 'secret123', 'role' => 'user']);
    }

    private function order(array $extra = []): Order
    {
        return Order::create(array_merge([
            'user_id' => $this->customer->id, 'total' => 100, 'status' => 'delivered',
            'payment_method' => 'cod', 'phone' => '012', 'address' => 'PP',
        ], $extra));
    }

    public function test_the_admin_deletes_a_customer_and_they_cannot_log_in(): void
    {
        $this->actingAs($this->admin)->deleteJson("/api/admin/customers/{$this->customer->id}")->assertOk();

        $this->assertNull(User::find($this->customer->id));
        $this->postJson('/api/login', ['email' => 'dara@example.com', 'password' => 'secret123'])->assertUnauthorized();
    }

    public function test_their_orders_stay_with_the_buyer_name_on_them(): void
    {
        // An older order that only has the account's name, and one with a name typed at checkout
        $older = $this->order();
        $typed = $this->order(['customer_name' => 'Typed', 'customer_email' => 'typed@example.com']);

        $this->actingAs($this->admin)->deleteJson("/api/admin/customers/{$this->customer->id}")->assertOk();

        $older->refresh();
        $typed->refresh();
        $this->assertNull($older->user_id);
        $this->assertSame(['Dara', 'dara@example.com'], [$older->customer_name, $older->customer_email]);
        $this->assertSame(['Typed', 'typed@example.com'], [$typed->customer_name, $typed->customer_email]);
    }

    public function test_a_logged_in_customer_is_cut_off_immediately(): void
    {
        $token = $this->customer->createToken('phone')->plainTextToken;

        $this->actingAs($this->admin)->deleteJson("/api/admin/customers/{$this->customer->id}")->assertOk();

        $this->app['auth']->forgetGuards();
        $this->getJson('/api/me', ['Authorization' => "Bearer $token"])->assertUnauthorized();
    }

    public function test_their_picture_is_removed(): void
    {
        $file = 'test-avatar-'.uniqid().'.png';
        file_put_contents(public_path('uploads/'.$file), 'x');
        $this->customer->update(['avatar' => $file]);

        $this->actingAs($this->admin)->deleteJson("/api/admin/customers/{$this->customer->id}")->assertOk();

        $this->assertFileDoesNotExist(public_path('uploads/'.$file));
    }

    public function test_an_admin_account_cannot_be_deleted(): void
    {
        $this->actingAs($this->admin)->deleteJson("/api/admin/customers/{$this->admin->id}")->assertUnprocessable();

        $this->assertNotNull(User::find($this->admin->id));
    }

    public function test_only_the_admin_can_delete(): void
    {
        $other = User::create(['name' => 'Thea', 'email' => 'thea@example.com', 'password' => 'secret123', 'role' => 'user']);

        $this->deleteJson("/api/admin/customers/{$other->id}")->assertUnauthorized();
        $this->actingAs($this->customer)->deleteJson("/api/admin/customers/{$other->id}")->assertForbidden();

        $this->assertNotNull(User::find($other->id));
    }
}
