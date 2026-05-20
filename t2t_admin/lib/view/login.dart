import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:t2t_admin/controllers/auth_controller.dart';
import 'package:t2t_admin/widgets/neumorphic_button.dart';
import 'package:t2t_admin/widgets/neumorphic_text_field.dart';
import 'dashboard.dart';
import 'package:t2t_admin/user_screens/dashboard_screen.dart';
import 'package:t2t_admin/user_screens/register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final AuthController _auth = AuthController();

  bool _obscure = true;
  
  late final AnimationController _fadeController;
  late final AnimationController _slideController;
  late final AnimationController _iconController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _iconRotationAnim;

  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _slideController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _iconController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));
    
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn)
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOut)
    );
    _iconRotationAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _iconController, curve: Curves.linear)
    );
    
    // Start animations
    _fadeController.forward();
    _slideController.forward();
    _iconController.repeat();
    
    // Check if user is already authenticated
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_auth.isAuthenticated) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _iconController.dispose();
    super.dispose();
  }

  Future<void> _showForgotPasswordDialog() async {
    final resetEmailCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFE8F5E9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Reset Password',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1B5E20),
          ),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter your email address and we\'ll send you a link to reset your password.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF4E7C52),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: resetEmailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'Email address',
                  prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF4E7C52)),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  hintStyle: GoogleFonts.inter(color: Colors.grey),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter your email';
                  final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                  if (!emailRegex.hasMatch(v.trim())) return 'Enter a valid email';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: const Color(0xFF4E7C52)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.of(ctx).pop();
              EasyLoading.show(status: 'Sending reset email...');
              try {
                await _auth.sendPasswordResetEmail(resetEmailCtrl.text.trim());
                EasyLoading.dismiss();
                if (!mounted) return;
                EasyLoading.showSuccess(
                  'Password reset email sent!\nCheck your inbox.',
                  duration: const Duration(seconds: 4),
                );
              } catch (e) {
                EasyLoading.dismiss();
                String message = 'Failed to send reset email.';
                if (e.toString().contains('user-not-found')) {
                  message = 'No account found with that email.';
                } else if (e.toString().contains('invalid-email')) {
                  message = 'Invalid email address.';
                } else if (e.toString().contains('too-many-requests')) {
                  message = 'Too many requests. Please try again later.';
                }
                EasyLoading.showError(message);
              } finally {
                resetEmailCtrl.dispose();
              }
            },
            child: Text(
              'Send Reset Link',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    EasyLoading.show(status: 'Signing in...');
    try {
      final cred = await _auth.signInWithEmail(_emailCtrl.text.trim(), _passCtrl.text);
      final uid = cred.user?.uid;
      if (uid == null) throw Exception('Authentication failed');
      final adminDoc = await FirebaseFirestore.instance.collection('admins').doc(uid).get();
      EasyLoading.dismiss();
      if (!mounted) return;
      if (adminDoc.exists) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      } else {
        final studentDoc = await FirebaseFirestore.instance.collection('students').doc(uid).get();
        if (!mounted) return;
        if (studentDoc.exists) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const UserDashboardScreen()),
          );
        } else {
          await _auth.signOut();
          EasyLoading.showError('Account not found. Please contact support.');
        }
      }
    } catch (e) {
      EasyLoading.dismiss();
      EasyLoading.showError(e is Exception ? e.toString() : 'Sign in failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      body: Stack(
        children:
          [
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
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _slideAnim,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Logo section
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: const BoxDecoration(
                              color: Color(0xFFE8F5E9),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0xFFC3D4C5),
                                  offset: Offset(6, 6),
                                  blurRadius: 15,
                                  spreadRadius: 1,
                                ),
                                BoxShadow(
                                  color: Colors.white,
                                  offset: Offset(-6, -6),
                                  blurRadius: 15,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: AnimatedBuilder(
                              animation: _iconRotationAnim,
                              builder: (context, child) {
                                return Transform.rotate(
                                  angle: _iconRotationAnim.value * 2 * 3.14159,
                                  child: Icon(
                                    Icons.recycling,
                                    size: 40,
                                    color: const Color(0xFF4CAF50),
                                  ),
                                );
                              },
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Welcome text
                          Text(
                            'Welcome Back',
                            style: GoogleFonts.outfit(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1B5E20),
                            ),
                          ),
                          
                          const SizedBox(height: 8),
                          
                          Text(
                            'Sign in to T2T',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: const Color(0xFF4E7C52),
                            ),
                          ),
                          
                          const SizedBox(height: 40),
                          
                          // Login form card
                          Container(
                            decoration: const BoxDecoration(
                              color: Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.all(Radius.circular(20)),
                              boxShadow: [
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
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  children: [
                                    // Email field
                                    NeumorphicTextField(
                                      controller: _emailCtrl,
                                      hintText: 'Email',
                                      keyboardType: TextInputType.emailAddress,
                                      prefixIcon: const Icon(Icons.email_outlined),
                                      validator: (v) => (v == null || v.isEmpty) ? 'Enter email' : null,
                                    ),
                                    
                                    const SizedBox(height: 20),
                                    
                                    // Password field
                                    NeumorphicTextField(
                                      controller: _passCtrl,
                                      hintText: 'Password',
                                      obscureText: _obscure,
                                      prefixIcon: const Icon(Icons.lock_outlined),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                        ),
                                        onPressed: () => setState(() => _obscure = !_obscure),
                                      ),
                                      validator: (v) => (v == null || v.length < 6) ? 'Password must be 6+ characters' : null,
                                    ),
                                    
                                    const SizedBox(height: 8),

                                    // Forgot password
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: _showForgotPasswordDialog,
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: Text(
                                          'Forgot password?',
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            color: const Color(0xFF2E7D32),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 16),
                                    
                                    // Sign in button
                                    NeumorphicPrimaryButton(
                                      label: 'Sign In',
                                      icon: Icons.login,
                                      onTap: _submit,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const RegisterScreen(),
                                ),
                              );
                            },
                            child: Text(
                              'New student? Register here',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: const Color(0xFF2E7D32),
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                                decorationColor: const Color(0xFF2E7D32),
                              ),
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Help text
                          Text(
                            'Need admin access? Contact your system administrator',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: const Color(0xFF4E7C52),
                            ),
                          ),
                          
                          const SizedBox(height: 40),
                          
                          // Bottom branding
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.eco, color: Color(0xFF2E7D32), size: 16),
                              SizedBox(width: 8),
                              Text(
                                'Trash 2 Treasure Admin',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF4E7C52),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

    );
  }
}
