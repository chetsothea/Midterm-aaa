<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Order;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;

// Sales between two days (Cambodia's calendar), as numbers for the app and as
// a CSV file that opens in Excel. Money counts only paid orders that were not cancelled.
class ReportController extends Controller
{
    private const TZ = 'Asia/Phnom_Penh';

    public function sales(Request $request)
    {
        [$from, $to, $orders] = $this->orders($request);
        // A cancelled order is no sale, even if money came in (it goes back)
        $paid = $orders->where('payment_status', 'paid')->where('status', '!=', 'cancelled');

        $days = [];
        for ($d = $from->copy(); $d->lte($to); $d->addDay()) {
            $days[$d->toDateString()] = ['date' => $d->toDateString(), 'orders' => 0, 'revenue' => 0.0];
        }
        foreach ($orders as $order) {
            $day = $order->created_at->copy()->setTimezone(self::TZ)->toDateString();
            if (! isset($days[$day]) || $order->status === 'cancelled') {
                continue;
            }
            $days[$day]['orders']++;
            if ($order->payment_status === 'paid') {
                $days[$day]['revenue'] = round($days[$day]['revenue'] + $order->total, 2);
            }
        }

        $products = [];
        foreach ($paid as $order) {
            foreach ($order->items as $item) {
                $name = $item->product?->name ?? 'Deleted product';
                $products[$name] ??= ['name' => $name, 'qty' => 0, 'revenue' => 0.0];
                $products[$name]['qty'] += $item->qty;
                $products[$name]['revenue'] = round($products[$name]['revenue'] + $item->price * $item->qty, 2);
            }
        }
        usort($products, fn ($a, $b) => $b['revenue'] <=> $a['revenue']);

        $methods = [];
        foreach ($paid->groupBy('payment_method') as $method => $group) {
            $methods[] = ['method' => $method, 'orders' => $group->count(), 'revenue' => round($group->sum('total'), 2)];
        }

        $notCancelled = $orders->where('status', '!=', 'cancelled');

        return [
            'from' => $from->toDateString(),
            'to' => $to->toDateString(),
            'orders' => $notCancelled->count(),
            'paid_orders' => $paid->count(),
            'cancelled_orders' => $orders->where('status', 'cancelled')->count(),
            'revenue' => round($paid->sum('total'), 2),
            'phones_sold' => (int) $paid->sum(fn ($o) => $o->items->sum('qty')),
            'discounts' => round($paid->sum('discount'), 2),
            'shipping_fees' => round($paid->sum('shipping_fee'), 2),
            'unpaid_total' => round($notCancelled->where('payment_status', '!=', 'paid')->sum('total'), 2),
            'average_order' => $paid->count() ? round($paid->sum('total') / $paid->count(), 2) : 0,
            'by_day' => array_values($days),
            'top_products' => array_slice($products, 0, 10),
            'by_payment' => $methods,
        ];
    }

    // One row per phone line, with a BOM so Excel reads the Khmer names correctly
    public function salesCsv(Request $request)
    {
        [$from, $to, $orders] = $this->orders($request);
        $name = "ps168-sales-{$from->toDateString()}-to-{$to->toDateString()}.csv";

        $rows = [[
            'Date', 'Order', 'Customer', 'Phone number', 'Status', 'Payment', 'Payment status',
            'Product', 'Colour', 'Storage', 'Qty', 'Unit price', 'Line total',
            'IMEI', 'Discount code', 'Order discount', 'Delivery fee', 'Order total',
        ]];
        foreach ($orders as $order) {
            foreach ($order->items as $i => $item) {
                $rows[] = [
                    $order->created_at->copy()->setTimezone(self::TZ)->format('Y-m-d H:i'),
                    $order->code ?: '#'.$order->id,
                    $order->customer_name,
                    $order->phone,
                    $order->status,
                    $order->payment_method,
                    $order->payment_status,
                    $item->product?->name ?? 'Deleted product',
                    $item->color,
                    $item->storage,
                    $item->qty,
                    number_format($item->price, 2, '.', ''),
                    number_format($item->price * $item->qty, 2, '.', ''),
                    implode(' ', $item->imeis),
                    // Order-wide amounts only on its first line, so a SUM in Excel stays right
                    $i === 0 ? $order->voucher_code : '',
                    $i === 0 ? number_format($order->discount ?? 0, 2, '.', '') : '',
                    $i === 0 ? number_format($order->shipping_fee ?? 0, 2, '.', '') : '',
                    $i === 0 ? number_format($order->total, 2, '.', '') : '',
                ];
            }
        }

        $out = fopen('php://temp', 'r+');
        fwrite($out, "\xEF\xBB\xBF");
        foreach ($rows as $row) {
            // A cell starting with = + - @ would run as a formula in Excel
            fputcsv($out, array_map(fn ($v) => preg_match('/^[=+\-@\t\r]/', (string) $v) ? "'".$v : $v, $row), escape: '');
        }
        rewind($out);
        $csv = stream_get_contents($out);
        fclose($out);

        return response($csv, 200, [
            'Content-Type' => 'text/csv; charset=UTF-8',
            'Content-Disposition' => "attachment; filename=\"$name\"",
        ]);
    }

    // The orders placed in the range, oldest first. Defaults to the last 30 days.
    private function orders(Request $request): array
    {
        $data = $request->validate([
            'from' => 'nullable|date_format:Y-m-d',
            'to' => 'nullable|date_format:Y-m-d|after_or_equal:from',
        ]);
        $to = isset($data['to']) ? Carbon::parse($data['to'], self::TZ) : now(self::TZ);
        $from = isset($data['from']) ? Carbon::parse($data['from'], self::TZ) : $to->copy()->subDays(29);
        $from = $from->startOfDay();
        $to = $to->startOfDay();
        abort_if($from->diffInDays($to) > 366, 422, 'ជ្រើសរើសបានយ៉ាងច្រើន 1 ឆ្នាំ');

        /** @var Collection $orders */
        $orders = Order::with(['items.product', 'items.units'])
            ->where('created_at', '>=', $from->copy()->utc())
            ->where('created_at', '<', $to->copy()->addDay()->utc())
            ->oldest()->oldest('id')->get();

        return [$from, $to, $orders];
    }
}
