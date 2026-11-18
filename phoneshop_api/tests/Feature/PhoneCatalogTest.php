<?php

namespace Tests\Feature;

use App\Models\Product;
use Database\Seeders\PhoneCatalogSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class PhoneCatalogTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        // No pictures in the test: point at an empty folder
        PhoneCatalogSeeder::$imageRoot = sys_get_temp_dir().'/no-pictures-here';
    }

    protected function tearDown(): void
    {
        PhoneCatalogSeeder::$imageRoot = '';
        parent::tearDown();
    }

    public function test_the_catalogue_has_20_complete_phones_priced_in_usd(): void
    {
        $phones = PhoneCatalogSeeder::catalogue();
        $this->assertCount(20, $phones);
        $this->assertCount(20, array_unique(array_column($phones, 'name')));
        foreach ($phones as $phone) {
            foreach (['name', 'brand', 'category', 'condition', 'ram', 'storage_prices', 'colors', 'description'] as $key) {
                $this->assertNotEmpty($phone[$key], "{$phone['name']}: $key");
            }
            foreach (PhoneCatalogSeeder::storageOptions($phone['storage_prices']) as $option) {
                $this->assertMatchesRegularExpression('/^\d+(GB|TB)$/', $option['storage']);
                $this->assertGreaterThan(100, $option['price'], $phone['name']);
                $this->assertLessThan(2500, $option['price'], $phone['name']);
            }
        }
    }

    public function test_seeding_fills_the_shop_and_running_it_again_does_not_duplicate(): void
    {
        $this->seed(PhoneCatalogSeeder::class);
        $this->seed(PhoneCatalogSeeder::class);
        $this->assertSame(20, Product::count());

        $pro = Product::where('name', 'iPhone 17 Pro Max')->first();
        $this->assertSame(1199.0, $pro->price); // the cheapest size
        $this->assertSame('256GB, 512GB, 1TB, 2TB', $pro->storage);

        // The store shows it with its discount
        $card = collect($this->getJson('/api/products')->json())->firstWhere('name', 'iPhone 17 Pro Max');
        $this->assertEquals(1139.05, $card['price']);
        $this->assertEquals(1199, $card['old_price']);
    }
}
