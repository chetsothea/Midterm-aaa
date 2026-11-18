<?php

namespace App\Support;

// Pictures the admin and customers upload live in public/uploads. Their URLs
// point at the /media route instead of the raw file, because a file served
// straight off disk (php artisan serve, or a plain web server) carries no
// CORS header, and Flutter web then can't draw it on its canvas.
class Uploads
{
    public static function url(?string $file): string
    {
        if (! $file) {
            return '';
        }

        return str_starts_with($file, 'http') ? $file : url('media/'.$file);
    }
}
