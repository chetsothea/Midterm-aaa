<?php

namespace Tests\Feature;

use App\Http\Controllers\Api\LiveController;
use App\Models\Category;
use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class LiveShoppingTest extends TestCase
{
    use RefreshDatabase;

    private User $admin;

    private User $customer;

    protected function setUp(): void
    {
        parent::setUp();
        $this->admin = User::create(['name' => 'Admin', 'email' => 'admin', 'password' => 'admin123', 'role' => 'admin']);
        $this->customer = User::create(['name' => 'Dara', 'email' => 'dara@example.com', 'password' => 'secret123', 'role' => 'user']);
    }

    private function product(string $name): Product
    {
        $category = Category::firstOrCreate(['name' => 'Smartphone']);

        return Product::create([
            'category_id' => $category->id, 'name' => $name, 'brand' => 'Apple',
            'price' => 999, 'stock' => 5,
        ]);
    }

    public function test_youtube_links_of_every_usual_shape_give_the_video_id(): void
    {
        foreach ([
            'dQw4w9WgXcQ',
            'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
            'https://youtu.be/dQw4w9WgXcQ?si=abc',
            'https://www.youtube.com/live/dQw4w9WgXcQ?feature=share',
            'https://m.youtube.com/watch?app=desktop&v=dQw4w9WgXcQ',
        ] as $link) {
            $this->assertSame('dQw4w9WgXcQ', LiveController::youtubeId($link), $link);
        }
        $this->assertNull(LiveController::youtubeId('https://example.com/video'));
    }

    public function test_nothing_is_live_until_the_admin_starts_it(): void
    {
        $this->getJson('/api/live')->assertOk()->assertJson(['is_live' => false, 'youtube_id' => '']);
    }

    public function test_admin_starts_a_live_with_pinned_phones_in_order(): void
    {
        $a = $this->product('iPhone 17');
        $b = $this->product('Galaxy S26');

        $this->actingAs($this->admin)->putJson('/api/admin/live', [
            'youtube' => 'https://youtu.be/dQw4w9WgXcQ',
            'title' => 'New iPhones live',
            'product_ids' => [$b->id, $a->id],
        ])->assertOk();

        $live = $this->getJson('/api/live')->assertOk()->json();
        $this->assertTrue($live['is_live']);
        $this->assertSame('dQw4w9WgXcQ', $live['youtube_id']);
        $this->assertSame('New iPhones live', $live['title']);
        $this->assertSame(['Galaxy S26', 'iPhone 17'], array_column($live['products'], 'name'));
    }

    public function test_customers_cannot_start_a_live(): void
    {
        $this->actingAs($this->customer)->putJson('/api/admin/live', ['youtube' => 'dQw4w9WgXcQ'])
            ->assertForbidden();
    }

    public function test_a_bad_link_is_refused(): void
    {
        $this->actingAs($this->admin)->putJson('/api/admin/live', ['youtube' => 'https://example.com/x'])
            ->assertUnprocessable();
    }

    public function test_viewers_comment_and_the_app_fetches_only_new_ones(): void
    {
        $this->actingAs($this->admin)->putJson('/api/admin/live', ['youtube' => 'dQw4w9WgXcQ']);

        // Guests can read but not write
        $this->app['auth']->forgetGuards();
        $this->postJson('/api/live/comments', ['message' => 'hi'])->assertUnauthorized();

        $first = $this->actingAs($this->customer)
            ->postJson('/api/live/comments', ['message' => '  How much is the 256GB?  '])
            ->assertCreated()
            ->assertJson(['name' => 'Dara', 'message' => 'How much is the 256GB?'])
            ->json();
        $this->assertArrayNotHasKey('email', $first); // no personal details

        $this->actingAs($this->customer)->postJson('/api/live/comments', ['message' => 'Blue please']);

        $all = $this->getJson('/api/live/comments')->assertOk()->json();
        $this->assertSame(['How much is the 256GB?', 'Blue please'], array_column($all, 'message'));

        $new = $this->getJson('/api/live/comments?after='.$first['id'])->json();
        $this->assertSame(['Blue please'], array_column($new, 'message'));
    }

    public function test_no_comments_after_the_live_ends_and_a_new_live_starts_clean(): void
    {
        $this->actingAs($this->admin)->putJson('/api/admin/live', ['youtube' => 'dQw4w9WgXcQ']);
        $this->actingAs($this->customer)->postJson('/api/live/comments', ['message' => 'Old'])->assertCreated();

        $this->actingAs($this->admin)->putJson('/api/admin/live', ['youtube' => ''])->assertOk();
        $this->actingAs($this->customer)->postJson('/api/live/comments', ['message' => 'Late'])
            ->assertUnprocessable();

        $this->actingAs($this->admin)->putJson('/api/admin/live', ['youtube' => 'aBcDeFgHiJk']);
        $this->assertSame([], $this->getJson('/api/live/comments')->json());
    }

    public function test_blocked_customers_cannot_comment_and_admin_can_remove_comments(): void
    {
        $this->actingAs($this->admin)->putJson('/api/admin/live', ['youtube' => 'dQw4w9WgXcQ']);
        $comment = $this->actingAs($this->customer)
            ->postJson('/api/live/comments', ['message' => 'spam'])->json();

        $this->actingAs($this->admin)->deleteJson('/api/admin/live/comments/'.$comment['id'])->assertNoContent();
        $this->assertSame([], $this->getJson('/api/live/comments')->json());

        $this->customer->forceFill(['blocked_at' => now()])->save();
        $this->actingAs($this->customer)->postJson('/api/live/comments', ['message' => 'again'])
            ->assertForbidden();
    }
}
