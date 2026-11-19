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
        // Hidden ones are not shown and don't count (the writer still sees theirs)
        $all = $product->reviews()->with('user:id,name,avatar')->latest()->get();
        $reviews = $all->whereNull('hidden_at')->values();
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
            'mine' => $user ? $all->firstWhere('user_id', $user->id)?->toPublic() : null,
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

    // ---------- Admin ----------

    // Newest reviews of every phone, hidden ones too, to keep an eye on them
    public function adminIndex()
    {
        return Review::with(['user:id,name', 'product:id,name'])->latest()->latest('id')->limit(200)->get()
            ->map(fn (Review $r) => [
                'id' => $r->id,
                'product' => $r->product?->name ?? '',
                'product_id' => $r->product_id,
                'name' => $r->user?->name ?? '',
                'rating' => $r->rating,
                'comment' => $r->comment ?? '',
                'hidden' => $r->hidden_at !== null,
                'created_at' => $r->created_at,
            ]);
    }

    // Hide a rude or fake review, or show it again
    public function setHidden(Request $request, Review $review)
    {
        $data = $request->validate(['hidden' => 'required|boolean']);
        $review->update(['hidden_at' => $data['hidden'] ? now() : null]);

        return ['id' => $review->id, 'hidden' => $review->hidden_at !== null];
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
