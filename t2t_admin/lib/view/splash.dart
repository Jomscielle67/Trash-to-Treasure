import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:t2t_admin/controllers/auth_controller.dart';
import 'login.dart';
import 'dashboard.dart';
import 'package:t2t_admin/user_screens/dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _iconController;
  late final AnimationController _textController;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _iconRotationAnim;
  late final Animation<double> _iconScaleAnim;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  final AuthController _auth = AuthController();

  @override
  void initState() {
    super.initState();

    // Main container animation
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scaleAnim = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);

    // Icon animations
    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _iconRotationAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _iconController, curve: Curves.easeInOut),
    );
    _iconScaleAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _iconController, curve: Curves.bounceOut),
    );

    // Text animations
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeIn));
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOut));

    // Start animations sequentially
    _controller.forward();
    Timer(const Duration(milliseconds: 300), () => _iconController.forward());
    Timer(const Duration(milliseconds: 600), () => _textController.forward());

    // Check authentication state after splash animation
    Timer(const Duration(seconds: 4), () {
      _checkAuthAndNavigate();
    });
  }

  void _checkAuthAndNavigate() async {
    if (_auth.isAuthenticated) {
      final user = _auth.currentUser;
      if (user != null) {
        final adminDoc =
            await FirebaseFirestore.instance
                .collection('admins')
                .doc(user.uid)
                .get();
        if (!mounted) return;
        if (adminDoc.exists) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const DashboardScreen()),
          );
          return;
        }
        final studentDoc =
            await FirebaseFirestore.instance
                .collection('students')
                .doc(user.uid)
                .get();
        if (!mounted) return;
        if (studentDoc.exists) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const UserDashboardScreen()),
          );
          return;
        }
      }
    }
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  void dispose() {
    _controller.dispose();
    _iconController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      body: Stack(
          children: [
            // Background decorative elements
            Positioned(
              top: size.height * 0.1,
              right: -50,
              child: AnimatedBuilder(
                animation: _iconRotationAnim,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _iconRotationAnim.value * 2 * 3.14159,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFC3D4C5).withOpacity(0.4),
                      ),
                      child: const Icon(
                        Icons.recycling,
                        size: 60,
                        color: Color(0xFF4E7C52),
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              bottom: size.height * 0.2,
              left: -30,
              child: AnimatedBuilder(
                animation: _iconRotationAnim,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: -_iconRotationAnim.value * 1.5 * 3.14159,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFC3D4C5).withOpacity(0.4),
                      ),
                      child: const Icon(
                        Icons.eco,
                        size: 40,
                        color: Color(0xFF4E7C52),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Main content
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo container with icon and transformation effect
                  ScaleTransition(
                    scale: _scaleAnim,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0xFFC3D4C5),
                            offset: Offset(8, 8),
                            blurRadius: 20,
                            spreadRadius: 1,
                          ),
                          BoxShadow(
                            color: Colors.white,
                            offset: Offset(-8, -8),
                            blurRadius: 20,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Animated recycling icon
                          AnimatedBuilder(
                            animation: _iconScaleAnim,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _iconScaleAnim.value,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [
                                            const Color(0xFF4CAF50),
                                            const Color(0xFF2E7D32),
                                          ],
                                        ),
                                      ),
                                    ),
                                    AnimatedBuilder(
                                      animation: _iconRotationAnim,
                                      builder: (context, child) {
                                        return Transform.rotate(
                                          angle:
                                              _iconRotationAnim.value *
                                              2 *
                                              3.14159,
                                          child: Icon(
                                            Icons.recycling,
                                            size: 40,
                                            color: Colors.white,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          // App name with shimmer effect
                          Shimmer(
                            color: const Color(0xFF4CAF50),
                            child: Text(
                              'Trash 2 Treasure',
                              style: GoogleFonts.outfit(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1B5E20),
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Animated subtitle
                  SlideTransition(
                    position: _slideAnim,
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: Column(
                        children: [
                          Text(
                            'Welcome to Trash 2 Treasure',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1B5E20),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Transform waste into rewards',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: const Color(0xFF4E7C52),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Enhanced progress indicator
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: Column(
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.eco, color: Color(0xFF2E7D32), size: 16),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward, color: Color(0xFF2E7D32), size: 16),
                            SizedBox(width: 8),
                            Icon(Icons.diamond, color: Color(0xFF2E7D32), size: 16),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: 200,
                          height: 4,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            color: const Color(0xFFC3D4C5),
                          ),
                          child: const LinearProgressIndicator(
                            backgroundColor: Colors.transparent,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2E7D32)),
                            minHeight: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Bottom branding
            Positioned(
              bottom: 60,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Text(
                  'Making the world greener, one reward at a time',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF4E7C52),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          ],
        ),
    );
  }
}
