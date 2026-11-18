<?php

namespace Tests\Feature;

use App\Models\PaymentAccount;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Tests\TestCase;

class PaymentAccountTest extends TestCase
{
    use RefreshDatabase;

    private function admin(): User
    {
        return User::create(['name' => 'Admin', 'email' => 'boss@example.com', 'password' => 'secret123', 'role' => 'admin']);
    }

    public function test_with_no_banks_saved_the_payment_page_shows_the_env_account(): void
    {
        config(['shop.payment.bank_name' => 'ABA Bank', 'shop.payment.account_number' => '111']);
        $this->getJson('/api/payment-info')
            ->assertOk()
            ->assertJsonPath('bank_name', 'ABA Bank')
            ->assertJsonCount(1, 'accounts')
            ->assertJsonPath('accounts.0.account_number', '111');
    }

    public function test_the_admin_adds_aba_and_acleda_with_their_qr_and_customers_see_both(): void
    {
        $admin = $this->admin();
        $aba = $this->actingAs($admin)->post('/api/admin/payment-accounts', [
            'bank_name' => 'ABA Bank', 'account_name' => 'PS168', 'account_number' => '000 111 222',
            'qr_image' => UploadedFile::fake()->image('aba.png', 300, 300),
        ], ['Accept' => 'application/json'])->assertCreated()->json();
        $this->actingAs($admin)->postJson('/api/admin/payment-accounts', [
            'bank_name' => 'ACLEDA Bank', 'account_name' => 'PS168', 'account_number' => '333 444',
        ])->assertCreated();

        $this->assertStringContainsString('/media/qr_', $aba['qr_image_url']);
        $this->assertFileExists(public_path('uploads/'.basename($aba['qr_image_url'])));

        $info = $this->getJson('/api/payment-info')->assertOk();
        $info->assertJsonCount(2, 'accounts')
            ->assertJsonPath('accounts.0.bank_name', 'ABA Bank')
            ->assertJsonPath('accounts.1.bank_name', 'ACLEDA Bank')
            ->assertJsonPath('accounts.1.qr_image_url', '')
            ->assertJsonPath('bank_name', 'ABA Bank'); // older apps still work

        // Removing a bank deletes its QR picture too
        $this->actingAs($admin)->deleteJson("/api/admin/payment-accounts/{$aba['id']}")->assertNoContent();
        $this->assertFileDoesNotExist(public_path('uploads/'.basename($aba['qr_image_url'])));
        $this->getJson('/api/payment-info')->assertJsonCount(1, 'accounts');
    }

    public function test_the_admin_can_change_the_number_and_replace_the_qr(): void
    {
        $admin = $this->admin();
        $id = $this->actingAs($admin)->postJson('/api/admin/payment-accounts', [
            'bank_name' => 'ACLEDA Bank', 'account_name' => 'PS168', 'account_number' => '1',
        ])->json('id');

        $updated = $this->actingAs($admin)->post("/api/admin/payment-accounts/$id", [
            'account_number' => '999 888',
            'qr_image' => UploadedFile::fake()->image('acleda.jpg'),
        ], ['Accept' => 'application/json'])->assertOk()->json();

        $this->assertSame('999 888', $updated['account_number']);
        $this->assertNotSame('', $updated['qr_image_url']);
        @unlink(public_path('uploads/'.basename($updated['qr_image_url'])));
    }

    public function test_customers_cannot_change_the_banks(): void
    {
        $customer = User::create(['name' => 'C', 'email' => 'c@example.com', 'password' => 'secret123', 'role' => 'user']);
        $this->actingAs($customer)->postJson('/api/admin/payment-accounts', [
            'bank_name' => 'Fake', 'account_name' => 'x', 'account_number' => '1',
        ])->assertForbidden();
        $this->assertSame(0, PaymentAccount::count());
    }
}
