<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

// One customer's stars and comment for one phone
class Review extends Model
{
    protected $fillable = ['product_id', 'user_id', 'rating', 'comment'];

    protected function casts(): array
    {
        return ['rating' => 'integer'];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function product(): BelongsTo
    {
        return $this->belongsTo(Product::class);
    }

    // What the app shows: first name only, never email or phone
    public function toPublic(): array
    {
        return [
            'id' => $this->id,
            'name' => $this->user?->name ?? '',
            'avatar_url' => $this->user?->avatar_url ?? '',
            'rating' => $this->rating,
            'comment' => $this->comment ?? '',
            'created_at' => $this->created_at,
        ];
    }
}
