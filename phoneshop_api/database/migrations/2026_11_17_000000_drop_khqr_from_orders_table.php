<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

// The shop no longer connects to Bakong: customers pay to the shop's own QR and the
// admin confirms it, so the per-order KHQR columns aren't used any more.
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->dropColumn(['khqr_string', 'khqr_md5', 'khqr_expires_at']);
        });
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->text('khqr_string')->nullable();
            $table->string('khqr_md5', 32)->nullable();
            $table->timestamp('khqr_expires_at')->nullable();
        });
    }
};
