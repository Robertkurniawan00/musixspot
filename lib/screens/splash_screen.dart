import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/spotify_logo.dart';
import 'main_navigation_screen.dart';
import 'favorite_artists_onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startSplashNavigation();
  }

  void _startSplashNavigation() {
    _timer = Timer(const Duration(milliseconds: 1400), () async {
      if (!mounted) return;
      try {
        final prefs = await SharedPreferences.getInstance();
        final isOnboarded = prefs.getBool('spotivibes_is_onboarded') ?? false;

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, _, _) => isOnboarded
                ? const MainNavigationScreen()
                : const FavoriteArtistsOnboardingScreen(),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, _, _) => const MainNavigationScreen(),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black, // Pure AMOLED Black
      body: Center(
        child: SpotifyLogo(size: 155, showText: false), // Clean authentic Spotify logo
      ),
    );
  }
}
