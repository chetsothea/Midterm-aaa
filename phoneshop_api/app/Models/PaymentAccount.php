<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

// One bank the shop takes payments into, with its KHQR picture
class PaymentAccount extends Model
{
    protected $fillable = ['bank_name', 'account_name', 'account_number', 'qr_image', 'sort'];

    protected $appends = ['qr_image_url'];

    protected $hidden = ['qr_image', 'created_at', 'updated_at'];

    // Built from the request host, so it works on the emulator and in Chrome alike
    public function getQrImageUrlAttribute(): string
    {
        return \App\Support\Uploads::url($this->qr_image);
    }

    // What the payment page shows: every saved bank, or the one in .env
    // (config/shop.php) while the admin has not added any yet
    public static function forCustomers(): array
    {
        $accounts = static::orderBy('sort')->orderBy('id')->get()
            ->map(fn (self $a) => [
                'id' => $a->id,
                'bank_name' => $a->bank_name,
                'account_name' => $a->account_name,
                'account_number' => $a->account_number,
                'qr_image_url' => $a->qr_image_url,
            ])->all();

        if ($accounts === []) {
            $info = config('shop.payment');
            $qr = \App\Support\Uploads::url($info['qr_image_url'] ?? '');
            $accounts = [[
                'id' => null,
                'bank_name' => $info['bank_name'] ?? '',
                'account_name' => $info['account_name'] ?? '',
                'account_number' => $info['account_number'] ?? '',
                'qr_image_url' => $qr,
            ]];
        }

        return $accounts;
    }
}
