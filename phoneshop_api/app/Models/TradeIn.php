<?php

namespace App\Models;

use App\Support\Uploads;
use Illuminate\Database\Eloquent\Model;

class TradeIn extends Model
{
    public const CONDITIONS = ['like_new', 'good', 'fair', 'broken'];

    protected $fillable = [
        'user_id', 'brand', 'model', 'storage', 'condition', 'battery_health', 'notes',
        'photos', 'wanted_product_id', 'status', 'offer_amount', 'admin_note', 'voucher_code',
    ];

    protected $hidden = ['photos'];

    protected $appends = ['photo_urls'];

    protected function casts(): array
    {
        return [
            'photos' => 'array',
            'offer_amount' => 'float',
            'battery_health' => 'integer',
        ];
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function wantedProduct()
    {
        return $this->belongsTo(Product::class, 'wanted_product_id');
    }

    public function getPhotoUrlsAttribute(): array
    {
        return array_map(fn ($f) => Uploads::url($f), $this->photos ?? []);
    }
}
