<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

// The order's own KHQR (with its amount) and the md5 Bakong finds it by
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->text('bakong_qr')->nullable();
            $table->string('bakong_md5', 32)->nullable()->index();
            $table->timestamp('bakong_checked_at')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->dropIndex(['bakong_md5']);
            $table->dropColumn(['bakong_qr', 'bakong_md5', 'bakong_checked_at']);
        });
    }
};
