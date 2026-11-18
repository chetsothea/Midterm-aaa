<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

// The admin and their staff: handling orders, delivery, IMEIs and the live chat.
// Money, prices, settings and accounts stay behind AdminOnly.
class ShopTeam
{
    public function handle(Request $request, Closure $next): Response
    {
        if (! in_array($request->user()?->role, ['admin', 'staff'], true)) {
            return response()->json(['message' => 'Admin only'], 403);
        }

        return $next($request);
    }
}
