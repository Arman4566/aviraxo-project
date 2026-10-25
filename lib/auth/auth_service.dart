import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService._();
  static final AuthService I = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// ✅ Web OAuth client id (client_type: 3) from google-services.json
  static const String _webClientId =
      "751621069614-e44f64p2sq2p6flpb5ouimvfbniiqgff.apps.googleusercontent.com";

  bool _googleInitialized = false;

  Stream<User?> authState() => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
  }) {
    return _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;

    // ✅ Required on Android for google_sign_in v7+ when using Credential Manager
    await GoogleSignIn.instance.initialize(serverClientId: _webClientId);
    _googleInitialized = true;
  }

  /// ✅ google_sign_in v7+ compatible
  Future<UserCredential> signInWithGoogle() async {
    await _ensureGoogleInitialized();

    // optional: clear previous session to avoid weird stuck state
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}

    final account = await GoogleSignIn.instance.authenticate();

    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw FirebaseAuthException(
        code: "missing-id-token",
        message: "Google Sign-In failed: idToken is null.",
      );
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    return _auth.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    await _auth.signOut();
  }
}
