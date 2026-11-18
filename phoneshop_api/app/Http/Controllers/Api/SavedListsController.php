<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Product;
use Illuminate\Http\Request;

// The logged-in customer's ♥ phones and cart, saved on their account
class SavedListsController extends Controller
{
    public function show(Request $request)
    {
        return $this->present($request->user());
    }

    // The app sends both lists whole each time they change
    public function update(Request $request)
    {
        $data = $request->validate([
            'favorites' => 'present|array|max:500',
            'favorites.*' => 'integer',
            'cart' => 'present|array|max:50',
            'cart.*.id' => 'required|integer',
            'cart.*.qty' => 'required|integer|min:1|max:99',
            'cart.*.color' => 'nullable|string|max:30',
            'cart.*.storage' => 'nullable|string|max:20',
        ]);

        // Only phones that still exist
        $ids = array_merge($data['favorites'], array_column($data['cart'], 'id'));
        $exists = array_flip(Product::whereIn('id', $ids)->pluck('id')->all());

        $favorites = array_values(array_unique(array_filter(
            $data['favorites'], fn ($id) => isset($exists[$id])
        )));
        $cart = [];
        foreach ($data['cart'] as $line) {
            if (isset($exists[$line['id']])) {
                $cart[] = [
                    'id' => $line['id'],
                    'color' => (string) ($line['color'] ?? ''),
                    'storage' => (string) ($line['storage'] ?? ''),
                    'qty' => $line['qty'],
                ];
            }
        }

        $user = $request->user();
        $user->forceFill(['favorite_ids' => $favorites, 'saved_cart' => $cart])->save();

        return $this->present($user);
    }

    private function present($user): array
    {
        return [
            'favorites' => $user->favorite_ids ?? [],
            'cart' => $user->saved_cart ?? [],
        ];
    }
}
