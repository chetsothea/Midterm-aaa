<?php

namespace Database\Seeders;

use App\Models\Category;
use App\Models\Product;
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

        $phones = Category::create(['name' => 'Smartphone']);

        $products = [
            ['iPhone 15 Pro', 'Apple', 999, 10, '8GB', '256GB', 'Natural Titanium'],
            ['iPhone 15', 'Apple', 799, 12, '6GB', '128GB', 'Black'],
            ['Galaxy S24 Ultra', 'Samsung', 1199, 8, '12GB', '256GB', 'Titanium Gray'],
            ['Galaxy A55', 'Samsung', 399, 20, '8GB', '128GB', 'Navy'],
            ['Redmi Note 13 Pro', 'Xiaomi', 299, 25, '8GB', '256GB', 'Purple'],
            ['Reno 11', 'Oppo', 449, 3, '12GB', '256GB', 'Green'],
        ];

        foreach ($products as [$name, $brand, $price, $stock, $ram, $storage, $color]) {
            Product::create([
                'category_id' => $phones->id,
                'name' => $name,
                'brand' => $brand,
                'price' => $price,
                'stock' => $stock,
                'ram' => $ram,
                'storage' => $storage,
                'color' => $color,
                'description' => "{$name} ពី {$brand} ថ្មី 100% ធានា 1 ឆ្នាំ",
            ]);
        }

        // The category itself is created by a migration; firstOrCreate keeps this safe either way
        $secondHand = Category::firstOrCreate(['name' => '2nd Hand']);

        $usedPhones = [
            ['iPhone 13 (មួយទឹក)', 'Apple', 399, 2, '4GB', '128GB', 'Midnight'],
            ['Galaxy S22 (មួយទឹក)', 'Samsung', 299, 1, '8GB', '128GB', 'White'],
        ];

        foreach ($usedPhones as [$name, $brand, $price, $stock, $ram, $storage, $color]) {
            Product::create([
                'category_id' => $secondHand->id,
                'name' => $name,
                'brand' => $brand,
                'price' => $price,
                'stock' => $stock,
                'ram' => $ram,
                'storage' => $storage,
                'color' => $color,
                'description' => "{$name} ស្អាត 95% ធានា 3 ខែ",
            ]);
        }
    }
}
