<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Notice;
use App\Models\Order;
use App\Models\Product;
use App\Models\Review;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AlertsRateReviewsTest extends TestCase
{
    use RefreshDatabase;

    private User $dara;

    private User $admin;

    private Product $phone;

    protected function setUp(): void
    {
        parent::setUp();
        $category = Category::firstOrCreate(['name' => 'Smartphone']);
        $this->phone = Product::create(['category_id' => $category->id, 'name' => 'Find X10', 'brand' => 'Oppo', 'price' => 999, 'stock' => 0]);
        $this->dara = User::create(['name' => 'Dara', 'email' => 'dara@example.com', 'password' => 'secret123', 'role' => 'user']);
        $this->admin = User::create(['name' => 'Boss', 'email' => 'boss@example.com', 'password' => 'secret123', 'role' => 'admin']);
    }

    public function test_back_in_stock_tells_the_customer_once(): void
    {
        $this->actingAs($this->dara)->postJson("/api/products/{$this->phone->id}/stock-alert")->assertCreated();
        $this->actingAs($this->dara)->getJson('/api/stock-alerts')->assertJsonPath('0.product_id', $this->phone->id);

        $this->actingAs($this->admin);
        $this->phone->update(['description' => 'still none']); // not back yet
        $this->assertSame(0, Notice::count());

        $this->phone->update(['stock' => 3]);
        $this->phone->update(['stock' => 0]);
        $this->phone->update(['stock' => 2]); // only told the first time

        $notices = Notice::where('user_id', $this->dara->id)->get();
        $this->assertCount(1, $notices);
        $this->assertSame('Find X10 មានក្នុងស្តុកវិញហើយ!', $notices[0]->title);
        $this->assertSame($this->phone->id, $notices[0]->product_id);
        $this->actingAs($this->dara)->getJson('/api/stock-alerts')->assertJsonCount(0);
    }

    public function test_alert_for_one_colour_and_size(): void
    {
        $this->phone->update([
            'color' => 'Blue, Black', 'storage_prices' => [['storage' => '256GB', 'price' => 999]],
            'variant_stock' => ['Blue|256GB' => 0, 'Black|256GB' => 1],
        ]);
        $this->actingAs($this->dara)->postJson("/api/products/{$this->phone->id}/stock-alert", ['color' => 'Blue', 'storage' => '256GB'])
            ->assertCreated()->assertJsonPath('variant', 'Blue|256GB');
        $this->actingAs($this->dara)->postJson("/api/products/{$this->phone->id}/stock-alert", ['color' => 'Pink', 'storage' => '1TB'])
            ->assertStatus(422);

        $this->actingAs($this->admin);
        $this->phone->update(['variant_stock' => ['Blue|256GB' => 0, 'Black|256GB' => 5]]); // other colour
        $this->assertSame(0, Notice::count());
        $this->phone->update(['variant_stock' => ['Blue|256GB' => 2, 'Black|256GB' => 5]]);
        $this->assertSame('Find X10 Blue 256GB មានក្នុងស្តុកវិញហើយ!', Notice::first()->title);
    }

    public function test_hearted_phone_getting_cheaper_tells_its_fans(): void
    {
        $this->dara->forceFill(['favorite_ids' => [$this->phone->id]])->save();
        $other = User::create(['name' => 'S', 'email' => 's@example.com', 'password' => 'secret123', 'role' => 'user']);

        $this->actingAs($this->admin);
        $this->phone->update(['price' => 1099]); // dearer: no news
        $this->phone->update(['discount_percent' => 10]); // 1099 → 989.10

        $this->assertSame(1, Notice::count());
        $notice = Notice::first();
        $this->assertSame($this->dara->id, $notice->user_id);
        $this->assertSame('ពី $1,099.00 មកនៅ $989.10', $notice->body);
        $this->assertSame(0, Notice::where('user_id', $other->id)->count());
    }

    public function test_riel_rate_is_shared_and_set_by_the_admin(): void
    {
        $this->getJson('/api/menu')->assertJsonPath('khr_rate', 4100);
        $this->actingAs($this->dara)->putJson('/api/admin/settings/khr-rate', ['khr_rate' => 4000])->assertForbidden();
        $this->actingAs($this->admin)->putJson('/api/admin/settings/khr-rate', ['khr_rate' => 4050])->assertOk();
        $this->getJson('/api/menu')->assertJsonPath('khr_rate', 4050);
        $this->actingAs($this->admin)->getJson('/api/admin/vouchers')->assertJsonPath('khr_rate', 4050);
    }

    public function test_admin_hides_a_review_and_it_stops_counting(): void
    {
        $this->phone->update(['stock' => 5]);
        $order = Order::create(['user_id' => $this->dara->id, 'customer_name' => 'Dara', 'total' => 999,
            'payment_method' => 'cod', 'phone' => '012', 'address' => 'PP']);
        $order->items()->create(['product_id' => $this->phone->id, 'qty' => 1, 'price' => 999]);
        $order->update(['status' => 'delivered']);
        $id = $this->actingAs($this->dara)->postJson("/api/products/{$this->phone->id}/reviews", ['rating' => 1, 'comment' => 'spam spam'])
            ->assertCreated()->json('id');

        $this->getJson("/api/products/{$this->phone->id}/reviews")->assertJsonPath('count', 1);

        $this->actingAs($this->admin)->getJson('/api/admin/reviews')->assertJsonPath('0.comment', 'spam spam');
        $this->actingAs($this->admin)->putJson("/api/admin/reviews/$id/hidden", ['hidden' => true])->assertJsonPath('hidden', true);

        $this->app['auth']->forgetGuards();
        $this->getJson("/api/products/{$this->phone->id}/reviews")->assertJsonPath('count', 0)->assertJsonPath('average', 0);
        $this->getJson("/api/products/{$this->phone->id}")->assertJsonPath('reviews_count', 0);
        // The writer still sees their own
        $this->actingAs($this->dara)->getJson("/api/products/{$this->phone->id}/reviews")->assertJsonPath('mine.comment', 'spam spam');

        $this->actingAs($this->dara)->putJson("/api/admin/reviews/$id/hidden", ['hidden' => false])->assertForbidden();
        $this->assertNotNull(Review::find($id)->hidden_at);
    }
}
