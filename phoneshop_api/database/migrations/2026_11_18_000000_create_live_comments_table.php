<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // What viewers type under the live shopping stream
        Schema::create('live_comments', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('message', 300);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('live_comments');
    }
};
