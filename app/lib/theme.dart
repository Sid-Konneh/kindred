import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Brand constants shared with the web app.
class K {
  static const brand = Color(0xFFEC3B63);
  static const g1 = Color(0xFFF2436B);
  static const g2 = Color(0xFFFF8A3D);
  static const grad = LinearGradient(colors: [g1, g2], begin: Alignment.topLeft, end: Alignment.bottomRight);
  static const good = Color(0xFF16A37B);
  static const superBlue = Color(0xFF2F8CFF);
  static const danger = Color(0xFFD92D4B);
  static const ink = Color(0xFF1D1A1F);
  static const palettes = [
    [Color(0xFFF2436B), Color(0xFFFF8A3D)],
    [Color(0xFF7B5CFA), Color(0xFFE8375A)],
    [Color(0xFF0E9F8E), Color(0xFF3B82F6)],
    [Color(0xFFF59E0B), Color(0xFFEF4444)],
    [Color(0xFFEC4899), Color(0xFF8B5CF6)],
    [Color(0xFF10B981), Color(0xFF0EA5E9)],
    [Color(0xFFF97316), Color(0xFFDB2777)],
    [Color(0xFF6366F1), Color(0xFF14B8A6)],
  ];
  static List<Color> paletteFor(String id) {
    var h = 0;
    for (final c in id.codeUnits) {
      h = (h * 31 + c) & 0xFFFFFFFF;
    }
    return palettes[h % palettes.length];
  }
}

/// Light/dark surface colours, including the silver used for loading skeletons.
class Pal {
  final Color bg, surface, surface2, text, muted, line, sk1, sk2, sk3;
  const Pal({required this.bg, required this.surface, required this.surface2, required this.text, required this.muted, required this.line, required this.sk1, required this.sk2, required this.sk3});
  static const light = Pal(
      bg: Color(0xFFFBF8F6), surface: Colors.white, surface2: Color(0xFFF4EFEC), text: K.ink, muted: Color(0xFF6F6A73),
      line: Color(0xFFECE6E2), sk1: Color(0xFFD8DBE0), sk2: Color(0xFFEDEFF2), sk3: Colors.white);
  static const dark = Pal(
      bg: Color(0xFF110F12), surface: Color(0xFF1B181D), surface2: Color(0xFF252127), text: Color(0xFFF5F1F3), muted: Color(0xFFA59FA8),
      line: Color(0xFF2E2930), sk1: Color(0xFF24252A), sk2: Color(0xFF32333A), sk3: Color(0xFF4A4C55));
  static Pal of(BuildContext c) => Theme.of(c).brightness == Brightness.dark ? dark : light;
}

TextStyle serif(double size, {Color? color, FontStyle? style, FontWeight weight = FontWeight.w600}) =>
    GoogleFonts.fraunces(fontSize: size, fontWeight: weight, color: color, fontStyle: style, letterSpacing: -0.02 * size, height: 1.1);

ThemeData buildTheme(Brightness b) {
  final p = b == Brightness.dark ? Pal.dark : Pal.light;
  final base = ThemeData(
    brightness: b,
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: K.brand, brightness: b, primary: K.brand, surface: p.surface),
    scaffoldBackgroundColor: p.bg,
  );
  OutlineInputBorder border(Color c) => OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c, width: 1.5));
  return base.copyWith(
    textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(bodyColor: p.text, displayColor: p.text),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: border(p.line),
      enabledBorder: border(p.line),
      focusedBorder: border(K.brand),
      errorBorder: border(K.danger),
      focusedErrorBorder: border(K.danger),
      hintStyle: TextStyle(color: p.muted),
    ),
    appBarTheme: AppBarTheme(backgroundColor: p.bg, elevation: 0, scrolledUnderElevation: 0, foregroundColor: p.text, centerTitle: false),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: K.ink,
      contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: p.surface, showDragHandle: true, surfaceTintColor: Colors.transparent),
    dividerColor: p.line,
  );
}
