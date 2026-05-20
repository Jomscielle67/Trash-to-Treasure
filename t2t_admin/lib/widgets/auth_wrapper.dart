import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:t2t_admin/controllers/auth_controller.dart';
import 'package:t2t_admin/view/login.dart';
import 'package:t2t_admin/view/dashboard.dart';

/// Wrapper widget that handles authentication state changes
/// and routes users to appropriate screens
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final AuthController authController = AuthController();
    
    return StreamBuilder<User?>(
      stream: authController.authStateChanges,
      builder: (context, snapshot) {
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // If user is authenticated, show dashboard
        if (snapshot.hasData && snapshot.data != null) {
          return const DashboardScreen();
        }

        // If user is not authenticated, show login
        return const LoginScreen();
      },
    );
  }
}