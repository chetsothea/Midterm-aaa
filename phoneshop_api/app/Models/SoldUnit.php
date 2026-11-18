<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

// One phone handed to a customer, known by its IMEI
class SoldUnit extends Model
{
    protected $fillable = ['order_item_id', 'imei'];

    public function item()
    {
        return $this->belongsTo(OrderItem::class, 'order_item_id');
    }
}
