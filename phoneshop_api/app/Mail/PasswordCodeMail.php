<?php

namespace App\Mail;

use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;

// "Your PS168 code is 482913", in Khmer and English, plain text
class PasswordCodeMail extends Mailable
{
    use Queueable;

    public function __construct(public string $name, public string $code, public int $minutes) {}

    public function envelope(): Envelope
    {
        return new Envelope(subject: "PS168: {$this->code} ជាលេខកូដរបស់អ្នក / your code");
    }

    public function content(): Content
    {
        return new Content(text: 'mail.password-code');
    }
}
