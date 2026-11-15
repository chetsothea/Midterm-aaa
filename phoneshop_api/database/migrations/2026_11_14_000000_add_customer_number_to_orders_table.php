<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    // Each customer's own order count: their 1st, 2nd, 3rd order... The shop-wide ID
    // jumps (#21 → #32) because of other people's orders, so customers see this instead.
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->unsignedInteger('customer_number')->nullable();
        });

        // Number the orders already placed, oldest first, per customer
        $next = [];
        DB::table('orders')->whereNotNull('user_id')->orderBy('id')->select(['id', 'user_id'])
            ->chunk(500, function ($orders) use (&$next) {
                foreach ($orders as $order) {
                    $next[$order->user_id] = ($next[$order->user_id] ?? 0) + 1;
                    DB::table('orders')->where('id', $order->id)->update(['customer_number' => $next[$order->user_id]]);
                }
            });
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->dropColumn('customer_number');
        });
    }
};
