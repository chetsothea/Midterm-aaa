<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Order;
use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ReviewTest extends TestCase
{
    use RefreshDatabase;

    private Product $phone;

    private User $buyer;

    protected function setUp(): void
    {
        parent::setUp();
        $category = Category::firstOrCreate(['name' => 'Smartphone']);
        $this->phone = Product::create([
            'category_id' => $category->id, 'name' => 'iPhone 17', 'brand' => 'Apple', 'price' => 999, 'stock' => 5,
        ]);
        $this->buyer = User::create(['name' => 'Dara', 'email' => 'dara@example.com', 'password' => 'secret123', 'role' => 'user']);
    }

    private function order(User $user, string $status): void
    {
        $order = Order::create([
            'user_id' => $user->id, 'customer_name' => $user->name, 'customer_email' => $user->email,
            'total' => 999, 'status' => $status, 'payment_method' => 'cod', 'phone' => '012', 'address' => 'PP',
        ]);
        $order->items()->create(['product_id' => $this->phone->id, 'qty' => 1, 'price' => 999]);
    }

    private function review(User $user, int $rating, string $comment = '')
    {
        return $this->actingAs($user)->postJson("/api/products/{$this->phone->id}/reviews", [
            'rating' => $rating, 'comment' => $comment,
        ]);
    }

    public function test_only_customers_who_received_the_phone_can_review_it(): void
    {
        // Not bought, or bought but still on its way: no
        $this->review($this->buyer, 5)->assertForbidden();
        $this->order($this->buyer, 'shipping');
        $this->review($this->buyer, 5)->assertForbidden();
        $this->getJson("/api/products/{$this->phone->id}/reviews")->assertJson(['can_review' => false]);

        // Delivered: yes
        $this->order($this->buyer, 'delivered');
        $this->review($this->buyer, 5, 'Great camera')->assertCreated()
            ->assertJson(['name' => 'Dara', 'rating' => 5, 'comment' => 'Great camera'])
            ->assertJsonMissing(['email' => 'dara@example.com']);

        // Guests can't
        $this->app['auth']->forgetGuards();
        $this->postJson("/api/products/{$this->phone->id}/reviews", ['rating' => 5])->assertUnauthorized();
    }

    public function test_a_second_review_edits_the_first_and_the_summary_adds_up(): void
    {
        $this->order($this->buyer, 'delivered');
        $other = User::create(['name' => 'Sokha', 'email' => 's@example.com', 'password' => 'secret123', 'role' => 'user']);
        $this->order($other, 'delivered');

        $this->review($this->buyer, 2, 'Meh');
        $this->review($this->buyer, 4, 'Better after update'); // replaces
        $this->review($other, 5);

        $summary = $this->actingAs($this->buyer)
            ->getJson("/api/products/{$this->phone->id}/reviews")->assertOk()->json();
        $this->assertSame(2, $summary['count']);
        $this->assertEquals(4.5, $summary['average']);
        $this->assertSame(['5' => 1, '4' => 1, '3' => 0, '2' => 0, '1' => 0], $summary['stars']);
        $this->assertTrue($summary['can_review']);
        $this->assertSame('Better after update', $summary['mine']['comment']);

        // The store's phone list carries the average and count
        $card = $this->getJson('/api/products')->json()[0];
        $this->assertEquals(4.5, $card['reviews_avg_rating']);
        $this->assertSame(2, $card['reviews_count']);
    }

    public function test_ratings_must_be_one_to_five_and_blocked_customers_cannot_review(): void
    {
        $this->order($this->buyer, 'delivered');
        $this->review($this->buyer, 0)->assertUnprocessable();
        $this->review($this->buyer, 6)->assertUnprocessable();

        $this->buyer->forceFill(['blocked_at' => now()])->save();
        $this->review($this->buyer, 5)->assertForbidden();
    }
}
