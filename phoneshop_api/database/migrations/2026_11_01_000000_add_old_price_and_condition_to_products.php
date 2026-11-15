<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('products', function (Blueprint $table) {
            // Price before discount; the store shows a "%xx" badge when it's higher than price
            $table->decimal('old_price', 10, 2)->nullable()->after('price');
            // "New", or how good a used phone is, e.g. "98%"
            $table->string('condition', 20)->default('New')->after('old_price');
        });
    }

    public function down(): void
    {
        Schema::table('products', function (Blueprint $table) {
            $table->dropColumn(['old_price', 'condition']);
        });
    }
};
