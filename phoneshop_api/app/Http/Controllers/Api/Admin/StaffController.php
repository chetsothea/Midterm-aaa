<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;

// The admin's staff accounts: they log in like the admin but only handle orders
class StaffController extends Controller
{
    public function index()
    {
        return User::where('role', 'staff')->latest()->get(['id', 'name', 'email', 'phone', 'created_at'])
            ->makeHidden(['avatar_url', 'google_account']);
    }

    // The activity log, newest first; ?user_id= for one person
    public function activity(Request $request)
    {
        return \App\Models\ActivityLog::query()
            ->when($request->query('user_id'), fn ($q, $id) => $q->where('user_id', $id))
            ->latest('created_at')->latest('id')->limit(300)->get();
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'name' => 'required|string|max:100',
            'email' => 'required|email|max:150|unique:users,email',
            'phone' => 'nullable|string|max:20',
            'password' => 'required|string|min:8',
        ], [
            'name.required' => 'សូមបញ្ចូលឈ្មោះ',
            'email.unique' => 'Email នេះមានគណនីរួចហើយ',
            'password.min' => 'ពាក្យសម្ងាត់យ៉ាងតិច 8 តួ',
        ]);

        $staff = User::create($data + ['role' => 'staff']);

        return response()->json($staff->only(['id', 'name', 'email', 'phone', 'created_at']), 201);
    }

    // New password for a staff member (they are logged out everywhere)
    public function update(Request $request, User $user)
    {
        abort_unless($user->role === 'staff', 422, 'មិនមែនជាគណនីបុគ្គលិកទេ');
        $data = $request->validate([
            'name' => 'required|string|max:100',
            'phone' => 'nullable|string|max:20',
            'password' => 'nullable|string|min:8',
        ]);
        $password = $data['password'] ?? null;
        unset($data['password']);
        $user->fill($data);
        if ($password) {
            $user->password = $password;
        }
        $user->save();
        if ($password) {
            $user->tokens()->delete();
        }

        return $user->only(['id', 'name', 'email', 'phone', 'created_at']);
    }

    public function destroy(User $user)
    {
        abort_unless($user->role === 'staff', 422, 'មិនមែនជាគណនីបុគ្គលិកទេ');
        $user->tokens()->delete();
        $user->delete();

        return response()->json(['message' => 'Deleted']);
    }
}
