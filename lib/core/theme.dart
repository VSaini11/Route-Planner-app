import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const kPrimary = Color(0xFF3B82F6);      // Electric Vibrant Indigo/Blue
const kPrimaryDark = Color(0xFF1D4ED8);
const kAccent = Color(0xFF6366F1);       // Futuristic Violet
const kNavy = Color(0xFF0F172A);         // Deep Slate Dark
const kDarkSurface = Color(0xFF1E293B);  // Modern Dark Surface
const kGreen = Color(0xFF10B981);        // Emerald
const kRed = Color(0xFFEF4444);          // Rose Red
const kAmber = Color(0xFFF59E0B);        // Amber

// Backwards compatibility alias
const kBlue = kPrimary;

ThemeData buildTheme(Brightness b) {
  final isDark = b == Brightness.dark;

  final scheme = ColorScheme.fromSeed(
    seedColor: kPrimary,
    brightness: b,
    primary: kPrimary,
    onPrimary: Colors.white,
    primaryContainer: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE),
    onPrimaryContainer: isDark ? const Color(0xFFBFDBFE) : const Color(0xFF1E40AF),
    secondary: kAccent,
    surface: isDark ? kDarkSurface : Colors.white,
    onSurface: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
    surfaceContainerHighest: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: b,
    visualDensity: VisualDensity.standard,
  );

  final textTheme = GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
    bodyColor: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
    displayColor: isDark ? Colors.white : const Color(0xFF0F172A),
  );

  return base.copyWith(
    textTheme: textTheme,
    scaffoldBackgroundColor: isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      scrolledUnderElevation: 0,
      elevation: 0,
      backgroundColor: isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
      titleTextStyle: GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        color: isDark ? Colors.white : const Color(0xFF0F172A),
      ),
      iconTheme: IconThemeData(
        color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: isDark ? const Color(0xFF131D2E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 46),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        textStyle: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 46),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        textStyle: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
        side: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
          width: 1.2,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 70,
      elevation: 0,
      backgroundColor: isDark ? const Color(0xFF0E1626) : Colors.white,
      indicatorColor: kPrimary.withValues(alpha: 0.15),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: kPrimary,
          );
        }
        return GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
        );
      }),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w600),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      side: BorderSide.none,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? const Color(0xFF131D2E) : Colors.white,
      isDense: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      labelStyle: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
      ),
      hintStyle: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: kPrimary, width: 2),
      ),
    ),
  );
}
