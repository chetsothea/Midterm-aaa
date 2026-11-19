<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

class AuthController extends Controller
{
    // The app asks which Google client to sign in with; empty = Google login is switched off
    public function googleConfig()
    {
        return ['client_id' => (string) config('services.google.client_id')];
    }

    // "Login with Google": the app sends the Google ID token, we check it with Google,
    // then log in the matching account (creating it on first use).
    public function google(Request $request)
    {
        $data = $request->validate(['id_token' => 'required|string']);
        $clientId = (string) config('services.google.client_id');
        if ($clientId === '') {
            return response()->json(['message' => 'Login with Google មិនទាន់បានកំណត់នៅឡើយ'], 503);
        }

        $check = Http::timeout(10)->get('https://oauth2.googleapis.com/tokeninfo', ['id_token' => $data['id_token']]);
        $claims = $check->json() ?? [];

        // Must be a valid token, made for *our* app, by Google, for a verified e-mail
        $valid = $check->ok()
            && ($claims['aud'] ?? null) === $clientId
            && in_array($claims['iss'] ?? null, ['accounts.google.com', 'https://accounts.google.com'], true)
            && (int) ($claims['exp'] ?? 0) > time()
            && ($claims['email_verified'] ?? null) === 'true'
            && ! empty($claims['sub'])
            && ! empty($claims['email']);
        if (! $valid) {
            return response()->json(['message' => 'គណនី Google មិនត្រឹមត្រូវ សូមព្យាយាមម្តងទៀត'], 401);
        }

        // Same Google account as before, or an existing account with this (Google-verified) e-mail
        $user = User::where('google_id', $claims['sub'])->first()
            ?? User::where('email', $claims['email'])->first();

        if ($user) {
            if ($user->blocked_at) {
                return $this->blockedResponse();
            }
            if (! $user->google_id) {
                $user->forceFill(['google_id' => $claims['sub']])->save();
            }
        } else {
            $user = new User([
                'name' => $claims['name'] ?? Str::before($claims['email'], '@'),
                'email' => $claims['email'],
                // Never used: this account signs in with Google
                'password' => Str::random(40),
                'role' => 'user',
            ]);
            $user->forceFill(['google_id' => $claims['sub'], 'email_verified_at' => now()])->save();
        }

        return response()->json([
            'token' => $user->createToken('mobile')->plainTextToken,
            'user' => $user,
        ]);
    }

    private function blockedResponse()
    {
        return response()->json(['message' => 'គណនីនេះត្រូវបានបិទ សូមទាក់ទង Admin'], 403);
    }

    public function register(Request $request)
    {
        $data = $request->validate([
            // People log in with this, so it can't be anyone else's, whatever the capitals
            'name' => [
                'required', 'string', 'max:100',
                function (string $attribute, mixed $value, \Closure $fail) {
                    if (User::whereRaw('LOWER(name) = ?', [mb_strtolower($value)])->exists()) {
                        $fail('Username នេះមានគេប្រើរួចហើយ');
                    }
                },
            ],
            'email' => 'required|email|unique:users,email',
            'phone' => 'required|string|max:20',
            'address' => 'required|string|max:500',
            'password' => 'required|string|min:6',
        ]);

        // role is never taken from the request: everyone who registers is a customer
        $user = User::create($data + ['role' => 'user']);

        return response()->json([
            'token' => $user->createToken('mobile')->plainTextToken,
            'user' => $user,
        ], 201);
    }

    public function login(Request $request)
    {
        // The "email" field takes an e-mail or a username. The admin's login is plain "admin".
        $data = $request->validate([
            'email' => 'required|string',
            'password' => 'required|string',
        ]);

        // Exactly as written at registration, capitals included. Older accounts can share
        // a username, so check the password against each of them.
        $login = $data['email'];
        $matches = User::where('email', $login)
            ->orWhere('name', $login)
            ->get() // the database ignores capitals, so compare them here
            ->filter(fn (User $candidate) => ($candidate->email === $login || $candidate->name === $login)
                && Hash::check($data['password'], $candidate->password));

        if ($matches->isEmpty()) {
            return response()->json(['message' => 'Email/Username ឬ Password មិនត្រឹមត្រូវ'], 401);
        }

        // An exact e-mail always wins. Otherwise never guess between accounts.
        $user = $matches->first(fn (User $match) => $match->email === $login)
            ?? ($matches->count() === 1 ? $matches->first() : null);

        if (! $user) {
            return response()->json(['message' => 'មានគណនីច្រើនប្រើឈ្មោះនេះ សូម Login ដោយប្រើ Email'], 422);
        }

        // Only after the password check, so this can't reveal which e-mails have accounts
        if ($user->blocked_at) {
            return $this->blockedResponse();
        }

        return response()->json([
            'token' => $user->createToken('mobile')->plainTextToken,
            'user' => $user,
        ]);
    }

