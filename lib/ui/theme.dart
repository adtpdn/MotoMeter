import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AmoledTheme {
  static ThemeData get darkTheme {
    final baseTheme = ThemeData.dark();
    return baseTheme.copyWith(
      scaffoldBackgroundColor: Colors.black,
      primaryColor: Colors.blueAccent,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.robotoMono(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
      ),
      textTheme: GoogleFonts.robotoMonoTextTheme(baseTheme.textTheme).copyWith(
        displayLarge: GoogleFonts.robotoMono(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 80),
        titleLarge: GoogleFonts.robotoMono(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        bodyLarge: GoogleFonts.robotoMono(color: Colors.white.withOpacity(0.9), fontSize: 16),
        labelLarge: GoogleFonts.robotoMono(color: Colors.white.withOpacity(0.6), fontSize: 14, letterSpacing: 1.2),
      ),
      colorScheme: const ColorScheme.dark(
        primary: Colors.blueAccent,
        secondary: Colors.cyanAccent,
        surface: Color(0xFF121212),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E1E1E),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
