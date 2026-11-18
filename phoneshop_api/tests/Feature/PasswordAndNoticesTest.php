<?php

namespace Tests\Feature;

use App\Mail\PasswordCodeMail;
use App\Models\Category;
use App\Models\Notice;
use App\Models\Order;
use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Mail;
use Tests\TestCase;

class PasswordAndNoticesTest extends TestCase
{
    use RefreshDatabase;

    private User $buyer;

    private User $admin;

    protected function setUp(): void
    {
        parent::setUp();
        $this->buyer = User::create(['name' => 'Dara', 'email' => 'dara@example.com', 'password' => 'oldpass1', 'role' => 'user']);
        $this->admin = User::create(['name' => 'Boss', 'email' => 'boss@example.com', 'password' => 'secret123', 'role' => 'admin']);
    }

    private function codeFor(string $email): ?string
    {
        $code = null;
        Mail::fake();
        $this->postJson('/api/password/code', ['email' => $email])->assertOk();
        Mail::assertSent(PasswordCodeMail::class, function ($mail) use (&$code) {
            $code = $mail->code;

            return true;
        });

        return $code;
    }

    public function test_forgot_password_with_an_emailed_code(): void
    {
        $this->buyer->createToken('old-phone');
        $code = $this->codeFor('dara@example.com');
        $this->assertMatchesRegularExpression('/^\d{6}$/', $code);

        $this->postJson('/api/password/reset', [
            'email' => 'dara@example.com', 'code' => $code,
            'password' => 'newpass99', 'password_confirmation' => 'newpass99',
        ])->assertOk();

        $this->postJson('/api/login', ['email' => 'dara@example.com', 'password' => 'newpass99'])->assertOk();
        $this->assertSame(1, $this->buyer->tokens()->count()); // the old phone was logged out; only the new login
        // The code works once
        $this->postJson('/api/password/reset', [
            'email' => 'dara@example.com', 'code' => $code,
            'password' => 'another1', 'password_confirmation' => 'another1',
        ])->assertStatus(422);
    }

    public function test_unknown_emails_and_the_admin_get_the_same_answer_but_no_mail(): void
    {
        Mail::fake();
        $a = $this->postJson('/api/password/code', ['email' => 'nobody@example.com'])->assertOk()->json('message');
        $b = $this->postJson('/api/password/code', ['email' => 'boss@example.com'])->assertOk()->json('message');
        $this->assertSame($a, $b);
        Mail::assertNothingSent();
    }

    public function test_wrong_codes_are_limited(): void
    {
        $code = $this->codeFor('dara@example.com');
        $wrong = $code === '000000' ? '111111' : '000000';
        for ($i = 0; $i < 5; $i++) {
            $this->postJson('/api/password/reset', [
                'email' => 'dara@example.com', 'code' => $wrong,
                'password' => 'newpass99', 'password_confirmation' => 'newpass99',
            ])->assertStatus(422);
        }
        // Even the right code no longer works after 5 misses
        $this->postJson('/api/password/reset', [
            'email' => 'dara@example.com', 'code' => $code,
            'password' => 'newpass99', 'password_confirmation' => 'newpass99',
        ])->assertStatus(422);
    }

    public function test_customer_hears_about_order_steps_and_payment(): void
    {
        $category = Category::firstOrCreate(['name' => 'Smartphone']);
        $phone = Product::create(['category_id' => $category->id, 'name' => 'X', 'brand' => 'X', 'price' => 100, 'stock' => 5]);
        $id = $this->actingAs($this->buyer)->postJson('/api/orders', [
            'items' => [['product_id' => $phone->id, 'qty' => 1]], 'payment_method' => 'cod',
            'customer_name' => 'Dara', 'customer_email' => 'dara@example.com', 'phone' => '012', 'address' => 'Phnom Penh',
        ])->json('id');
        $this->assertSame(0, Notice::count()); // placing it is not news to them

        $this->actingAs($this->admin)->putJson("/api/admin/orders/$id", ['status' => 'confirmed'])->assertOk();
        $this->actingAs($this->admin)->putJson("/api/admin/orders/$id", ['status' => 'shipping', 'courier' => 'J&T'])->assertOk();
        $this->actingAs($this->admin)->putJson("/api/admin/orders/$id", ['payment_status' => 'paid'])->assertOk();

        $inbox = $this->actingAs($this->buyer)->getJson('/api/notices')->assertOk()->json();
        $this->assertSame(3, $inbox['unread']);
        $this->assertStringContainsString('បានទទួលប្រាក់', $inbox['notices'][0]['title']);
        $this->assertStringContainsString('J&T', $inbox['notices'][1]['body']);
        $this->assertSame($id, $inbox['notices'][2]['order_id']);

        $this->actingAs($this->buyer)->postJson('/api/notices/read')->assertOk();
        $this->actingAs($this->buyer)->getJson('/api/notices')->assertJsonPath('unread', 0);

        // Their own cancel is not a notice; another customer sees nothing
        $this->actingAs($this->buyer)->postJson("/api/orders/$id/received")->assertOk();
        $this->assertSame(0, Notice::whereNull('read_at')->count());
        $other = User::create(['name' => 'S', 'email' => 's@example.com', 'password' => 'secret123', 'role' => 'user']);
        $this->actingAs($other)->getJson('/api/notices')->assertJsonCount(0, 'notices');
    }

    public function test_unpaid_order_cancelled_by_the_shop_clock_is_told(): void
    {
        $category = Category::firstOrCreate(['name' => 'Smartphone']);
        $phone = Product::create(['category_id' => $category->id, 'name' => 'X', 'brand' => 'X', 'price' => 100, 'stock' => 5]);
        $id = $this->actingAs($this->buyer)->postJson('/api/orders', [
            'items' => [['product_id' => $phone->id, 'qty' => 1]], 'payment_method' => 'khqr',
            'customer_name' => 'Dara', 'customer_email' => 'dara@example.com', 'phone' => '012', 'address' => 'Phnom Penh',
        ])->json('id');
        $this->app['auth']->forgetGuards();
        $this->travel(31)->minutes();
        Order::expireUnpaid();

        $this->assertSame('cancelled', Order::find($id)->status);
        $this->assertSame(1, Notice::where('user_id', $this->buyer->id)->count());
    }
}
