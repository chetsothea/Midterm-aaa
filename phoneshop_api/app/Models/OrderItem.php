<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Carbon;

class OrderItem extends Model
{
    protected $fillable = ['order_id', 'product_id', 'qty', 'color', 'storage', 'price', 'warranty_months'];

    protected $appends = ['imeis', 'warranty_until'];

    protected $hidden = ['units', 'order'];

    protected function casts(): array
    {
        return ['price' => 'float', 'warranty_months' => 'integer'];
    }

    public function product()
    {
        return $this->belongsTo(Product::class);
    }

    public function order()
    {
        return $this->belongsTo(Order::class);
    }

    // Back on the shelf, in the same colour and size (order cancelled or deleted)
    public function putBack(): void
    {
        $product = $this->product_id ? Product::lockForUpdate()->find($this->product_id) : null;
        $product?->moveStock($this->color, $this->storage, $this->qty);
    }

    public function units()
    {
        return $this->hasMany(SoldUnit::class)->orderBy('id');
    }

    public function getImeisAttribute(): array
    {
        return $this->units->pluck('imei')->all();
    }

    // Covered until this day; null before delivery or when sold without warranty
    public function warrantyUntil(): ?Carbon
    {
        $start = $this->order?->delivered_at;
        if (! $start || ! $this->warranty_months) {
            return null;
        }

        return $start->copy()->addMonthsNoOverflow($this->warranty_months);
    }

    public function getWarrantyUntilAttribute(): ?string
    {
        return $this->warrantyUntil()?->toIso8601String();
    }
}
