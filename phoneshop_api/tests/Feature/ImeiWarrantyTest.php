<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Order;
use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Tests\TestCase;

class ImeiWarrantyTest extends TestCase
{
    use RefreshDatabase;

    // Real-format IMEIs (valid Luhn check digit)
    private const A = '490154203237518';

    private const B = '356938035643809';

    private User $buyer;

    private User $admin;

    private Product $phone;

    protected function setUp(): void
    {
        parent::setUp();
        $category = Category::firstOrCreate(['name' => 'Smartphone']);
        $this->phone = Product::create([
            'category_id' => $category->id, 'name' => 'iPhone 17', 'brand' => 'Apple', 'price' => 999, 'stock' => 5,
        ]);
        $this->buyer = User::create(['name' => 'Dara', 'email' => 'dara@example.com', 'password' => 'secret123', 'role' => 'user']);
        $this->admin = User::create(['name' => 'Boss', 'email' => 'boss@example.com', 'password' => 'secret123', 'role' => 'admin']);
    }

    private function buy(int $qty = 2): array
    {
        return $this->actingAs($this->buyer)->postJson('/api/orders', [
            'items' => [['product_id' => $this->phone->id, 'qty' => $qty]],
            'payment_method' => 'cod',
            'customer_name' => 'Dara', 'customer_email' => 'dara@example.com',
            'phone' => '012345678', 'address' => 'Phnom Penh',
        ])->assertCreated()->json();
    }

    public function test_warranty_starts_on_delivery_and_lasts_the_phones_months(): void
    {
        $this->phone->update(['warranty_months' => 6]);
        $order = $this->buy();
        $this->assertSame(6, $order['items'][0]['warranty_months']);
        $this->assertNull($order['items'][0]['warranty_until']); // not delivered yet

        Carbon::setTestNow('2026-11-18 10:00:00');
        $this->actingAs($this->admin)->putJson("/api/admin/orders/{$order['id']}", ['status' => 'delivered'])->assertOk();
        // Changing the phone later does not change what was sold
        $this->phone->update(['warranty_months' => 24]);

        $item = $this->actingAs($this->buyer)->getJson("/api/orders/{$order['id']}")->json('items.0');
        $this->assertStringStartsWith('2027-05-18', $item['warranty_until']);
        Carbon::setTestNow();
    }

    public function test_admin_records_imeis_and_looks_up_a_warranty(): void
    {
        $order = $this->buy(2);
        $itemId = $order['items'][0]['id'];
        $this->actingAs($this->admin);

        $this->putJson("/api/admin/order-items/$itemId/imeis", ['imeis' => ['4901 5420 3237 518', self::B]])
            ->assertOk()->assertJsonPath('imeis', [self::A, self::B]);

        // The customer sees them on their order
        $this->actingAs($this->buyer)->getJson("/api/orders/{$order['id']}")
            ->assertJsonPath('items.0.imeis', [self::A, self::B]);

        $this->actingAs($this->admin);
        Order::find($order['id'])->update(['status' => 'delivered']);
        $this->getJson('/api/admin/warranty/'.self::B)->assertOk()->assertJson([
            'product' => 'iPhone 17', 'customer_name' => 'Dara', 'warranty_months' => 12, 'under_warranty' => true,
        ]);
        $this->getJson('/api/admin/warranty/111111111111116')->assertNotFound();

        // Taking one off keeps the other
        $this->putJson("/api/admin/order-items/$itemId/imeis", ['imeis' => [self::A]])
            ->assertOk()->assertJsonPath('imeis', [self::A]);
    }

    public function test_wrong_imeis_are_refused(): void
    {
        $first = $this->buy(1);
        $second = $this->buy(1);
        $this->actingAs($this->admin);
        $item = $first['items'][0]['id'];

        $this->putJson("/api/admin/order-items/$item/imeis", ['imeis' => ['12345']])
            ->assertStatus(422)->assertJsonPath('errors', fn ($e) => str_contains(json_encode($e, JSON_UNESCAPED_UNICODE), '15 ខ្ទង់'));
        $this->putJson("/api/admin/order-items/$item/imeis", ['imeis' => ['490154203237519']]) // bad check digit
            ->assertStatus(422);
        $this->putJson("/api/admin/order-items/$item/imeis", ['imeis' => [self::A, self::B]]) // only 1 phone
            ->assertStatus(422)->assertJsonPath('errors.imeis.0', 'Order នេះមានតែ 1 គ្រឿងប៉ុណ្ណោះ');

        $this->putJson("/api/admin/order-items/$item/imeis", ['imeis' => [self::A]])->assertOk();
        $this->putJson("/api/admin/order-items/{$second['items'][0]['id']}/imeis", ['imeis' => [self::A]])
            ->assertStatus(422)->assertJsonPath('errors.imeis.0', fn ($m) => str_contains($m, 'លក់រួចហើយ'));
    }

    public function test_customers_cannot_set_or_look_up_imeis(): void
    {
        $order = $this->buy(1);
        $this->actingAs($this->buyer)->putJson("/api/admin/order-items/{$order['items'][0]['id']}/imeis", ['imeis' => [self::A]])
            ->assertForbidden();
        $this->actingAs($this->buyer)->getJson('/api/admin/warranty/'.self::A)->assertForbidden();
    }
}
