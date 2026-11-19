<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Voucher;
use App\Support\Shipping;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

// The admin's discount codes and delivery prices
class VoucherController extends Controller
{
    public function index()
    {
        return [
            // Trade-in credits are managed from the trade-in page
            'vouchers' => Voucher::whereNull('user_id')->latest()->get()->map(fn (Voucher $v) => $this->present($v)),
            'shipping' => Shipping::rates(),
            'khr_rate' => Shipping::khrRate(),
        ];
    }

    // Riel for one dollar, shown next to prices; 0 hides riel
    public function updateKhrRate(Request $request)
    {
        $data = $request->validate(['khr_rate' => 'required|integer|min:0|max:100000']);
        \App\Models\Setting::setText('khr_rate', (string) $data['khr_rate']);

        return ['khr_rate' => Shipping::khrRate()];
    }

    public function store(Request $request)
    {
        $voucher = Voucher::create($this->validated($request));

        return response()->json($this->present($voucher), 201);
    }

    public function update(Request $request, Voucher $voucher)
    {
        $voucher->update($this->validated($request, $voucher));

        return $this->present($voucher->fresh());
    }

    public function destroy(Voucher $voucher)
    {
        $voucher->delete(); // orders keep the code's name and the amount they got off

        return response()->json(['message' => 'Deleted']);
    }

    public function updateShipping(Request $request)
    {
        $data = $request->validate([
            'phnom_penh' => 'required|numeric|min:0|max:1000',
            'province' => 'required|numeric|min:0|max:1000',
            'free_over' => 'required|numeric|min:0|max:100000',
        ], [
            '*.numeric' => 'សូមបញ្ចូលជាលេខ',
            '*.min' => 'មិនអាចតិចជាង 0',
        ]);
        Shipping::setRates((float) $data['phnom_penh'], (float) $data['province'], (float) $data['free_over']);

        return Shipping::rates();
    }

    private function validated(Request $request, ?Voucher $voucher = null): array
    {
        $request->merge(['code' => Voucher::normalize($request->input('code'))]);

        $data = $request->validate([
            'code' => ['required', 'string', 'max:30', 'regex:/^[A-Z0-9_-]+$/',
                Rule::unique('vouchers', 'code')->ignore($voucher?->id)],
            'type' => 'required|in:percent,fixed',
            'value' => ['required', 'numeric', 'gt:0', $request->input('type') === 'percent' ? 'max:100' : 'max:100000'],
            'min_total' => 'nullable|numeric|min:0',
            'max_discount' => 'nullable|numeric|gt:0',
            'max_uses' => 'nullable|integer|min:1',
            'expires_at' => 'nullable|date',
            'active' => 'boolean',
        ], [
            'code.required' => 'សូមបញ្ចូលកូដ',
            'code.regex' => 'កូដប្រើបានតែអក្សរ A-Z លេខ - និង _',
            'code.unique' => 'កូដនេះមានរួចហើយ',
            'value.required' => 'សូមបញ្ចូលចំនួនបញ្ចុះ',
            'value.gt' => 'ចំនួនបញ្ចុះត្រូវធំជាង 0',
            'value.max' => 'ភាគរយមិនអាចលើស 100',
        ]);
        $data['min_total'] ??= 0;

        return $data;
    }

    private function present(Voucher $v): array
    {
        return [
            'id' => $v->id,
            'code' => $v->code,
            'type' => $v->type,
            'value' => $v->value,
            'label' => $v->label,
            'min_total' => $v->min_total,
            'max_discount' => $v->max_discount,
            'max_uses' => $v->max_uses,
            'used_count' => $v->used_count,
            'expires_at' => $v->expires_at?->toIso8601String(),
            'active' => $v->active,
        ];
    }
}
