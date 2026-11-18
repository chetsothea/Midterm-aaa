<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\LiveComment;
use App\Models\Product;
use App\Models\Setting;
use Illuminate\Http\Request;

// Live shopping: the seller streams on YouTube Live; the app shows that stream
// with the comments viewers type here and the phones the admin pinned.
//
// Settings used: live_youtube (the video id, '' = not live), live_title and
// live_products (pinned product ids, comma separated, in order).
class LiveController extends Controller
{
    // The live session: is it on, which YouTube video, and the pinned phones
    public function show()
    {
        $youtube = Setting::text('live_youtube');
        $ids = array_values(array_filter(array_map('intval', explode(',', Setting::text('live_products')))));
        // Keep the admin's order; phones deleted since are simply left out
        $products = Product::whereIn('id', $ids)->get()
            ->sortBy(fn ($p) => array_search($p->id, $ids))
            ->values();

        return response()->json([
            'is_live' => $youtube !== '',
            'youtube_id' => $youtube,
            'title' => Setting::text('live_title'),
            'products' => $products,
        ]);
    }

    // Comments, oldest first. ?after=<id> returns only newer ones, so the app
    // can ask every few seconds for what is new.
    public function comments(Request $request)
    {
        $after = (int) $request->query('after', 0);
        $query = LiveComment::with('user:id,name,avatar')->orderBy('id');
        if ($after > 0) {
            $query->where('id', '>', $after)->limit(100);
        } else {
            // First load: the latest 50, still oldest first
            $query = LiveComment::with('user:id,name,avatar')
                ->whereIn('id', LiveComment::orderByDesc('id')->limit(50)->pluck('id'))
                ->orderBy('id');
        }

        return $query->get()->map->toPublic()->values();
    }

    public function postComment(Request $request)
    {
        $user = $request->user();
        if ($user->blocked_at) {
            return response()->json(['message' => 'Account blocked'], 403);
        }
        if (Setting::text('live_youtube') === '') {
            return response()->json(['message' => 'The live has ended'], 422);
        }
        $data = $request->validate(['message' => ['required', 'string', 'max:300']]);
        $comment = LiveComment::create([
            'user_id' => $user->id,
            'message' => trim($data['message']),
        ]);

        return response()->json($comment->load('user:id,name,avatar')->toPublic(), 201);
    }

    // Admin: start or update the live (a YouTube link or id, a title, pinned
    // phones), or end it with an empty youtube. Starting a new video clears
    // the previous live's comments.
    public function update(Request $request)
    {
        $data = $request->validate([
            'youtube' => ['nullable', 'string', 'max:255'],
            'title' => ['nullable', 'string', 'max:255'],
            'product_ids' => ['nullable', 'array', 'max:20'],
            'product_ids.*' => ['integer', 'exists:products,id'],
        ]);

        $youtube = trim($data['youtube'] ?? '');
        $id = $youtube === '' ? '' : self::youtubeId($youtube);
        if ($youtube !== '' && $id === null) {
            return response()->json(['message' => 'Not a YouTube link'], 422);
        }
        if ($id !== Setting::text('live_youtube')) {
            LiveComment::query()->delete();
        }

        Setting::setText('live_youtube', $id);
        Setting::setText('live_title', trim($data['title'] ?? ''));
        Setting::setText('live_products', implode(',', $data['product_ids'] ?? []));

        return $this->show();
    }

    // Admin: remove a comment that shouldn't be there
    public function deleteComment(LiveComment $comment)
    {
        $comment->delete();

        return response()->noContent();
    }

    // The 11-character video id from any usual YouTube link, or the id itself
    public static function youtubeId(string $text): ?string
    {
        $text = trim($text);
        if (preg_match('/^[A-Za-z0-9_-]{11}$/', $text)) {
            return $text;
        }
        $patterns = [
            '#youtu\.be/([A-Za-z0-9_-]{11})#',
            '#[?&]v=([A-Za-z0-9_-]{11})#',
            '#youtube\.com/(?:live|embed|shorts)/([A-Za-z0-9_-]{11})#',
        ];
        foreach ($patterns as $pattern) {
            if (preg_match($pattern, $text, $m)) {
                return $m[1];
            }
        }

        return null;
    }
}
