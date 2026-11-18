<?php

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

// Takes the white / checkerboard background off every product picture already
// uploaded (new uploads are cleaned when the admin saves them). The original
// files are kept in public/uploads/originals, in case one needs putting back.
Artisan::command('products:clean-backgrounds', function () {
    $uploads = public_path('uploads');
    $originals = $uploads.'/originals';
    if (! is_dir($originals)) {
        mkdir($originals, 0755, true);
    }

    $clean = function (?string $file) use ($uploads, $originals): ?string {
        if (! $file || str_starts_with($file, 'http') || ! is_file("$uploads/$file")) {
            return $file;
        }
        $new = \App\Support\BackgroundRemover::process("$uploads/$file");
        if (! $new) {
            $this->line("  kept   $file (no plain background found)");

            return $file;
        }
        if ($new !== $file) {
            rename("$uploads/$file", "$originals/$file");
        }
        $this->info("  clean  $file -> $new");

        return $new;
    };

    foreach (\App\Models\Product::all() as $product) {
        $this->line("#{$product->id} {$product->name}");
        $image = $clean($product->getRawOriginal('image'));
        $colors = $product->color_images ?? [];
        foreach ($colors as $color => $file) {
            $colors[$color] = $clean($file);
        }
        $product->forceFill([
            'image' => $image,
            'color_images' => $colors ?: null,
        ])->save();
    }
})->purpose('Remove the white / checkerboard background from product pictures');

// Unpaid KHQR orders past their time are cancelled and their phones go back
// on sale (see Order::expireUnpaid; run the scheduler with `php artisan schedule:work`)
Artisan::command('orders:expire-unpaid', function () {
    $this->info(\App\Models\Order::expireUnpaid().' unpaid order(s) cancelled');
})->purpose('Cancel KHQR orders nobody paid for in time and restock them');

Schedule::command('orders:expire-unpaid')->everyMinute();

// Customers who paid and closed the app: their orders still turn paid
Artisan::command('orders:check-bakong', function () {
    $paid = 0;
    \App\Models\Order::where('payment_method', 'khqr')
        ->whereIn('payment_status', ['unpaid', 'verifying'])
        ->where('status', 'pending')
        ->whereNotNull('bakong_md5')
        ->where('created_at', '>', now()->subMinutes(\App\Models\Order::unpaidMinutes() + 60))
        ->each(function ($order) use (&$paid) {
            try {
                $paid += $order->checkBakong(force: true) ? 1 : 0;
            } catch (\App\Services\Bakong\BakongUnavailable $e) {
                $this->warn($e->getMessage());
            }
        });
    $this->info("$paid order(s) found paid on Bakong");
})->purpose('Mark KHQR orders paid once Bakong shows the payment');

Schedule::command('orders:check-bakong')->everyMinute()->withoutOverlapping();

// Clear logins older than their 30 days out of the database once a day
Schedule::command('sanctum:prune-expired --hours=24')->daily();
