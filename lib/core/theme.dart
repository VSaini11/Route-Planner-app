import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const kBlue = Color(0xFF2563EB);
const kNavy = Color(0xFF0F172A);
const kGreen = Color(0xFF10B981);
const kRed = Color(0xFFEF4444);
const kAmber = Color(0xFFF59E0B);

ThemeData buildTheme(Brightness b) {
  final scheme = ColorScheme.fromSeed(
    seedColor: kBlue,
    brightness: b,
    surface: b == Brightness.light ? Colors.white : const Color(0xFF1E293B),
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: b,
    visualDensity: VisualDensity.compact,
  );

  final textTheme = GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
    bodyColor: b == Brightness.light ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
    displayColor: b == Brightness.light ? const Color(0xFF0F172A) : Colors.white,
  );

  return base.copyWith(
    textTheme: textTheme,
    scaffoldBackgroundColor: b == Brightness.light ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      scrolledUnderElevation: 0,
      elevation: 0,
      backgroundColor: b == Brightness.light ? Colors.white : const Color(0xFF1E293B),
      titleTextStyle: GoogleFonts.plusJakartaSans(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: b == Brightness.light ? const Color(0xFF0F172A) : Colors.white,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: b == Brightness.light ? Colors.white : const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: b == Brightness.light ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
          width: 1,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 42),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        textStyle: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 42),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        textStyle: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w600),
        side: BorderSide(
          color: b == Brightness.light ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 62,
      elevation: 2,
      indicatorColor: kBlue.withValues(alpha: 0.14),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w700, color: kBlue);
        }
        return GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w500);
      }),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: b == Brightness.light ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      labelStyle: GoogleFonts.plusJakartaSans(fontSize: 13),
      hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: b == Brightness.light ? const Color(0xFFE2E8F0) : const Color(0xFF334155)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: b == Brightness.light ? const Color(0xFFE2E8F0) : const Color(0xFF334155)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kBlue, width: 1.5),
      ),
    ),
  );
}
