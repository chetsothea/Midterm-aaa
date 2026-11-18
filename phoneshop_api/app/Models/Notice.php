<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

// One message in a customer's in-app inbox (the 🔔 in the app)
class Notice extends Model
{
    protected $fillable = ['user_id', 'kind', 'title', 'body', 'order_id', 'trade_in_id', 'read_at'];

    protected $casts = ['read_at' => 'datetime'];

    public static function tell(?int $userId, string $kind, string $title, ?string $body = null, array $links = []): void
    {
        // Nobody to tell, or they did it themselves (cancelled, confirmed receipt)
        if (! $userId || auth()->id() === $userId) {
            return;
        }
        static::create(['user_id' => $userId, 'kind' => $kind, 'title' => $title, 'body' => $body] + $links);
    }
}
