<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('products', function (Blueprint $table) {
            // % off every storage size; price and storage_prices keep the regular prices
            $table->decimal('discount_percent', 5, 2)->nullable()->after('price');
            $table->dropColumn('old_price');
        });
    }

    public function down(): void
    {
        Schema::table('products', function (Blueprint $table) {
            $table->decimal('old_price', 10, 2)->nullable()->after('price');
            $table->dropColumn('discount_percent');
        });
    }
};
