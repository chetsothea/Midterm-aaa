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
}
