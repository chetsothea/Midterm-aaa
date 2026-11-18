<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

// ♥ phones and the cart, kept on the account so they follow the customer
// to another phone or browser
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->json('favorite_ids')->nullable();
            $table->json('saved_cart')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['favorite_ids', 'saved_cart']);
        });
    }
};
