<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class GoogleLoginTest extends TestCase
{
    use RefreshDatabase;

    private const CLIENT_ID = 'test-web-client.apps.googleusercontent.com';

    protected function setUp(): void
    {
        parent::setUp();
        config(['services.google.client_id' => self::CLIENT_ID]);
    }

    // What Google's tokeninfo endpoint answers for an ID token
    private function googleSays(array $claims = [], int $status = 200): void
    {
        Http::fake(['oauth2.googleapis.com/*' => Http::response(array_merge([
            'aud' => self::CLIENT_ID,
            'iss' => 'https://accounts.google.com',
            'exp' => (string) (time() + 3600),
            'sub' => '1234567890',
            'email' => 'dara@gmail.com',
            'email_verified' => 'true',
            'name' => 'Dara Sok',
        ], $claims), $status)]);
    }

    public function test_first_google_login_creates_a_customer_account(): void
    {
        $this->googleSays();

        $response = $this->postJson('/api/auth/google', ['id_token' => 'token'])->assertOk();

        $response->assertJsonPath('user.email', 'dara@gmail.com')
            ->assertJsonPath('user.name', 'Dara Sok')
            ->assertJsonPath('user.role', 'user')
            ->assertJsonMissingPath('user.google_id');
        $this->assertNotEmpty($response->json('token'));
        $this->assertSame('1234567890', User::firstWhere('email', 'dara@gmail.com')->google_id);
    }

    public function test_existing_account_with_the_same_email_is_linked_not_duplicated(): void
    {
        $existing = User::create(['name' => 'Dara', 'email' => 'dara@gmail.com', 'password' => 'secret123', 'role' => 'user']);
        $this->googleSays();

        $this->postJson('/api/auth/google', ['id_token' => 'token'])
            ->assertOk()
            ->assertJsonPath('user.id', $existing->id);

        $this->assertSame(1, User::count());
        $this->assertSame('1234567890', $existing->fresh()->google_id);
    }

    public function test_token_made_for_another_app_is_rejected(): void
    {
        $this->googleSays(['aud' => 'someone-elses-app.apps.googleusercontent.com']);

        $this->postJson('/api/auth/google', ['id_token' => 'token'])->assertUnauthorized();
        $this->assertSame(0, User::count());
    }

    public function test_unverified_email_is_rejected(): void
    {
        $this->googleSays(['email_verified' => 'false']);

        $this->postJson('/api/auth/google', ['id_token' => 'token'])->assertUnauthorized();
    }

    public function test_expired_or_invalid_token_is_rejected(): void
    {
        $this->googleSays(['error' => 'invalid_token'], 400);

        $this->postJson('/api/auth/google', ['id_token' => 'token'])->assertUnauthorized();
    }

    public function test_google_login_is_off_until_a_client_id_is_set(): void
    {
        config(['services.google.client_id' => '']);

        $this->getJson('/api/auth/google-config')->assertExactJson(['client_id' => '']);
        $this->postJson('/api/auth/google', ['id_token' => 'token'])->assertStatus(503);
    }
}
