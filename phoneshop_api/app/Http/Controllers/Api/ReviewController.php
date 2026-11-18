<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Models\Review;
use Illuminate\Http\Request;

// Reviews you can trust: only a customer who actually received this phone
// (an order of theirs containing it is delivered) can rate it, once; writing
// again edits their review.
class ReviewController extends Controller
{
    // Average, count, how many of each star, and the reviews, newest first.
    // Signed-in customers also learn whether they may review (and their own).
    public function index(Request $request, Product $product)
    {
        $reviews = $product->reviews()->with('user:id,name,avatar')->latest()->get();
        $user = $request->user('sanctum');

        $stars = [];
        for ($s = 5; $s >= 1; $s--) {
            $stars[(string) $s] = $reviews->where('rating', $s)->count();
        }

        return response()->json([
            'average' => $reviews->isEmpty() ? 0 : round($reviews->avg('rating'), 1),
            'count' => $reviews->count(),
            'stars' => $stars,
            'reviews' => $reviews->map->toPublic()->values(),
            'can_review' => $user ? self::hasReceived($user->id, $product->id) : false,
            'mine' => $user ? $reviews->firstWhere('user_id', $user->id)?->toPublic() : null,
        ]);
    }

    public function store(Request $request, Product $product)
    {
        $user = $request->user();
        if ($user->blocked_at) {
            return response()->json(['message' => 'Account blocked'], 403);
        }
        if (! self::hasReceived($user->id, $product->id)) {
            return response()->json([
                'message' => 'មានតែអតិថិជនដែលបានទទួលទូរស័ព្ទនេះទើបអាចវាយតម្លៃបាន',
            ], 403);
        }
        $data = $request->validate([
            'rating' => ['required', 'integer', 'between:1,5'],
            'comment' => ['nullable', 'string', 'max:1000'],
        ]);

        $review = Review::updateOrCreate(
            ['product_id' => $product->id, 'user_id' => $user->id],
            ['rating' => $data['rating'], 'comment' => trim($data['comment'] ?? '') ?: null],
        );

        return response()->json($review->load('user:id,name,avatar')->toPublic(), 201);
    }

    // The customer has a delivered order with this phone in it
    public static function hasReceived(int $userId, int $productId): bool
    {
        return \App\Models\Order::where('user_id', $userId)
            ->where('status', 'delivered')
            ->whereHas('items', fn ($q) => $q->where('product_id', $productId))
            ->exists();
    }
}
