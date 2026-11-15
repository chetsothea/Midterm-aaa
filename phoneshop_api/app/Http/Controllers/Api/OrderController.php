<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Order;
use App\Models\Product;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class OrderController extends Controller
{
    public function index(Request $request)
    {
        // Not the cancelled ones the customer removed from their list
        return $request->user()->orders()->whereNull('customer_hidden_at')
            ->with(['items.product', 'trackings'])->latest()->get();
    }

    public function show(Request $request, Order $order)
    {
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
        ]);
    }

    private function placeOrder(array $data, int $userId): Order
    {
        $order = DB::transaction(function () use ($data, $userId) {
            $total = 0;
            $lines = [];

            foreach ($data['items'] as $item) {
                // Lock the row so two customers can't buy the last unit at the same time
                $product = Product::lockForUpdate()->find($item['product_id']);

                if ($product->stock < $item['qty']) {
                    throw ValidationException::withMessages([
                        'items' => "{$product->name} នៅសល់តែ {$product->stock} គ្រឿងប៉ុណ្ណោះ",
                    ]);
                }

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

                $product->decrement('stock', $item['qty']);
                // Price comes from the database, never from the app
                $total += $price * $item['qty'];
                $lines[] = [
                    'product_id' => $product->id,
                    'qty' => $item['qty'],
                    'color' => $colors ? $color : null,
                    'storage' => $storage,
                    'price' => $price,
                ];
            }

            // The customer's own count: locking their account row means two orders
            // placed at the same moment can't get the same number
            User::lockForUpdate()->find($userId);
            $number = (int) Order::where('user_id', $userId)->max('customer_number') + 1;

            $order = Order::create([
                'user_id' => $userId,
                'customer_number' => $number,
                'customer_name' => $data['customer_name'],
                'customer_email' => $data['customer_email'],
                'total' => $total,
                'payment_method' => $data['payment_method'],
                'phone' => $data['phone'],
                'address' => $data['address'],
            ]);
            $order->items()->createMany($lines);
            // First step of the delivery timeline ("បានទទួល Order របស់អ្នក")
            $order->refresh()->track();

            return $order;
        });

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

        if ($order->status !== 'pending' || $order->payment_status !== 'unpaid') {
            return response()->json(['message' => 'អាចបោះបង់បានតែ Order ដែលនៅ Pending និងមិនទាន់បង់ប្រាក់ប៉ុណ្ណោះ'], 422);
        }

        $order->cancelAndRestock();

        return $order->load(['items.product', 'trackings']);
    }
}
