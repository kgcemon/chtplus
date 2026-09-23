import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// A Google sign-in attempt that failed for a reason worth showing the user.
///
/// Cancelling is not a failure — that returns null instead, so the UI can stay
/// quiet when someone simply backs out of the account chooser.
class GoogleSignInFailure implements Exception {
  const GoogleSignInFailure(this.message, {this.detail});

  final String message;
  final String? detail;

  @override
  String toString() => message;
}

/// Wraps Google Sign-In so the rest of the app only deals with "give me an ID
/// token, or tell me why not".
///
/// The client id comes from `/api/app-config` (Admin → Settings → Google
/// Sign-In), the same value the website uses, and is passed as the
/// `serverClientId` so Google issues an ID token our backend can verify.
///
/// On Android this only works when the **same Google Cloud project that owns
/// that client id** also has an Android OAuth client registered for this app's
/// package name and signing-certificate SHA-1. Without it Google rejects the
/// request, which is by far the most common cause of a failure here.
class GoogleSignInService {
  GoogleSignInService._();

  static final GoogleSignInService instance = GoogleSignInService._();

  String? _initializedFor;

  Future<void> _ensureInitialized(String clientId) async {
    if (_initializedFor == clientId) return;
    try {
      await GoogleSignIn.instance.initialize(serverClientId: clientId);
      _initializedFor = clientId;
    } catch (error) {
      throw GoogleSignInFailure(
        'Google sign-in could not start on this device.',
        detail: '$error',
      );
    }
  }

  bool get isSupported => GoogleSignIn.instance.supportsAuthenticate();

  /// Returns the Google ID token to POST to `/api/auth/google`, or null when
  /// the person cancelled. Throws [GoogleSignInFailure] for anything else.
  Future<String?> idToken(String clientId) async {
    if (clientId.isEmpty) {
      throw const GoogleSignInFailure(
        'Google sign-in is not configured for this app yet.',
      );
    }
    if (!isSupported) {
      throw const GoogleSignInFailure(
        'This device cannot use Google sign-in. Please use your email and password.',
      );
    }

    await _ensureInitialized(clientId);

    try {
      final account = await GoogleSignIn.instance.authenticate();
      final token = account.authentication.idToken;
      if (token == null || token.isEmpty) {
        throw const GoogleSignInFailure(
          'Google did not return a sign-in token. Please try again.',
        );
      }
      return token;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;

      debugPrint('Google Sign-In failed: ${error.code} — ${error.description}');
      throw GoogleSignInFailure(
        _messageFor(error),
        detail: '${error.code}: ${error.description}',
      );
    } catch (error) {
      if (error is GoogleSignInFailure) rethrow;
      debugPrint('Google Sign-In failed: $error');
      throw GoogleSignInFailure(
        'Google sign-in failed. Please try again, or use your email and password.',
        detail: '$error',
      );
    }
  }

  /// `clientConfigurationError` is what Google returns when this app's package
  /// name + SHA-1 are not registered against the client id, so it gets a
  /// message an admin can act on rather than a generic failure.
  String _messageFor(GoogleSignInException error) {
    switch (error.code) {
      case GoogleSignInExceptionCode.clientConfigurationError:
        return 'Google sign-in is not set up for this app build yet. '
            'Please use your email and password for now.';
      case GoogleSignInExceptionCode.providerConfigurationError:
        return 'Google Play services are unavailable or out of date on this device.';
      case GoogleSignInExceptionCode.uiUnavailable:
        return 'The Google sign-in screen could not be opened. Please try again.';
      default:
        return 'Google sign-in failed. Please try again, or use your email and password.';
    }
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Signing out of the app does not depend on Google accepting this.
    }
  }
}
