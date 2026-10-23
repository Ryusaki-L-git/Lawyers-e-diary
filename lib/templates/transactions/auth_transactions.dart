import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Conditional import for Google Sign-In.
/// On Android, this uses the real google_sign_in plugin.
/// On Windows, this is replaced with a stub that throws [UnsupportedError].
/// The login screen already hides the Google Sign-In button on Windows.
import 'google_sign_in_stub.dart'
    if (dart.library.io) 'package:google_sign_in/google_sign_in.dart';

class AuthTransactions {
  AuthTransactions({FirebaseAuth? auth, GoogleSignIn? googleSignIn})
    : _auth = auth ?? FirebaseAuth.instance,
      _googleSignIn =
          googleSignIn ?? (Platform.isWindows ? null : GoogleSignIn());

  final FirebaseAuth _auth;
  final GoogleSignIn? _googleSignIn;

  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _saveLoginState();
    return credential;
  }

  Future<UserCredential?> signInWithGoogle() async {
    if (_googleSignIn == null) {
      throw UnsupportedError(
        'Google Sign-In is not available on this platform.',
      );
    }
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth?.idToken,
      accessToken: googleAuth?.accessToken,
    );
    final userCredential = await _auth.signInWithCredential(credential);
    await _saveLoginState();
    return userCredential;
  }

  Future<void> createAccount({
    required String email,
    required String password,
  }) async {
    await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Signs the user out of Firebase Authentication.
  ///
  /// The local session flag is cleared as well so it can never claim a
  /// signed-out user is still signed in. Firebase Authentication remains the
  /// source of truth for the session.
  Future<void> signOut() async {
    await _auth.signOut();
    await _clearLoginState();
  }

  Future<void> _saveLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
  }

  Future<void> _clearLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
  }
}
