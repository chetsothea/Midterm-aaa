<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

// IMEI of every phone sold, and how long each one is under warranty
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('products', function (Blueprint $table) {
            $table->unsignedSmallInteger('warranty_months')->default(12); // 0 = no warranty
        });

        Schema::table('order_items', function (Blueprint $table) {
            // Copied at sale, so changing the phone later doesn't change past warranties
            $table->unsignedSmallInteger('warranty_months')->nullable();
        });

        Schema::table('orders', function (Blueprint $table) {
            $table->timestamp('delivered_at')->nullable(); // warranty starts here
        });

        // One row per phone handed over; an IMEI can only be sold once
        Schema::create('sold_units', function (Blueprint $table) {
            $table->id();
            $table->foreignId('order_item_id')->constrained()->cascadeOnDelete();
            $table->string('imei', 15)->unique();
            $table->timestamps();
        });

        // Orders already delivered: their warranty starts at that tracking step
        foreach (DB::table('orders')->where('status', 'delivered')->pluck('id') as $id) {
            $at = DB::table('order_trackings')->where('order_id', $id)
                ->where('status', 'delivered')->min('created_at');
            DB::table('orders')->where('id', $id)->update(['delivered_at' => $at]);
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('sold_units');
        Schema::table('orders', fn (Blueprint $t) => $t->dropColumn('delivered_at'));
        Schema::table('order_items', fn (Blueprint $t) => $t->dropColumn('warranty_months'));
        Schema::table('products', fn (Blueprint $t) => $t->dropColumn('warranty_months'));
    }
};
