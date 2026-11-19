<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

// Who on the shop's team changed what, and when
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('activity_logs', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();
            $table->string('user_name', 100); // kept if the staff account is removed later
            $table->string('role', 10);
            $table->string('action', 60);
            $table->string('subject', 150)->nullable(); // "Order PS-7K3Q9A", "iPhone 17"
            $table->json('details')->nullable(); // the fields that were sent (never passwords)
            $table->string('ip', 45)->nullable();
            $table->timestamp('created_at')->useCurrent();
            $table->index('created_at');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('activity_logs');
    }
};
