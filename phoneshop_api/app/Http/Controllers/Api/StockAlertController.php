<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Models\StockAlert;
use Illuminate\Http\Request;

// "Tell me when it's back": the customer's list, and turning one on or off
class StockAlertController extends Controller
{
    public function index(Request $request)
    {
        return StockAlert::where('user_id', $request->user()->id)->get(['product_id', 'variant']);
    }

    public function store(Request $request, Product $product)
    {
        $variant = $this->variant($request, $product);
        StockAlert::firstOrCreate(['user_id' => $request->user()->id, 'product_id' => $product->id, 'variant' => $variant]);

        return response()->json(['product_id' => $product->id, 'variant' => $variant], 201);
    }

    public function destroy(Request $request, Product $product)
    {
        StockAlert::where('user_id', $request->user()->id)->where('product_id', $product->id)
            ->where('variant', $this->variant($request, $product))->delete();

        return response()->json(['message' => 'Removed']);
    }

    // The colour/size asked about, only for phones counted per colour/size
    private function variant(Request $request, Product $product): string
    {
        $data = $request->validate(['color' => 'nullable|string|max:30', 'storage' => 'nullable|string|max:20']);
        if (! $product->hasVariantStock()) {
            return '';
        }
        $key = Product::variantKey($data['color'] ?? '', $data['storage'] ?? '');
        abort_unless(in_array($key, $product->variantKeys(), true), 422, 'ពណ៌ ឬ Storage មិនត្រឹមត្រូវ');

        return $key;
    }
}
