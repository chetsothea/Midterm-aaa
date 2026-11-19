<?php

namespace App\Support;

// Smaller copies of uploaded pictures for the app: WebP (keeps the clear
// background), at a few fixed widths, made once and kept in uploads/cache.
// The original file is never changed.
class MediaResizer
{
    public const WIDTHS = [160, 320, 640, 960];

    // Path of the resized copy, made if needed; null = serve the original
    // (unknown width, or not a picture GD can read)
    public static function path(string $original, int $width): ?string
    {
        if (! in_array($width, self::WIDTHS, true) || ! function_exists('imagewebp')) {
            return null;
        }
        $cacheDir = public_path('uploads/cache');
        $target = $cacheDir.'/'.pathinfo($original, PATHINFO_FILENAME).'_'.$width.'.webp';
        if (is_file($target) && filemtime($target) >= filemtime($original)) {
            return $target;
        }

        $data = @file_get_contents($original);
        $image = $data === false ? false : @imagecreatefromstring($data);
        if (! $image) {
            return null;
        }
        $w = imagesx($image);
        $h = imagesy($image);
        // Never made bigger: a narrower picture is only turned into WebP
        $newW = min($width, $w);
        $newH = (int) round($h * $newW / $w);
        $small = imagecreatetruecolor($newW, $newH);
        imagealphablending($small, false);
        imagesavealpha($small, true);
        imagefill($small, 0, 0, imagecolorallocatealpha($small, 0, 0, 0, 127));
        imagecopyresampled($small, $image, 0, 0, 0, 0, $newW, $newH, $w, $h);

        if (! is_dir($cacheDir)) {
            mkdir($cacheDir, 0755, true);
        }
        $ok = imagewebp($small, $target, 82);
        imagedestroy($image);
        imagedestroy($small);

        return $ok ? $target : null;
    }
}
