<?php

namespace Tests\Feature;

use Tests\TestCase;

class MediaTest extends TestCase
{
    public function test_uploaded_picture_is_served_with_cors_header(): void
    {
        $name = 'media_test_'.uniqid().'.png';
        file_put_contents(public_path('uploads/'.$name), 'png');

        try {
            $this->get('/media/'.$name)
                ->assertOk()
                ->assertHeader('Access-Control-Allow-Origin', '*');
        } finally {
            @unlink(public_path('uploads/'.$name));
        }
    }

    public function test_missing_or_outside_files_are_refused(): void
    {
        $this->get('/media/nope.png')->assertNotFound();
        $this->get('/media/..%2F.env')->assertNotFound();
        $this->get('/media/.htaccess')->assertNotFound();
    }

    public function test_a_small_webp_copy_is_made_once_and_kept(): void
    {
        $name = 'media_test_'.uniqid().'.png';
        $img = imagecreatetruecolor(700, 700);
        imagesavealpha($img, true);
        imagefill($img, 0, 0, imagecolorallocatealpha($img, 0, 0, 0, 127));
        imagefilledrectangle($img, 200, 100, 500, 600, imagecolorallocate($img, 30, 120, 255));
        imagepng($img, public_path('uploads/'.$name));
        imagedestroy($img);
        $cached = public_path('uploads/cache/'.pathinfo($name, PATHINFO_FILENAME).'_320.webp');

        try {
            $small = $this->get('/media/'.$name.'?w=320')->assertOk()->assertHeader('Content-Type', 'image/webp');
            $this->assertFileExists($cached);
            $copy = imagecreatefromwebp($cached);
            $this->assertSame(320, imagesx($copy));
            // The empty corner stays see-through
            $this->assertSame(127, (imagecolorat($copy, 2, 2) >> 24) & 0x7F);
            $this->assertLessThan(filesize(public_path('uploads/'.$name)), filesize($cached));

            // A width that is not offered gets the original
            $this->get('/media/'.$name.'?w=333')->assertOk()->assertHeader('Content-Type', 'image/png');
        } finally {
            @unlink(public_path('uploads/'.$name));
            @unlink($cached);
        }
    }
}
