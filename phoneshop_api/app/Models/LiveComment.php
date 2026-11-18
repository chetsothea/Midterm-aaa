<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

// One message a viewer typed under the live shopping stream
class LiveComment extends Model
{
    protected $fillable = ['user_id', 'message'];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    // What the app shows: who, what, when (never the viewer's email or phone)
    public function toPublic(): array
    {
        return [
            'id' => $this->id,
            'name' => $this->user?->name ?? '',
            'avatar_url' => $this->user?->avatar_url ?? '',
            'message' => $this->message,
            'created_at' => $this->created_at,
        ];
    }
}
