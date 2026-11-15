<?php

use App\Models\Order;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Where the package has been: one row per step, newest shown first to the customer
        Schema::create('order_trackings', function (Blueprint $table) {
            $table->id();
            $table->foreignId('order_id')->constrained()->cascadeOnDelete();
            // The order status at this step (pending, confirmed, shipping, delivered, cancelled)
            $table->string('status', 20);
            $table->string('location', 150)->nullable(); // e.g. "សាខា បាត់ដំបង"
            $table->string('note', 255)->nullable();      // e.g. "អ្នកដឹកកំពុងធ្វើដំណើរ"
            $table->timestamps();
        });

        Schema::table('orders', function (Blueprint $table) {
            // Delivery company and its parcel number, e.g. "J&T Express" / "JT0123456789"
            $table->string('courier', 50)->nullable()->after('address');
            $table->string('tracking_number', 50)->nullable()->after('courier');
        });

        // Give orders placed before tracking existed a starting history:
        // "order received" at the order date, plus their current status if it moved on since
        foreach (DB::table('orders')->get() as $order) {
            $steps = [['pending', $order->created_at]];
            if ($order->status !== 'pending') {
                $steps[] = [$order->status, $order->updated_at];
            }
            foreach ($steps as [$status, $at]) {
                DB::table('order_trackings')->insert([
                    'order_id' => $order->id,
                    'status' => $status,
                    'note' => Order::TRACKING_NOTES[$status] ?? null,
                    'created_at' => $at,
                    'updated_at' => $at,
                ]);
            }
        }
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->dropColumn(['courier', 'tracking_number']);
        });
        Schema::dropIfExists('order_trackings');
    }
};
