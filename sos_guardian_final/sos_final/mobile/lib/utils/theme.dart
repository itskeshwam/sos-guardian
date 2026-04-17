import 'package:flutter/material.dart';

class T {
  // colours
  static const bg       = Color(0xFF0A0A12);
  static const card     = Color(0xFF13131F);
  static const cardHi   = Color(0xFF1C1C2E);
  static const border   = Color(0xFF252538);
  static const red      = Color(0xFFFF1744);
  static const redDark  = Color(0xFFB71C1C);
  static const redGlow  = Color(0x44FF1744);
  static const blue     = Color(0xFF2979FF);
  static const green    = Color(0xFF00E676);
  static const orange   = Color(0xFFFF9100);
  static const txt      = Color(0xFFFFFFFF);
  static const txt2     = Color(0xFF8E8EA0);
  static const txt3     = Color(0xFF44445A);

  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bg,
    colorScheme: const ColorScheme.dark(
      primary: red,
      secondary: blue,
      surface: card,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: bg,
      elevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: txt),
      titleTextStyle: TextStyle(
        color: txt,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: .3,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: card,
      selectedItemColor: red,
      unselectedItemColor: txt3,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontSize: 11),
    ),
    cardTheme: CardThemeData(
      color: card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: border),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? blue : txt3,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? blue.withAlpha(80)
            : border,
      ),
    ),
  );
}
