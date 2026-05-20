import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:t2t_admin/controllers/auth_controller.dart';
import 'package:t2t_admin/widgets/neumorphic_button.dart';
import 'package:t2t_admin/widgets/neumorphic_text_field.dart';
import 'dashboard.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _deptCtrl = TextEditingController();
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
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _fadeAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    _iconRotationAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _iconController, curve: Curves.linear));

    _fadeController.forward();
    _slideController.forward();
    _iconController.repeat();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _deptCtrl.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _iconController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    EasyLoading.show(status: 'Creating account...');
    try {
      await _auth.registerAdminWithFirestore(
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
        department: _deptCtrl.text.trim(),
      );
      EasyLoading.dismiss();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } catch (e) {
      EasyLoading.dismiss();
      EasyLoading.showError(
        e is Exception ? e.toString() : 'Registration failed',
      );
    }
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
              top: size.height * 0.08,
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
              bottom: size.height * 0.15,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _slideAnim,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Logo
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
                                  child: const Icon(
                                    Icons.recycling,
                                    size: 40,
                                    color: Color(0xFF4CAF50),
                                  ),
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 24),

                          Text(
                            'Create Account',
                            style: GoogleFonts.outfit(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1B5E20),
                            ),
                          ),

                          const SizedBox(height: 8),

                          Text(
                            'Register for T2T',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: const Color(0xFF4E7C52),
                            ),
                          ),

                          const SizedBox(height: 40),

                          // Form card
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
                                    // Full name
                                    NeumorphicTextField(
                                      controller: _nameCtrl,
                                      hintText: 'Full Name',
                                      prefixIcon: const Icon(Icons.person_outlined),
                                      validator: (v) => (v == null || v.isEmpty) ? 'Enter your name' : null,
                                    ),

                                    const SizedBox(height: 20),

                                    // Email
                                    NeumorphicTextField(
                                      controller: _emailCtrl,
                                      hintText: 'Email',
                                      keyboardType: TextInputType.emailAddress,
                                      prefixIcon: const Icon(Icons.email_outlined),
                                      validator: (v) => (v == null || v.isEmpty) ? 'Enter email' : null,
                                    ),

                                    const SizedBox(height: 20),

                                    // Department
                                    NeumorphicTextField(
                                      controller: _deptCtrl,
                                      hintText: 'Department',
                                      prefixIcon: const Icon(Icons.business_outlined),
                                      validator: (v) => (v == null || v.isEmpty) ? 'Enter department' : null,
                                    ),

                                    const SizedBox(height: 20),

                                    // Password
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

                                    const SizedBox(height: 24),

                                    // Submit button
                                    NeumorphicPrimaryButton(
                                      label: 'Create Account',
                                      icon: Icons.person_add,
                                      onTap: _submit,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(
                              'Already have an account? Sign in',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: const Color(0xFF2E7D32),
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                                decorationColor: const Color(0xFF2E7D32),
                              ),
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
