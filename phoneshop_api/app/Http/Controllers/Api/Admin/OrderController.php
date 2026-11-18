<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\OrderTracking;
use App\Models\Product;
use App\Models\Setting;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class OrderController extends Controller
{
    public function index(Request $request)
    {
        Order::expireUnpaid(); // free stock held by orders nobody paid for
        $query = Order::with(['user', 'items.product', 'trackings'])->latest();

        if ($status = $request->query('status')) {
            $query->where('status', $status);
        }

        return $query->get();
    }

    public function update(Request $request, Order $order)
    {
        $data = $request->validate([
            'status' => 'sometimes|in:pending,confirmed,shipping,delivered,cancelled',
            'payment_status' => 'sometimes|in:unpaid,verifying,paid',
            'courier' => 'sometimes|nullable|string|max:50',
            'tracking_number' => 'sometimes|nullable|string|max:50',
            // Optional details for the tracking step a status change creates
            'location' => 'nullable|string|max:150',
            'note' => 'nullable|string|max:255',
        ]);
        $location = $data['location'] ?? null;
        $note = $data['note'] ?? null;
        unset($data['location'], $data['note']);

        if ($order->status === 'cancelled') {
            return response()->json(['message' => 'Order នេះត្រូវបានបោះបង់រួចហើយ'], 422);
        }

        if (($data['status'] ?? null) === 'cancelled') {
            $order->cancelAndRestock(); // records its own tracking step
            unset($data['status']);
        }

        $statusChanged = isset($data['status']) && $data['status'] !== $order->status;
        $order->update($data);
        if ($statusChanged) {
            $order->track($location, $note);
        }

        return $order->load(['user', 'items.product', 'trackings']);
    }

    // Removes the order for good, with its items and tracking steps. An order still in
    // progress puts its stock back; a delivered one was sold and a cancelled one already did.
    public function destroy(Order $order)
    {
        DB::transaction(function () use ($order) {
            if (! in_array($order->status, ['delivered', 'cancelled'], true)) {
                foreach ($order->items as $item) {
                    $item->product?->increment('stock', $item->qty);
                }
                $order->releaseVoucher();
            }
            $order->delete();
        });

        return response()->json(['message' => 'Deleted']);
    }

    // A delivery update without a status change, e.g. "ដល់សាខា បាត់ដំបង"
    public function addTracking(Request $request, Order $order)
    {
        $data = $request->validate([
            'location' => 'required_without:note|nullable|string|max:150',
            'note' => 'required_without:location|nullable|string|max:255',
        ], [
            'location.required_without' => 'សូមបញ្ចូលទីតាំង ឬកំណត់សម្គាល់',
            'note.required_without' => 'សូមបញ្ចូលទីតាំង ឬកំណត់សម្គាល់',
        ]);

        if ($order->status === 'cancelled') {
            return response()->json(['message' => 'Order នេះត្រូវបានបោះបង់រួចហើយ'], 422);
        }

        $order->trackings()->create([
            'status' => $order->status,
            'location' => $data['location'] ?? null,
            'note' => $data['note'] ?? null,
        ]);

        return $order->load(['user', 'items.product', 'trackings']);
    }

    // Asked by the admin app every few seconds: orders placed after the one it last saw.
    // Without ?after, just the newest ID, so the app knows where to start.
    public function newOrders(Request $request)
    {
        $data = $request->validate(['after' => 'nullable|integer|min:0']);
        $latest = (int) Order::max('id');

        if (! isset($data['after'])) {
            return ['latest_id' => $latest, 'count' => 0, 'orders' => []];
        }

        $newer = Order::where('id', '>', $data['after']);

        return [
            'latest_id' => $latest,
            'count' => (clone $newer)->count(),
            'orders' => $newer->latest('id')->limit(5)->get(['id', 'customer_name', 'total', 'payment_method']),
        ];
    }

    // The admin has seen the customers' "I got my parcel" notices
    public function markReceivedSeen()
    {
        Order::whereNotNull('received_at')->whereNull('received_seen_at')->update(['received_seen_at' => now()]);

        return response()->json(['message' => 'OK']);
    }

    // Corrects a step typed wrongly. Its status and time stay: only where and the note change.
    public function updateTracking(Request $request, Order $order, OrderTracking $tracking)
    {
        abort_unless($tracking->order_id === $order->id, 404);

        $data = $request->validate([
            'location' => 'nullable|string|max:150',
            'note' => 'nullable|string|max:255',
        ]);

        $tracking->update([
            'location' => $data['location'] ?? null,
            'note' => $data['note'] ?? null,
        ]);

        return $order->load(['user', 'items.product', 'trackings']);
    }

    // Registered customers, newest first, with how many orders each has placed
    public function customers()
    {
        return User::where('role', 'user')
            // select() before withCount(), which would otherwise select every column
            ->select(['id', 'name', 'email', 'phone', 'address', 'blocked_at', 'created_at'])
            ->withCount('orders')
            ->latest()
            ->latest('id')
            ->get()
            // The picture is not selected above, and the list does not show it
            ->makeHidden('avatar_url');
    }

    // Fix a customer's details, or give them a new password when they've forgotten it.
    // Passwords are stored hashed, so the old one can be replaced but never shown.
    public function updateCustomer(Request $request, User $user)
    {
        if ($user->role !== 'user') {
            return response()->json(['message' => 'អាចកែបានតែគណនីអតិថិជនប៉ុណ្ណោះ'], 422);
        }

        $data = $request->validate([
            'name' => 'required|string|max:100',
            'email' => ['required', 'email', Rule::unique('users', 'email')->ignore($user->id)],
            'phone' => 'nullable|string|max:20',
            'address' => 'nullable|string|max:500',
            'password' => 'nullable|string|min:6', // empty = keep the current one
        ]);

        $newPassword = $data['password'] ?? null;
        unset($data['password']);

        $user->fill($data);
        if ($newPassword) {
            $user->password = $newPassword; // hashed by the model's cast
        }
        $user->save();

        // Anyone still logged in with the old password has to log in with the new one
        if ($newPassword) {
            $user->tokens()->delete();
        }

        return response()->json($user->only(['id', 'name', 'email', 'phone', 'address']));
    }

    // Disable or re-enable a customer's account. Their orders are kept either way.
    public function setCustomerBlocked(Request $request, User $user)
    {
        $data = $request->validate(['blocked' => 'required|boolean']);

        // Only customers: the admin can't lock themselves (or another admin) out
        if ($user->role !== 'user') {
            return response()->json(['message' => 'អាចបិទបានតែគណនីអតិថិជនប៉ុណ្ណោះ'], 422);
        }

        $user->forceFill(['blocked_at' => $data['blocked'] ? now() : null])->save();

        // Logged in right now? Their tokens stop working immediately.
        if ($data['blocked']) {
            $user->tokens()->delete();
        }

        return response()->json(['id' => $user->id, 'blocked_at' => $user->blocked_at]);
    }

    // Removes the account for good. The orders stay for the shop's records, with the
    // buyer's name and e-mail kept on them, but no longer belong to any account.
    public function deleteCustomer(User $user)
    {
        // Only customers: the admin can't delete themselves (or another admin)
        if ($user->role !== 'user') {
            return response()->json(['message' => 'អាចលុបបានតែគណនីអតិថិជនប៉ុណ្ណោះ'], 422);
        }

        DB::transaction(function () use ($user) {
            foreach ($user->orders as $order) {
                $order->update([
                    'user_id' => null,
                    'customer_name' => $order->customer_name ?: $user->name,
                    'customer_email' => $order->customer_email ?: $user->email,
                ]);
            }
            $user->tokens()->delete();
            $user->delete();
        });

        if ($user->avatar && file_exists(public_path('uploads/'.$user->avatar))) {
            unlink(public_path('uploads/'.$user->avatar));
        }

        return response()->json(['message' => 'Deleted']);
    }

    // The stock level the admin wants to be warned at
    public function updateLowStockThreshold(Request $request)
    {
        $data = $request->validate(['threshold' => 'required|integer|min:0|max:100000']);

        Setting::setLowStockThreshold($data['threshold']);

        return $this->dashboard();
    }

    public function dashboard()
    {
        $threshold = Setting::lowStockThreshold();

        $unpaidDelivered = Order::where('status', 'delivered')->where('payment_status', 'unpaid');

        return [
            'total_products' => Product::count(),
            'low_stock' => Product::where('stock', '<=', $threshold)->count(),
            'low_stock_threshold' => $threshold,
            'total_customers' => User::where('role', 'user')->count(),
            'total_orders' => Order::count(),
            'pending_orders' => Order::where('status', 'pending')->count(),
            'verifying_payments' => Order::where('payment_status', 'verifying')->count(),
            // Customers who said they got their parcel, since the admin last looked
            'new_received' => Order::whereNotNull('received_at')->whereNull('received_seen_at')->count(),
            // Money still to collect: the customer has the phone, the shop doesn't have the cash
            'unpaid_delivered' => $unpaidDelivered->count(),
            'unpaid_delivered_total' => (float) $unpaidDelivered->sum('total'),
            'revenue' => (float) Order::where('payment_status', 'paid')->sum('total'),
            'revenue_by_day' => $this->revenueByDay(),
            'orders_by_status' => $this->ordersByStatus(),
            'top_products' => $this->topProducts(),
        ];
    }

    // Paid orders per day for the last 7 days, oldest first; days without sales count as 0.
    // Days follow Cambodia's calendar: the database stores UTC.
    private function revenueByDay(): array
    {
        $timezone = 'Asia/Phnom_Penh';
        $today = now($timezone)->startOfDay();

        $days = [];
        for ($i = 6; $i >= 0; $i--) {
            $days[$today->copy()->subDays($i)->toDateString()] = 0.0;
        }

        $orders = Order::where('payment_status', 'paid')
            ->where('created_at', '>=', $today->copy()->subDays(6)->utc())
            ->get(['total', 'created_at']);

        foreach ($orders as $order) {
            $day = $order->created_at->copy()->setTimezone($timezone)->toDateString();
            if (isset($days[$day])) {
                $days[$day] += $order->total;
            }
        }

        return array_map(
            fn ($date, $total) => ['date' => $date, 'total' => $total],
            array_keys($days),
            array_values($days),
        );
    }

    // Every status in the order an order moves through them, including those at 0
    private function ordersByStatus(): array
    {
        $counts = Order::query()->selectRaw('status, COUNT(*) AS total')->groupBy('status')->pluck('total', 'status');

        return array_map(
            fn ($status) => ['status' => $status, 'count' => (int) ($counts[$status] ?? 0)],
            ['pending', 'confirmed', 'shipping', 'delivered', 'cancelled'],
        );
    }

    // Best sellers by units; cancelled orders don't count
    private function topProducts(): array
    {
        return OrderItem::query()
            ->join('orders', 'orders.id', '=', 'order_items.order_id')
            ->join('products', 'products.id', '=', 'order_items.product_id')
            ->where('orders.status', '!=', 'cancelled')
            ->groupBy('products.id', 'products.name')
            ->orderByDesc('qty')
            ->orderBy('products.name')
            ->limit(5)
            ->get(['products.name', DB::raw('SUM(order_items.qty) AS qty')])
            ->map(fn ($row) => ['name' => $row->name, 'qty' => (int) $row->qty])
            ->all();
    }
}
