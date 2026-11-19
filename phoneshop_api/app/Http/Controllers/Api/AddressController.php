<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Address;
use Illuminate\Http\Request;

// The customer's other delivery addresses (the main one stays on the account)
class AddressController extends Controller
{
    private const MAX = 10;

    public function index(Request $request)
    {
        return Address::where('user_id', $request->user()->id)->orderBy('id')->get();
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'label' => 'required|string|max:40',
            'address' => 'required|string|max:500',
        ], ['label.required' => 'សូមដាក់ឈ្មោះ ឧ. ការងារ', 'address.required' => 'សូមបញ្ចូលអាសយដ្ឋាន']);

        $mine = Address::where('user_id', $request->user()->id);
        abort_if($mine->count() >= self::MAX, 422, 'រក្សាទុកបានយ៉ាងច្រើន '.self::MAX.' អាសយដ្ឋាន');
        // The same address twice is not a new one
        $same = (clone $mine)->where('address', $data['address'])->first();
        if ($same) {
            $same->update(['label' => $data['label']]);

            return $same;
        }

        return response()->json(Address::create($data + ['user_id' => $request->user()->id]), 201);
    }

    public function destroy(Request $request, Address $address)
    {
        abort_unless($address->user_id === $request->user()->id, 404);
        $address->delete();

        return response()->json(['message' => 'Deleted']);
    }
}
