<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Order;
use App\Models\Product;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class BestSellersTest extends TestCase
{
    use RefreshDatabase;

    private function product(string $name, float $price, int $stock = 5): Product
    {
        $category = Category::firstOrCreate(['name' => 'Smartphone']);

        return Product::create([
            'category_id' => $category->id, 'name' => $name, 'brand' => 'X',
            'price' => $price, 'stock' => $stock,
        ]);
    }

    private function sell(Product $product, int $qty, string $status = 'delivered'): void
    {
        $order = Order::create([
            'customer_name' => 'A', 'customer_email' => 'a@example.com', 'total' => $product->price * $qty,
            'status' => $status, 'payment_method' => 'cod', 'phone' => '012', 'address' => 'PP',
        ]);
        $order->items()->create(['product_id' => $product->id, 'qty' => $qty, 'price' => $product->price]);
    }

    public function test_most_sold_first_cancelled_orders_and_sold_out_phones_left_out(): void
    {
        $cheap = $this->product('Cheap', 100);
        $popular = $this->product('Popular', 500);
        $soldOut = $this->product('Sold out', 900, stock: 0);
        $flagship = $this->product('Flagship', 1500);

        $this->sell($cheap, 2);
        $this->sell($popular, 5);
        $this->sell($popular, 1, 'pending');
        $this->sell($cheap, 10, 'cancelled'); // doesn't count
        $this->sell($soldOut, 20);

        $list = $this->getJson('/api/best-sellers')->assertOk()->json();

        // Sold phones first, by units; then the rest topped up by price
        $this->assertSame(['Popular', 'Cheap', 'Flagship'], array_column($list, 'name'));
        $this->assertSame([6, 2, 0], array_column($list, 'sold'));
    }

    public function test_with_no_sales_yet_it_shows_the_priciest_phones_in_stock(): void
    {
        $this->product('A', 300);
        $this->product('B', 1200);
        $this->product('C', 800);

        $list = $this->getJson('/api/best-sellers')->assertOk()->json();
        $this->assertSame(['B', 'C', 'A'], array_column($list, 'name'));
    }
}
