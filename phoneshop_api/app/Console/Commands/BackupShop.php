<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Symfony\Component\Process\Process;

// A copy of the shop's database (orders, customers, phones) and the uploaded
// pictures, kept in storage/app/backups for the last N days. Runs every night;
// copy that folder off the server too (Google Drive, another machine).
class BackupShop extends Command
{
    protected $signature = 'shop:backup {--keep=14 : how many days of backups to keep}';

    protected $description = 'Back up the database and uploaded pictures';

    public function handle(): int
    {
        $dir = storage_path('app/backups');
        if (! is_dir($dir)) {
            mkdir($dir, 0750, true);
        }
        $stamp = now('Asia/Phnom_Penh')->format('Y-m-d_His'); // Cambodia time in the name
        $connection = config('database.default');
        $db = config("database.connections.$connection");

        if ($db['driver'] === 'sqlite') {
            $target = "$dir/database_$stamp.sqlite";
            // VACUUM INTO makes a clean, consistent copy even while the shop is open
            \DB::statement('VACUUM INTO ?', [$target]);
        } elseif (in_array($db['driver'], ['mysql', 'mariadb'], true)) {
            $target = "$dir/database_$stamp.sql";
            $dump = new Process([
                'mysqldump', '--single-transaction', '--routines', '--no-tablespaces',
                '-h', $db['host'], '-P', (string) $db['port'], '-u', $db['username'], $db['database'],
                '--result-file='.$target,
            ], null, ['MYSQL_PWD' => (string) $db['password']]);
            $dump->setTimeout(600)->run();
            if (! $dump->isSuccessful()) {
                $this->error('mysqldump failed: '.trim($dump->getErrorOutput()));

                return self::FAILURE;
            }
        } else {
            $this->error("Backups are not set up for the {$db['driver']} database");

            return self::FAILURE;
        }

        // The uploaded pictures (phones, bank QRs, avatars, trade-in photos)
        $pictures = "$dir/uploads_$stamp.tar.gz";
        $tar = new Process(['tar', '-czf', $pictures, '-C', public_path(), 'uploads']);
        $tar->setTimeout(600)->run();
        if (! $tar->isSuccessful()) {
            $this->warn('Pictures not backed up: '.trim($tar->getErrorOutput()));
        }

        // Keep the newest --keep days
        $cutoff = now()->subDays((int) $this->option('keep'))->getTimestamp();
        foreach (glob("$dir/{database,uploads}_*", GLOB_BRACE) as $old) {
            if (filemtime($old) < $cutoff) {
                unlink($old);
            }
        }

        $this->info('Backup saved: '.basename($target).(is_file($pictures) ? ' + '.basename($pictures) : ''));

        return self::SUCCESS;
    }
}
