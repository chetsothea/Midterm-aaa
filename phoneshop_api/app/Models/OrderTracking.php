<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

// One step of a delivery: the status at that moment, where the package was, and a note
class OrderTracking extends Model
{
    protected $fillable = ['order_id', 'status', 'location', 'note'];

    protected $hidden = ['order_id', 'updated_at'];
}
