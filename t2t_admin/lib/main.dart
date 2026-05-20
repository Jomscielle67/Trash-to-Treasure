import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:t2t_admin/view/splash.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:t2t_admin/services/bgm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await BgmService.instance.start();
  runApp(const ProviderScope(child: MyApp()));
}

class AppTheme {
  // Neumorphism green-tinted palette
  static const Color neuBase       = Color(0xFFE8F5E9); // soft green base (same as bg)
  static const Color neuDark       = Color(0xFFC3D4C5); // dark shadow
  static const Color neuLight      = Color(0xFFFFFFFF); // light highlight
  static const Color primary       = Color(0xFF2E7D32); // deep green
  static const Color primaryLight  = Color(0xFF4CAF50); // medium green
  static const Color textDark      = Color(0xFF1B5E20); // dark green text
  static const Color textMid       = Color(0xFF4E7C52); // secondary text

  static ThemeData lightTheme() {
    final base = ThemeData.light();
    return base.copyWith(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: primary,
        onPrimary: Colors.white,
        surface: neuBase,
        onSurface: textDark,
      ),
      scaffoldBackgroundColor: neuBase,
      appBarTheme: const AppBarTheme(
        backgroundColor: neuBase,
        foregroundColor: textDark,
        elevation: 0,
        surfaceTintColor: neuBase,
        iconTheme: IconThemeData(color: primary),
      ),
      cardTheme: CardThemeData(
        color: neuBase,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: neuBase,
        selectedItemColor: primary,
        unselectedItemColor: textMid,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.outfit(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: textDark,
        ),
        headlineMedium: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textDark,
        ),
        headlineSmall: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textDark,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: textDark,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textMid,
        ),
      ),
      iconTheme: const IconThemeData(color: primary),
      dividerColor: neuDark,
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
    );
  }

  // Keep dark theme as fallback (system dark mode) but also green-tinted
  static ThemeData darkTheme() => lightTheme();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'T2T',
      builder: EasyLoading.init(),
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
    );
  }
}
