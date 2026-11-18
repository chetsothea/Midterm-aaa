<?php

namespace App\Services\Bakong;

// Bakong could not be asked (offline, timeout, expired token)
class BakongUnavailable extends \RuntimeException {}
