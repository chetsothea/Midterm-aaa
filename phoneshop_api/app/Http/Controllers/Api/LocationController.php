<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;

// Cambodia's provinces → districts → communes → villages for the checkout address pickers.
// Data: database/data/cambodia_locations.json (see cambodia_locations.SOURCE.md).
class LocationController extends Controller
{
    // GET /api/locations             → the 25 provinces
    // GET /api/locations?parent=12   → districts of Phnom Penh
    // GET /api/locations?parent=1201 → communes of Chamkar Mon, and so on down to villages
    public function index(Request $request)
    {
        $parent = (string) $request->query('parent', '');

        return response()
            ->json(self::children()[$parent] ?? [])
            // Place names rarely change; let the app reuse the answer for a day
            ->header('Cache-Control', 'public, max-age=86400');
    }

    private static function children(): array
    {
        static $children = null;

        return $children ??= json_decode(
            file_get_contents(database_path('data/cambodia_locations.json')),
            true
        )['children'];
    }
}
