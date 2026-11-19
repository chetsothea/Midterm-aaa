import 'package:flutter/material.dart';
import '../components/common.dart';
import '../components/store_app_bar.dart';
import '../data/api_service.dart';
import '../hooks/cart.dart';
import '../hooks/language.dart';
import '../theme/app_theme.dart';
import 'privacy_screen.dart';

// The customer closes their own account. Says plainly what goes and what the
// shop keeps, then asks for the password (or "DELETE" for Google accounts).
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _form = GlobalKey<FormState>();
  final _input = TextEditingController();
  bool _busy = false;
  bool _hide = true;

  bool get _google => ApiService.currentUser?.googleAccount ?? false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ApiService.deleteAccount(
        password: _google ? '' : _input.text,
        confirm: _google ? _input.text.trim() : '',
      );
      Cart.instance.clear();
      if (!mounted) return;
      showMessage(
        context,
        trf('គណនីរបស់អ្នកត្រូវបានលុបហើយ', 'Your account was deleted'),
      );
      Navigator.of(context).popUntil((r) => r.isFirst); // back to the store
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _point(IconData icon, Color color, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: AppColors.text, height: 1.4),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.page,
      appBar: storeAppBar(title: Text(trf('លុបគណនី', 'Delete account'))),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          children: [
            const Icon(
              Icons.person_remove_outlined,
              size: 56,
              color: AppColors.red,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              trf(
                'លុបគណនីរបស់អ្នកជាអចិន្ត្រៃយ៍',
                'Delete your account for good',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _point(
              Icons.delete_outline,
              AppColors.red,
              trf(
                'នឹងលុប: គណនី ពាក្យសម្ងាត់ រូប Profile ទូរស័ព្ទ ♥ Cart ការវាយតម្លៃ មតិ Live សំណើ Trade-in (និងរូប) និងការជូនដំណឹង',
                'Deleted: your login, password, profile picture, ♥, cart, reviews, Live comments, trade-ins (with photos) and notifications',
              ),
            ),
            _point(
              Icons.receipt_long_outlined,
              AppColors.amber,
              trf(
                'ហាងរក្សាទុក Order ចាស់ៗ (ឈ្មោះ លេខទូរស័ព្ទ អាសយដ្ឋាន IMEI) សម្រាប់បញ្ជីគណនេយ្យ និងការធានា ប៉ុន្តែវាលែងភ្ជាប់នឹងគណនីណាទៀតហើយ',
                'The shop keeps past orders (name, phone, address, IMEI) for its accounts and warranties, no longer linked to any account',
              ),
            ),
            _point(
              Icons.block,
              AppColors.muted,
              trf(
                'មិនអាចយកមកវិញបានទេ។ កូដ Trade-in ដែលមិនទាន់ប្រើ ក៏នឹងបាត់ដែរ',
                "This can't be undone. Unused trade-in codes are lost too",
              ),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrivacyScreen()),
              ),
              child: Text(trf('អានគោលការណ៍ឯកជនភាព', 'Read the privacy policy')),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _input,
              obscureText: !_google && _hide,
              autofillHints: _google ? null : const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: _google
                    ? trf(
                        'វាយពាក្យ DELETE ដើម្បីបញ្ជាក់',
                        'Type DELETE to confirm',
                      )
                    : trf('ពាក្យសម្ងាត់របស់អ្នក', 'Your password'),
                prefixIcon: Icon(
                  _google ? Icons.keyboard_outlined : Icons.lock_outline,
                ),
                suffixIcon: _google
                    ? null
                    : IconButton(
                        tooltip: _hide
                            ? trf('បង្ហាញ', 'Show')
                            : trf('លាក់', 'Hide'),
                        icon: Icon(
                          _hide
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(() => _hide = !_hide),
                      ),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              validator: (v) {
                if (_google) {
                  return v!.trim().toUpperCase() == 'DELETE'
                      ? null
                      : trf('សូមវាយពាក្យ DELETE', 'Type DELETE');
                }
                return v!.isEmpty
                    ? trf('សូមបញ្ចូលពាក្យសម្ងាត់', 'Enter your password')
                    : null;
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: _busy ? null : _delete,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.red,
                minimumSize: const Size.fromHeight(52),
              ),
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.delete_forever),
              label: Text(trf('លុបគណនីរបស់ខ្ញុំ', 'Delete my account')),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(trf('ទេ ខ្ញុំនៅប្រើបន្ត', 'No, keep my account')),
            ),
          ],
        ),
      ),
    );
  }
}
