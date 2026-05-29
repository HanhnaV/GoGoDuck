import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> _initializeUserIfNew(String uid) async {
    final userRef = _firestore.doc('users/$uid');
    final snapshot = await userRef.get();

    if (!snapshot.exists) {
      await userRef.set({
        'balance': 1000,
        'total_wins': 0,
        'last_claim_time': '',
        'created_at': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> ensureUserInitialized() async {
    final user = _auth.currentUser;
    if (user != null) {
      await _initializeUserIfNew(user.uid);
    }
  }
}
