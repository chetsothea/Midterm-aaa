<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Order;
use App\Models\Product;
use App\Models\User;
use App\Models\Voucher;
use App\Services\Bakong\BakongUnavailable;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class OrderController extends Controller
{
    public function index(Request $request)
    {
        Order::expireUnpaid(); // free stock held by orders nobody paid for
        // Not the cancelled ones the customer removed from their list
        return $request->user()->orders()->whereNull('customer_hidden_at')
            ->with(['items.product', 'trackings'])->latest()->get();
    }

    public function show(Request $request, Order $order)
    {
        Order::expireUnpaid(); // free stock held by orders nobody paid for
        abort_unless($order->isOwnedBy($request), 404);

        return $order->load(['items.product', 'trackings']);
    }

    // Logged-in customer: the order is linked to their account
    public function store(Request $request)
    {
        $order = $this->placeOrder($this->validateCheckout($request), $request->user()->id);

        return response()->json($order, 201);
    }

    // The checkout form: who is buying, where to deliver, and what
    private function validateCheckout(Request $request): array
    {
        return $request->validate([
            'customer_name' => 'required|string|max:100',
            'customer_email' => 'required|email|max:150',
            'phone' => 'required|string|max:20',
            'address' => 'required|string|max:500',
            'payment_method' => 'required|in:cod,khqr',
            'items' => 'required|array|min:1',
            'items.*.product_id' => 'required|integer|exists:products,id',
            'items.*.qty' => 'required|integer|min:1',
            'items.*.color' => 'nullable|string|max:30',
            'items.*.storage' => 'nullable|string|max:20',
            'voucher_code' => 'nullable|string|max:30',
        ]);
    }

    // What the order will cost before it is placed: phones, delivery fee and
    // any code, all worked out here from the database, never by the app
    public function quote(Request $request)
    {
        $data = $request->validate([
            'address' => 'nullable|string|max:500',
            'voucher_code' => 'nullable|string|max:30',
            'items' => 'required|array|min:1',
            'items.*.product_id' => 'required|integer|exists:products,id',
            'items.*.qty' => 'required|integer|min:1',
            'items.*.color' => 'nullable|string|max:30',
            'items.*.storage' => 'nullable|string|max:20',
        ]);

        [, $subtotal] = $this->priceLines($data['items'], false);
        $charges = $this->charges($subtotal, $data['address'] ?? '', $data['voucher_code'] ?? null, $request->user()->id, false);

        return [
            'subtotal' => $subtotal,
            'discount' => $charges['discount'],
            'voucher_code' => $charges['voucher']?->code,
            'voucher_label' => $charges['voucher']?->label,
            'shipping_fee' => $charges['shipping_fee'],
            'shipping_zone' => \App\Support\Shipping::isPhnomPenh($data['address'] ?? '') ? 'phnom_penh' : 'province',
            'total' => $charges['total'],
            'shipping' => \App\Support\Shipping::rates(),
        ];
    }

    // The order's phones at today's prices. With $reserve the rows are locked
    // and the stock taken, so two customers can't buy the last unit together.
    private function priceLines(array $items, bool $reserve): array
    {
        $subtotal = 0;
        $lines = [];

        foreach ($items as $item) {
            $product = $reserve
                ? Product::lockForUpdate()->find($item['product_id'])
                : Product::find($item['product_id']);

            // The colour must be one the product is sold in
            $color = $item['color'] ?? null;
            $colors = $product->colorOptions();
            if ($colors && ! in_array($color, $colors, true)) {
                throw ValidationException::withMessages([
                    'items' => "សូមជ្រើសពណ៌សម្រាប់ {$product->name}",
                ]);
            }

            // Products sold in several sizes are priced by the size picked
            $storage = null;
            $price = $product->salePrice();
            if ($product->storage_prices) {
                $storage = $item['storage'] ?? null;
                $price = $product->priceForStorage($storage);
                if ($price === null) {
                    throw ValidationException::withMessages([
                        'items' => "សូមជ្រើស Storage សម្រាប់ {$product->name}",
                    ]);
                }
            }

            // Checked for the exact colour and size picked
            $left = $product->stockFor($colors ? $color : null, $storage);
            if ($left < $item['qty']) {
                $what = trim($product->name.' '.implode(' ', array_filter([$colors ? $color : null, $storage])));
                throw ValidationException::withMessages([
                    'items' => $left > 0 ? "{$what} នៅសល់តែ {$left} គ្រឿងប៉ុណ្ណោះ" : "{$what} អស់ស្តុកហើយ",
                ]);
            }

            if ($reserve) {
                $product->moveStock($colors ? $color : null, $storage, -$item['qty']);
            }
            // Price comes from the database, never from the app
            $subtotal += $price * $item['qty'];
            $lines[] = [
                'product_id' => $product->id,
                'qty' => $item['qty'],
                'color' => $colors ? $color : null,
                'storage' => $storage,
                'price' => $price,
                'warranty_months' => $product->warranty_months,
            ];
        }

        return [$lines, round($subtotal, 2)];
    }

    // Discount from the code (checked), then the delivery fee on what is left
    private function charges(float $subtotal, string $address, ?string $code, ?int $userId, bool $lock): array
    {
        $voucher = null;
        $discount = 0.0;
        if (Voucher::normalize($code) !== '') {
            $voucher = Voucher::findCode($code, $lock);
            $problem = $voucher ? $voucher->problemFor($subtotal, $userId) : 'រកមិនឃើញកូដនេះទេ';
            if ($problem) {
                throw ValidationException::withMessages(['voucher_code' => $problem]);
            }
            $discount = $voucher->discountFor($subtotal);
        }

        $fee = \App\Support\Shipping::feeFor($address, $subtotal - $discount);

        return [
            'voucher' => $voucher,
            'discount' => $discount,
            'shipping_fee' => $fee,
            'total' => round($subtotal - $discount + $fee, 2),
        ];
    }

    private function placeOrder(array $data, int $userId): Order
    {
        $order = DB::transaction(function () use ($data, $userId) {
            [$lines, $subtotal] = $this->priceLines($data['items'], true);

            // The customer's own count: locking their account row means two orders
            // placed at the same moment can't get the same number
            User::lockForUpdate()->find($userId);
            $number = (int) Order::where('user_id', $userId)->max('customer_number') + 1;

            // After the account lock, so the "once per customer" check can't race
            $charges = $this->charges($subtotal, $data['address'], $data['voucher_code'] ?? null, $userId, true);
            $charges['voucher']?->increment('used_count');

            $order = Order::create([
                'user_id' => $userId,
                'customer_number' => $number,
                'customer_name' => $data['customer_name'],
                'customer_email' => $data['customer_email'],
                'subtotal' => $subtotal,
                'discount' => $charges['discount'],
                'voucher_code' => $charges['voucher']?->code,
                'shipping_fee' => $charges['shipping_fee'],
                'total' => $charges['total'],
                'payment_method' => $data['payment_method'],
                'phone' => $data['phone'],
                'address' => $data['address'],
            ]);
            $order->items()->createMany($lines);
            // First step of the delivery timeline ("បានទទួល Order របស់អ្នក")
            $order->refresh()->track();

            return $order;
        });

        // Its own QR with the amount in it, when Bakong is set up
        $order->attachBakongQr();

        // fresh() so the database defaults (status, payment_status) are included
        return $order->fresh(['items.product', 'trackings']);
    }

    // Customer says they paid by the shop's QR / bank transfer; the admin then checks the
    // shop's bank app and confirms it. The transaction ID is optional, it only helps the admin.
    public function pay(Request $request, Order $order)
    {
        abort_unless($order->isOwnedBy($request), 404);

        $data = $request->validate([
            'transaction_ref' => 'nullable|string|max:100',
        ]);

        if ($order->payment_status === 'paid' || $order->status === 'cancelled') {
            return response()->json(['message' => 'Order នេះមិនអាចបង់ប្រាក់បានទេ'], 422);
        }

        $order->update([
            'transaction_ref' => trim((string) ($data['transaction_ref'] ?? '')) ?: null,
            'payment_status' => 'verifying',
        ]);

        return $order->load(['items.product', 'trackings']);
    }

    // The payment page asks this every few seconds while the customer pays:
    // the server checks with Bakong and the order comes back marked paid once
    // the money has arrived. "bakong_down" tells the app Bakong couldn't answer.
    public function checkPayment(Request $request, Order $order)
    {
        abort_unless($order->isOwnedBy($request), 404);

        $down = false;
        try {
            $order->checkBakong();
        } catch (BakongUnavailable) {
            $down = true;
        }

        return [
            ...$order->fresh(['items.product', 'trackings'])->toArray(),
            'bakong_down' => $down,
        ];
    }

    // The customer confirms the parcel arrived, so the admin doesn't have to find out elsewhere
    public function received(Request $request, Order $order)
    {
        abort_unless($order->isOwnedBy($request), 404);

        // Also after the admin marked it delivered: only the customer knows it's in their hands
        if (! in_array($order->status, ['shipping', 'delivered'], true) || $order->received_at) {
            return response()->json(['message' => 'មិនអាចបញ្ជាក់ Order នេះបានទេ'], 422);
        }

        $order->update(['status' => 'delivered', 'received_at' => now()]);
        $order->track(null, 'អ្នកទិញបានបញ្ជាក់ថាទទួលឥវ៉ាន់ហើយ');

        return $order->load(['items.product', 'trackings']);
    }

    // Takes a cancelled or received order off the customer's list. Only hidden from them:
    // the shop keeps it, so its records and the dashboard numbers don't change.
    public function hide(Request $request, Order $order)
    {
        abort_unless($order->isOwnedBy($request), 404);

        if (! in_array($order->status, ['cancelled', 'delivered'], true)) {
            return response()->json(['message' => 'អាចលុបបានតែ Order ដែលបានទទួល ឬបានបោះបង់ប៉ុណ្ណោះ'], 422);
        }

        $order->update(['customer_hidden_at' => now()]);

        return response()->json(['message' => 'OK']);
    }

    public function cancel(Request $request, Order $order)
    {
        abort_unless($order->isOwnedBy($request), 404);

        // Only before it leaves the shop: just placed, or being packed
        if (! $order->can_cancel) {
            $message = in_array($order->status, ['shipping', 'delivered'], true)
                ? 'Order នេះចាប់ផ្តើមដឹកជញ្ជូនហើយ មិនអាចបោះបង់បានទេ។ សូមទាក់ទងហាង'
                : 'Order នេះមិនអាចបោះបង់បានទេ';

            return response()->json(['message' => $message], 422);
        }

        // Money already came in: the shop owes it back, and the timeline says so
        $note = match ($order->payment_status) {
            'paid' => 'អតិថិជនបានបោះបង់ · ហាងត្រូវបង្វិលប្រាក់ $'.number_format($order->total, 2),
            'verifying' => 'អតិថិជនបានបោះបង់ · ពិនិត្យការបង់ប្រាក់ ហើយបង្វិលប្រាក់បើបានទទួល',
            default => 'អតិថិជនបានបោះបង់ Order',
        };
        $order->cancelAndRestock($note);

        return $order->load(['items.product', 'trackings']);
    }
}
