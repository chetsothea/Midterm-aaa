<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\PaymentAccount;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

// The admin adds, edits and removes the banks shown on the payment page
class PaymentAccountController extends Controller
{
    public function index()
    {
        return PaymentAccount::orderBy('sort')->orderBy('id')->get();
    }

    public function store(Request $request)
    {
        $data = $this->validated($request, true);
        $data['qr_image'] = $this->storeQr($request);
        $data['sort'] ??= (int) PaymentAccount::max('sort') + 1;

        return response()->json(PaymentAccount::create($data), 201);
    }

    // POST (not PUT) so the app can send a new QR picture as multipart
    public function update(Request $request, PaymentAccount $paymentAccount)
    {
        $data = $this->validated($request, false);
        if ($request->hasFile('qr_image')) {
            $this->deleteQr($paymentAccount->qr_image);
            $data['qr_image'] = $this->storeQr($request);
        } elseif ($request->boolean('remove_qr')) {
            $this->deleteQr($paymentAccount->qr_image);
            $data['qr_image'] = null;
        }
        $paymentAccount->update($data);

        return $paymentAccount->fresh();
    }

    public function destroy(PaymentAccount $paymentAccount)
    {
        $this->deleteQr($paymentAccount->qr_image);
        $paymentAccount->delete();

        return response()->noContent();
    }

    private function validated(Request $request, bool $creating): array
    {
        $rule = $creating ? 'required' : 'sometimes';

        return $request->validate([
            'bank_name' => "$rule|string|max:60",
            'account_name' => "$rule|string|max:100",
            'account_number' => "$rule|string|max:40",
            'sort' => 'sometimes|integer|min:0',
            'qr_image' => 'nullable|image|max:4096',
        ], [
            'bank_name.required' => 'សូមបញ្ចូលឈ្មោះធនាគារ',
            'account_name.required' => 'សូមបញ្ចូលឈ្មោះគណនី',
            'account_number.required' => 'សូមបញ្ចូលលេខគណនី',
            'qr_image.image' => 'QR ត្រូវតែជារូបភាព',
        ]);
    }

    // The QR is kept exactly as uploaded: no background removal, it must scan
    private function storeQr(Request $request): ?string
    {
        if (! $request->hasFile('qr_image')) {
            return null;
        }
        $file = $request->file('qr_image');
        $name = 'qr_'.Str::random(16).'.'.$file->extension();
        $file->move(public_path('uploads'), $name);

        return $name;
    }

    private function deleteQr(?string $name): void
    {
        if ($name && ! str_starts_with($name, 'http') && is_file(public_path('uploads/'.$name))) {
            unlink(public_path('uploads/'.$name));
        }
    }
}
