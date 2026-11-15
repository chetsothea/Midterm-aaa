<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Tests\TestCase;

class ProfileTest extends TestCase
{
    use RefreshDatabase;

    private User $customer;

    protected function setUp(): void
    {
        parent::setUp();
        $this->customer = User::create(['name' => 'Dara', 'email' => 'dara@example.com', 'password' => 'secret123', 'role' => 'user', 'phone' => '012', 'address' => 'PP']);
    }

    protected function tearDown(): void
    {
        foreach (User::whereNotNull('avatar')->pluck('avatar') as $file) {
            @unlink(public_path('uploads/'.$file));
        }
        parent::tearDown();
    }

    private function picture(): UploadedFile
    {
        // A real 1x1 PNG, because the image rule looks at the content
        return UploadedFile::fake()->createWithContent('me.png', base64_decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=='
        ));
    }

    private function save(array $data = [])
    {
        return $this->actingAs($this->customer)->post('/api/profile', array_merge(
            ['name' => 'Dara', 'email' => 'dara@example.com', 'phone' => '012', 'address' => 'PP'], $data
        ), ['Accept' => 'application/json']);
    }

    public function test_the_customer_edits_their_details(): void
    {
        $this->save(['name' => 'Dara Sok', 'phone' => '099', 'address' => 'Siem Reap'])
            ->assertOk()->assertJsonPath('name', 'Dara Sok');

        $fresh = $this->customer->fresh();
        $this->assertSame(['Dara Sok', '099', 'Siem Reap'], [$fresh->name, $fresh->phone, $fresh->address]);
    }

    public function test_the_role_cannot_be_changed_here(): void
    {
        $this->save(['role' => 'admin'])->assertOk();

        $this->assertSame('user', $this->customer->fresh()->role);
    }

    public function test_the_customer_changes_their_email_and_logs_in_with_it(): void
    {
        $this->save(['email' => 'new@example.com'])->assertOk()->assertJsonPath('email', 'new@example.com');

        $this->postJson('/api/login', ['email' => 'new@example.com', 'password' => 'secret123'])->assertOk();
    }

    public function test_an_email_someone_else_uses_is_refused_but_keeping_yours_is_fine(): void
    {
        User::create(['name' => 'Thea', 'email' => 'thea@example.com', 'password' => 'secret123', 'role' => 'user']);

        $this->save(['email' => 'thea@example.com'])->assertUnprocessable()->assertJsonValidationErrors('email');
        $this->save(['email' => 'not-an-email'])->assertUnprocessable()->assertJsonValidationErrors('email');
        $this->save(['email' => 'dara@example.com'])->assertOk();
    }

    public function test_a_new_password_needs_no_old_one_and_replaces_it(): void
    {
        $this->save(['password' => 'brand-new-1'])->assertOk();

        $this->postJson('/api/login', ['email' => 'dara@example.com', 'password' => 'brand-new-1'])->assertOk();
        $this->postJson('/api/login', ['email' => 'dara@example.com', 'password' => 'secret123'])->assertUnauthorized();
    }

    public function test_an_empty_password_keeps_the_old_one_and_a_short_one_is_refused(): void
    {
        $this->save(['password' => ''])->assertOk();
        $this->postJson('/api/login', ['email' => 'dara@example.com', 'password' => 'secret123'])->assertOk();

        $this->save(['password' => '123'])->assertUnprocessable()->assertJsonValidationErrors('password');
    }

    public function test_a_new_password_logs_out_other_phones_but_not_this_one(): void
    {
        $other = $this->customer->createToken('other')->plainTextToken;
        $this_phone = $this->customer->createToken('this')->plainTextToken;

        $this->post('/api/profile', [
            'name' => 'Dara', 'email' => 'dara@example.com', 'phone' => '012', 'address' => 'PP', 'password' => 'brand-new-1',
        ], ['Accept' => 'application/json', 'Authorization' => "Bearer $this_phone"])->assertOk();

        $this->app['auth']->forgetGuards();
        $this->getJson('/api/me', ['Authorization' => "Bearer $other"])->assertUnauthorized();
        $this->app['auth']->forgetGuards();
        $this->getJson('/api/me', ['Authorization' => "Bearer $this_phone"])->assertOk();
    }

    public function test_a_new_picture_replaces_the_old_file(): void
    {
        $url = $this->save(['avatar' => $this->picture()])->assertOk()->json('avatar_url');
        $first = $this->customer->fresh()->avatar;
        $this->assertStringEndsWith('/uploads/'.$first, $url);
        $this->assertFileExists(public_path('uploads/'.$first));

        $this->customer->refresh();
        $this->save(['avatar' => $this->picture()])->assertOk();
        $this->assertFileDoesNotExist(public_path('uploads/'.$first));
    }

    public function test_only_pictures_are_accepted(): void
    {
        $file = UploadedFile::fake()->createWithContent('me.php', '<?php echo 1;');

        $this->save(['avatar' => $file])->assertUnprocessable()->assertJsonValidationErrors('avatar');
        $this->assertNull($this->customer->fresh()->avatar);
    }

    public function test_a_name_someone_else_uses_is_refused_but_your_own_shared_name_is_fine(): void
    {
        User::create(['name' => 'Thea', 'email' => 'thea@example.com', 'password' => 'secret123', 'role' => 'user']);

        $this->save(['name' => 'THEA'])->assertUnprocessable()->assertJsonValidationErrors('name');

        // Older accounts can share a name: keeping yours must still save
        $this->customer->forceFill(['name' => 'Thea'])->save();
        $this->save(['name' => 'Thea', 'phone' => '099'])->assertOk();
    }

    public function test_a_guest_cannot_edit_anything(): void
    {
        $this->postJson('/api/profile', ['name' => 'x', 'phone' => '1', 'address' => 'y'])->assertUnauthorized();
    }
}
