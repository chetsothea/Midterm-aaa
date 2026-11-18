<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Order;
use App\Models\Product;
use App\Models\User;
use App\Services\Bakong\Khqr;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class BakongPaymentTest extends TestCase
{
    use RefreshDatabase;

    private Product $phone;

    private User $buyer;

    protected function setUp(): void
    {
        parent::setUp();
        config([
            'shop.bakong.token' => 'test-token',
            'shop.bakong.account_id' => 'ps168@aclb',
            'shop.bakong.api_url' => 'https://bakong.test',
            'shop.bakong.currency' => 'USD',
        ]);
        $category = Category::firstOrCreate(['name' => 'Smartphone']);
        $this->phone = Product::create([
            'category_id' => $category->id, 'name' => 'iPhone 17', 'brand' => 'Apple', 'price' => 999.5, 'stock' => 5,
        ]);
        $this->buyer = User::create(['name' => 'Dara', 'email' => 'dara@example.com', 'password' => 'secret123', 'role' => 'user']);
    }

    private function placeOrder(string $method = 'khqr'): array
    {
        return $this->actingAs($this->buyer)->postJson('/api/orders', [
            'items' => [['product_id' => $this->phone->id, 'qty' => 1]],
            'payment_method' => $method,
            'customer_name' => 'Dara', 'customer_email' => 'dara@example.com',
            'phone' => '012345678', 'address' => 'Phnom Penh',
        ])->assertCreated()->json();
    }

    // What the fake Bakong answers next; can change during a test
    private array $reply = [];

    private bool $faked = false;

    private function bakongSays(?array $data, int $status = 200): void
    {
        $this->reply = [
            $data === null
                ? ['responseCode' => 1, 'responseMessage' => 'Transaction could not be found.', 'data' => null]
                : ['responseCode' => 0, 'responseMessage' => 'Getting transaction successfully.', 'data' => $data],
            $status,
        ];
        if (! $this->faked) {
            $this->faked = true;
            Http::fake(['bakong.test/*' => fn () => Http::response(...$this->reply)]);
        }
    }

    private function paidData(array $over = []): array
    {
        return [
            'hash' => 'abc123hash', 'fromAccountId' => 'dara@aba', 'toAccountId' => 'ps168@aclb',
            'currency' => 'USD', 'amount' => 999.5, ...$over,
        ];
    }

    public function test_the_crc_matches_the_emv_standard(): void
    {
        $this->assertSame('29B1', Khqr::crc16('123456789'));
    }

    public function test_a_khqr_order_gets_its_own_qr_with_the_amount_and_order_code(): void
    {
        $order = $this->placeOrder();
        $qr = $order['bakong_qr'];

        $this->assertStringStartsWith('000201010212', $qr); // dynamic QR
        $this->assertStringContainsString(Khqr::tag('29', Khqr::tag('00', 'ps168@aclb')), $qr);
        $this->assertStringContainsString(Khqr::tag('54', '999.5'), $qr);
        $this->assertStringContainsString('5303840', $qr); // USD
        $this->assertStringContainsString($order['code'], $qr);
        // The CRC at the end is right
        $this->assertSame(substr($qr, -4), Khqr::crc16(substr($qr, 0, -4)));
        $this->assertArrayNotHasKey('bakong_md5', $order); // never sent to the app
        $this->assertSame(md5($qr), Order::find($order['id'])->bakong_md5);

        // Cash on delivery gets none
        $this->assertNull($this->placeOrder('cod')['bakong_qr']);
    }

    public function test_once_bakong_shows_the_payment_the_order_is_paid(): void
    {
        $order = $this->placeOrder();

        $this->bakongSays(null);
        $this->actingAs($this->buyer)->getJson("/api/orders/{$order['id']}/check-payment")
            ->assertOk()->assertJsonPath('payment_status', 'unpaid');

        $this->travel(5)->seconds();
        $this->bakongSays($this->paidData());
        $this->actingAs($this->buyer)->getJson("/api/orders/{$order['id']}/check-payment")
            ->assertOk()
            ->assertJsonPath('payment_status', 'paid')
            ->assertJsonPath('transaction_ref', 'abc123hash')
            ->assertJsonPath('bakong_down', false);

        Http::assertSent(fn ($request) => $request->url() === 'https://bakong.test/v1/check_transaction_by_md5'
            && $request['md5'] === md5($order['bakong_qr'])
            && $request->hasHeader('Authorization', 'Bearer test-token'));
    }

    public function test_less_money_or_another_account_is_not_accepted(): void
    {
        $order = $this->placeOrder();
        $this->bakongSays($this->paidData(['amount' => 1]));
        $this->actingAs($this->buyer)->getJson("/api/orders/{$order['id']}/check-payment")
            ->assertJsonPath('payment_status', 'verifying'); // admin looks

        $other = $this->placeOrder();
        $this->bakongSays($this->paidData(['toAccountId' => 'someone@aba']));
        $this->actingAs($this->buyer)->getJson("/api/orders/{$other['id']}/check-payment")
            ->assertJsonPath('payment_status', 'verifying');
    }

    public function test_when_bakong_is_down_nothing_is_marked_and_the_app_is_told(): void
    {
        $order = $this->placeOrder();
        $this->bakongSays(null, 500);
        $this->actingAs($this->buyer)->getJson("/api/orders/{$order['id']}/check-payment")
            ->assertOk()
            ->assertJsonPath('payment_status', 'unpaid')
            ->assertJsonPath('bakong_down', true);
    }

    public function test_a_payment_at_the_last_second_saves_the_order_from_cancelling(): void
    {
        $order = $this->placeOrder();
        $this->travel(31)->minutes();
        $this->bakongSays($this->paidData());

        $this->assertSame(0, Order::expireUnpaid());
        $this->assertSame('paid', Order::find($order['id'])->payment_status);
        $this->assertSame('pending', Order::find($order['id'])->status);
    }

    public function test_an_unpaid_order_is_still_cancelled_and_bakong_down_only_delays_it(): void
    {
        $order = $this->placeOrder();
        $this->travel(31)->minutes();
        $this->bakongSays(null, 503);
        $this->assertSame(0, Order::expireUnpaid()); // can't tell yet: wait
        $this->assertSame('pending', Order::find($order['id'])->status);

        $this->bakongSays(null); // Bakong back: not paid
        $this->assertSame(1, Order::expireUnpaid());
        $this->assertSame('cancelled', Order::find($order['id'])->status);
        $this->assertSame(5, $this->phone->fresh()->stock);
    }

    public function test_the_scheduler_finds_payments_of_customers_who_closed_the_app(): void
    {
        $order = $this->placeOrder();
        $this->bakongSays($this->paidData());
        $this->artisan('orders:check-bakong')->assertSuccessful();
        $this->assertSame('paid', Order::find($order['id'])->payment_status);
    }

    public function test_only_the_owner_can_check(): void
    {
        $order = $this->placeOrder();
        $stranger = User::create(['name' => 'X', 'email' => 'x@example.com', 'password' => 'secret123', 'role' => 'user']);
        $this->actingAs($stranger)->getJson("/api/orders/{$order['id']}/check-payment")->assertNotFound();
    }

    public function test_without_a_token_bakong_is_off_and_orders_work_as_before(): void
    {
        config(['shop.bakong.token' => '']);
        $order = $this->placeOrder();
        $this->assertNull($order['bakong_qr']);
        $this->getJson('/api/payment-info')->assertJsonPath('bakong', false);
    }
}
