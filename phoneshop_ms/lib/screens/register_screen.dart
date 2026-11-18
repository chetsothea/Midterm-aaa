import 'package:flutter/material.dart';
import '../data/api_service.dart';
import '../components/address_picker.dart';
import '../components/auth_ui.dart';
import '../components/common.dart';
import '../hooks/language.dart';
import '../theme/app_theme.dart';

// Returns the new User to the login screen when registration succeeds
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _phone = TextEditingController();
  // Built by AddressPicker (province → village + house/street); null until complete
  String? _address;
  bool _isLoading = false;

  void _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final user = await ApiService.register(
        _username.text.trim(),
        _email.text.trim(),
        _phone.text.trim(),
        _address!, // validate() above made sure every level is picked
        _password.text,
      );
      if (mounted) Navigator.pop(context, user);
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    for (final c in [_email, _username, _password, _confirm, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  // "① Account" — a numbered heading for each part of the form
  Widget _part(int step, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF101318), Color(0xFF3D7BFF)],
              ),
            ),
            child: Text(
              '$step',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
          ),
          Icon(icon, color: authAccent, size: 20),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: tr('Create your account'),
      subtitle: tr('Please fill in your information to get started.'),
      children: [
        Form(
          key: _formKey,
          // The phone's password manager can fill in and save the new account
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _part(1, trf('គណនី', 'Account'), Icons.person_outline),
                AuthField(
                  label: tr('Email Address'),
                  controller: _email,
                  hint: tr('Enter your email'),
                  icon: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  validator: (v) =>
                      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v!.trim())
                      ? null
                      : tr('Please enter a valid email'),
                ),
                AuthField(
                  label: tr('Username'),
                  controller: _username,
                  hint: tr('Choose a username'),
                  icon: Icons.person_outline,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newUsername],
                  validator: (v) =>
                      v!.trim().isEmpty ? tr('Please choose a username') : null,
                ),
                AuthField(
                  label: tr('Password'),
                  controller: _password,
                  hint: tr('Enter your password'),
                  icon: Icons.lock_outline,
                  password: true,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: (v) =>
                      v!.length < 6 ? tr('At least 6 characters') : null,
                ),
                // How strong the password is, while typing
                PasswordStrength(controller: _password),
                AuthField(
                  label: tr('Confirm Password'),
                  controller: _confirm,
                  hint: tr('Re-enter your password'),
                  icon: Icons.lock_outline,
                  password: true,
                  textInputAction: TextInputAction.next,
                  validator: (v) =>
                      v != _password.text ? tr('Passwords do not match') : null,
                ),
                const SizedBox(height: AppSpacing.xxs),
                _part(
                  2,
                  trf('ទំនាក់ទំនង និងអាសយដ្ឋាន', 'Contact and address'),
                  Icons.local_shipping_outlined,
                ),
                AuthField(
                  label: tr('Phone Number'),
                  controller: _phone,
                  hint: '+855 12 345 678',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  validator: (v) =>
                      v!.replaceAll(RegExp(r'[^0-9]'), '').length < 8
                      ? tr('Please enter a valid phone number')
                      : null,
                ),
                // Same label style as the fields above
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    tr('Address'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                AddressPicker(
                  radius: 22,
                  onChanged: (address) => _address = address,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        AuthButton(
          text: tr('Create Account'),
          loading: _isLoading,
          onPressed: _register,
        ),
        const SizedBox(height: 6),
        AuthSwitchLink(
          question: tr('Already have an account?'),
          action: tr('Sign in'),
          onTap: () => Navigator.pop(context),
        ),
      ],
    );
  }
}
