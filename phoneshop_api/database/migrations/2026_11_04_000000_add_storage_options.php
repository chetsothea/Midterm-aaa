<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('products', function (Blueprint $table) {
            // [{"storage": "256GB", "price": 1199}, {"storage": "512GB", "price": 1399}]
            $table->json('storage_prices')->nullable()->after('storage');
        });

        Schema::table('order_items', function (Blueprint $table) {
            // The storage size the customer picked, e.g. "512GB"
            $table->string('storage', 20)->nullable()->after('color');
        });
    }

    public function down(): void
    {
        Schema::table('order_items', function (Blueprint $table) {
            $table->dropColumn('storage');
        });

        Schema::table('products', function (Blueprint $table) {
            $table->dropColumn('storage_prices');
        });
    }
};
