<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            // When the customer said they got the parcel, and when the admin saw that
            $table->timestamp('received_at')->nullable();
            $table->timestamp('received_seen_at')->nullable();
        });

        // Customers who already confirmed: recorded, but nothing new to tell the admin
        $confirmed = DB::table('order_trackings')
            ->where('note', 'អ្នកទិញបានបញ្ជាក់ថាទទួលឥវ៉ាន់ហើយ')
            ->get(['order_id', 'created_at']);
        foreach ($confirmed as $step) {
            DB::table('orders')->where('id', $step->order_id)->update([
                'received_at' => $step->created_at,
                'received_seen_at' => $step->created_at,
            ]);
        }
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->dropColumn(['received_at', 'received_seen_at']);
        });
    }
};
