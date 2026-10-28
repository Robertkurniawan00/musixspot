import 'package:flutter/material.dart';

enum AppThemeMode {
  spotifyDark,
  amoledBlack,
  softPink,
}

class AppThemeColors {
  final String name;
  final String id;
  final AppThemeMode mode;
  final Color background;
  final Color cardSurface;
  final Color cardSurfaceHighlight;
  final Color miniPlayerBackground;
  final Color bottomNavBackground;
  final Color primary;
  final Color primaryLight;
  final Color textPrimary;
  final Color textSecondary;
  final Color textSubdued;
  final Color divider;
  final Color heartActive;
  final Color likedSongsGradientStart;
  final Color likedSongsGradientEnd;

  const AppThemeColors({
    required this.name,
    required this.id,
    required this.mode,
    required this.background,
    required this.cardSurface,
    required this.cardSurfaceHighlight,
    required this.miniPlayerBackground,
    required this.bottomNavBackground,
    required this.primary,
    required this.primaryLight,
    required this.textPrimary,
    required this.textSecondary,
    required this.textSubdued,
    required this.divider,
    required this.heartActive,
    required this.likedSongsGradientStart,
    required this.likedSongsGradientEnd,
  });

  // 1. Classic Spotify Dark
  static const AppThemeColors spotifyDark = AppThemeColors(
    name: 'MusicXSpot Dark',
    id: 'spotify_dark',
    mode: AppThemeMode.spotifyDark,
    background: Color(0xFF121212),
    cardSurface: Color(0xFF181818),
    cardSurfaceHighlight: Color(0xFF282828),
    miniPlayerBackground: Color(0xFF282828),
    bottomNavBackground: Color(0xFA121212),
    primary: Color(0xFF1DB954),
    primaryLight: Color(0xFF1ED760),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFB3B3B3),
    textSubdued: Color(0xFF727272),
    divider: Color(0xFF282828),
    heartActive: Color(0xFF1ED760),
    likedSongsGradientStart: Color(0xFF450AF5),
    likedSongsGradientEnd: Color(0xFF8E8EE5),
  );

  // 2. AMOLED Black (Pure Pitch Black #000000 for OLED screens)
  static const AppThemeColors amoledBlack = AppThemeColors(
    name: 'AMOLED Black',
    id: 'amoled_black',
    mode: AppThemeMode.amoledBlack,
    background: Color(0xFF000000),
    cardSurface: Color(0xFF0B0B0B),
    cardSurfaceHighlight: Color(0xFF161616),
    miniPlayerBackground: Color(0xFF141414),
    bottomNavBackground: Color(0xFF000000),
    primary: Color(0xFF1DB954),
    primaryLight: Color(0xFF1ED760),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFA5A5A5),
    textSubdued: Color(0xFF666666),
    divider: Color(0xFF181818),
    heartActive: Color(0xFF1ED760),
    likedSongsGradientStart: Color(0xFF240A34),
    likedSongsGradientEnd: Color(0xFF4C2A59),
  );

  // 3. Soft Pink (Aesthetic Midnight Plum with Soft Blossom Pink)
  static const AppThemeColors softPink = AppThemeColors(
    name: 'Soft Pink',
    id: 'soft_pink',
    mode: AppThemeMode.softPink,
    background: Color(0xFF150C13),
    cardSurface: Color(0xFF22131F),
    cardSurfaceHighlight: Color(0xFF331D2E),
    miniPlayerBackground: Color(0xFF2D1829),
    bottomNavBackground: Color(0xFA150C13),
    primary: Color(0xFFFF70A6),
    primaryLight: Color(0xFFFF85B3),
    textPrimary: Color(0xFFFFF0F6),
    textSecondary: Color(0xFFDCA9C2),
    textSubdued: Color(0xFF946F83),
    divider: Color(0xFF331D2E),
    heartActive: Color(0xFFFF70A6),
    likedSongsGradientStart: Color(0xFF8A2387),
    likedSongsGradientEnd: Color(0xFFE94057),
  );

  static AppThemeColors fromMode(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.spotifyDark:
        return spotifyDark;
      case AppThemeMode.amoledBlack:
        return amoledBlack;
      case AppThemeMode.softPink:
        return softPink;
    }
  }

  static AppThemeColors fromId(String id) {
    switch (id) {
      case 'amoled_black':
        return amoledBlack;
      case 'soft_pink':
        return softPink;
      default:
        return spotifyDark;
    }
  }
}

class SpotifyTheme {
  // Global current active theme colors
  static AppThemeColors current = AppThemeColors.spotifyDark;

  // Canonical Constants for const expressions
  static const Color spotifyGreen = Color(0xFF1DB954);
  static const Color spotifyGreenLight = Color(0xFF1ED760);
  static const Color background = Color(0xFF121212);
  static const Color cardSurface = Color(0xFF181818);
  static const Color cardSurfaceHighlight = Color(0xFF282828);
  static const Color miniPlayerBackground = Color(0xFF282828);
  static const Color bottomNavBackground = Color(0xFA121212);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color textSubdued = Color(0xFF727272);
  static const Color divider = Color(0xFF282828);
  static const Color heartActive = Color(0xFF1ED760);
  static const Color likedSongsGradientStart = Color(0xFF450AF5);
  static const Color likedSongsGradientEnd = Color(0xFF8E8EE5);

  static ThemeData getThemeData(AppThemeMode mode) {
    final colors = AppThemeColors.fromMode(mode);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: colors.background,
      primaryColor: colors.primary,
      canvasColor: colors.background,
      colorScheme: ColorScheme.dark(
        primary: colors.primary,
        secondary: colors.primaryLight,
        surface: colors.cardSurface,
        onPrimary: Colors.black,
        onSurface: colors.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: colors.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colors.bottomNavBackground,
        selectedItemColor: colors.textPrimary,
        unselectedItemColor: colors.textSecondary,
        selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      textTheme: TextTheme(
        headlineMedium: TextStyle(
          color: colors.textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.6,
        ),
        titleLarge: TextStyle(
          color: colors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        titleMedium: TextStyle(
          color: colors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: colors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: TextStyle(
          color: colors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
        bodySmall: TextStyle(
          color: colors.textSubdued,
          fontSize: 11,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  static ThemeData get darkTheme => getThemeData(current.mode);
}
