import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/music_player_provider.dart';
import '../theme/spotify_theme.dart';
import '../widgets/mini_player.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'library_screen.dart';
import '../services/language_service.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    SearchScreen(),
    LibraryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MusicPlayerProvider>();
    final hasActiveSong = provider.currentSong != null;

    return Scaffold(
      backgroundColor: SpotifyTheme.background,
      body: Stack(
        children: [
          // Current Selected Screen
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),

          // Bottom Navigation Gradient Overlay + MiniPlayer
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Floating MiniPlayer (if a song is active)
                if (hasActiveSong) const MiniPlayer(),

                // Bottom Navigation Bar with Spotify Styling
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Color(0xD0000000),
                        Colors.black,
                      ],
                    ),
                  ),
                  child: BottomNavigationBar(
                    currentIndex: _currentIndex,
                    onTap: (index) {
                      setState(() {
                        _currentIndex = index;
                      });
                    },
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    selectedItemColor: Colors.white,
                    unselectedItemColor: SpotifyTheme.textSecondary,
                    selectedFontSize: 11,
                    unselectedFontSize: 11,
                    items: [
                      BottomNavigationBarItem(
                        icon: const Icon(Icons.home_outlined),
                        activeIcon: const Icon(Icons.home_filled),
                        label: LanguageService.tr('nav_home'),
                      ),
                      BottomNavigationBarItem(
                        icon: const Icon(Icons.search_outlined),
                        activeIcon: const Icon(Icons.search),
                        label: LanguageService.tr('nav_search'),
                      ),
                      BottomNavigationBarItem(
                        icon: const Icon(Icons.library_music_outlined),
                        activeIcon: const Icon(Icons.library_music),
                        label: LanguageService.tr('nav_library'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
