import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:t2t_admin/models/admin_model.dart';

class AuthController {
  FirebaseAuth get _auth {
    if (Firebase.apps.isEmpty) {
      throw FirebaseException(
        plugin: 'firebase_core',
        message: 'No Firebase app has been created. Make sure you called Firebase.initializeApp()',
      );
    }
    return FirebaseAuth.instance;
  }

  User? get currentUser {
    try {
      return _auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  Future<UserCredential> signInWithEmail(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
      return cred;
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw Exception('Unknown error signing in');
    }
  }


  Future<UserCredential> registerWithEmail(String email, String password) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
      return cred;
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw Exception('Unknown error registering');
    }
  }

  /// Register admin and create Firestore document
  Future<UserCredential> registerAdminWithFirestore({
    required String name,
    required String email,
    required String password,
    String department = '',
  }) async {
    final cred = await registerWithEmail(email, password);
    final user = cred.user;
    if (user == null) throw Exception('User creation failed');
    final admin = AdminModel(
      id: user.uid,
      name: name,
      email: email,
      department: department,
    );
    await FirebaseFirestore.instance.collection('admins').doc(user.uid).set(admin.toMap());
    return cred;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Send a password reset email to the given address
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw Exception('Failed to send password reset email');
    }
  }

  /// Check if user is currently authenticated
  bool get isAuthenticated {
    try {
      return currentUser != null;
    } catch (e) {
      return false;
    }
  }

  /// Stream of authentication state changes
  Stream<User?> get authStateChanges {
    try {
      return _auth.authStateChanges();
    } catch (_) {
      return Stream.value(null);
    }
  }

  /// Initialize auth state listener (optional - for additional setup)
  Future<void> initializeAuth() async {
    try {
      // This can be used for any initial auth setup if needed
      await _auth.authStateChanges().first;
    } catch (e) {
      // Handle any initialization errors silently
    }
  }
}
