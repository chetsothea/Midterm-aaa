<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class EditCustomerTest extends TestCase
{
    use RefreshDatabase;

    private User $admin;

    private User $customer;

    protected function setUp(): void
    {
        parent::setUp();
        $this->admin = User::create(['name' => 'Admin', 'email' => 'admin', 'password' => 'admin123', 'role' => 'admin']);
        $this->customer = User::create([
            'name' => 'Dara', 'email' => 'dara@example.com', 'password' => 'oldpass1',
            'phone' => '012', 'address' => 'PP', 'role' => 'user',
        ]);
    }

    private function edit(User $user, array $changes = [])
    {
        return $this->actingAs($this->admin)->putJson("/api/admin/customers/{$user->id}", array_merge([
            'name' => 'Dara', 'email' => 'dara@example.com', 'phone' => '012', 'address' => 'PP',
        ], $changes));
    }

    private function login(string $password)
    {
        Auth::forgetGuards();

        return $this->postJson('/api/login', ['email' => 'dara@example.com', 'password' => $password]);
    }

    public function test_admin_can_edit_details_and_the_password_stays_the_same(): void
    {
        $this->edit($this->customer, ['name' => 'Dara Sok', 'phone' => '099', 'address' => 'Siem Reap'])
            ->assertOk()
            ->assertJsonMissingPath('password');

        $fresh = $this->customer->fresh();
        $this->assertSame(['Dara Sok', '099', 'Siem Reap'], [$fresh->name, $fresh->phone, $fresh->address]);
        $this->login('oldpass1')->assertOk();
    }

    public function test_a_new_password_replaces_the_old_one_and_is_stored_hashed(): void
    {
        $this->edit($this->customer, ['password' => 'newpass1'])->assertOk();

        $this->login('oldpass1')->assertUnauthorized();
        $this->login('newpass1')->assertOk();

        $stored = $this->customer->fresh()->password;
        $this->assertNotSame('newpass1', $stored);
        $this->assertTrue(Hash::check('newpass1', $stored));
    }

    public function test_a_new_password_logs_out_old_sessions_but_a_details_edit_does_not(): void
    {
        $this->login('oldpass1');
        $this->assertSame(1, $this->customer->tokens()->count());

        $this->edit($this->customer, ['phone' => '099']);
        $this->assertSame(1, $this->customer->tokens()->count());

        $this->edit($this->customer, ['password' => 'newpass1']);
        $this->assertSame(0, $this->customer->tokens()->count());
    }

    public function test_it_rejects_bad_input(): void
    {
        User::create(['name' => 'Other', 'email' => 'other@example.com', 'password' => 'secret123', 'role' => 'user']);

        $this->edit($this->customer, ['email' => 'other@example.com'])->assertStatus(422)->assertJsonValidationErrors('email');
        $this->edit($this->customer, ['email' => 'nope'])->assertStatus(422)->assertJsonValidationErrors('email');
        $this->edit($this->customer, ['name' => ''])->assertStatus(422)->assertJsonValidationErrors('name');
        $this->edit($this->customer, ['password' => '123'])->assertStatus(422)->assertJsonValidationErrors('password');
    }

    public function test_keeping_their_own_email_is_allowed(): void
    {
        $this->edit($this->customer, ['email' => 'dara@example.com'])->assertOk();
    }

    public function test_the_role_cannot_be_changed_through_this_form(): void
    {
        $this->edit($this->customer, ['role' => 'admin'])->assertOk();

        $this->assertSame('user', $this->customer->fresh()->role);
    }

    public function test_an_admin_account_cannot_be_edited_here(): void
    {
        $this->edit($this->admin, ['password' => 'hacked123'])->assertStatus(422);

        $this->assertTrue(Hash::check('admin123', $this->admin->fresh()->password));
    }

    public function test_customers_cannot_edit_anyone(): void
    {
        $this->actingAs($this->customer)
            ->putJson("/api/admin/customers/{$this->customer->id}", ['name' => 'X', 'email' => 'x@example.com'])
            ->assertForbidden();
    }
}
