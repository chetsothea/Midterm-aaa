<?php

namespace App\Http\Middleware;

use App\Models\ActivityLog;
use Closure;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

// Writes one line to the activity log for every change the admin or staff
// make (not for looking): who, what, on which order/phone/code, and the
// fields they sent. Passwords and uploaded files are never written down.
class LogTeamActivity
{
    // Controller@method → what it means, in Khmer
    private const ACTIONS = [
        'OrderController@update' => 'កែ Order',
        'OrderController@destroy' => 'លុប Order',
        'OrderController@markRefunded' => 'បង្វិលប្រាក់',
        'OrderController@addTracking' => 'បន្ថែមទីតាំងដឹកជញ្ជូន',
        'OrderController@updateTracking' => 'កែទីតាំងដឹកជញ្ជូន',
        'OrderController@updateCustomer' => 'កែព័ត៌មានអតិថិជន',
        'OrderController@deleteCustomer' => 'លុបគណនីអតិថិជន',
        'OrderController@setCustomerBlocked' => 'បិទ/បើកគណនីអតិថិជន',
        'OrderController@updateLowStockThreshold' => 'កំណត់ស្តុកទាប',
        'WarrantyController@setImeis' => 'បញ្ចូល IMEI',
        'ProductController@store' => 'បន្ថែមទូរស័ព្ទ',
        'ProductController@update' => 'កែទូរស័ព្ទ',
        'ProductController@destroy' => 'លុបទូរស័ព្ទ',
        'VoucherController@store' => 'បង្កើតកូដបញ្ចុះ',
        'VoucherController@update' => 'កែកូដបញ្ចុះ',
        'VoucherController@destroy' => 'លុបកូដបញ្ចុះ',
        'VoucherController@updateShipping' => 'កែថ្លៃដឹក',
        'VoucherController@updateKhrRate' => 'កែអត្រាប្តូរប្រាក់',
        'PaymentAccountController@store' => 'បន្ថែមគណនីធនាគារ',
        'PaymentAccountController@update' => 'កែគណនីធនាគារ',
        'PaymentAccountController@destroy' => 'លុបគណនីធនាគារ',
        'StaffController@store' => 'បន្ថែមបុគ្គលិក',
        'StaffController@update' => 'កែបុគ្គលិក',
        'StaffController@destroy' => 'លុបបុគ្គលិក',
        'TradeInController@offer' => 'ផ្តល់តម្លៃ Trade-in',
        'TradeInController@reject' => 'បដិសេធ Trade-in',
        'TradeInController@complete' => 'ចេញកូដ Trade-in',
        'ReviewController@setHidden' => 'លាក់/បង្ហាញការវាយតម្លៃ',
        'LiveController@update' => 'កែ Live',
        'LiveController@deleteComment' => 'លុបមតិ Live',
    ];

    private const NEVER = ['password', 'password_confirmation', 'token', 'image', 'qr_image', 'color_images', 'photos'];

    public function handle(Request $request, Closure $next): Response
    {
        $response = $next($request);

        $user = $request->user();
        $action = self::ACTIONS[class_basename((string) $request->route()?->getActionName())] ?? null;
        if ($request->isMethodSafe() || ! $action || ! $user || $response->getStatusCode() >= 300) {
            return $response;
        }

        ActivityLog::create([
            'user_id' => $user->id,
            'user_name' => $user->name,
            'role' => $user->role,
            'action' => $action,
            'subject' => $this->subject($request) ?? $this->createdSubject($response),
            'details' => $this->details($request) ?: null,
            'ip' => $request->ip(),
        ]);

        return $response;
    }

    // The order / phone / code the change was about, by a name people know
    private function subject(Request $request): ?string
    {
        foreach ($request->route()->parameters() as $model) {
            if (! $model instanceof Model) {
                continue;
            }

            return match (class_basename($model)) {
                'Order' => 'Order '.($model->code ?: '#'.$model->id),
                'OrderItem' => 'Order '.($model->order?->code ?: '#'.$model->order_id).' · '.($model->product?->name ?? ''),
                'Product' => $model->name,
                'Voucher' => $model->code,
                'User' => $model->name.' ('.$model->email.')',
                'TradeIn' => 'Trade-in #'.$model->id.' '.$model->brand.' '.$model->model,
                'PaymentAccount' => $model->bank_name,
                'Review' => 'Review #'.$model->id,
                default => class_basename($model).' #'.$model->getKey(),
            };
        }

        return null;
    }

    // Something new (a phone, a code): its name from the answer
    private function createdSubject(Response $response): ?string
    {
        $data = json_decode((string) $response->getContent(), true);

        return is_array($data) ? ($data['name'] ?? $data['code'] ?? $data['bank_name'] ?? null) : null;
    }

    private function details(Request $request): array
    {
        $fields = $request->except(self::NEVER);
        array_walk_recursive($fields, function (&$v) {
            if (is_string($v) && mb_strlen($v) > 200) {
                $v = mb_substr($v, 0, 200).'…';
            }
        });

        return $fields;
    }
}
