<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            // Guests can order without an account
            $table->unsignedBigInteger('user_id')->nullable()->change();
            // Who to deliver to and contact, typed in at checkout
            $table->string('customer_name', 100)->nullable()->after('user_id');
            $table->string('customer_email', 150)->nullable()->after('customer_name');
            // Lets a guest view / pay / cancel their own order without logging in
            $table->string('access_token', 64)->nullable()->unique()->after('customer_email');
        });
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->dropColumn(['customer_name', 'customer_email', 'access_token']);
            $table->unsignedBigInteger('user_id')->nullable(false)->change();
        });
    }
};
