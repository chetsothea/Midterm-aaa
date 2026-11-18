<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Support\BackgroundRemover;
use Illuminate\Http\Request;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class ProductController extends Controller
{
    private function rules(): array
    {
        return [
            'category_id' => 'nullable|integer|exists:categories,id',
            'name' => 'required|string|max:150',
            'brand' => 'nullable|string|max:50',
            'price' => 'required|numeric|min:0',
            'discount_percent' => 'nullable|numeric|min:0|max:99',
            'condition' => 'nullable|string|max:20',
            'warranty_months' => 'nullable|integer|min:0|max:120',
            'stock' => 'required|integer|min:0',
            'ram' => 'nullable|string|max:20',
            'storage' => 'nullable|string|max:255',
            // Sizes customers can pick, each with its own price: "256GB=1199, 512GB=1399"
            'storage_prices' => 'nullable|string|max:500',
            // Several colours separated by commas, e.g. "Blue, Red, Black"
            'color' => 'nullable|string|max:255',
            'description' => 'nullable|string',
            'image' => 'nullable|image|max:4096',
            // One picture per colour, sent as color_images[Blue], color_images[Red], ...
            'color_images' => 'nullable|array',
            'color_images.*' => 'image|max:4096',
        ];
    }

    // "256GB=1199, 512GB=1399" → [['storage' => '256GB', 'price' => 1199.0], ...]
    // When there are options, the product's own price becomes the cheapest one
    // (shown on store cards) and its storage field lists every size.
    private function applyStoragePrices(array $data): array
    {
        if (! array_key_exists('storage_prices', $data)) {
            return $data;
        }

        $options = [];
        foreach (array_filter(array_map('trim', explode(',', (string) $data['storage_prices']))) as $part) {
            if (! preg_match('/^([^=:]{1,20})\s*[=:]\s*\$?(\d+(?:\.\d{1,2})?)$/', $part, $m)) {
                throw ValidationException::withMessages([
                    'storage_prices' => "ទម្រង់មិនត្រឹមត្រូវ: \"{$part}\" (ឧ. 256GB=1199, 512GB=1399)",
                ]);
            }
            $options[] = ['storage' => trim($m[1]), 'price' => (float) $m[2]];
        }

        $data['storage_prices'] = $options ?: null;
        if ($options) {
            $data['price'] = min(array_column($options, 'price'));
            $data['storage'] = implode(', ', array_column($options, 'storage'));
        }

        return $data;
    }

    // Saves uploaded colour pictures over the old ones, and drops pictures
    // of colours that were removed from the colour list
    private function saveColorImages(Request $request, Product $product): void
    {
        $images = $product->color_images ?? [];

        foreach ($request->file('color_images', []) as $color => $file) {
            $this->deleteImage($images[$color] ?? null);
            $images[$color] = $this->storeUpload($file);
        }

        foreach (array_diff(array_keys($images), $product->colorOptions()) as $removed) {
            $this->deleteImage($images[$removed]);
            unset($images[$removed]);
        }

        $product->update(['color_images' => $images ?: null]);
    }

    private function saveImage(Request $request): ?string
    {
        if (! $request->hasFile('image')) {
            return null;
        }

        return $this->storeUpload($request->file('image'));
    }

    // Saves an uploaded picture and takes its white / checkerboard background
    // off (a transparent PNG), so the phone sits cleanly on any card
    private function storeUpload(UploadedFile $file): string
    {
        $name = Str::random(20).'.'.$file->extension();
        $file->move(public_path('uploads'), $name);
        $clean = BackgroundRemover::process(public_path('uploads/'.$name));
        if ($clean && $clean !== $name) {
            unlink(public_path('uploads/'.$name));
        }

        return $clean ?? $name;
    }

    private function deleteImage(?string $image): void
    {
        if ($image && ! str_starts_with($image, 'http') && file_exists(public_path('uploads/'.$image))) {
            unlink(public_path('uploads/'.$image));
        }
    }

    public function store(Request $request)
    {
        $data = $request->validate($this->rules());
        if (array_key_exists('warranty_months', $data) && $data['warranty_months'] === null) {
            unset($data['warranty_months']); // left empty: keep the 12-month default
        }
        unset($data['color_images']);
        $data = $this->applyStoragePrices($data);
        $data['image'] = $this->saveImage($request);

        $product = Product::create($data);
        $this->saveColorImages($request, $product);

        return response()->json($product, 201);
    }

    // POST instead of PUT because PHP doesn't parse multipart bodies on PUT
    public function update(Request $request, Product $product)
    {
        $data = $request->validate($this->rules());
        if (array_key_exists('warranty_months', $data) && $data['warranty_months'] === null) {
            unset($data['warranty_months']); // left empty: keep the 12-month default
        }
        unset($data['color_images']);
        $data = $this->applyStoragePrices($data);

        if ($image = $this->saveImage($request)) {
            $this->deleteImage($product->image);
            $data['image'] = $image;
        } else {
            unset($data['image']);
        }

        $product->update($data);
        $this->saveColorImages($request, $product);

        return $product;
    }

    public function destroy(Product $product)
    {
        $this->deleteImage($product->image);
        foreach ($product->color_images ?? [] as $file) {
            $this->deleteImage($file);
        }
        $product->delete();

        return response()->json(['message' => 'Deleted']);
    }
}
