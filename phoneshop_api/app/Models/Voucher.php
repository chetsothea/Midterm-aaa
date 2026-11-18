<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

// A discount code the admin hands out, e.g. NEWYEAR10 = 10% off orders over $300
class Voucher extends Model
{
    protected $fillable = [
        'code', 'type', 'value', 'min_total', 'max_discount',
        'max_uses', 'used_count', 'expires_at', 'active', 'user_id',
    ];

    protected function casts(): array
    {
        return [
            'value' => 'float',
            'min_total' => 'float',
            'max_discount' => 'float',
            'max_uses' => 'integer',
            'used_count' => 'integer',
            'expires_at' => 'datetime',
            'active' => 'boolean',
        ];
    }

    public static function normalize(?string $code): string
    {
        return strtoupper(trim((string) $code));
    }

    public static function findCode(?string $code, bool $lock = false): ?self
    {
        $code = self::normalize($code);
        if ($code === '') {
            return null;
        }
        $query = static::where('code', $code);

        return $lock ? $query->lockForUpdate()->first() : $query->first();
    }

    // Why this code can't be used on this order, in Khmer; null when it can
    public function problemFor(float $subtotal, ?int $userId): ?string
    {
        if (! $this->active) {
            return 'កូដនេះត្រូវបានបិទ';
        }
        // A trade-in credit: only for the customer who traded their phone
        if ($this->user_id && $this->user_id !== $userId) {
            return 'រកមិនឃើញកូដនេះទេ';
        }
        if ($this->expires_at && $this->expires_at->isPast()) {
            return 'កូដនេះផុតកំណត់ហើយ';
        }
        if ($this->max_uses !== null && $this->used_count >= $this->max_uses) {
            return 'កូដនេះត្រូវបានប្រើអស់ហើយ';
        }
        if ($subtotal < $this->min_total) {
            return 'កូដនេះប្រើបានចំពោះការបញ្ជាទិញចាប់ពី $'.self::money($this->min_total);
        }
        // Each customer once (a cancelled order gives the code back)
        if ($userId && Order::where('user_id', $userId)->where('voucher_code', $this->code)
            ->where('status', '!=', 'cancelled')->exists()) {
            return 'អ្នកបានប្រើកូដនេះរួចហើយ';
        }

        return null;
    }

    // Dollars taken off, never more than the phones cost
    public function discountFor(float $subtotal): float
    {
        $off = $this->type === 'percent'
            ? $subtotal * $this->value / 100
            : $this->value;
        if ($this->type === 'percent' && $this->max_discount) {
            $off = min($off, $this->max_discount);
        }

        return round(min($off, $subtotal), 2);
    }

    // "10%" or "$20"
    public function getLabelAttribute(): string
    {
        return $this->type === 'percent'
            ? self::money($this->value).'%'
            : '$'.self::money($this->value);
    }

    private static function money(float $n): string
    {
        return rtrim(rtrim(number_format($n, 2, '.', ''), '0'), '.');
    }
}
