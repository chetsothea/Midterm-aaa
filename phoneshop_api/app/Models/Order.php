<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class Order extends Model
{
    protected $fillable = [
        'user_id', 'customer_name', 'customer_email', 'access_token',
        'total', 'status', 'payment_method',
        'payment_status', 'transaction_ref', 'phone', 'address',
        'courier', 'tracking_number', 'received_at', 'received_seen_at',
        'customer_number',
        'customer_hidden_at',
    ];

    // Shown to the customer when the admin doesn't type a note of their own
    public const TRACKING_NOTES = [
        'pending' => 'បានទទួល Order របស់អ្នក',
        'confirmed' => 'Order ត្រូវបានបញ្ជាក់ ហាងកំពុងរៀបចំឥវ៉ាន់',
        'shipping' => 'ឥវ៉ាន់កំពុងដឹកជញ្ជូនមកកាន់អ្នក',
        'delivered' => 'ឥវ៉ាន់បានដល់ដៃអ្នកទទួលហើយ',
        'cancelled' => 'Order ត្រូវបានបោះបង់',
    ];

    // Letters and digits that can't be mixed up when read out (no 0/O, 1/I/L)
    private const CODE_CHARS = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

    // "PS-7K3Q9A": random, so it says nothing about how many orders came before
    public static function newCode(): string
    {
        do {
            $code = 'PS-';
            for ($i = 0; $i < 6; $i++) {
                $code .= self::CODE_CHARS[random_int(0, strlen(self::CODE_CHARS) - 1)];
            }
        } while (self::where('code', $code)->exists());

        return $code;
    }

    protected static function booted(): void
    {
        static::creating(function (Order $order) {
            $order->code ??= self::newCode();
        });
    }

    // Only sent once, in the guest checkout response
    protected $hidden = ['access_token'];

    // The logged-in owner, or a guest holding this order's token (X-Order-Token header)
    public function isOwnedBy(Request $request): bool
    {
        $user = $request->user('sanctum');
        if ($user && $this->user_id === $user->id) {
            return true;
        }

        $token = (string) $request->header('X-Order-Token');

        return $this->access_token && $token !== '' && hash_equals($this->access_token, $token);
    }

    protected function casts(): array
    {
        return [
            'total' => 'float',
            'received_at' => 'datetime',
            'received_seen_at' => 'datetime',
            'customer_hidden_at' => 'datetime',
        ];
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function items()
    {
        return $this->hasMany(OrderItem::class);
    }

    // Newest step first, the way the customer reads it
    public function trackings()
    {
        return $this->hasMany(OrderTracking::class)->latest()->latest('id');
    }

    // Records one delivery step at the order's current status
    public function track(?string $location = null, ?string $note = null): OrderTracking
    {
        return $this->trackings()->create([
            'status' => $this->status,
            'location' => $location ?: null,
            'note' => $note ?: (self::TRACKING_NOTES[$this->status] ?? null),
        ]);
    }

    // Puts the reserved stock back on the shelf
    public function cancelAndRestock(): void
    {
        DB::transaction(function () {
            foreach ($this->items as $item) {
                $item->product?->increment('stock', $item->qty);
            }

            $this->update(['status' => 'cancelled']);
            $this->track();
        });
    }
}
