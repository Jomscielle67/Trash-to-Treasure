import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import '../models/student_model.dart';

/// Auth controller for student-facing screens.
class StudentAuthController {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  static User? get currentUser => _auth.currentUser;

  // Login method (used only by student login; unified login is in view/login.dart)
  static Future<bool> login(
    String email,
    String password,
    BuildContext context,
  ) async {
    try {
      EasyLoading.show(status: 'Signing in...');

      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (credential.user != null) {
        final doc =
            await _firestore
                .collection('students')
                .doc(credential.user!.uid)
                .get();

        if (!doc.exists) {
          await _auth.signOut();
          EasyLoading.dismiss();
          _showSnackBar(
            context,
            'Account not found. Please register first.',
            isError: true,
          );
          return false;
        }

        EasyLoading.dismiss();
        _showSnackBar(context, 'Welcome back!');
        return true;
      }

      EasyLoading.dismiss();
      return false;
    } on FirebaseAuthException catch (e) {
      EasyLoading.dismiss();
      String message = 'Login failed';

      switch (e.code) {
        case 'user-not-found':
          message = 'No user found with this email address.';
          break;
        case 'wrong-password':
          message = 'Incorrect password.';
          break;
        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;
        case 'user-disabled':
          message = 'This account has been disabled.';
          break;
        case 'too-many-requests':
          message = 'Too many failed attempts. Please try again later.';
          break;
        default:
          message = e.message ?? 'Login failed';
      }

      _showSnackBar(context, message, isError: true);
      return false;
    } catch (e) {
      EasyLoading.dismiss();
      _showSnackBar(
        context,
        'An unexpected error occurred. Please try again.',
        isError: true,
      );
      return false;
    }
  }

  // Logout method
  static Future<void> logout() async {
    try {
      await _auth.signOut();
    } catch (e) {
      // Handle logout error if needed
    }
  }

  // Check if user is logged in and is a student
  static Future<bool> isUserLoggedIn() async {
    final user = currentUser;
    if (user == null) return false;

    try {
      final doc = await _firestore.collection('students').doc(user.uid).get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  // Get current student data
  static Future<StudentModel?> getCurrentStudent() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestore.collection('students').doc(user.uid).get();
      if (doc.exists) {
        return StudentModel.fromMap(doc.data()!, doc.id);
      }
    } catch (e) {
      // Handle error
    }
    return null;
  }

  // Update student stats
  static Future<bool> updateStudentStats({
    required int bottlesToAdd,
    required int pointsToAdd,
  }) async {
    final user = currentUser;
    if (user == null) return false;

    try {
      await _firestore.collection('students').doc(user.uid).update({
        'bottles': FieldValue.increment(bottlesToAdd),
        'totalBottlesLifetime': FieldValue.increment(bottlesToAdd),
        'points': FieldValue.increment(pointsToAdd),
        'totalPointsEarned': FieldValue.increment(pointsToAdd),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  static void _showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