    public function me(Request $request)
    {
        return $request->user();
    }

    // The customer closes their own account (App Store and Play Store require
    // this). Asks for the password, or for Google accounts the word DELETE.
    public function deleteAccount(Request $request)
    {
        $user = $request->user();
        if ($user->role !== 'user') {
            return response()->json(['message' => 'គណនី Admin/Staff មិនអាចលុបពីទីនេះបានទេ'], 422);
        }

        $data = $request->validate([
            'password' => 'nullable|string',
            'confirm' => 'nullable|string',
        ]);
        $confirmed = $user->google_id
            ? strtoupper(trim((string) ($data['confirm'] ?? ''))) === 'DELETE'
            : Hash::check((string) ($data['password'] ?? ''), $user->password);
        if (! $confirmed) {
            return response()->json(['message' => $user->google_id
                ? 'សូមវាយពាក្យ DELETE ដើម្បីបញ្ជាក់'
                : 'ពាក្យសម្ងាត់មិនត្រឹមត្រូវ'], 422);
        }

        // Not while an order is on its way: the shop still needs to reach them
        $busy = $user->orders()->whereIn('status', ['pending', 'confirmed', 'shipping'])->count();
        if ($busy) {
            return response()->json([
                'message' => "អ្នកមាន Order {$busy} កំពុងដំណើរការ។ សូមរង់ចាំឱ្យដល់ ឬបោះបង់វាសិន ទើបលុបគណនីបាន",
            ], 422);
        }

        $user->closeAccount();

        return response()->json(['message' => 'គណនីរបស់អ្នកត្រូវបានលុបហើយ']);
    }

    // The customer's own details, password and picture. The role can't be changed here.
    // No old password is asked for: this is also how a logged-in customer who forgot it sets a new one.
    public function updateProfile(Request $request)
    {
        $user = $request->user();
        $data = $request->validate([
            'name' => [
                'required', 'string', 'max:100',
                // Older accounts can share a name, so only a new name is checked
                function (string $attribute, mixed $value, \Closure $fail) use ($user) {
                    $lower = mb_strtolower($value);
                    if ($lower !== mb_strtolower($user->name)
                        && User::whereRaw('LOWER(name) = ?', [$lower])->exists()) {
                        $fail('Username នេះមានគេប្រើរួចហើយ');
                    }
                },
            ],
            'email' => ['required', 'email', Rule::unique('users', 'email')->ignore($user->id)],
            'phone' => 'required|string|max:20',
            'address' => 'required|string|max:500',
            'password' => 'nullable|string|min:6',
            'avatar' => 'nullable|image|mimes:jpg,jpeg,png,webp|max:4096',
        ]);
        unset($data['avatar']);
        if (empty($data['password'])) {
            unset($data['password']);
        }

        if ($request->hasFile('avatar')) {
            $file = $request->file('avatar');
            $name = Str::random(20).'.'.$file->extension();
            $file->move(public_path('uploads'), $name);
            if ($user->avatar && file_exists(public_path('uploads/'.$user->avatar))) {
                unlink(public_path('uploads/'.$user->avatar));
            }
            $data['avatar'] = $name;
        }

        $user->update($data);

        // A new password logs out every other phone, in case someone else was using the account
        if (isset($data['password'])) {
            $user->tokens()->where('id', '!=', $user->currentAccessToken()->id ?? 0)->delete();
        }

        return $user;
    }

    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json(['message' => 'Logged out']);
    }
}
