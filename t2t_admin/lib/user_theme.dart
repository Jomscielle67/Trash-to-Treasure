import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Neumorphism green-tinted palette  (used by student-facing screens)
class AppColors {
  static const primary        = Color(0xFF2E7D32); // Deep green
  static const secondary      = Color(0xFF4CAF50); // Medium green
  static const neuBase        = Color(0xFFE8F5E9); // Soft green base (bg)
  static const neuDark        = Color(0xFFC3D4C5); // Dark neumorphic shadow
  static const neuLight       = Color(0xFFFFFFFF); // Light neumorphic highlight
  static const background     = Color(0xFFE8F5E9); // Same as neuBase
  static const surface        = Color(0xFFE8F5E9); // Surfaces match base
  static const textPrimary    = Color(0xFF1B5E20); // Dark green text
  static const textSecondary  = Color(0xFF4E7C52); // Muted green text
  static const error          = Color(0xFFFF5252);
  static const pointsYellow   = Color(0xFFFFD600);
  static const blueAccent     = Color(0xFF00B0FF);
}

final ThemeData userAppTheme = ThemeData(
  brightness: Brightness.light,
  scaffoldBackgroundColor: AppColors.neuBase,
  useMaterial3: true,
  colorScheme: ColorScheme.light(
    primary: AppColors.primary,
    secondary: AppColors.secondary,
    surface: AppColors.neuBase,
    error: AppColors.error,
    onPrimary: Colors.white,
    onSurface: AppColors.textPrimary,
  ),
  textTheme: TextTheme(
    displayLarge: GoogleFonts.poppins(
      color: AppColors.textPrimary,
      fontSize: 34,
      fontWeight: FontWeight.w700,
    ),
    displayMedium: GoogleFonts.poppins(
      color: AppColors.textPrimary,
      fontSize: 24,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: GoogleFonts.inter(
      color: AppColors.textSecondary,
      fontSize: 16,
      fontWeight: FontWeight.w400,
    ),
    bodyMedium: GoogleFonts.inter(
      color: AppColors.textSecondary,
      fontSize: 14,
      fontWeight: FontWeight.w400,
    ),
    labelLarge: GoogleFonts.inter(
      color: AppColors.textPrimary,
      fontSize: 12,
      fontWeight: FontWeight.w600,
    ),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.neuBase,
    elevation: 0,
    surfaceTintColor: AppColors.neuBase,
    centerTitle: false,
    titleTextStyle: TextStyle(
        color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
    iconTheme: IconThemeData(color: AppColors.primary),
  ),
  cardColor: AppColors.neuBase,
  cardTheme: const CardThemeData(
    color: AppColors.neuBase,
    elevation: 0,
    margin: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      elevation: 0,
    ),
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: AppColors.neuBase,
    selectedItemColor: AppColors.primary,
    unselectedItemColor: AppColors.textSecondary,
    elevation: 0,
    type: BottomNavigationBarType.fixed,
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: AppColors.secondary,
    foregroundColor: Colors.white,
    elevation: 0,
  ),
  iconTheme: const IconThemeData(color: AppColors.primary),
);
