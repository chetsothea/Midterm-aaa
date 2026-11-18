import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/models/user.dart';
import '../data/api_service.dart';
import '../data/google_auth.dart';
import '../hooks/language.dart';
import '../components/auth_ui.dart';
import '../components/common.dart';
import '../components/google_web_button_stub.dart'
    if (dart.library.js_interop) '../components/google_web_button_web.dart';
import 'admin/admin_home_screen.dart';
import '../theme/theme.dart';
import 'register_screen.dart';

// Call before anything that needs an account: buying needs one, browsing doesn't.
// Opens the login screen for guests and returns true once a customer is logged in.
// [reason] is shown on the login page; by default it's about buying.
Future<bool> requireLogin(BuildContext context, {String? reason}) async {
  if (ApiService.isLoggedIn) return true;
  final loggedIn = await Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (_) => LoginScreen(
        reason: reason ?? tr('សូម Login ឬបង្កើតគណនី ដើម្បីទិញទូរស័ព្ទ'),
      ),
    ),
  );
  return loggedIn == true;
}

class LoginScreen extends StatefulWidget {
  final String? reason;

  const LoginScreen({super.key, this.reason});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  // True once Google login is set up (GOOGLE_CLIENT_ID) on a platform that supports it.
  // The button is always shown; until then it explains why it can't be used yet.
  bool _googleReady = false;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _googleEvents;

  @override
  void initState() {
    super.initState();
    GoogleAuth.ensureReady().then((ready) {
      if (ready && mounted) _listenToGoogle();
    });
  }

  void _listenToGoogle() {
    if (_googleEvents != null) return;
    _googleEvents = GoogleAuth.events.listen(
      _onGoogleEvent,
      onError: (Object e) {
        if (mounted) showMessage(context, 'Google: $e', error: true);
      },
    );
    setState(() {
      _googleReady = true;
    });
  }

  void _onGoogleEvent(GoogleSignInAuthenticationEvent event) async {
    if (event is! GoogleSignInAuthenticationEventSignIn || _isLoading) return;
    setState(() {
      _isLoading = true;
    });
    try {
      await GoogleAuth.finishSignIn(event.user);
      if (mounted) _finish(ApiService.currentUser!);
    } catch (e) {
      if (mounted) {
        showMessage(
          context,
          trf('Login with Google បរាជ័យ: $e', 'Login with Google failed: $e'),
          error: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Google login can't be used here yet: say why instead of doing nothing
  void _googleUnavailable() async {
    if (!GoogleAuth.platformSupported) {
      showMessage(
        context,
        tr('Login with Google មិនគាំទ្រលើ Windows ទេ សូមប្រើ Android ឬ Chrome'),
        error: true,
      );
      return;
    }
    // Maybe the API was just down when the screen opened: try once more
    if (await GoogleAuth.ensureReady()) {
      if (!mounted) return;
      _listenToGoogle();
      if (GoogleAuth.canUseOwnButton) _googleSignIn();
      return;
    }
    if (mounted) {
      showMessage(
        context,
        tr('Login with Google មិនទាន់បានកំណត់នៅឡើយ (GOOGLE_CLIENT_ID)'),
        error: true,
      );
    }
  }

  // Mobile: opens Google's account chooser; the result comes back on GoogleAuth.events
  void _googleSignIn() async {
    try {
      await GoogleAuth.signIn();
    } on GoogleSignInException catch (e) {
      // The user just closed the account chooser
      if (e.code == GoogleSignInExceptionCode.canceled) return;
      if (mounted) {
        showMessage(
          context,
          'Google: ${e.description ?? e.code.name}',
          error: true,
        );
      }
    } catch (e) {
      if (mounted) showMessage(context, 'Google: $e', error: true);
    }
  }

  // Admins go to the admin panel; customers go back to where they were in the store
  void _finish(User user) {
    if (user.isAdmin) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AdminHomeScreen()),
        (_) => false,
      );
    } else {
      Navigator.pop(context, true);
    }
  }

  void _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final user = await ApiService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (mounted) _finish(user);
    } catch (e) {
      if (mounted) {
        showMessage(
          context,
          trf('Login បរាជ័យ: $e', 'Login failed: $e'),
          error: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _openRegister() async {
    final user = await Navigator.push<User>(
      context,
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
    if (user != null && mounted) _finish(user);
  }

  // There is no e-mail reset yet, so the admin resets it for the customer over Telegram
  void _forgotPassword() async {
    final contact = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Forgot password?')),
        content: Text(
          tr('សូមទាក់ទង Admin តាម Telegram ដើម្បីកំណត់ពាក្យសម្ងាត់ថ្មី។'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('បិទ')),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: authAccent),
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.send, size: 18),
            label: const Text('Telegram'),
          ),
        ],
      ),
    );
    if (contact != true) return;
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
  void dispose() {
    _googleEvents?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: tr('Login to your account'),
      subtitle: tr('Please enter your credentials to continue.'),
      children: [
        if (widget.reason != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              widget.reason!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: authAccent),
            ),
          ),
        // Labels stay above the fields (a hint disappears once you type), and the
        // phone's password manager can fill both in
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthField(
                  controller: _emailController,
                  label: tr('Email or username'),
                  hint: 'you@example.com',
                  icon: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [
                    AutofillHints.email,
                    AutofillHints.username,
                  ],
                  validator: (v) => v!.trim().isEmpty
                      ? tr('Please enter your email or username')
                      : null,
                ),
                AuthField(
                  controller: _passwordController,
                  label: tr('Password'),
                  hint: tr('Enter your password'),
                  icon: Icons.lock_outline,
                  password: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  validator: (v) =>
                      v!.isEmpty ? tr('Please enter your password') : null,
                  onSubmitted: (_) => _handleLogin(),
                ),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _forgotPassword,
            style: TextButton.styleFrom(foregroundColor: authAccent),
            child: Text(tr('Forgot password?'), style: TextStyle(fontSize: 15)),
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        AuthButton(
          text: tr('Sign In'),
          loading: _isLoading,
          onPressed: _handleLogin,
        ),
        const SizedBox(height: 6),
        AuthSwitchLink(
          question: tr("Don't have an account?"),
          action: tr('Create an account'),
          onTap: _openRegister,
        ),
        AuthDivider(text: tr('or continue with')),
        const SizedBox(height: 10),
        if (!_googleReady)
          GoogleButton(onPressed: _isLoading ? null : _googleUnavailable)
        else if (GoogleAuth.canUseOwnButton)
          GoogleButton(onPressed: _isLoading ? null : _googleSignIn)
        else
          // web: Google must draw the button itself; centred under the others
          Center(child: googleWebButton()),
      ],
    );
  }
}
