<?php

namespace App\Services\Bakong;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

// Talks to the National Bank's Bakong Open API: asks whether the KHQR with a
// given md5 has been paid, and into which account, how much, in what currency.
class Bakong
{
    // On only when the shop has a Bakong account ID and an API token
    public static function enabled(): bool
    {
        return (string) config('shop.bakong.token') !== ''
            && (string) config('shop.bakong.account_id') !== '';
    }

    public static function accountId(): string
    {
        return (string) config('shop.bakong.account_id');
    }

    public static function currency(): string
    {
        return strtoupper((string) config('shop.bakong.currency', 'USD'));
    }

    public static function qrFor(float $amount, string $billNumber, ?int $expiresAtMs): string
    {
        return Khqr::individual(
            self::accountId(),
            (string) config('shop.bakong.merchant_name', 'PS168'),
            (string) config('shop.bakong.merchant_city', 'Phnom Penh'),
            $amount,
            self::currency(),
            $billNumber,
            'PS168',
            $expiresAtMs,
        );
    }

    /**
     * The payment found for this md5, or null when nobody has paid yet.
     * Throws BakongUnavailable when Bakong can't be asked (network, bad token),
     * so callers never mistake "couldn't check" for "not paid".
     *
     * @return array{hash: string, from: string, to: string, amount: float, currency: string}|null
     */
    public static function findPayment(string $md5): ?array
    {
        try {
            $response = Http::withToken((string) config('shop.bakong.token'))
                ->acceptJson()
                ->timeout(8)
                ->post(rtrim((string) config('shop.bakong.api_url'), '/').'/v1/check_transaction_by_md5', [
                    'md5' => $md5,
                ]);
        } catch (\Throwable $e) {
            throw new BakongUnavailable('Bakong: '.$e->getMessage(), 0, $e);
        }

        if ($response->status() === 401 || $response->status() === 403) {
            Log::warning('Bakong token rejected: renew BAKONG_TOKEN at api-bakong.nbc.gov.kh');
            throw new BakongUnavailable('Bakong token rejected');
        }
        if (! $response->successful()) {
            throw new BakongUnavailable('Bakong answered '.$response->status());
        }

        $body = $response->json() ?? [];
        // responseCode 0 = found; 1 = not found (not paid yet)
        if ((int) ($body['responseCode'] ?? 1) !== 0 || empty($body['data'])) {
            return null;
        }
        $data = $body['data'];

        return [
            'hash' => (string) ($data['hash'] ?? ''),
            'from' => (string) ($data['fromAccountId'] ?? ''),
            'to' => (string) ($data['toAccountId'] ?? ''),
            'amount' => (float) ($data['amount'] ?? 0),
            'currency' => strtoupper((string) ($data['currency'] ?? '')),
        ];
    }

    // The money went into the shop's account, in full, in the right currency
    public static function covers(array $payment, float $total): bool
    {
        return strcasecmp($payment['to'], self::accountId()) === 0
            && $payment['currency'] === self::currency()
            && $payment['amount'] + 0.001 >= $total;
    }
}
