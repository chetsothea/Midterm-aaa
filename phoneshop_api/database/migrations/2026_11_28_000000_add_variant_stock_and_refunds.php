<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Stock per colour and size: {"Blue|256GB": 3, "Black|512GB": 0}.
        // Null = one shared count in products.stock, as before.
        Schema::table('products', function (Blueprint $table) {
            $table->json('variant_stock')->nullable();
        });

        // A cancelled order the customer had already paid: money to give back
        Schema::table('orders', function (Blueprint $table) {
            $table->string('refund_status', 10)->nullable(); // due, refunded
            $table->timestamp('refunded_at')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('orders', fn (Blueprint $t) => $t->dropColumn(['refund_status', 'refunded_at']));
        Schema::table('products', fn (Blueprint $t) => $t->dropColumn('variant_stock'));
    }
};
