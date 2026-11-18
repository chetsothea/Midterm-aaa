<?php

namespace App\Console\Commands;

use App\Services\Bakong\Bakong;
use App\Models\User;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Hash;

// Before (and after) going live: lists every setting that is unsafe or
// unfinished for a real shop, with what to change in .env
class CheckProduction extends Command
{
    protected $signature = 'shop:check-production';

    protected $description = 'Check the settings are safe for the live shop';

    public function handle(): int
    {
        $problems = [];
        $warnings = [];

        if (config('app.debug')) {
            $problems[] = 'APP_DEBUG=true: errors show the code and secrets to anyone. Set APP_DEBUG=false';
        }
        if (! app()->isProduction()) {
            $problems[] = 'APP_ENV is "'.app()->environment().'". Set APP_ENV=production';
        }
        if (! config('app.key')) {
            $problems[] = 'APP_KEY is empty. Run: php artisan key:generate';
        }
        if (! str_starts_with((string) config('app.url'), 'https://')) {
            $problems[] = 'APP_URL is not https. Set APP_URL=https://your-domain';
        }
        if (in_array(config('mail.default'), ['log', 'array'], true)) {
            $problems[] = 'MAIL_MAILER='.config('mail.default').': password codes are not really e-mailed. Set up SMTP';
        }
        if (in_array('*', (array) config('cors.allowed_origins'), true)) {
            $warnings[] = 'CORS allows every website. Set CORS_ALLOWED_ORIGINS=https://your-web-shop (phone apps are not affected)';
        }
        if (config('database.default') === 'sqlite') {
            $warnings[] = 'The database is SQLite: fine for a small shop on one server, MySQL is safer with many orders';
        }
        // The stack channel has no level of its own: look at the channels it writes to
        $default = config('logging.default');
        $channels = config("logging.channels.$default.driver") === 'stack'
            ? (array) config("logging.channels.$default.channels")
            : [$default];
        $debugLogs = collect($channels)->contains(fn ($c) => config("logging.channels.$c.level", 'debug') === 'debug');
        if ($debugLogs) {
            $warnings[] = 'LOG_LEVEL=debug fills the disk. Set LOG_LEVEL=warning';
        }
        if (! Bakong::enabled()) {
            $warnings[] = 'Bakong is off: KHQR payments are checked by hand. Set BAKONG_TOKEN and BAKONG_ACCOUNT_ID';
        }
        // The seeded admin password must not survive into the live shop
        $defaultAdmin = User::where('role', 'admin')->get()
            ->contains(fn (User $u) => Hash::check('admin123', $u->password));
        if ($defaultAdmin) {
            $problems[] = 'An admin still has the password "admin123". Change it now';
        }
        if (! is_writable(storage_path()) || ! is_writable(public_path('uploads'))) {
            $problems[] = 'storage/ or public/uploads is not writable by the web server';
        }

        foreach ($problems as $p) {
            $this->line("  <fg=red>✗</> $p");
        }
        foreach ($warnings as $w) {
            $this->line("  <fg=yellow>!</> $w");
        }
        if (! $problems && ! $warnings) {
            $this->info('  ✓ Everything looks ready');
        }
        $this->newLine();
        $this->line('Remember: the scheduler must run every minute (cron: php artisan schedule:run).');

        return $problems ? self::FAILURE : self::SUCCESS;
    }
}
