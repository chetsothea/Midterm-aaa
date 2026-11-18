<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

// Discount codes, and what an order charged for delivery and took off with a code
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('vouchers', function (Blueprint $table) {
            $table->id();
            $table->string('code', 30)->unique(); // stored in capitals, e.g. KHMERNEWYEAR
            $table->string('type', 10); // percent or fixed
            $table->decimal('value', 10, 2); // 10 (%) or 20 ($)
            $table->decimal('min_total', 10, 2)->default(0); // order must reach this
            $table->decimal('max_discount', 10, 2)->nullable(); // cap for percent codes
            $table->unsignedInteger('max_uses')->nullable(); // null = no limit
            $table->unsignedInteger('used_count')->default(0);
            $table->timestamp('expires_at')->nullable();
            $table->boolean('active')->default(true);
            $table->timestamps();
        });

        Schema::table('orders', function (Blueprint $table) {
            $table->decimal('subtotal', 10, 2)->nullable(); // phones only; null on older orders
            $table->decimal('shipping_fee', 10, 2)->default(0);
            $table->decimal('discount', 10, 2)->default(0);
            $table->string('voucher_code', 30)->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->dropColumn(['subtotal', 'shipping_fee', 'discount', 'voucher_code']);
        });
        Schema::dropIfExists('vouchers');
    }
};
