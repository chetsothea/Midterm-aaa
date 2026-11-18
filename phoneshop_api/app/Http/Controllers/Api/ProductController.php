<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Category;
use App\Models\Order;
use App\Models\PaymentAccount;
use App\Services\Bakong\Bakong;
use App\Models\OrderItem;
use App\Models\Product;
use Illuminate\Support\Facades\DB;
use Illuminate\Http\Request;

class ProductController extends Controller
{
    public function index(Request $request)
    {
        Order::expireUnpaid(); // free stock held by orders nobody paid for
        // Each phone carries its star average and number of reviews
        $query = Product::query()->withRating()->latest();

        if ($search = $request->query('search')) {
            $query->where(function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                    ->orWhere('brand', 'like', "%{$search}%");
            });
        }

        if ($brand = $request->query('brand')) {
            $query->where('brand', $brand);
        }

        if ($categoryId = $request->query('category_id')) {
            $query->where('category_id', $categoryId);
        }

        return $query->get();
    }

    // The phones customers buy most (units in orders that weren't cancelled),
    // for the store's top carousel. Each has a "sold" count. Topped up with
    // the priciest phones in stock (sold = 0) while there are few sales, so
    // the carousel is never empty. Only phones in stock.
    public function bestSellers()
    {
        $limit = 6;
        $sold = OrderItem::query()
            ->join('orders', 'orders.id', '=', 'order_items.order_id')
            ->where('orders.status', '!=', 'cancelled')
            ->whereNotNull('order_items.product_id')
            ->groupBy('order_items.product_id')
            ->orderByDesc('units')
            ->pluck(DB::raw('SUM(order_items.qty) AS units'), 'order_items.product_id');

        $top = Product::withRating()->whereIn('id', $sold->keys())->where('stock', '>', 0)->get()
            ->sortByDesc(fn ($p) => [$sold[$p->id], $p->price])
            ->take($limit)
            ->each(fn ($p) => $p->setAttribute('sold', (int) $sold[$p->id]))
            ->values();

        if ($top->count() < $limit) {
            $more = Product::withRating()->where('stock', '>', 0)
                ->whereNotIn('id', $top->pluck('id'))
                ->orderByDesc('price')
                ->limit($limit - $top->count())
                ->get()
                ->each(fn ($p) => $p->setAttribute('sold', 0));
            $top = $top->concat($more)->values();
        }

        return $top;
    }

    public function show(Product $product)
    {
        return Product::withRating()->find($product->id);
    }

    public function categories()
    {
        return Category::orderBy('name')->get();
    }

    // Store navigation: every brand, plus each category with the brands it contains
    public function menu()
    {
        $brandsOf = fn ($query) => $query->whereNotNull('brand')->where('brand', '!=', '')
            ->distinct()->orderBy('brand')->pluck('brand');

        return [
            'telegram' => ltrim((string) config('shop.telegram'), '@'),
            'brands' => $brandsOf(Product::query()),
            // Smartphone and 2nd Hand first, any other category after them
            'categories' => Category::orderBy('id')->get()
                ->sortBy(fn ($category) => ['Smartphone' => 0, '2nd Hand' => 1][$category->name] ?? 2)
                ->values()
                ->map(fn ($category) => [
                'id' => $category->id,
                'name' => $category->name,
                'brands' => $brandsOf($category->products()),
            ]),
        ];
    }

    // The banks a customer can pay into. The first one is also given at the
    // top level, as older app versions read only bank_name, account_number...
    public function paymentInfo()
    {
        $accounts = PaymentAccount::forCustomers();

        return [
            ...$accounts[0],
            'accounts' => $accounts,
            'bakong' => Bakong::enabled(),
            'shipping' => \App\Support\Shipping::rates(),
        ];
    }
}
