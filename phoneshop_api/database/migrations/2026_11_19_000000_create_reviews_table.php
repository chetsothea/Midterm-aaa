<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Stars and a few words from customers who received the phone
        Schema::create('reviews', function (Blueprint $table) {
            $table->id();
            $table->foreignId('product_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->unsignedTinyInteger('rating'); // 1..5
            $table->string('comment', 1000)->nullable();
            $table->timestamps();
            $table->unique(['product_id', 'user_id']); // one review each; editing replaces it
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('reviews');
    }
};
