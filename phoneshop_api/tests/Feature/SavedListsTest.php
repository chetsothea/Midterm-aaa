<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class SavedListsTest extends TestCase
{
    use RefreshDatabase;

    public function test_favorites_and_cart_are_kept_on_the_account(): void
    {
        $category = Category::firstOrCreate(['name' => 'Smartphone']);
        $a = Product::create(['category_id' => $category->id, 'name' => 'A', 'brand' => 'X', 'price' => 10, 'stock' => 5]);
        $b = Product::create(['category_id' => $category->id, 'name' => 'B', 'brand' => 'X', 'price' => 10, 'stock' => 5]);
        $dara = User::create(['name' => 'Dara', 'email' => 'dara@example.com', 'password' => 'secret123', 'role' => 'user']);
        $sok = User::create(['name' => 'Sok', 'email' => 'sok@example.com', 'password' => 'secret123', 'role' => 'user']);

        $this->actingAs($dara)->getJson('/api/me/saved')->assertExactJson(['favorites' => [], 'cart' => []]);

        $this->actingAs($dara)->putJson('/api/me/saved', [
            'favorites' => [$a->id, $b->id, $a->id, 9999], // duplicate and a deleted phone
            'cart' => [
                ['id' => $b->id, 'qty' => 2, 'color' => 'Blue', 'storage' => '256GB'],
                ['id' => 9999, 'qty' => 1],
            ],
        ])->assertOk()->assertExactJson([
            'favorites' => [$a->id, $b->id],
            'cart' => [['id' => $b->id, 'color' => 'Blue', 'storage' => '256GB', 'qty' => 2]],
        ]);

        // Another device, same account: the same lists; another account: its own
        $this->actingAs($dara)->getJson('/api/me/saved')->assertJsonPath('cart.0.qty', 2);
        $this->actingAs($sok)->getJson('/api/me/saved')->assertJsonPath('favorites', []);

        // Never shown in the account's own details
        $this->actingAs($dara)->getJson('/api/me')->assertJsonMissingPath('saved_cart');
    }

    public function test_bad_lists_are_refused_and_guests_cannot_save(): void
    {
        $dara = User::create(['name' => 'Dara', 'email' => 'dara@example.com', 'password' => 'secret123', 'role' => 'user']);
        $this->actingAs($dara)->putJson('/api/me/saved', ['favorites' => [], 'cart' => [['id' => 1, 'qty' => 0]]])
            ->assertStatus(422);

        $this->app['auth']->forgetGuards();
        $this->putJson('/api/me/saved', ['favorites' => [], 'cart' => []])->assertUnauthorized();
    }
}
