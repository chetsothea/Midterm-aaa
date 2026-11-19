<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Product extends Model
{
    protected $fillable = [
        'category_id', 'name', 'brand', 'price', 'discount_percent', 'condition', 'stock',
        'ram', 'storage', 'storage_prices', 'color', 'description', 'image', 'color_images',
        'warranty_months', 'variant_stock',
    ];

    protected $hidden = ['image', 'color_images'];

    protected $appends = ['image_url', 'color_image_urls'];

    protected function casts(): array
    {
        return [
            'category_id' => 'integer',
            'price' => 'float',
            'discount_percent' => 'float',
            'stock' => 'integer',
            'color_images' => 'array',
            'storage_prices' => 'array',
            'variant_stock' => 'array',
        ];
    }

    protected static function booted(): void
    {
        // With stock per colour/size, the phone's total is always their sum
        static::saving(function (Product $product) {
            if (is_array($product->variant_stock)) {
                $product->variant_stock = $product->cleanVariantStock($product->variant_stock);
                $product->stock = array_sum($product->variant_stock);
            }
        });
        // Tell the customers who asked: back in stock, or cheaper than before
        static::updated(function (Product $product) {
            $product->announceRestock();
            $product->announcePriceDrop();
        });
    }

    // The lowest price a customer pays (cheapest size, after the discount)
    public static function lowestSalePrice(float $price, ?array $sizes, ?float $discount): float
    {
        $prices = $sizes ? array_map(fn ($o) => (float) $o['price'], $sizes) : [$price];

        return round(min($prices) * (1 - ($discount ?? 0) / 100), 2);
    }

    private function announceRestock(): void
    {
        $before = (array) ($this->getOriginal('variant_stock') ?? []);
        $was = fn (string $key) => $key === '' || ! $before
            ? (int) $this->getOriginal('stock')
            : (int) ($before[$key] ?? 0);
        $now = fn (string $key) => $key === '' || ! $this->hasVariantStock()
            ? (int) $this->stock
            : (int) ($this->variant_stock[$key] ?? 0);

        foreach (StockAlert::where('product_id', $this->id)->get() as $alert) {
            if ($was($alert->variant) > 0 || $now($alert->variant) <= 0) {
                continue;
            }
            $what = trim($this->name.' '.str_replace('|', ' ', $alert->variant));
            Notice::tell($alert->user_id, 'stock', "{$what} មានក្នុងស្តុកវិញហើយ!",
                'ចុចដើម្បីមើល និងទិញ មុនវាអស់ម្តងទៀត', ['product_id' => $this->id]);
            $alert->delete(); // told once
        }
    }

    private function announcePriceDrop(): void
    {
        $old = self::lowestSalePrice(
            (float) $this->getOriginal('price'),
            $this->getOriginal('storage_prices'),
            $this->getOriginal('discount_percent') === null ? null : (float) $this->getOriginal('discount_percent'),
        );
        $new = self::lowestSalePrice((float) $this->price, $this->storage_prices, $this->discount_percent);
        if ($new >= $old) {
            return;
        }
        // Customers who ♥ this phone (lists are small; read them here)
        $fans = User::whereNotNull('favorite_ids')->where('role', 'user')->get(['id', 'favorite_ids'])
            ->filter(fn (User $u) => in_array($this->id, (array) $u->favorite_ids, true));
        foreach ($fans as $fan) {
            Notice::tell($fan->id, 'price', "♥ {$this->name} ចុះតម្លៃ!",
                'ពី $'.number_format($old, 2).' មកនៅ $'.number_format($new, 2), ['product_id' => $this->id]);
        }
    }

    // "Blue|256GB"; '' for a side the phone doesn't have ("Blue|", "|256GB")
    public static function variantKey(?string $color, ?string $storage): string
    {
        return trim((string) $color).'|'.trim((string) $storage);
    }

    // Every colour × size this phone is sold in
    public function variantKeys(): array
    {
        $colors = $this->colorOptions() ?: [''];
        $sizes = array_column($this->storage_prices ?? [], 'storage') ?: [''];
        $keys = [];
        foreach ($colors as $c) {
            foreach ($sizes as $s) {
                $keys[] = self::variantKey($c, $s);
            }
        }

        return $keys;
    }

    // Only real combinations, whole numbers, none below 0; missing ones are 0
    public function cleanVariantStock(array $stock): array
    {
        $clean = [];
        foreach ($this->variantKeys() as $key) {
            $clean[$key] = max(0, (int) ($stock[$key] ?? 0));
        }

        return $clean;
    }

    public function hasVariantStock(): bool
    {
        return is_array($this->variant_stock) && $this->variant_stock !== [];
    }

    // How many of this colour/size are on the shelf
    public function stockFor(?string $color, ?string $storage): int
    {
        if (! $this->hasVariantStock()) {
            return (int) $this->stock;
        }

        return (int) ($this->variant_stock[self::variantKey($color, $storage)] ?? 0);
    }

    // Sold (negative) or put back (positive). Call on a row locked for update.
    public function moveStock(?string $color, ?string $storage, int $change): void
    {
        if ($this->hasVariantStock()) {
            $stock = $this->variant_stock;
            $key = self::variantKey($color, $storage);
            $stock[$key] = max(0, (int) ($stock[$key] ?? 0) + $change);
            $this->variant_stock = $stock;
            $this->save(); // the saving hook updates the total
        } elseif ($change < 0) {
            $this->decrement('stock', -$change);
        } else {
            $this->increment('stock', $change);
        }
    }

    // Price customers pay for one storage size, or null if the product isn't sold in that size
    public function priceForStorage(?string $storage): ?float
    {
        foreach ($this->storage_prices ?? [] as $option) {
            if ($option['storage'] === $storage) {
                return $this->discounted((float) $option['price']);
            }
        }

        return null;
    }

    // Price customers pay when the product has no storage sizes to pick
    public function salePrice(): float
    {
        return $this->discounted($this->price);
    }

    private function discounted(float $price): float
    {
        return round($price * (1 - ($this->discount_percent ?? 0) / 100), 2);
    }

    // The store sees the price to pay as price, and the regular one as old_price
    public function toArray(): array
    {
        $data = parent::toArray();
        $data['old_price'] = null;
        if (! $this->discount_percent || ! array_key_exists('price', $data)) {
            return $data;
        }

        $data['old_price'] = $this->price;
        $data['price'] = $this->salePrice();
        if ($this->storage_prices) {
            $data['storage_prices'] = array_map(fn ($option) => [
                'storage' => $option['storage'],
                'price' => $this->discounted((float) $option['price']),
                'old_price' => (float) $option['price'],
            ], $this->storage_prices);
        }

        return $data;
    }

    // "Natural Titanium, Black, Blue" → ['Natural Titanium', 'Black', 'Blue']
    public function colorOptions(): array
    {
        return array_values(array_filter(array_map('trim', explode(',', (string) $this->color))));
    }

    // An empty condition from the admin form means a new phone
    public function setConditionAttribute(?string $value): void
    {
        $this->attributes['condition'] = $value ?: 'New';
    }

    // Adds reviews_avg_rating and reviews_count to each phone
    public function scopeWithRating($query)
    {
        $shown = fn ($q) => $q->whereNull('hidden_at'); // hidden reviews don't count
        return $query->withAvg(['reviews' => $shown], 'rating')->withCount(['reviews' => $shown]);
    }

    public function reviews()
    {
        return $this->hasMany(Review::class);
    }

    public function category()
    {
        return $this->belongsTo(Category::class);
    }

    // Full URL built from the current request host, so it works from the emulator (10.0.2.2) too
    public function getImageUrlAttribute(): string
    {
        return self::uploadUrl($this->image);
    }

    // {"Blue": "http://.../uploads/abc.jpg", ...} — the picture to show when that colour is picked
    public function getColorImageUrlsAttribute(): object
    {
        $urls = [];
        foreach ($this->color_images ?? [] as $color => $file) {
            $urls[$color] = self::uploadUrl($file);
        }

        return (object) $urls; // always a JSON object, even when empty
    }

    private static function uploadUrl(?string $file): string
    {
        return \App\Support\Uploads::url($file);
    }
}
