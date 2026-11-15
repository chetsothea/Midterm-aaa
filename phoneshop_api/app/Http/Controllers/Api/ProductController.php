<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Category;
use App\Models\Product;
use Illuminate\Http\Request;

class ProductController extends Controller
{
    public function index(Request $request)
    {
        $query = Product::query()->latest();

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

    public function show(Product $product)
    {
        return $product;
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

    public function paymentInfo()
    {
        $info = config('shop.payment');
        $qr = $info['qr_image_url'] ?? '';

        // A plain file name means public/uploads/<name>; build the URL from the
        // request host so it works on the emulator (10.0.2.2) and in Chrome alike
        if ($qr !== '' && ! str_starts_with($qr, 'http')) {
            $info['qr_image_url'] = url('uploads/'.$qr);
        }

        return $info;
    }
}
