<?php

namespace App\Support;

use App\Models\Setting;

// Delivery fee: one price inside Phnom Penh, another for the provinces, and free
// once the order (after any discount) reaches the admin's threshold. All three
// are set by the admin; 0 means free / no threshold.
class Shipping
{
    public static function rates(): array
    {
        return [
            'phnom_penh' => (float) (Setting::text('shipping_phnom_penh') ?: 0),
            'province' => (float) (Setting::text('shipping_province') ?: 0),
            'free_over' => (float) (Setting::text('shipping_free_over') ?: 0),
        ];
    }

    public static function setRates(float $phnomPenh, float $province, float $freeOver): void
    {
        Setting::setText('shipping_phnom_penh', (string) $phnomPenh);
        Setting::setText('shipping_province', (string) $province);
        Setting::setText('shipping_free_over', (string) $freeOver);
    }

    // Riel for one dollar (shown next to prices); 0 = don't show riel
    public static function khrRate(): int
    {
        $rate = Setting::text('khr_rate');

        return $rate === '' ? 4100 : (int) $rate;
    }

    // The address picker always writes the province, e.g. "..., រាជធានីភ្នំពេញ, កម្ពុជា"
    public static function isPhnomPenh(string $address): bool
    {
        return str_contains($address, 'ភ្នំពេញ') || stripos($address, 'phnom penh') !== false;
    }

    public static function feeFor(string $address, float $amount): float
    {
        $rates = self::rates();
        if ($rates['free_over'] > 0 && $amount >= $rates['free_over']) {
            return 0.0;
        }

        return self::isPhnomPenh($address) ? $rates['phnom_penh'] : $rates['province'];
    }
}
