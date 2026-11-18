<?php

namespace Tests\Feature;

use Illuminate\Support\Facades\Artisan;
use Tests\TestCase;

class ProductionReadyTest extends TestCase
{
    public function test_media_only_answers_allowed_websites_when_limited(): void
    {
        config(['cors.allowed_origins' => ['https://ps168.example']]);
        $name = 'media_test_'.uniqid().'.png';
        file_put_contents(public_path('uploads/'.$name), 'png');
        try {
            $this->get('/media/'.$name, ['Origin' => 'https://ps168.example'])
                ->assertHeader('Access-Control-Allow-Origin', 'https://ps168.example');
            $this->get('/media/'.$name, ['Origin' => 'https://evil.example'])
                ->assertOk()->assertHeaderMissing('Access-Control-Allow-Origin');
        } finally {
            @unlink(public_path('uploads/'.$name));
        }
    }

    public function test_backup_copies_the_database_and_pictures(): void
    {
        $dir = storage_path('app/backups');
        $before = glob("$dir/*") ?: [];
        // Tests run on an in-memory database; back up a real SQLite file instead
        $file = storage_path('framework/testing-backup.sqlite');
        @unlink($file);
        touch($file);
        config(['database.connections.backup_test' => ['driver' => 'sqlite', 'database' => $file, 'prefix' => '']]);
        config(['database.default' => 'backup_test']);
        \DB::purge('backup_test');
        \DB::connection('backup_test')->statement('CREATE TABLE t (x int)');
        \DB::connection('backup_test')->insert('INSERT INTO t VALUES (7)');

        try {
            $this->assertSame(0, Artisan::call('shop:backup'));
            $new = array_values(array_diff(glob("$dir/*") ?: [], $before));
            $db = current(array_filter($new, fn ($f) => str_ends_with($f, '.sqlite')));
            $this->assertNotFalse($db);
            $copy = new \PDO('sqlite:'.$db);
            $this->assertSame(7, (int) $copy->query('SELECT x FROM t')->fetchColumn());
            $this->assertNotEmpty(array_filter($new, fn ($f) => str_ends_with($f, '.tar.gz')));
        } finally {
            foreach (array_diff(glob("$dir/*") ?: [], $before) as $f) {
                @unlink($f);
            }
            @unlink($file);
        }
    }
}
