<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // "Tell me when it's back": one per customer, phone and (optional) colour/size
        Schema::create('stock_alerts', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('product_id')->constrained()->cascadeOnDelete();
            $table->string('variant', 60)->default(''); // "Blue|256GB", '' = any
            $table->timestamps();
            $table->unique(['user_id', 'product_id', 'variant']);
        });

        // A 🔔 about a phone (back in stock, cheaper) opens that phone
        Schema::table('notices', function (Blueprint $table) {
            $table->foreignId('product_id')->nullable()->constrained()->nullOnDelete();
        });

        // The admin can hide a rude or fake review (kept, not shown)
        Schema::table('reviews', function (Blueprint $table) {
            $table->timestamp('hidden_at')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('reviews', fn (Blueprint $t) => $t->dropColumn('hidden_at'));
        Schema::table('notices', fn (Blueprint $t) => $t->dropConstrainedForeignId('product_id'));
        Schema::dropIfExists('stock_alerts');
    }
};
