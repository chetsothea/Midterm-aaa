<?php

namespace App\Models;

// use Illuminate\Contracts\Auth\MustVerifyEmail;
use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasApiTokens, HasFactory, Notifiable;

    /**
     * The attributes that are mass assignable.
     *
     * @var list<string>
     */
    protected $fillable = [
        'name',
        'email',
        'password',
        'phone',
        'address',
        'telegram',
        'role',
        'avatar',
    ];

    /**
     * The attributes that should be hidden for serialization.
     *
     * @var list<string>
     */
    protected $hidden = [
        'password',
        'remember_token',
        'google_id',
        'avatar',
        'favorite_ids',
        'saved_cart',
    ];

    protected $appends = ['avatar_url', 'google_account'];

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
            'favorite_ids' => 'array',
            'saved_cart' => 'array',
        ];
    }

    // Full URL of the profile picture, '' when there is none
    public function getAvatarUrlAttribute(): string
    {
        return \App\Support\Uploads::url($this->avatar);
    }

    // Signs in with Google (has no password of their own to type)
    public function getGoogleAccountAttribute(): bool
    {
        return $this->google_id !== null;
    }

    // Removes the account for good: the login, saved lists, reviews, comments,
    // trade-ins (with their photos) and notices. Orders stay for the shop's
    // records and warranties, with the name and e-mail written on them, but no
    // longer belong to any account.
    public function closeAccount(): void
    {
        $files = [$this->avatar];
        foreach (TradeIn::where('user_id', $this->id)->get() as $tradeIn) {
            array_push($files, ...($tradeIn->photos ?? []));
        }

        \Illuminate\Support\Facades\DB::transaction(function () {
            foreach ($this->orders as $order) {
                $order->update([
                    'user_id' => null,
                    'customer_name' => $order->customer_name ?: $this->name,
                    'customer_email' => $order->customer_email ?: $this->email,
                ]);
            }
            $this->tokens()->delete();
            $this->delete(); // the rest goes with it (foreign keys)
        });

        foreach (array_filter($files) as $file) {
            if (! str_starts_with($file, 'http') && is_file(public_path('uploads/'.$file))) {
                unlink(public_path('uploads/'.$file));
            }
        }
    }

    public function orders()
    {
        return $this->hasMany(Order::class);
    }
}
