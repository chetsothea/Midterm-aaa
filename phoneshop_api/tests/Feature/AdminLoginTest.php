<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AdminLoginTest extends TestCase
{
    use RefreshDatabase;

    public function test_admin_logs_in_with_the_username_admin(): void
    {
        User::create(['name' => 'Admin', 'email' => 'admin', 'password' => 'admin123', 'role' => 'admin']);

        $this->postJson('/api/login', ['email' => 'admin', 'password' => 'admin123'])
            ->assertOk()
            ->assertJsonPath('user.role', 'admin');

        $this->postJson('/api/login', ['email' => 'admin', 'password' => 'wrong'])->assertUnauthorized();
    }

    public function test_customers_still_log_in_with_their_email(): void
    {
        User::create(['name' => 'Dara', 'email' => 'dara@example.com', 'password' => 'secret123', 'role' => 'user']);

        $this->postJson('/api/login', ['email' => 'dara@example.com', 'password' => 'secret123'])
            ->assertOk()
            ->assertJsonPath('user.role', 'user');
    }

    public function test_nobody_can_register_as_admin(): void
    {
        $this->postJson('/api/register', [
            'name' => 'Sneaky', 'email' => 'admin', 'password' => 'secret123',
            'phone' => '012345678', 'address' => 'Phnom Penh',
        ])->assertStatus(422)->assertJsonValidationErrors('email');

        User::create(['name' => 'Admin', 'email' => 'admin', 'password' => 'admin123', 'role' => 'admin']);
        $this->postJson('/api/register', [
            'name' => 'ADMIN', 'email' => 'sneaky@example.com', 'password' => 'secret123',
            'phone' => '012345678', 'address' => 'Phnom Penh',
        ])->assertStatus(422)->assertJsonValidationErrors('name');
    }

    private function customer(string $name, string $email, string $password): User
    {
        return User::create(['name' => $name, 'email' => $email, 'password' => $password, 'role' => 'user']);
    }

    private function login(string $login, string $password)
    {
        return $this->postJson('/api/login', ['email' => $login, 'password' => $password]);
    }

    public function test_a_new_account_can_log_in_with_its_username(): void
    {
        $this->postJson('/api/register', [
            'name' => 'Thea', 'email' => 'thea@example.com', 'password' => '123456',
            'phone' => '012345678', 'address' => 'Phnom Penh',
        ])->assertCreated();

        $this->login('Thea', '123456')->assertOk()->assertJsonPath('user.email', 'thea@example.com');
        $this->login('thea@example.com', '123456')->assertOk();
        $this->login('Thea', 'wrong1')->assertUnauthorized();
    }

    public function test_the_capitals_must_match_how_the_account_was_created(): void
    {
        $this->customer('Thea', 'Thea@Example.com', '123456');

        foreach (['thea', 'THEA', 'tHeA', 'thea@example.com', 'THEA@EXAMPLE.COM', 'Thea@example.com'] as $wrong) {
            $this->login($wrong, '123456')->assertUnauthorized()->assertJsonMissingPath('token');
        }

        $this->login('Thea', '123456')->assertOk();
        $this->login('Thea@Example.com', '123456')->assertOk();
    }

    public function test_shared_usernames_with_the_same_capitals_are_told_apart_by_their_password(): void
    {
        $this->customer('Thea', 'one@example.com', 'password1');
        $this->customer('thea', 'two@example.com', 'password2');

        $this->login('thea', 'password2')->assertOk()->assertJsonPath('user.email', 'two@example.com');
        $this->login('Thea', 'password1')->assertOk()->assertJsonPath('user.email', 'one@example.com');
    }

    public function test_it_never_guesses_when_shared_usernames_have_the_same_password(): void
    {
        $this->customer('Thea', 'one@example.com', 'samepass');
        $this->customer('Thea', 'two@example.com', 'samepass');

        $this->login('Thea', 'samepass')->assertStatus(422)->assertJsonMissingPath('token');
        $this->login('two@example.com', 'samepass')->assertOk()->assertJsonPath('user.email', 'two@example.com');
    }

    public function test_a_customer_named_like_an_email_cannot_take_over_that_login(): void
    {
        $this->customer('other@example.com', 'mine@example.com', 'samepass');
        $this->customer('Other', 'other@example.com', 'samepass');

        // The exact e-mail wins over someone whose username looks the same
        $this->login('other@example.com', 'samepass')->assertOk()->assertJsonPath('user.name', 'Other');
    }

    public function test_a_taken_username_cannot_be_registered_again(): void
    {
        $this->customer('Thea', 'one@example.com', 'password1');

        $this->postJson('/api/register', [
            'name' => 'THEA', 'email' => 'two@example.com', 'password' => 'password2',
            'phone' => '012345678', 'address' => 'Phnom Penh',
        ])->assertStatus(422)->assertJsonValidationErrors('name');
    }

    public function test_a_disabled_account_cannot_log_in_with_its_username(): void
    {
        $user = $this->customer('Thea', 'one@example.com', 'password1');
        $user->forceFill(['blocked_at' => now()])->save();

        $this->login('Thea', 'password1')->assertForbidden();
    }
}
