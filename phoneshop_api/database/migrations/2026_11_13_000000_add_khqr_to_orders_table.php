<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    // The QR made for this order, and the MD5 that Bakong knows its payment by
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->text('khqr_string')->nullable();
            $table->string('khqr_md5', 32)->nullable();
            $table->timestamp('khqr_expires_at')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->dropColumn(['khqr_string', 'khqr_md5', 'khqr_expires_at']);
        });
    }
};
