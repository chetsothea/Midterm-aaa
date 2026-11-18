<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    use WithoutModelEvents;

    /**
     * Seed the application's database.
     *
     * Test accounts:
     *   Admin:    admin / admin123
     *   Customer: user@phoneshop.com  / user123
     */
    public function run(): void
    {
        User::create([
            'name' => 'Admin',
            'email' => 'admin',
            'password' => 'admin123',
            'role' => 'admin',
        ]);

        User::create([
            'name' => 'Customer',
            'email' => 'user@phoneshop.com',
            'password' => 'user123',
            'phone' => '012345678',
            'address' => 'Phnom Penh',
            'role' => 'user',
        ]);

        // 20 phones with real specs and USD prices (database/data/phones.json)
        $this->call(PhoneCatalogSeeder::class);
    }
}
