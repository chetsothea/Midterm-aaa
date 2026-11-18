<?php

namespace App\Models;

use App\Services\Bakong\Bakong;
use App\Services\Bakong\BakongUnavailable;
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
        'bakong_qr', 'bakong_md5', 'bakong_checked_at',
        'subtotal', 'shipping_fee', 'discount', 'voucher_code',
    ];

    protected $casts = ['bakong_checked_at' => 'datetime'];

    protected $appends = ['pay_before'];

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
    protected $hidden = ['access_token', 'bakong_md5', 'bakong_checked_at'];

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
            'subtotal' => 'float',
            'shipping_fee' => 'float',
            'discount' => 'float',
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
    public function cancelAndRestock(?string $note = null): void
    {
        DB::transaction(function () use ($note) {
            foreach ($this->items as $item) {
                $item->product?->increment('stock', $item->qty);
            }
            $this->releaseVoucher();

            $this->update(['status' => 'cancelled']);
            $this->track(null, $note);
        });
    }

    // A cancelled order gives its discount code back
    public function releaseVoucher(): void
    {
        if ($this->voucher_code) {
            Voucher::where('code', $this->voucher_code)->where('used_count', '>', 0)->decrement('used_count');
        }
    }

    // A KHQR order holds its phones only this long while nobody has paid
    public static function unpaidMinutes(): int
    {
        return (int) config('shop.unpaid_minutes', 30);
    }

    // When an unpaid KHQR order will be cancelled; null for any other order
    public function getPayBeforeAttribute(): ?string
    {
        if ($this->payment_method !== 'khqr' || $this->payment_status !== 'unpaid'
            || $this->status !== 'pending' || ! $this->created_at) {
            return null;
        }

        return $this->created_at->copy()->addMinutes(self::unpaidMinutes())->toIso8601String();
    }

    // Cancels KHQR orders nobody paid for in time and puts their phones back
    // on the shelf. An order whose customer already sent a payment reference
    // (payment_status "verifying") waits for the admin instead. Runs every
    // minute from the scheduler, and also before orders or stock are read, so
    // it works even where the scheduler isn't running.
    public static function expireUnpaid(): int
    {
        $expired = static::where('payment_method', 'khqr')
            ->where('payment_status', 'unpaid')
            ->where('status', 'pending')
            ->where('created_at', '<', now()->subMinutes(self::unpaidMinutes()))
            ->with('items.product')
            ->get();
        $cancelled = 0;
        foreach ($expired as $order) {
            // Last look at Bakong: a payment made at the final second still counts
            if ($order->bakong_md5 && Bakong::enabled()) {
                try {
                    if ($order->checkBakong(force: true)) {
                        continue;
                    }
                } catch (BakongUnavailable) {
                    // Can't tell if it was paid: wait (up to an hour) rather
                    // than cancel an order the customer may have paid for
                    if ($order->created_at->gt(now()->subMinutes(self::unpaidMinutes() + 60))) {
                        continue;
                    }
                }
            }
            $order->cancelAndRestock('មិនបានបង់ប្រាក់ទាន់ពេល Order ត្រូវបានបោះបង់ដោយស្វ័យប្រវត្តិ');
            $cancelled++;
        }

        return $cancelled;
    }

    // Gives a new KHQR order its own Bakong QR with the exact amount in it,
    // payable until the order would be cancelled
    public function attachBakongQr(): void
    {
        if ($this->payment_method !== 'khqr' || ! Bakong::enabled()) {
            return;
        }
        $expires = $this->created_at->copy()->addMinutes(self::unpaidMinutes());
        $qr = Bakong::qrFor((float) $this->total, (string) $this->code, $expires->getTimestampMs());
        $this->update(['bakong_qr' => $qr, 'bakong_md5' => md5($qr)]);
    }

    // Asks Bakong whether this order's QR was paid; marks it paid when the
    // full amount reached the shop's account. At most once every few seconds
    // per order unless forced. Throws BakongUnavailable when Bakong can't answer.
    public function checkBakong(bool $force = false): bool
    {
        if (! $this->bakong_md5 || ! Bakong::enabled() || $this->payment_status === 'paid'
            || $this->status === 'cancelled') {
            return $this->payment_status === 'paid';
        }
        if (! $force && $this->bakong_checked_at && $this->bakong_checked_at->gt(now()->subSeconds(3))) {
            return false;
        }
        $this->update(['bakong_checked_at' => now()]);

        $payment = Bakong::findPayment($this->bakong_md5);
        if ($payment === null) {
            return false;
        }
        if (! Bakong::covers($payment, (float) $this->total)) {
            // Paid to the QR but not in full or not to us: leave it for the admin
            $this->update([
                'payment_status' => 'verifying',
                'transaction_ref' => substr($payment['hash'], 0, 100) ?: null,
            ]);
            $this->track(null, 'ការបង់ប្រាក់មិនត្រូវចំនួន Admin នឹងពិនិត្យ');

            return false;
        }

        $this->update([
            'payment_status' => 'paid',
            'transaction_ref' => substr($payment['hash'], 0, 100) ?: null,
        ]);
        $this->track(null, 'បានទទួលប្រាក់តាម Bakong KHQR (ផ្ទៀងផ្ទាត់ដោយស្វ័យប្រវត្តិ)');

        return true;
    }
}
