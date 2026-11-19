<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AddressTest extends TestCase
{
    use RefreshDatabase;

    public function test_customer_keeps_several_addresses_of_their_own(): void
    {
        $dara = User::create(['name' => 'Dara', 'email' => 'dara@example.com', 'password' => 'secret123', 'role' => 'user']);
        $sok = User::create(['name' => 'Sok', 'email' => 'sok@example.com', 'password' => 'secret123', 'role' => 'user']);

        $work = $this->actingAs($dara)->postJson('/api/addresses', ['label' => 'ការងារ', 'address' => 'ផ្ទះ 5, ខណ្ឌដូនពេញ, រាជធានីភ្នំពេញ, កម្ពុជា'])
            ->assertCreated()->json('id');
        // Same address again just renames it
        $this->actingAs($dara)->postJson('/api/addresses', ['label' => 'ការិយាល័យ', 'address' => 'ផ្ទះ 5, ខណ្ឌដូនពេញ, រាជធានីភ្នំពេញ, កម្ពុជា'])
            ->assertOk()->assertJsonPath('id', $work);
        $this->actingAs($dara)->postJson('/api/addresses', ['label' => '', 'address' => 'x'])->assertStatus(422);

        $this->actingAs($dara)->getJson('/api/addresses')->assertJsonCount(1)->assertJsonPath('0.label', 'ការិយាល័យ')
            ->assertJsonMissingPath('0.user_id');
        $this->actingAs($sok)->getJson('/api/addresses')->assertJsonCount(0);
        $this->actingAs($sok)->deleteJson("/api/addresses/$work")->assertNotFound();

        $this->actingAs($dara)->deleteJson("/api/addresses/$work")->assertOk();
        $this->actingAs($dara)->getJson('/api/addresses')->assertJsonCount(0);
    }

    public function test_at_most_ten(): void
    {
        $dara = User::create(['name' => 'Dara', 'email' => 'dara@example.com', 'password' => 'secret123', 'role' => 'user']);
        for ($i = 1; $i <= 10; $i++) {
            $this->actingAs($dara)->postJson('/api/addresses', ['label' => "A$i", 'address' => "Place $i"])->assertCreated();
        }
        $this->actingAs($dara)->postJson('/api/addresses', ['label' => 'A11', 'address' => 'Place 11'])->assertStatus(422);
    }
}
