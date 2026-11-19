<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Order;
use App\Models\Product;
use App\Models\TradeIn;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class DeleteOwnAccountTest extends TestCase
{
    use RefreshDatabase;

    private User $dara;

    protected function setUp(): void
    {
        parent::setUp();
        $this->dara = User::create(['name' => 'Dara', 'email' => 'dara@example.com', 'password' => 'secret123', 'role' => 'user']);
    }

    private function order(string $status): Order
    {
        $category = Category::firstOrCreate(['name' => 'Smartphone']);
        $phone = Product::create(['category_id' => $category->id, 'name' => 'X', 'brand' => 'X', 'price' => 100, 'stock' => 5]);
        $id = $this->actingAs($this->dara)->postJson('/api/orders', [
            'items' => [['product_id' => $phone->id, 'qty' => 1]], 'payment_method' => 'cod',
            'customer_name' => 'Dara', 'customer_email' => 'dara@example.com', 'phone' => '012', 'address' => 'PP',
        ])->json('id');
        Order::find($id)->update(['status' => $status]);

        return Order::find($id);
    }

    public function test_customer_deletes_their_account_with_the_password(): void
    {
        $done = $this->order('delivered');
        $photo = 'tradein_test_'.uniqid().'.jpg';
        file_put_contents(public_path('uploads/'.$photo), 'x');
        TradeIn::create(['user_id' => $this->dara->id, 'brand' => 'A', 'model' => 'B', 'condition' => 'good', 'photos' => [$photo]]);

        $this->actingAs($this->dara)->deleteJson('/api/me', ['password' => 'wrong'])->assertStatus(422);
        $this->assertNotNull(User::find($this->dara->id));

        $this->actingAs($this->dara)->deleteJson('/api/me', ['password' => 'secret123'])->assertOk();
        $this->assertNull(User::find($this->dara->id));
        $this->assertSame(0, TradeIn::count());
        $this->assertFileDoesNotExist(public_path('uploads/'.$photo));
        // The shop keeps the sale (warranty, accounts) without the account
        $kept = $done->fresh();
        $this->assertNull($kept->user_id);
        $this->assertSame('Dara', $kept->customer_name);

        $this->app['auth']->forgetGuards();
        $this->postJson('/api/login', ['email' => 'dara@example.com', 'password' => 'secret123'])->assertUnauthorized();
    }

    public function test_not_while_an_order_is_on_its_way(): void
    {
        $this->order('shipping');
        $this->actingAs($this->dara)->deleteJson('/api/me', ['password' => 'secret123'])
            ->assertStatus(422)->assertJsonPath('message', fn ($m) => str_contains($m, 'Order 1 កំពុងដំណើរការ'));
        $this->assertNotNull(User::find($this->dara->id));
    }

    public function test_google_accounts_type_delete_and_staff_cannot_use_it(): void
    {
        $this->dara->forceFill(['google_id' => 'g-123'])->save();
        $this->actingAs($this->dara)->getJson('/api/me')->assertJsonPath('google_account', true);
        $this->actingAs($this->dara)->deleteJson('/api/me', ['confirm' => 'nope'])->assertStatus(422);
        $this->actingAs($this->dara)->deleteJson('/api/me', ['confirm' => 'delete'])->assertOk();

        $staff = User::create(['name' => 'S', 'email' => 's@example.com', 'password' => 'secret123', 'role' => 'staff']);
        $this->actingAs($staff)->deleteJson('/api/me', ['password' => 'secret123'])->assertStatus(422);
    }
}
