<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Notice;
use App\Models\TradeIn;
use App\Models\Voucher;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

// Trade-in: the customer's side (send, accept, decline, cancel) and the
// admin's (offer, refuse, complete when the old phone is in the shop)
class TradeInController extends Controller
{
    private const MAX_PHOTOS = 4;

    // ---------- Customer ----------

    public function mine(Request $request)
    {
        return TradeIn::where('user_id', $request->user()->id)
            ->with('wantedProduct:id,name')->latest()->latest('id')->get();
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'brand' => 'required|string|max:50',
            'model' => 'required|string|max:100',
            'storage' => 'nullable|string|max:20',
            'condition' => ['required', Rule::in(TradeIn::CONDITIONS)],
            'battery_health' => 'nullable|integer|min:1|max:100',
            'notes' => 'nullable|string|max:1000',
            'wanted_product_id' => 'nullable|integer|exists:products,id',
            'photos' => 'nullable|array|max:'.self::MAX_PHOTOS,
            'photos.*' => 'image|max:6144',
        ], [
            'brand.required' => 'សូមបញ្ចូលម៉ាក',
            'model.required' => 'សូមបញ្ចូលម៉ូដែល',
            'photos.max' => 'រូបភាពយ៉ាងច្រើន '.self::MAX_PHOTOS,
            'photos.*.image' => 'ឯកសារត្រូវតែជារូបភាព',
        ]);

        // Only a few open requests at a time
        $open = TradeIn::where('user_id', $request->user()->id)->whereIn('status', ['pending', 'offered'])->count();
        abort_if($open >= 3, 422, 'អ្នកមានសំណើរង់ចាំ 3 រួចហើយ សូមរង់ចាំការឆ្លើយតប');

        $photos = [];
        foreach ($request->file('photos', []) as $file) {
            $name = 'tradein_'.Str::random(20).'.'.$file->extension();
            $file->move(public_path('uploads'), $name);
            $photos[] = $name;
        }
        unset($data['photos']);

        $tradeIn = TradeIn::create($data + [
            'user_id' => $request->user()->id,
            'photos' => $photos,
            'status' => 'pending',
        ]);

        return response()->json($tradeIn->load('wantedProduct:id,name'), 201);
    }

    public function accept(Request $request, TradeIn $tradeIn)
    {
        return $this->customerMove($request, $tradeIn, ['offered'], 'accepted');
    }

    public function decline(Request $request, TradeIn $tradeIn)
    {
        return $this->customerMove($request, $tradeIn, ['offered'], 'declined');
    }

    public function cancel(Request $request, TradeIn $tradeIn)
    {
        return $this->customerMove($request, $tradeIn, ['pending', 'offered', 'accepted'], 'cancelled');
    }

    private function customerMove(Request $request, TradeIn $tradeIn, array $from, string $to)
    {
        abort_unless($tradeIn->user_id === $request->user()->id, 404);
        abort_unless(in_array($tradeIn->status, $from, true), 422, 'មិនអាចធ្វើបានក្នុងស្ថានភាពនេះទេ');
        $tradeIn->update(['status' => $to]);

        return $tradeIn->load('wantedProduct:id,name');
    }

    // ---------- Admin ----------

    public function index(Request $request)
    {
        $status = $request->query('status');

        return TradeIn::with(['user:id,name,email,phone', 'wantedProduct:id,name'])
            ->when($status, fn ($q) => $q->where('status', $status))
            ->latest()->latest('id')->get()
            ->each(fn ($t) => $t->user?->makeHidden(['avatar_url', 'google_account']));
    }

    // What the shop will pay (as credit) for the phone, after looking at it
    public function offer(Request $request, TradeIn $tradeIn)
    {
        abort_unless(in_array($tradeIn->status, ['pending', 'offered'], true), 422, 'មិនអាចផ្តល់តម្លៃក្នុងស្ថានភាពនេះទេ');
        $data = $request->validate([
            'offer_amount' => 'required|numeric|gt:0|max:10000',
            'admin_note' => 'nullable|string|max:500',
        ], ['offer_amount.required' => 'សូមបញ្ចូលតម្លៃ', 'offer_amount.gt' => 'តម្លៃត្រូវធំជាង 0']);

        $tradeIn->update($data + ['status' => 'offered']);
        Notice::tell($tradeIn->user_id, 'trade_in', 'តម្លៃ Trade-in: $'.number_format($tradeIn->offer_amount, 2),
            "ហាងផ្តល់តម្លៃសម្រាប់ {$tradeIn->brand} {$tradeIn->model} សូមចូលមើល ហើយយល់ព្រម ឬបដិសេធ", ['trade_in_id' => $tradeIn->id]);

        return $tradeIn->load(['user:id,name,email,phone', 'wantedProduct:id,name']);
    }

    // The shop won't take this phone
    public function reject(Request $request, TradeIn $tradeIn)
    {
        abort_unless(in_array($tradeIn->status, ['pending', 'offered', 'accepted'], true), 422, 'មិនអាចបដិសេធក្នុងស្ថានភាពនេះទេ');
        $data = $request->validate(['admin_note' => 'nullable|string|max:500']);
        $tradeIn->update(['status' => 'rejected', 'admin_note' => $data['admin_note'] ?? $tradeIn->admin_note]);
        Notice::tell($tradeIn->user_id, 'trade_in', 'Trade-in មិនត្រូវបានទទួល',
            "ហាងមិនអាចទទួល {$tradeIn->brand} {$tradeIn->model} បានទេ".($tradeIn->admin_note ? ": {$tradeIn->admin_note}" : ''), ['trade_in_id' => $tradeIn->id]);

        return $tradeIn->load(['user:id,name,email,phone', 'wantedProduct:id,name']);
    }

    // The old phone is in the shop: the agreed amount becomes a one-time code
    // only this customer can use, valid 90 days
    public function complete(TradeIn $tradeIn)
    {
        abort_unless($tradeIn->status === 'accepted', 422, 'អតិថិជនមិនទាន់យល់ព្រមតម្លៃនៅឡើយទេ');

        DB::transaction(function () use ($tradeIn) {
            do {
                $code = 'TRADE-'.strtoupper(Str::random(6));
            } while (Voucher::where('code', $code)->exists());

            Voucher::create([
                'code' => $code,
                'type' => 'fixed',
                'value' => $tradeIn->offer_amount,
                'min_total' => 0,
                'max_uses' => 1,
                'expires_at' => now()->addDays(90)->endOfDay(),
                'active' => true,
                'user_id' => $tradeIn->user_id,
            ]);
            $tradeIn->update(['status' => 'completed', 'voucher_code' => $code]);
            Notice::tell($tradeIn->user_id, 'trade_in', "កូដ Trade-in: {$code}",
                'ប្រើកូដនេះពេល Checkout ដើម្បីបញ្ចុះ $'.number_format($tradeIn->offer_amount, 2).' (90 ថ្ងៃ)', ['trade_in_id' => $tradeIn->id]);
        });

        return $tradeIn->fresh()->load(['user:id,name,email,phone', 'wantedProduct:id,name']);
    }
}
