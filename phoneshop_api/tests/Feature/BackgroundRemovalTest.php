<?php

namespace Tests\Feature;

use App\Models\Product;
use App\Models\User;
use App\Support\BackgroundRemover;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Tests\TestCase;

class BackgroundRemovalTest extends TestCase
{
    use RefreshDatabase;

    // A "phone" (dark rounded slab with a white screen glint inside) on a fake
    // transparent checkerboard, saved as a JPEG like the shop's real uploads
    private function checkerboardPhoto(): string
    {
        $img = imagecreatetruecolor(200, 200);
        $white = imagecolorallocate($img, 255, 255, 255);
        $grey = imagecolorallocate($img, 245, 245, 245);
        for ($y = 0; $y < 200; $y += 10) {
            for ($x = 0; $x < 200; $x += 10) {
                imagefilledrectangle($img, $x, $y, $x + 9, $y + 9, (($x + $y) / 10) % 2 ? $grey : $white);
            }
        }
        imagefilledrectangle($img, 70, 30, 130, 170, imagecolorallocate($img, 40, 50, 70));
        imagefilledrectangle($img, 90, 60, 110, 80, $white); // white inside the phone
        $path = tempnam(sys_get_temp_dir(), 'phone').'.jpg';
        imagejpeg($img, $path, 95);
        imagedestroy($img);

        return $path;
    }

    private function alphaAt(string $png, int $x, int $y): int
    {
        $img = imagecreatefrompng($png);

        return (imagecolorat($img, $x, $y) >> 24) & 127; // 127 = fully clear
    }

    public function test_the_checkerboard_becomes_transparent_and_the_phone_stays(): void
    {
        $photo = $this->checkerboardPhoto();
        $name = BackgroundRemover::process($photo);
        $png = dirname($photo).'/'.$name;

        $this->assertStringEndsWith('.png', $name);
        [$w, $h] = getimagesize($png);
        $this->assertLessThan(120, $w); // cropped close around the phone
        $this->assertSame(127, $this->alphaAt($png, 0, 0)); // corner: clear
        $this->assertSame(0, $this->alphaAt($png, (int) ($w / 2), (int) ($h * 0.8))); // body: solid
        // The white part inside the phone is walled off, so it is kept
        $this->assertSame(0, $this->alphaAt($png, (int) ($w / 2), (int) ($h * 0.3)));
        @unlink($photo);
        @unlink($png);
    }

    public function test_a_photo_without_a_plain_backdrop_is_left_alone(): void
    {
        $img = imagecreatetruecolor(100, 100);
        imagefill($img, 0, 0, imagecolorallocate($img, 30, 90, 160)); // all blue
        $path = tempnam(sys_get_temp_dir(), 'scene').'.jpg';
        imagejpeg($img, $path);
        $this->assertNull(BackgroundRemover::process($path));
        @unlink($path);
    }

    public function test_an_uploaded_product_picture_is_saved_without_its_background(): void
    {
        $admin = User::create(['name' => 'Admin', 'email' => 'admin', 'password' => 'admin123', 'role' => 'admin']);
        $photo = $this->checkerboardPhoto();

        $this->actingAs($admin)->post('/api/admin/products', [
            'name' => 'Test Phone',
            'price' => 100,
            'stock' => 2,
            'image' => new UploadedFile($photo, 'phone.jpg', 'image/jpeg', null, true),
        ], ['Accept' => 'application/json'])->assertCreated();

        $file = Product::first()->getRawOriginal('image');
        $this->assertStringEndsWith('.png', $file);
        $this->assertFileExists(public_path('uploads/'.$file));
        $this->assertSame(127, $this->alphaAt(public_path('uploads/'.$file), 0, 0));
        unlink(public_path('uploads/'.$file));
    }
}
