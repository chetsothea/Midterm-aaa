<?php

use App\Models\Order;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    // A random reference like "PS-7K3Q9A" for customers and bills, so the running
    // order numbers (and how many orders the shop gets) stay private
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->string('code', 12)->nullable()->unique();
        });

        DB::table('orders')->whereNull('code')->orderBy('id')->pluck('id')
            ->each(fn ($id) => DB::table('orders')->where('id', $id)->update(['code' => Order::newCode()]));
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->dropUnique(['code']);
            $table->dropColumn('code');
        });
    }
};
