<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Order;
use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Tests\TestCase;

class StaffAndReportsTest extends TestCase
{
    use RefreshDatabase;

    private User $admin;

    private User $buyer;

    private Product $phone;

    protected function setUp(): void
    {
        parent::setUp();
        $category = Category::firstOrCreate(['name' => 'Smartphone']);
        $this->phone = Product::create(['category_id' => $category->id, 'name' => 'ទូរស័ព្ទ X', 'brand' => 'X', 'price' => 100, 'stock' => 50]);
        $this->admin = User::create(['name' => 'Boss', 'email' => 'boss@example.com', 'password' => 'secret123', 'role' => 'admin']);
        $this->buyer = User::create(['name' => 'Dara', 'email' => 'dara@example.com', 'password' => 'secret123', 'role' => 'user']);
    }

    private function order(int $qty, string $payment = 'paid', string $status = 'confirmed', string $method = 'cod', string $name = 'Dara'): Order
    {
        $id = $this->actingAs($this->buyer)->postJson('/api/orders', [
            'items' => [['product_id' => $this->phone->id, 'qty' => $qty]],
            'payment_method' => $method,
            'customer_name' => $name, 'customer_email' => 'dara@example.com',
            'phone' => '012345678', 'address' => 'Phnom Penh',
        ])->assertCreated()->json('id');
        $order = Order::find($id);
        $order->update(['payment_status' => $payment, 'status' => $status]);

        return $order;
    }

    public function test_admin_creates_staff_who_can_work_orders_but_not_money_or_settings(): void
    {
        $this->actingAs($this->admin)->postJson('/api/admin/staff', [
            'name' => 'Sok', 'email' => 'sok@example.com', 'password' => 'staffpass1',
        ])->assertCreated();
        $staff = User::where('email', 'sok@example.com')->first();
        $this->assertSame('staff', $staff->role);

        // Logs in like anyone else, and the app learns the role
        $this->app['auth']->forgetGuards();
        $this->postJson('/api/login', ['email' => 'sok@example.com', 'password' => 'staffpass1'])
            ->assertOk()->assertJsonPath('user.role', 'staff');

        $order = $this->order(1, 'unpaid', 'pending');
        $this->actingAs($staff);
        $this->getJson('/api/admin/orders')->assertOk();
        $this->putJson("/api/admin/orders/{$order->id}", ['status' => 'confirmed'])->assertOk();
        $this->getJson('/api/admin/warranty/490154203237518')->assertNotFound();

        foreach ([
            ['get', '/api/admin/dashboard'],
            ['get', '/api/admin/reports/sales'],
            ['get', '/api/admin/customers'],
            ['get', '/api/admin/staff'],
            ['get', '/api/admin/vouchers'],
            ['post', '/api/admin/products'],
            ['delete', "/api/admin/orders/{$order->id}"],
            ['put', '/api/admin/settings/shipping'],
        ] as [$method, $url]) {
            $this->json($method, $url)->assertForbidden();
        }

        // Customers can do neither
        $this->actingAs($this->buyer)->getJson('/api/admin/orders')->assertForbidden();
    }

    public function test_admin_can_reset_and_remove_staff_but_not_customers_through_it(): void
    {
        $this->actingAs($this->admin);
        $id = $this->postJson('/api/admin/staff', ['name' => 'Sok', 'email' => 'sok@example.com', 'password' => 'staffpass1'])->json('id');
        $this->getJson('/api/admin/staff')->assertJsonCount(1)->assertJsonPath('0.email', 'sok@example.com');
        $this->putJson("/api/admin/staff/$id", ['name' => 'Sok Dara', 'password' => 'newpass99'])->assertOk()->assertJsonPath('name', 'Sok Dara');
        $this->putJson("/api/admin/staff/{$this->buyer->id}", ['name' => 'X'])->assertStatus(422);
        $this->deleteJson("/api/admin/staff/{$this->buyer->id}")->assertStatus(422);
        $this->deleteJson("/api/admin/staff/$id")->assertOk();
        $this->assertNull(User::find($id));
    }

    public function test_sales_report_counts_paid_money_per_day_product_and_payment(): void
    {
        Carbon::setTestNow('2026-11-10 03:00:00'); // 10:00 in Phnom Penh
        $this->order(2, 'paid', 'delivered');            // $200 paid
        $this->order(1, 'unpaid', 'pending', 'khqr');    // $100 still to pay
        $this->order(3, 'paid', 'cancelled');            // cancelled: not counted
        Carbon::setTestNow('2026-11-11 18:00:00'); // 01:00 on the 12th in Phnom Penh
        $this->order(1, 'paid', 'delivered', 'khqr');    // $100 paid, on the 12th
        Carbon::setTestNow('2026-11-20 03:00:00');

        $report = $this->actingAs($this->admin)
            ->getJson('/api/admin/reports/sales?from=2026-11-10&to=2026-11-12')->assertOk()->json();

        $this->assertSame(3, $report['orders']);
        $this->assertSame(2, $report['paid_orders']);
        $this->assertSame(1, $report['cancelled_orders']);
        $this->assertEquals(300, $report['revenue']);
        $this->assertSame(3, $report['phones_sold']);
        $this->assertEquals(100, $report['unpaid_total']);
        $this->assertEquals(150, $report['average_order']);
        $this->assertSame(
            [['2026-11-10', 2, 200], ['2026-11-11', 0, 0], ['2026-11-12', 1, 100]],
            array_map(fn ($d) => [$d['date'], $d['orders'], (int) $d['revenue']], $report['by_day'])
        );
        $this->assertSame([['name' => 'ទូរស័ព្ទ X', 'qty' => 3, 'revenue' => 300]],
            array_map(fn ($p) => ['name' => $p['name'], 'qty' => $p['qty'], 'revenue' => (int) $p['revenue']], $report['top_products']));
        $this->assertEqualsCanonicalizing(['cod', 'khqr'], array_column($report['by_payment'], 'method'));
        Carbon::setTestNow();
    }

    public function test_csv_opens_in_excel_with_khmer_and_cannot_run_formulas(): void
    {
        $this->order(2, 'paid', 'delivered', 'cod', '=HYPERLINK("http://evil")');
        $today = now('Asia/Phnom_Penh')->toDateString();

        $response = $this->actingAs($this->admin)->get("/api/admin/reports/sales.csv?from=$today&to=$today")->assertOk();
        $this->assertStringContainsString('text/csv', $response->headers->get('Content-Type'));
        $this->assertStringContainsString("ps168-sales-$today-to-$today.csv", $response->headers->get('Content-Disposition'));

        $csv = $response->getContent();
        $this->assertStringStartsWith("\xEF\xBB\xBF", $csv);
        $this->assertStringContainsString('ទូរស័ព្ទ X', $csv);
        $this->assertStringContainsString("'=HYPERLINK", $csv);
        $this->assertSame(2, substr_count(trim($csv), "\n") + 1); // header + one line
    }

    public function test_report_range_is_checked(): void
    {
        $this->actingAs($this->admin)->getJson('/api/admin/reports/sales?from=2026-11-10&to=2026-11-01')->assertStatus(422);
        $this->actingAs($this->admin)->getJson('/api/admin/reports/sales?from=2020-01-01&to=2026-01-01')->assertStatus(422);
        $this->actingAs($this->admin)->getJson('/api/admin/reports/sales')->assertOk()->assertJsonCount(30, 'by_day');
    }
}
