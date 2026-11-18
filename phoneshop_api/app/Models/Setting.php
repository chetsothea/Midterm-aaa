<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

// A shop setting the admin can change from the app
class Setting extends Model
{
    public const LOW_STOCK_DEFAULT = 3;

    protected $primaryKey = 'key';

    protected $keyType = 'string';

    public $incrementing = false;

    protected $fillable = ['key', 'value'];

    // A phone counts as "low stock" at this many units or fewer
    public static function lowStockThreshold(): int
    {
        return (int) (static::find('low_stock_threshold')?->value ?? self::LOW_STOCK_DEFAULT);
    }

    public static function setLowStockThreshold(int $threshold): void
    {
        static::updateOrCreate(['key' => 'low_stock_threshold'], ['value' => (string) $threshold]);
    }

    // Any text setting; '' when it was never set
    public static function text(string $key): string
    {
        return static::find($key)?->value ?? '';
    }

    public static function setText(string $key, string $value): void
    {
        static::updateOrCreate(['key' => $key], ['value' => $value]);
    }
}
