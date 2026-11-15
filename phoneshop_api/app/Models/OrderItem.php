<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class OrderItem extends Model
{
    protected $fillable = ['order_id', 'product_id', 'qty', 'color', 'storage', 'price'];

    protected function casts(): array
    {
        return ['price' => 'float'];
    }

    public function product()
    {
        return $this->belongsTo(Product::class);
    }
}
