import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'api_service.dart';
import '../hooks/language.dart';

// "Login with Google". The Google client ID lives in the API's .env (GOOGLE_CLIENT_ID)
// and is fetched at runtime, so turning Google login on needs no app change.
//
// Works on Android and Web. google_sign_in has no Windows version, so there
// (and whenever no client ID is set) Google login simply isn't offered.
class GoogleAuth {
  static Future<bool>? _ready;

  static bool get platformSupported =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  // True once Google sign-in is set up and can be offered; safe to call many times
  static Future<bool> ensureReady() => _ready ??= _init();

  // Tests start each case from scratch
  @visibleForTesting
  static void reset() => _ready = null;

  static Future<bool> _init() async {
    if (!platformSupported) return false;
    try {
      // Don't leave the Google button waiting forever if the API doesn't answer
      final clientId = await ApiService.fetchGoogleClientId().timeout(
        const Duration(seconds: 10),
      );
      if (clientId.isEmpty) return false;
      await GoogleSignIn.instance.initialize(
        // Web signs in with the web client directly; mobile asks Google for an
        // ID token addressed to it (the "server client"), which the API checks.
        clientId: kIsWeb ? clientId : null,
        serverClientId: kIsWeb ? null : clientId,
      );
      return true;
    } catch (e) {
      debugPrint('Google sign-in unavailable: $e');
      _ready = null; // allow another try later (e.g. the API was down)
      return false;
    }
  }

  // Every successful Google sign-in, from our button (mobile) or Google's (web)
  static Stream<GoogleSignInAuthenticationEvent> get events =>
      GoogleSignIn.instance.authenticationEvents;

  // Mobile: we draw the button and call [signIn]. Web: Google draws its own button.
  static bool get canUseOwnButton =>
      GoogleSignIn.instance.supportsAuthenticate();

  static Future<void> signIn() => GoogleSignIn.instance.authenticate();

  // Exchanges the Google account for one of our accounts (created on first use)
  static Future<void> finishSignIn(GoogleSignInAccount account) async {
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw ApiException(tr('Google មិនបានផ្ញើ ID token មកទេ'));
    }
    await ApiService.loginWithGoogle(idToken);
  }

  // So the next Google login shows the account chooser again
  static Future<void> signOut() async {
    if (_ready == null || !await _ready!) return;
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Already signed out of Google; nothing to do
    }
  }
}
