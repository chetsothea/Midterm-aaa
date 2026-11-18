<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Product extends Model
{
    protected $fillable = [
        'category_id', 'name', 'brand', 'price', 'discount_percent', 'condition', 'stock',
        'ram', 'storage', 'storage_prices', 'color', 'description', 'image', 'color_images',
        'warranty_months',
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
        ];
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
        return $query->withAvg('reviews', 'rating')->withCount('reviews');
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
