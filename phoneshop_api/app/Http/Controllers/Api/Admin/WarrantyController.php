<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\OrderItem;
use App\Models\SoldUnit;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

// IMEIs of the phones handed over, and the warranty desk's lookup by IMEI
class WarrantyController extends Controller
{
    // The IMEIs of one order line, one per phone (fewer while not all are known)
    public function setImeis(Request $request, OrderItem $item)
    {
        $request->merge([
            'imeis' => array_values(array_filter(array_map(
                fn ($i) => preg_replace('/\D/', '', (string) $i),
                (array) $request->input('imeis', [])
            ))),
        ]);
        $data = $request->validate([
            'imeis' => 'present|array|max:'.$item->qty,
            'imeis.*' => 'distinct|digits:15',
        ], [
            'imeis.max' => "Order នេះមានតែ {$item->qty} គ្រឿងប៉ុណ្ណោះ",
            'imeis.*.digits' => 'IMEI ត្រូវមាន 15 ខ្ទង់',
            'imeis.*.distinct' => 'IMEI ដដែលបញ្ចូលពីរដង',
        ]);

        foreach ($data['imeis'] as $imei) {
            if (! self::luhn($imei)) {
                throw ValidationException::withMessages(['imeis' => "IMEI {$imei} មិនត្រឹមត្រូវ (សូមពិនិត្យលេខម្តងទៀត)"]);
            }
            $other = SoldUnit::where('imei', $imei)->where('order_item_id', '!=', $item->id)->first();
            if ($other) {
                $code = $other->item?->order?->code ?? '#'.$other->item?->order_id;
                throw ValidationException::withMessages(['imeis' => "IMEI {$imei} ត្រូវបានលក់រួចហើយក្នុង Order {$code}"]);
            }
        }

        $item->units()->whereNotIn('imei', $data['imeis'])->delete();
        foreach ($data['imeis'] as $imei) {
            $item->units()->firstOrCreate(['imei' => $imei]);
        }

        return $item->fresh()->load(['product', 'units']);
    }

    // Who bought this phone and until when it is covered
    public function lookup(string $imei)
    {
        $unit = SoldUnit::with('item.order', 'item.product')->where('imei', preg_replace('/\D/', '', $imei))->first();
        abort_unless($unit && $unit->item?->order, 404, 'រកមិនឃើញ IMEI នេះក្នុងការលក់របស់ហាងទេ');

        $item = $unit->item;
        $order = $item->order;
        $until = $item->warrantyUntil();

        return [
            'imei' => $unit->imei,
            'product' => $item->product?->name ?? 'Deleted product',
            'color' => $item->color,
            'storage' => $item->storage,
            'order_id' => $order->id,
            'order_code' => $order->code,
            'customer_name' => $order->customer_name,
            'phone' => $order->phone,
            'sold_at' => $order->created_at?->toIso8601String(),
            'delivered_at' => $order->delivered_at?->toIso8601String(),
            'warranty_months' => $item->warranty_months,
            'warranty_until' => $until?->toIso8601String(),
            'under_warranty' => $until !== null && $until->isFuture(),
        ];
    }

    // The check digit every real IMEI has (Luhn), so a mistyped number is caught
    public static function luhn(string $digits): bool
    {
        $sum = 0;
        foreach (str_split(strrev($digits)) as $i => $d) {
            $n = (int) $d * ($i % 2 ? 2 : 1);
            $sum += $n > 9 ? $n - 9 : $n;
        }

        return $sum % 10 === 0;
    }
}
