<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

// Trade-in: a customer offers their old phone; the shop makes an offer; once
// the shop has the phone, the agreed amount becomes a code only they can use
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('trade_ins', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('brand', 50);
            $table->string('model', 100);
            $table->string('storage', 20)->nullable();
            $table->string('condition', 20); // like_new, good, fair, broken
            $table->unsignedTinyInteger('battery_health')->nullable(); // %
            $table->text('notes')->nullable();
            $table->json('photos')->nullable(); // file names in public/uploads
            $table->foreignId('wanted_product_id')->nullable()->constrained('products')->nullOnDelete();
            // pending → offered → accepted → completed; or declined / rejected / cancelled
            $table->string('status', 20)->default('pending');
            $table->decimal('offer_amount', 10, 2)->nullable();
            $table->string('admin_note', 500)->nullable();
            $table->string('voucher_code', 30)->nullable();
            $table->timestamps();
        });

        // A code can belong to one customer (the trade-in credit)
        Schema::table('vouchers', function (Blueprint $table) {
            $table->foreignId('user_id')->nullable()->constrained()->cascadeOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('vouchers', function (Blueprint $table) {
            $table->dropConstrainedForeignId('user_id');
        });
        Schema::dropIfExists('trade_ins');
    }
};
