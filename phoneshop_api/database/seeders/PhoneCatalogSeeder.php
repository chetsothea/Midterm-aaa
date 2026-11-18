<?php

namespace Database\Seeders;

use App\Models\Category;
use App\Models\Product;
use App\Support\BackgroundRemover;
use Illuminate\Database\Seeder;
use Illuminate\Support\Str;

// Fills the shop with the 20-phone mock catalogue in database/data/phones.json.
//
//   php artisan db:seed --class=PhoneCatalogSeeder
//
// Safe to run again: a phone with the same name is updated, not duplicated, and
// a picture the admin already uploaded is kept when the catalogue has none.
// Pictures are copied from the repo's product_images folder into
// public/uploads (backgrounds removed if they have any).
class PhoneCatalogSeeder extends Seeder
{
    public static function catalogue(): array
    {
        return json_decode(
            file_get_contents(database_path('data/phones.json')),
            true,
            flags: JSON_THROW_ON_ERROR,
        )['phones'];
    }

    // Where the catalogue's picture paths point (the repo's product_images)
    public static string $imageRoot = '';

    public function run(): void
    {
        $root = static::$imageRoot ?: base_path('../product_images');

        foreach (static::catalogue() as $phone) {
            $category = Category::firstOrCreate(['name' => $phone['category']]);
            $options = self::storageOptions($phone['storage_prices']);

            $product = Product::firstOrNew(['name' => $phone['name']]);
            $product->fill([
                'category_id' => $category->id,
                'brand' => $phone['brand'],
                'condition' => $phone['condition'],
                'ram' => $phone['ram'],
                'storage_prices' => $options,
                'price' => min(array_column($options, 'price')),
                'storage' => implode(', ', array_column($options, 'storage')),
                'discount_percent' => $phone['discount_percent'] ?: null,
                'stock' => $phone['stock'],
                'color' => implode(', ', $phone['colors']),
                'description' => $phone['description'],
                // New phones: 12 months. Used ones carry the shop's 3-month warranty
                'warranty_months' => $phone['condition'] === 'New' ? 12 : 3,
            ]);

            $images = $phone['images'] ?? [];
            $main = $images['_main'] ?? ($images[$phone['colors'][0]] ?? null);
            if ($main && ($file = self::copyPicture("$root/$main"))) {
                $product->image = $file;
            }
            $colorImages = [];
            foreach ($phone['colors'] as $color) {
                if (isset($images[$color]) && ($file = self::copyPicture("$root/{$images[$color]}"))) {
                    $colorImages[$color] = $file;
                }
            }
            if ($colorImages) {
                $product->color_images = $colorImages;
            }

            $product->save();
        }
    }

    // "256GB=1199, 512GB=1399" -> [['storage' => '256GB', 'price' => 1199.0], ...]
    public static function storageOptions(string $text): array
    {
        $options = [];
        foreach (array_filter(array_map('trim', explode(',', $text))) as $part) {
            [$storage, $price] = array_map('trim', explode('=', $part, 2));
            $options[] = ['storage' => $storage, 'price' => (float) $price];
        }

        return $options;
    }

    // Copies one picture into public/uploads under a random name (the same
    // way admin uploads are stored); null when the file isn't there
    private static function copyPicture(string $source): ?string
    {
        if (! is_file($source)) {
            return null;
        }
        $name = Str::random(20).'.'.strtolower(pathinfo($source, PATHINFO_EXTENSION));
        $target = public_path('uploads/'.$name);
        copy($source, $target);
        // Already-transparent pictures come back unchanged (null)
        $clean = BackgroundRemover::process($target);
        if ($clean && $clean !== $name) {
            unlink($target);
        }

        return $clean ?? $name;
    }
}
