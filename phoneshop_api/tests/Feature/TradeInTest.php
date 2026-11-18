<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Product;
use App\Models\TradeIn;
use App\Models\User;
use App\Models\Voucher;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Tests\TestCase;

class TradeInTest extends TestCase
{
    use RefreshDatabase;

    private User $buyer;

    private User $other;

    private User $admin;

    private Product $phone;

    protected function setUp(): void
    {
        parent::setUp();
        $category = Category::firstOrCreate(['name' => 'Smartphone']);
        $this->phone = Product::create(['category_id' => $category->id, 'name' => 'iPhone 17', 'brand' => 'Apple', 'price' => 999, 'stock' => 5]);
        $this->buyer = User::create(['name' => 'Dara', 'email' => 'dara@example.com', 'password' => 'secret123', 'role' => 'user']);
        $this->other = User::create(['name' => 'Sok', 'email' => 'sok@example.com', 'password' => 'secret123', 'role' => 'user']);
        $this->admin = User::create(['name' => 'Boss', 'email' => 'boss@example.com', 'password' => 'secret123', 'role' => 'admin']);
    }

    protected function tearDown(): void
    {
        foreach (glob(public_path('uploads/tradein_*')) as $f) {
            if (filemtime($f) >= time() - 120) {
                @unlink($f);
            }
        }
        parent::tearDown();
    }

    private function send(array $extra = []): array
    {
        return $this->actingAs($this->buyer)->post('/api/trade-ins', [
            'brand' => 'Apple', 'model' => 'iPhone 13', 'storage' => '128GB',
            'condition' => 'good', 'battery_health' => 86, 'notes' => 'Small scratch',
            'wanted_product_id' => $this->phone->id,
            ...$extra,
        ], ['Accept' => 'application/json'])->assertCreated()->json();
    }

    public function test_full_trade_in_ends_with_a_code_only_the_customer_can_use(): void
    {
        $sent = $this->send(['photos' => [UploadedFile::fake()->image('front.jpg'), UploadedFile::fake()->image('back.jpg')]]);
        $this->assertSame('pending', $sent['status']);
        $this->assertCount(2, $sent['photo_urls']);
        $this->assertStringContainsString('/media/tradein_', $sent['photo_urls'][0]);
        $this->assertSame('iPhone 17', $sent['wanted_product']['name']);

        // The admin offers; the customer can't complete it themselves
        $this->actingAs($this->admin)->putJson("/api/admin/trade-ins/{$sent['id']}/offer", ['offer_amount' => 250, 'admin_note' => 'Battery OK'])
            ->assertOk()->assertJson(['status' => 'offered', 'offer_amount' => 250]);
        $this->actingAs($this->admin)->postJson("/api/admin/trade-ins/{$sent['id']}/complete")->assertStatus(422);

        $this->actingAs($this->buyer)->postJson("/api/trade-ins/{$sent['id']}/accept")->assertOk()->assertJsonPath('status', 'accepted');

        $done = $this->actingAs($this->admin)->postJson("/api/admin/trade-ins/{$sent['id']}/complete")->assertOk()->json();
        $this->assertSame('completed', $done['status']);
        $this->assertStringStartsWith('TRADE-', $done['voucher_code']);

        $voucher = Voucher::where('code', $done['voucher_code'])->first();
        $this->assertEquals(250, $voucher->value);
        $this->assertSame(1, $voucher->max_uses);

        // Not listed with the shop's public codes
        $this->actingAs($this->admin)->getJson('/api/admin/vouchers')->assertJsonCount(0, 'vouchers');

        $quote = fn (User $as) => $this->actingAs($as)->postJson('/api/orders/quote', [
            'items' => [['product_id' => $this->phone->id, 'qty' => 1]],
            'voucher_code' => $done['voucher_code'],
        ]);
        $quote($this->buyer)->assertOk()->assertJson(['discount' => 250, 'total' => 749]);
        $quote($this->other)->assertStatus(422)->assertJsonPath('errors.voucher_code.0', 'រកមិនឃើញកូដនេះទេ');

        // The customer was told about the offer and the code in the app's 🔔
        $titles = $this->actingAs($this->buyer)->getJson('/api/notices')->json('notices.*.title');
        $this->assertSame(['កូដ Trade-in: '.$done['voucher_code'], 'តម្លៃ Trade-in: $250.00'], $titles);
    }

    public function test_customer_can_decline_or_cancel_and_sees_only_their_own(): void
    {
        $a = $this->send();
        $b = $this->send();
        $this->actingAs($this->buyer)->postJson("/api/trade-ins/{$a['id']}/accept")->assertStatus(422); // no offer yet
        $this->actingAs($this->admin)->putJson("/api/admin/trade-ins/{$a['id']}/offer", ['offer_amount' => 100])->assertOk();
        $this->actingAs($this->buyer)->postJson("/api/trade-ins/{$a['id']}/decline")->assertOk()->assertJsonPath('status', 'declined');
        $this->actingAs($this->buyer)->postJson("/api/trade-ins/{$b['id']}/cancel")->assertOk()->assertJsonPath('status', 'cancelled');

        $this->actingAs($this->other)->getJson('/api/trade-ins')->assertJsonCount(0);
        $this->actingAs($this->other)->postJson("/api/trade-ins/{$a['id']}/cancel")->assertNotFound();
        $this->actingAs($this->buyer)->getJson('/api/trade-ins')->assertJsonCount(2);
    }

    public function test_admin_can_refuse_and_list_by_status(): void
    {
        $a = $this->send();
        $this->send();
        $this->actingAs($this->admin)->postJson("/api/admin/trade-ins/{$a['id']}/reject", ['admin_note' => 'Screen broken inside'])
            ->assertOk()->assertJson(['status' => 'rejected', 'admin_note' => 'Screen broken inside']);
        $this->actingAs($this->admin)->getJson('/api/admin/trade-ins?status=pending')->assertJsonCount(1)
            ->assertJsonPath('0.user.name', 'Dara');
        $this->actingAs($this->admin)->putJson("/api/admin/trade-ins/{$a['id']}/offer", ['offer_amount' => 50])->assertStatus(422);
    }

    public function test_bad_requests_and_limits(): void
    {
        $this->actingAs($this->buyer)->postJson('/api/trade-ins', ['brand' => '', 'model' => 'X', 'condition' => 'melted'])
            ->assertStatus(422)->assertJsonValidationErrors(['brand', 'condition']);
        $this->send();
        $this->send();
        $this->send();
        $this->actingAs($this->buyer)->postJson('/api/trade-ins', ['brand' => 'A', 'model' => 'B', 'condition' => 'good'])
            ->assertStatus(422); // three open already

        // Staff can't set money; customers can't reach admin
        $staff = User::create(['name' => 'St', 'email' => 'st@example.com', 'password' => 'secret123', 'role' => 'staff']);
        $id = TradeIn::first()->id;
        $this->actingAs($staff)->putJson("/api/admin/trade-ins/$id/offer", ['offer_amount' => 9999])->assertForbidden();
        $this->actingAs($this->buyer)->getJson('/api/admin/trade-ins')->assertForbidden();
    }
}
