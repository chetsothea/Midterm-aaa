import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../components/common.dart';
import '../components/store_app_bar.dart';
import '../components/ux.dart';
import '../data/api_service.dart';
import '../hooks/language.dart';
import '../theme/app_theme.dart';

// Forgot password, in two steps: the e-mail gets a 6-digit code, then the code
// and a new password. Pops true when the password was changed.
class ForgotPasswordScreen extends StatefulWidget {
  final String email;

  const ForgotPasswordScreen({super.key, this.email = ''});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(
    text: widget.email.contains('@') ? widget.email : '',
  );
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _again = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  bool _hide = true;

  @override
  void dispose() {
    for (final c in [_email, _code, _password, _again]) {
      c.dispose();
    }
    super.dispose();
  }

  InputDecoration _input(
    String label,
    IconData icon, {
    String? helper,
    Widget? suffix,
  }) => InputDecoration(
    labelText: label,
    helperText: helper,
    helperMaxLines: 2,
    prefixIcon: Icon(icon),
    suffixIcon: suffix,
    filled: true,
    fillColor: AppColors.surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
  );

  Future<void> _sendCode() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      final message = await ApiService.requestPasswordCode(_email.text.trim());
      if (!mounted) return;
      setState(() => _codeSent = true);
      showMessage(context, message);
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      await ApiService.resetPassword(
        email: _email.text.trim(),
        code: _code.text.trim(),
        password: _password.text,
      );
      if (!mounted) return;
      Haptics.success();
      showMessage(
        context,
        trf(
          'បានកំណត់ពាក្យសម្ងាត់ថ្មី សូម Login',
          'Password changed, please log in',
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // No e-mail arriving: the shop can still help over Telegram
  Future<void> _telegram() async {
    try {
      final username =
          ((await ApiService.fetchMenu())['telegram'] ?? '') as String;
      if (username.isEmpty) throw tr('ហាងមិនទាន់បានកំណត់ Telegram');
      final opened = await launchUrl(
        Uri.parse('https://t.me/$username'),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw tr('មិនអាចបើក Telegram បានទេ');
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.page,
      appBar: storeAppBar(
        title: Text(trf('ភ្លេចពាក្យសម្ងាត់', 'Forgot password')),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          children: [
            Icon(
              _codeSent ? Icons.mark_email_read_outlined : Icons.lock_reset,
              size: 56,
              color: AppColors.accent,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _codeSent
                  ? trf(
                      'យើងបានផ្ញើលេខកូដ 6 ខ្ទង់ទៅ ${_email.text.trim()}។ សូមពិនិត្យ Inbox (និង Spam)។',
                      'We sent a 6-digit code to ${_email.text.trim()}. Check your inbox (and spam).',
                    )
                  : trf(
                      'បញ្ចូល Email ដែលអ្នកប្រើ Login ហើយយើងនឹងផ្ញើលេខកូដដើម្បីកំណត់ពាក្យសម្ងាត់ថ្មី។',
                      'Enter the e-mail you log in with and we\'ll send a code to set a new password.',
                    ),
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.text, height: 1.5),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _email,
              enabled: !_codeSent,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: _input('Email', Icons.email_outlined),
              validator: (v) =>
                  RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v!.trim())
                  ? null
                  : trf('Email មិនត្រឹមត្រូវ', 'Not a valid e-mail'),
            ),
            if (_codeSent) ...[
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _code,
                autofocus: true,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                style: const TextStyle(
                  fontSize: 22,
                  letterSpacing: 8,
                  fontWeight: FontWeight.w700,
                ),
                decoration: _input(
                  trf('លេខកូដ 6 ខ្ទង់', '6-digit code'),
                  Icons.pin_outlined,
                ),
                validator: (v) => v!.length == 6
                    ? null
                    : trf('លេខកូដមាន 6 ខ្ទង់', 'The code has 6 digits'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _password,
                obscureText: _hide,
                autofillHints: const [AutofillHints.newPassword],
                decoration: _input(
                  trf('ពាក្យសម្ងាត់ថ្មី', 'New password'),
                  Icons.lock_outline,
                  helper: trf('យ៉ាងតិច 6 តួ', 'At least 6 characters'),
                  suffix: IconButton(
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
                ),
                validator: (v) => v!.length < 6
                    ? trf('យ៉ាងតិច 6 តួ', 'At least 6 characters')
                    : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _again,
                obscureText: _hide,
                decoration: _input(
                  trf('វាយពាក្យសម្ងាត់ថ្មីម្តងទៀត', 'Type it again'),
                  Icons.lock_outline,
                ),
                validator: (v) => v != _password.text
                    ? trf(
                        'ពាក្យសម្ងាត់ទាំងពីរមិនដូចគ្នា',
                        "The passwords don't match",
                      )
                    : null,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: _busy ? null : (_codeSent ? _reset : _sendCode),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                minimumSize: const Size.fromHeight(52),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _codeSent
                          ? trf('កំណត់ពាក្យសម្ងាត់ថ្មី', 'Set new password')
                          : trf('ផ្ញើលេខកូដ', 'Send code'),
                    ),
            ),
            if (_codeSent)
              TextButton(
                onPressed: _busy ? null : _sendCode,
                child: Text(
                  trf('មិនបានទទួល? ផ្ញើម្តងទៀត', "Didn't get it? Send again"),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            TextButton.icon(
              onPressed: _telegram,
              icon: const Icon(Icons.send, size: 18),
              label: Text(
                trf(
                  'នៅតែមិនបាន? ទាក់ទងហាងតាម Telegram',
                  'Still stuck? Message the shop on Telegram',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
