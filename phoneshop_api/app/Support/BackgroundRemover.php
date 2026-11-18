<?php

namespace App\Support;

use GdImage;
use SplFixedArray;

// Takes the background off a product photo: a white, light-grey or
// "fake transparent" checkerboard backdrop becomes real transparency.
//
// It starts from the picture's edges and spreads inwards through every
// light, colourless pixel it can reach, so the white or silver parts *inside*
// the phone (a screen reflection, a white phone) are kept: they are walled
// off by the phone's darker outline. The edge is softened against JPEG fringes,
// and the result is cropped close around the phone and saved as a PNG.
class BackgroundRemover
{
    // A pixel counts as backdrop when it is at least this bright…
    private const MIN_BRIGHTNESS = 226;

    // …and this close to grey (max - min channel)
    private const MAX_COLOUR = 22;

    // Writes <name>.png next to $path and returns its file name, or null when
    // the picture has no light backdrop to remove (it is left as it is).
    public static function process(string $path): ?string
    {
        $image = self::load($path);
        if (! $image) {
            return null;
        }
        $w = imagesx($image);
        $h = imagesy($image);

        $background = self::floodFromEdges($image, $w, $h);
        $removed = 0;
        for ($i = 0; $i < $w * $h; $i++) {
            $removed += $background[$i] ? 1 : 0;
        }
        // Nothing (or almost everything) to remove: not a product-on-backdrop photo
        if ($removed < $w * $h * 0.05 || $removed > $w * $h * 0.97) {
            imagedestroy($image);

            return null;
        }

        $out = imagecreatetruecolor($w, $h);
        imagealphablending($out, false);
        imagesavealpha($out, true);
        $clear = imagecolorallocatealpha($out, 0, 0, 0, 127);
        imagefill($out, 0, 0, $clear);

        [$minX, $minY, $maxX, $maxY] = [$w, $h, -1, -1];
        for ($y = 0; $y < $h; $y++) {
            for ($x = 0; $x < $w; $x++) {
                $i = $y * $w + $x;
                if ($background[$i]) {
                    continue;
                }
                $rgb = imagecolorat($image, $x, $y);
                $r = ($rgb >> 16) & 255;
                $g = ($rgb >> 8) & 255;
                $b = $rgb & 255;

                // Soft edge: a light pixel right next to the backdrop is part
                // backdrop (JPEG fringe), so it is made partly see-through
                $alpha = 0; // GD: 0 = solid, 127 = clear
                if (self::touchesBackground($background, $x, $y, $w, $h)) {
                    $bright = ($r + $g + $b) / 3;
                    if ($bright > 170) {
                        $alpha = (int) min(110, ($bright - 170) / 85 * 127);
                    }
                }
                imagesetpixel($out, $x, $y, imagecolorallocatealpha($out, $r, $g, $b, $alpha));
                $minX = min($minX, $x);
                $minY = min($minY, $y);
                $maxX = max($maxX, $x);
                $maxY = max($maxY, $y);
            }
        }
        imagedestroy($image);

        // Crop close around the phone, with a little air on every side
        $pad = (int) round(max($maxX - $minX, $maxY - $minY) * 0.04);
        $minX = max(0, $minX - $pad);
        $minY = max(0, $minY - $pad);
        $maxX = min($w - 1, $maxX + $pad);
        $maxY = min($h - 1, $maxY + $pad);
        $cropped = imagecrop($out, [
            'x' => $minX, 'y' => $minY,
            'width' => $maxX - $minX + 1, 'height' => $maxY - $minY + 1,
        ]);
        imagedestroy($out);
        if (! $cropped) {
            return null;
        }
        imagealphablending($cropped, false);
        imagesavealpha($cropped, true);

        $name = pathinfo($path, PATHINFO_FILENAME).'.png';
        imagepng($cropped, dirname($path).'/'.$name, 6);
        imagedestroy($cropped);

        return $name;
    }

    private static function load(string $path): ?GdImage
    {
        $data = @file_get_contents($path);
        $image = $data === false ? false : @imagecreatefromstring($data);
        if (! $image) {
            return null;
        }
        // Work in full colour (a palette PNG would lose the alpha we add)
        if (! imageistruecolor($image)) {
            imagepalettetotruecolor($image);
        }
        // A PNG that already has transparency: flatten it on white first, so
        // its see-through parts count as backdrop too
        $w = imagesx($image);
        $h = imagesy($image);
        $flat = imagecreatetruecolor($w, $h);
        imagefill($flat, 0, 0, imagecolorallocate($flat, 255, 255, 255));
        imagecopy($flat, $image, 0, 0, 0, 0, $w, $h);
        imagedestroy($image);

        return $flat;
    }

    private static function isBackdrop(int $rgb): bool
    {
        $r = ($rgb >> 16) & 255;
        $g = ($rgb >> 8) & 255;
        $b = $rgb & 255;

        return min($r, $g, $b) >= self::MIN_BRIGHTNESS
            && max($r, $g, $b) - min($r, $g, $b) <= self::MAX_COLOUR;
    }

    // Every backdrop pixel reachable from the border, as a flat true/false grid
    private static function floodFromEdges(GdImage $image, int $w, int $h): SplFixedArray
    {
        $seen = new SplFixedArray($w * $h);
        $queue = new \SplQueue;
        $push = function (int $x, int $y) use ($image, $w, $seen, $queue) {
            $i = $y * $w + $x;
            if ($seen[$i] === null) {
                $seen[$i] = self::isBackdrop(imagecolorat($image, $x, $y));
                if ($seen[$i]) {
                    $queue->enqueue($i);
                }
            }
        };
        for ($x = 0; $x < $w; $x++) {
            $push($x, 0);
            $push($x, $h - 1);
        }
        for ($y = 0; $y < $h; $y++) {
            $push(0, $y);
            $push($w - 1, $y);
        }
        while (! $queue->isEmpty()) {
            $i = $queue->dequeue();
            $x = $i % $w;
            $y = intdiv($i, $w);
            if ($x > 0) {
                $push($x - 1, $y);
            }
            if ($x < $w - 1) {
                $push($x + 1, $y);
            }
            if ($y > 0) {
                $push($x, $y - 1);
            }
            if ($y < $h - 1) {
                $push($x, $y + 1);
            }
        }
        // Unvisited (null) or not backdrop (false) both mean "keep"
        for ($i = 0; $i < $w * $h; $i++) {
            $seen[$i] = $seen[$i] === true;
        }

        return $seen;
    }

    private static function touchesBackground(SplFixedArray $bg, int $x, int $y, int $w, int $h): bool
    {
        return ($x > 0 && $bg[$y * $w + $x - 1])
            || ($x < $w - 1 && $bg[$y * $w + $x + 1])
            || ($y > 0 && $bg[($y - 1) * $w + $x])
            || ($y < $h - 1 && $bg[($y + 1) * $w + $x]);
    }
}
