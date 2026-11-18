<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Mail\PasswordCodeMail;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;

// Forgot password: a 6-digit code is e-mailed, then code + new password resets it.
// The answer to "send me a code" is the same whether or not the e-mail has an
// account, so nobody can use it to find out who shops here.
class PasswordResetController extends Controller
{
    private const MINUTES = 15;

    private const MAX_ATTEMPTS = 5;

    public function send(Request $request)
    {
        $data = $request->validate(['email' => 'required|email|max:150'], [
            'email.required' => 'សូមបញ្ចូល Email',
            'email.email' => 'Email មិនត្រឹមត្រូវ',
        ]);

        $user = User::where('email', $data['email'])->first();
        // Customers and staff only; the admin's password is changed by hand on the server
        if ($user && ! $user->blocked_at && $user->role !== 'admin') {
            $code = (string) random_int(100000, 999999);
            DB::table('password_codes')->where('user_id', $user->id)->delete();
            DB::table('password_codes')->insert([
                'user_id' => $user->id,
                'code_hash' => Hash::make($code),
                'expires_at' => now()->addMinutes(self::MINUTES),
                'created_at' => now(),
                'updated_at' => now(),
            ]);
            try {
                Mail::to($user->email)->send(new PasswordCodeMail($user->name, $code, self::MINUTES));
            } catch (\Throwable $e) {
                Log::error('Password code e-mail failed: '.$e->getMessage());
            }
        }

        return ['message' => 'បើ Email នេះមានគណនី យើងបានផ្ញើលេខកូដ 6 ខ្ទង់ទៅហើយ', 'minutes' => self::MINUTES];
    }

    public function reset(Request $request)
    {
        $data = $request->validate([
            'email' => 'required|email',
            'code' => 'required|digits:6',
            'password' => 'required|string|min:6|confirmed',
        ], [
            'code.digits' => 'លេខកូដមាន 6 ខ្ទង់',
            'password.min' => 'ពាក្យសម្ងាត់យ៉ាងតិច 6 តួ',
            'password.confirmed' => 'ពាក្យសម្ងាត់ទាំងពីរមិនដូចគ្នា',
        ]);

        $wrong = response()->json(['message' => 'លេខកូដមិនត្រឹមត្រូវ ឬផុតកំណត់ហើយ'], 422);

        $user = User::where('email', $data['email'])->first();
        $row = $user ? DB::table('password_codes')->where('user_id', $user->id)->first() : null;
        if (! $row || now()->greaterThan($row->expires_at) || $row->attempts >= self::MAX_ATTEMPTS) {
            return $wrong;
        }
        if (! Hash::check($data['code'], $row->code_hash)) {
            DB::table('password_codes')->where('id', $row->id)->increment('attempts');

            return $wrong;
        }

        $user->password = $data['password']; // hashed by the model's cast
        $user->save();
        $user->tokens()->delete(); // logged out everywhere the old password was used
        DB::table('password_codes')->where('user_id', $user->id)->delete();

        return ['message' => 'បានកំណត់ពាក្យសម្ងាត់ថ្មី សូម Login'];
    }
}
