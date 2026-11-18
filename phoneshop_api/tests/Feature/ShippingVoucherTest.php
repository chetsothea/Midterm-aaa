<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Order;
use App\Models\Product;
use App\Models\User;
use App\Models\Voucher;
use App\Support\Shipping;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ShippingVoucherTest extends TestCase
{
    use RefreshDatabase;

    private Product $phone;

    private User $buyer;

    private User $admin;

    private const PP = 'ផ្ទះ 12, សង្កាត់បឹងកេងកង, ខណ្ឌបឹងកេងកង, រាជធានីភ្នំពេញ, កម្ពុជា';

    private const PROVINCE = 'ភូមិ ១, ឃុំ ក, ស្រុក ខ, ខេត្តបាត់ដំបង, កម្ពុជា';

    protected function setUp(): void
    {
        parent::setUp();
        $category = Category::firstOrCreate(['name' => 'Smartphone']);
        $this->phone = Product::create([
            'category_id' => $category->id, 'name' => 'Galaxy S26', 'brand' => 'Samsung', 'price' => 200, 'stock' => 10,
        ]);
        $this->buyer = User::create(['name' => 'Dara', 'email' => 'dara@example.com', 'password' => 'secret123', 'role' => 'user']);
        $this->admin = User::create(['name' => 'Boss', 'email' => 'boss@example.com', 'password' => 'secret123', 'role' => 'admin']);
        Shipping::setRates(1.5, 3, 500);
    }

    private function order(array $extra = [], int $qty = 1, ?User $as = null)
    {
        return $this->actingAs($as ?? $this->buyer)->postJson('/api/orders', [
            'items' => [['product_id' => $this->phone->id, 'qty' => $qty]],
            'payment_method' => 'cod',
            'customer_name' => 'Dara', 'customer_email' => 'dara@example.com',
            'phone' => '012345678', 'address' => self::PP,
            ...$extra,
        ]);
    }

    public function test_delivery_fee_depends_on_province_and_is_free_over_threshold(): void
    {
        $pp = $this->order()->assertCreated()->json();
        $this->assertEquals(200, $pp['subtotal']);
        $this->assertEquals(1.5, $pp['shipping_fee']);
        $this->assertEquals(201.5, $pp['total']);

        $province = $this->order(['address' => self::PROVINCE])->json();
        $this->assertEquals(3, $province['shipping_fee']);
        $this->assertEquals(203, $province['total']);

        $big = $this->order([], 3)->json(); // $600 ≥ $500
        $this->assertEquals(0, $big['shipping_fee']);
        $this->assertEquals(600, $big['total']);
    }

    public function test_percent_code_takes_money_off_and_counts_a_use(): void
    {
        Voucher::create(['code' => 'NEWYEAR10', 'type' => 'percent', 'value' => 10, 'min_total' => 100]);

        $order = $this->order(['voucher_code' => ' newyear10 '])->assertCreated()->json();
        $this->assertEquals(20, $order['discount']);
        $this->assertEquals('NEWYEAR10', $order['voucher_code']);
        $this->assertEquals(200 - 20 + 1.5, $order['total']);
        $this->assertSame(1, Voucher::first()->used_count);
    }

    public function test_quote_matches_what_the_order_will_cost(): void
    {
        Voucher::create(['code' => 'SAVE20', 'type' => 'fixed', 'value' => 20]);

        $this->actingAs($this->buyer)->postJson('/api/orders/quote', [
            'items' => [['product_id' => $this->phone->id, 'qty' => 2]],
            'address' => self::PROVINCE,
            'voucher_code' => 'save20',
        ])->assertOk()->assertJson([
            'subtotal' => 400, 'discount' => 20, 'voucher_label' => '$20',
            'shipping_fee' => 3, 'shipping_zone' => 'province', 'total' => 383,
        ]);
        $this->assertSame(0, Voucher::first()->used_count); // asking is not using
    }

    public function test_bad_codes_are_refused_with_a_reason(): void
    {
        Voucher::create(['code' => 'OLD', 'type' => 'fixed', 'value' => 5, 'expires_at' => now()->subDay()]);
        Voucher::create(['code' => 'BIG', 'type' => 'fixed', 'value' => 5, 'min_total' => 1000]);
        Voucher::create(['code' => 'OFF', 'type' => 'fixed', 'value' => 5, 'active' => false]);
        Voucher::create(['code' => 'ONE', 'type' => 'fixed', 'value' => 5, 'max_uses' => 1, 'used_count' => 1]);

        foreach (['NOPE' => 'រកមិនឃើញ', 'OLD' => 'ផុតកំណត់', 'BIG' => '$1000', 'OFF' => 'បិទ', 'ONE' => 'ប្រើអស់'] as $code => $why) {
            $this->order(['voucher_code' => $code])->assertStatus(422)
                ->assertJsonPath('errors.voucher_code.0', fn ($m) => str_contains($m, $why));
        }
        $this->assertSame(10, $this->phone->fresh()->stock); // nothing was reserved
    }

    public function test_a_customer_uses_a_code_once_and_gets_it_back_on_cancel(): void
    {
        Voucher::create(['code' => 'HELLO', 'type' => 'fixed', 'value' => 10]);

        $first = $this->order(['voucher_code' => 'HELLO'])->assertCreated()->json();
        $this->order(['voucher_code' => 'HELLO'])->assertStatus(422)
            ->assertJsonPath('errors.voucher_code.0', 'អ្នកបានប្រើកូដនេះរួចហើយ');

        Order::find($first['id'])->cancelAndRestock();
        $this->assertSame(0, Voucher::first()->used_count);
        $this->order(['voucher_code' => 'HELLO'])->assertCreated();
    }

    public function test_percent_code_respects_its_cap(): void
    {
        Voucher::create(['code' => 'HALF', 'type' => 'percent', 'value' => 50, 'max_discount' => 30]);

        $this->assertEquals(30, $this->order(['voucher_code' => 'HALF'])->json('discount'));
    }

    public function test_admin_manages_codes_and_delivery_prices(): void
    {
        $this->actingAs($this->admin);
        $id = $this->postJson('/api/admin/vouchers', ['code' => 'pchum', 'type' => 'percent', 'value' => 15])
            ->assertCreated()->assertJson(['code' => 'PCHUM', 'label' => '15%'])->json('id');
        $this->postJson('/api/admin/vouchers', ['code' => 'PCHUM', 'type' => 'fixed', 'value' => 5])
            ->assertStatus(422)->assertJsonPath('errors.code.0', 'កូដនេះមានរួចហើយ');
        $this->postJson('/api/admin/vouchers', ['code' => 'X', 'type' => 'percent', 'value' => 120])
            ->assertStatus(422);
        $this->putJson("/api/admin/vouchers/$id", ['code' => 'PCHUM', 'type' => 'percent', 'value' => 15, 'active' => false])
            ->assertOk()->assertJson(['active' => false]);

        $this->putJson('/api/admin/settings/shipping', ['phnom_penh' => 2, 'province' => 4.5, 'free_over' => 0])
            ->assertOk()->assertJson(['phnom_penh' => 2, 'province' => 4.5, 'free_over' => 0]);
        $this->getJson('/api/admin/vouchers')->assertOk()->assertJsonCount(1, 'vouchers')
            ->assertJsonPath('shipping.province', 4.5);
        $this->getJson('/api/payment-info')->assertJsonPath('shipping.phnom_penh', 2);

        $this->deleteJson("/api/admin/vouchers/$id")->assertOk();
        $this->assertSame(0, Voucher::count());
    }

    public function test_customers_cannot_manage_codes(): void
    {
        $this->actingAs($this->buyer)->postJson('/api/admin/vouchers', ['code' => 'FREE', 'type' => 'fixed', 'value' => 999])
            ->assertForbidden();
        $this->actingAs($this->buyer)->putJson('/api/admin/settings/shipping', ['phnom_penh' => 0, 'province' => 0, 'free_over' => 0])
            ->assertForbidden();
    }

    public function test_bakong_qr_carries_the_full_total_with_delivery(): void
    {
        config(['shop.bakong.token' => 't', 'shop.bakong.account_id' => 'ps168@aclb']);
        $order = $this->order(['payment_method' => 'khqr'])->json();
        $this->assertStringContainsString('5405201.5', $order['bakong_qr']);
    }
}
