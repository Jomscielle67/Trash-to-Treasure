import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:t2t_admin/models/student_model.dart';
import 'package:t2t_admin/user_screens/dashboard_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String? _department;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  late final AnimationController _fadeController;
  late final AnimationController _slideController;
  late final AnimationController _iconController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _iconRotationAnim;

  final List<String> _departments = [
    'Accountancy, Business and Management',
    'College of Computer Studies',
    'College of Hospitality Management and Tourism',
    'College of Teacher Education',
    'College of Engineering',
    'Senior High School',
    'Food safety and security',
    'College of Fisheries',
    'College of Industrial Technology',
    'College of Agriculture',
    'College of Nursing',
    'Business Affairs Office',
  ];

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
    _fullNameController.dispose();
    _studentIdController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _iconController.dispose();
    super.dispose();
  }

  String _getPasswordStrength(String password) {
    if (password.length < 6) return 'Weak';
    if (password.length < 8) return 'Fair';

    bool hasUpper = password.contains(RegExp(r'[A-Z]'));
    bool hasLower = password.contains(RegExp(r'[a-z]'));
    bool hasDigits = password.contains(RegExp(r'[0-9]'));
    bool hasSpecial = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

    int score = 0;
    if (hasUpper) score++;
    if (hasLower) score++;
    if (hasDigits) score++;
    if (hasSpecial) score++;

    if (password.length >= 12 && score >= 3) return 'Very Strong';
    if (password.length >= 10 && score >= 3) return 'Strong';
    if (score >= 2) return 'Good';
    return 'Fair';
  }

  Color _getPasswordStrengthColor(String strength) {
    switch (strength) {
      case 'Weak':
        return Colors.red;
      case 'Fair':
        return Colors.orange;
      case 'Good':
        return Colors.blue;
      case 'Strong':
        return Colors.green;
      case 'Very Strong':
        return Colors.green.shade700;
      default:
        return Colors.grey;
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    EasyLoading.show(status: 'Creating account...');

    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      await credential.user?.updateDisplayName(_fullNameController.text.trim());

      final student = StudentModel(
        id: credential.user!.uid,
        fullName: _fullNameController.text.trim(),
        studentID: _studentIdController.text.trim(),
        email: _emailController.text.trim(),
        department: _department!,
      );

      await FirebaseFirestore.instance
          .collection('students')
          .doc(credential.user!.uid)
          .set(student.toMap());

      EasyLoading.dismiss();

      if (!mounted) return;
      _showSnackBar('Account created successfully! Welcome to T2T!');

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const UserDashboardScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      EasyLoading.dismiss();
      String message = 'Registration failed';

      switch (e.code) {
        case 'weak-password':
          message = 'The password provided is too weak.';
          break;
        case 'email-already-in-use':
          message = 'An account already exists with this email.';
          break;
        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;
        default:
          message = e.message ?? 'Registration failed';
      }

      if (!mounted) return;
      _showSnackBar(message, isError: true);
    } catch (e) {
      EasyLoading.dismiss();
      if (!mounted) return;
      _showSnackBar(
        'An unexpected error occurred. Please try again.',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final passwordStrength = _getPasswordStrength(_passwordController.text);

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
                        color: const Color(0xFF4CAF50).withOpacity(0.08),
                      ),
                      child: Icon(
                        Icons.recycling,
                        size: 60,
                        color: const Color(0xFF4CAF50).withOpacity(0.25),
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              bottom: size.height * 0.12,
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
                        color: const Color(0xFF4CAF50).withOpacity(0.08),
                      ),
                      child: Icon(
                        Icons.eco,
                        size: 40,
                        color: const Color(0xFF4CAF50).withOpacity(0.25),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Main content
            SafeArea(
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
                      children: [
                        // Back button row
                        Align(
                          alignment: Alignment.centerLeft,
                          child: GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(
                                color: Color(0xFFE8F5E9),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(color: Color(0xFFC3D4C5), offset: Offset(4, 4), blurRadius: 10),
                                  BoxShadow(color: Colors.white, offset: Offset(-4, -4), blurRadius: 10),
                                ],
                              ),
                              child: const Icon(
                                Icons.arrow_back,
                                color: Color(0xFF2E7D32),
                                size: 20,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Logo
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Color(0xFFC3D4C5), offset: Offset(4, 4), blurRadius: 12),
                              BoxShadow(color: Colors.white, offset: Offset(-4, -4), blurRadius: 12),
                            ],
                          ),
                          child: AnimatedBuilder(
                            animation: _iconRotationAnim,
                            builder: (context, child) {
                              return Transform.rotate(
                                angle: _iconRotationAnim.value * 2 * 3.14159,
                                child: const Icon(
                                  Icons.school,
                                  size: 40,
                                  color: Color(0xFF4CAF50),
                                ),
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 24),

                        Text(
                          'Join T2T',
                          style: GoogleFonts.outfit(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1B5E20),
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          'Create your student account',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: const Color(0xFF4E7C52),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Form card
                        Container(
                          decoration: const BoxDecoration(
                            color: Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.all(Radius.circular(20)),
                            boxShadow: [
                              BoxShadow(color: Color(0xFFC3D4C5), offset: Offset(6, 6), blurRadius: 15, spreadRadius: 1),
                              BoxShadow(color: Colors.white, offset: Offset(-6, -6), blurRadius: 15, spreadRadius: 1),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Full Name
                                  TextFormField(
                                    controller: _fullNameController,
                                    style: TextStyle(
                                      color: Colors.grey.shade800,
                                      fontSize: 16,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'Full Name',
                                      prefixIcon: const Icon(
                                        Icons.person_outlined,
                                        color: Color(0xFF4CAF50),
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF4CAF50),
                                          width: 2,
                                        ),
                                      ),
                                      labelStyle: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    validator:
                                        (v) =>
                                            (v == null || v.trim().isEmpty)
                                                ? 'Enter your full name'
                                                : null,
                                  ),
                                  const SizedBox(height: 16),

                                  // Student ID
                                  TextFormField(
                                    controller: _studentIdController,
                                    style: TextStyle(
                                      color: Colors.grey.shade800,
                                      fontSize: 16,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'Student ID',
                                      prefixIcon: const Icon(
                                        Icons.badge_outlined,
                                        color: Color(0xFF4CAF50),
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF4CAF50),
                                          width: 2,
                                        ),
                                      ),
                                      labelStyle: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    validator:
                                        (v) =>
                                            (v == null || v.trim().isEmpty)
                                                ? 'Enter your student ID'
                                                : null,
                                  ),
                                  const SizedBox(height: 16),

                                  // Email
                                  TextFormField(
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    style: TextStyle(
                                      color: Colors.grey.shade800,
                                      fontSize: 16,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'Email',
                                      prefixIcon: const Icon(
                                        Icons.email_outlined,
                                        color: Color(0xFF4CAF50),
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF4CAF50),
                                          width: 2,
                                        ),
                                      ),
                                      labelStyle: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty)
                                        return 'Enter your email';
                                      final re = RegExp(
                                        r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}",
                                      );
                                      if (!re.hasMatch(v))
                                        return 'Enter a valid email address';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  // Department dropdown
                                  DropdownButtonFormField<String>(
                                    value: _department,
                                    items:
                                        _departments
                                            .map(
                                              (d) => DropdownMenuItem(
                                                value: d,
                                                child: Text(
                                                  d,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.grey.shade800,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            )
                                            .toList(),
                                    onChanged:
                                        (v) => setState(() => _department = v),
                                    decoration: InputDecoration(
                                      labelText: 'Department',
                                      prefixIcon: const Icon(
                                        Icons.school_outlined,
                                        color: Color(0xFF4CAF50),
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF4CAF50),
                                          width: 2,
                                        ),
                                      ),
                                      labelStyle: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    validator:
                                        (v) =>
                                            (v == null || v.isEmpty)
                                                ? 'Select your department'
                                                : null,
                                    isExpanded: true,
                                    dropdownColor: const Color(0xFFE8F5E9),
                                    style: TextStyle(
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Password
                                  TextFormField(
                                    controller: _passwordController,
                                    obscureText: _obscurePassword,
                                    onChanged: (v) => setState(() {}),
                                    style: TextStyle(
                                      color: Colors.grey.shade800,
                                      fontSize: 16,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'Password',
                                      prefixIcon: const Icon(
                                        Icons.lock_outlined,
                                        color: Color(0xFF4CAF50),
                                      ),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                          color: const Color(0xFF4CAF50),
                                        ),
                                        onPressed:
                                            () => setState(
                                              () =>
                                                  _obscurePassword =
                                                      !_obscurePassword,
                                            ),
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF4CAF50),
                                          width: 2,
                                        ),
                                      ),
                                      labelStyle: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.isEmpty)
                                        return 'Enter a password';
                                      if (v.length < 6)
                                        return 'Password must be at least 6 characters';
                                      return null;
                                    },
                                  ),

                                  if (_passwordController.text.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Text(
                                          'Strength: ',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        Text(
                                          passwordStrength,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: _getPasswordStrengthColor(
                                              passwordStrength,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 16),

                                  // Confirm Password
                                  TextFormField(
                                    controller: _confirmPasswordController,
                                    obscureText: _obscureConfirmPassword,
                                    style: TextStyle(
                                      color: Colors.grey.shade800,
                                      fontSize: 16,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'Confirm Password',
                                      prefixIcon: const Icon(
                                        Icons.lock_outline,
                                        color: Color(0xFF4CAF50),
                                      ),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscureConfirmPassword
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                          color: const Color(0xFF4CAF50),
                                        ),
                                        onPressed:
                                            () => setState(
                                              () =>
                                                  _obscureConfirmPassword =
                                                      !_obscureConfirmPassword,
                                            ),
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF4CAF50),
                                          width: 2,
                                        ),
                                      ),
                                      labelStyle: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.isEmpty)
                                        return 'Confirm your password';
                                      if (v != _passwordController.text)
                                        return 'Passwords do not match';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 24),

                                  // Submit button
                                  SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: ElevatedButton(
                                      onPressed: _register,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF4CAF50,
                                        ),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        elevation: 3,
                                      ),
                                      child: Text(
                                        'Create Account',
                                        style: GoogleFonts.inter(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Already have account
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

                        const SizedBox(height: 8),

                        Text(
                          'By creating an account, you agree to our terms and conditions',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Bottom branding
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.eco,
                              color: const Color(0xFF4E7C52),
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Trash 2 Treasure',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFF4E7C52),
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
          ],
        ),
    );
  }
}
