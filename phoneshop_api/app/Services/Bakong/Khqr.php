<?php

namespace App\Services\Bakong;

// Builds a KHQR string (Cambodia's EMVCo QR standard) for one payment into
// the shop's Bakong account. Any Cambodian bank app (ABA, ACLEDA, Wing...)
// scans it with the amount already filled in. The md5 of the string is how
// Bakong finds the payment afterwards.
class Khqr
{
    public const CURRENCY_CODES = ['USD' => '840', 'KHR' => '116'];

    public static function individual(
        string $accountId,
        string $merchantName,
        string $merchantCity,
        float $amount,
        string $currency = 'USD',
        string $billNumber = '',
        string $storeLabel = '',
        ?int $expiresAtMs = null,
    ): string {
        $currency = strtoupper($currency);
        $nowMs = (int) floor(microtime(true) * 1000);

        $qr = self::tag('00', '01')                    // payload format
            .self::tag('01', '12')                     // dynamic: one payment, with amount
            .self::tag('29', self::tag('00', $accountId)) // individual Bakong account
            .self::tag('52', '5999')                   // merchant category
            .self::tag('53', self::CURRENCY_CODES[$currency] ?? '840')
            .self::tag('54', self::amount($amount, $currency))
            .self::tag('58', 'KH')
            .self::tag('59', self::clip($merchantName, 25))
            .self::tag('60', self::clip($merchantCity, 15));

        $extra = ($billNumber !== '' ? self::tag('01', self::clip($billNumber, 25)) : '')
            .($storeLabel !== '' ? self::tag('03', self::clip($storeLabel, 25)) : '');
        if ($extra !== '') {
            $qr .= self::tag('62', $extra);
        }

        // When it was made and when it stops being payable
        $qr .= self::tag('99', self::tag('00', (string) $nowMs)
            .($expiresAtMs ? self::tag('01', (string) $expiresAtMs) : ''));

        $qr .= '6304';

        return $qr.self::crc16($qr);
    }

    public static function md5(string $qr): string
    {
        return md5($qr);
    }

    // "999", "12.5": USD keeps up to 2 decimals, riel is whole
    public static function amount(float $amount, string $currency): string
    {
        if ($currency === 'KHR') {
            return (string) (int) round($amount);
        }

        return rtrim(rtrim(number_format($amount, 2, '.', ''), '0'), '.');
    }

    // ID + 2-digit length + value
    public static function tag(string $id, string $value): string
    {
        return $id.str_pad((string) strlen($value), 2, '0', STR_PAD_LEFT).$value;
    }

    // CRC-16/CCITT-FALSE (poly 0x1021, start 0xFFFF), as EMVCo requires
    public static function crc16(string $data): string
    {
        $crc = 0xFFFF;
        for ($i = 0, $n = strlen($data); $i < $n; $i++) {
            $crc ^= ord($data[$i]) << 8;
            for ($b = 0; $b < 8; $b++) {
                $crc = ($crc & 0x8000) ? (($crc << 1) ^ 0x1021) : ($crc << 1);
                $crc &= 0xFFFF;
            }
        }

        return strtoupper(str_pad(dechex($crc), 4, '0', STR_PAD_LEFT));
    }

    // Plain ASCII and within the field's limit
    private static function clip(string $text, int $max): string
    {
        $ascii = preg_replace('/[^\x20-\x7E]/', '', $text) ?: 'PS168';

        return substr($ascii, 0, $max);
    }
}
