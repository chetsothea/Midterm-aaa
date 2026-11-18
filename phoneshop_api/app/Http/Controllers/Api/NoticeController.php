<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Notice;
use Illuminate\Http\Request;

// The customer's 🔔: newest 50 messages and how many are unread
class NoticeController extends Controller
{
    public function index(Request $request)
    {
        $mine = Notice::where('user_id', $request->user()->id);

        return [
            'unread' => (clone $mine)->whereNull('read_at')->count(),
            'notices' => $mine->latest()->latest('id')->limit(50)->get(),
        ];
    }

    public function readAll(Request $request)
    {
        Notice::where('user_id', $request->user()->id)->whereNull('read_at')->update(['read_at' => now()]);

        return ['unread' => 0];
    }
}
