import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static FirebaseAuth get _auth => FirebaseAuth.instance;

  static Stream<User?> authStateChanges() => _auth.authStateChanges();

  static User? get currentUser => _auth.currentUser;

  static Future<UserCredential> signInAnonymously() =>
      _auth.signInAnonymously();

  static Future<void> signOut() => _auth.signOut();
}
