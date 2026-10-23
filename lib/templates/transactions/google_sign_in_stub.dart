class GoogleSignIn {
  const GoogleSignIn();

  Future<GoogleSignInAccount?> signIn() async {
    throw UnsupportedError('Google Sign-In is not available on this platform.');
  }

  Future<void> signOut() async {
    // No-op on unsupported platforms.
  }

  Future<void> disconnect() async {
    // No-op on unsupported platforms.
  }
}

class GoogleSignInAccount {
  final String id;
  final String email;
  final String? displayName;
  final Future<GoogleSignInAuthentication?> authentication;

  GoogleSignInAccount({
    required this.id,
    required this.email,
    this.displayName,
    required this.authentication,
  });
}

class GoogleSignInAuthentication {
  final String? idToken;
  final String? accessToken;

  GoogleSignInAuthentication({this.idToken, this.accessToken});
}
