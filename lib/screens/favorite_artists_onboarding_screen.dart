import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/artist.dart';
import '../services/music_api_service.dart';
import '../services/deezer_api_service.dart';
import '../services/language_service.dart';
import '../providers/music_player_provider.dart';
import '../theme/spotify_theme.dart';
import 'main_navigation_screen.dart';

class FavoriteArtistsOnboardingScreen extends StatefulWidget {
  final bool isFromSettings;

  const FavoriteArtistsOnboardingScreen({
    super.key,
    this.isFromSettings = false,
  });

  @override
  State<FavoriteArtistsOnboardingScreen> createState() =>
      _FavoriteArtistsOnboardingScreenState();
}

class _FavoriteArtistsOnboardingScreenState
    extends State<FavoriteArtistsOnboardingScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedArtistIds = {};
  List<Artist> _displayedArtists = [];
  List<Artist> _allArtists = [];
  String _searchQuery = '';
  bool _isSearchingOnline = false;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _allArtists = List.from(MusicApiService.getComprehensiveArtists());
    _displayedArtists = List.from(_allArtists);
    _loadSavedFavorites();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList('favorite_artist_ids') ?? [];
      final savedData = prefs.getStringList('favorite_artists_data') ?? [];

      for (final raw in savedData) {
        try {
          final art = Artist.fromJson(json.decode(raw));
          if (!_allArtists.any((a) => a.id == art.id || a.name.toLowerCase() == art.name.toLowerCase())) {
            _allArtists.add(art);
          }
        } catch (_) {}
      }

      if (saved.isNotEmpty && mounted) {
        setState(() {
          _selectedArtistIds.addAll(saved);
          if (_searchQuery.isEmpty) {
            _reorderArtists();
          }
        });
      }
    } catch (_) {}
  }

  void _onSearch(String query) {
    _searchDebounce?.cancel();
    final cleanQ = query.trim();
    setState(() {
      _searchQuery = cleanQ.toLowerCase();
      if (_searchQuery.isEmpty) {
        _isSearchingOnline = false;
        _reorderArtists();
      } else {
        // 1. Instant local filter
        _displayedArtists = _allArtists.where((a) {
          final name = a.name.toLowerCase();
          final country = a.country.toLowerCase();
          final genre = a.genres.join(' ').toLowerCase();
          return name.contains(_searchQuery) ||
              country.contains(_searchQuery) ||
              genre.contains(_searchQuery);
        }).toList();
      }
    });

    // 2. Debounced online catalog search across 100M+ artists on Deezer
    if (cleanQ.length >= 2) {
      setState(() {
        _isSearchingOnline = true;
      });

      _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
        try {
          final onlineArtists = await DeezerApiService.searchArtists(cleanQ, limit: 15);
          if (mounted && _searchQuery == cleanQ.toLowerCase()) {
            setState(() {
              _isSearchingOnline = false;
              for (final art in onlineArtists) {
                if (!_allArtists.any((a) => a.id == art.id || a.name.toLowerCase() == art.name.toLowerCase())) {
                  _allArtists.add(art);
                }
                if (!_displayedArtists.any((a) => a.id == art.id || a.name.toLowerCase() == art.name.toLowerCase())) {
                  _displayedArtists.add(art);
                }
              }
            });
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _isSearchingOnline = false;
            });
          }
        }
      });
    } else {
      setState(() {
        _isSearchingOnline = false;
      });
    }
  }

  /// Dynamic Smart Re-shuffle:
  /// When user selects an artist, analyze country & genre to recommend
  /// related artists of the same style / region, bubbling them up!
  void _toggleArtist(Artist artist) {
    setState(() {
      if (_selectedArtistIds.contains(artist.id)) {
        _selectedArtistIds.remove(artist.id);
      } else {
        _selectedArtistIds.add(artist.id);
      }
      if (_searchQuery.isEmpty) {
        _reorderArtists(justTapped: artist);
      }
    });
  }

  void _reorderArtists({Artist? justTapped}) {
    // 1. Gather all currently selected artists
    final selectedArtists =
        _allArtists.where((a) => _selectedArtistIds.contains(a.id)).toList();

    // 2. Extract selected genres and countries for taste profiling
    final preferredGenres = <String>{};
    final preferredCountries = <String>{};
    for (final a in selectedArtists) {
      preferredGenres.addAll(a.genres.map((g) => g.toLowerCase()));
      preferredCountries.add(a.country.toLowerCase());
    }

    if (justTapped != null) {
      preferredGenres.addAll(justTapped.genres.map((g) => g.toLowerCase()));
      preferredCountries.add(justTapped.country.toLowerCase());
    }

    // 3. Separate remaining unselected artists and score them by affinity
    final unselected =
        _allArtists.where((a) => !_selectedArtistIds.contains(a.id)).toList();

    unselected.sort((a, b) {
      int scoreA = 0;
      int scoreB = 0;

      // Affinity bonus for same country/region (Indonesia, PH, TH, MY)
      if (preferredCountries.contains(a.country.toLowerCase())) scoreA += 5;
      if (preferredCountries.contains(b.country.toLowerCase())) scoreB += 5;

      // Affinity bonus for overlapping genres
      for (final g in a.genres) {
        if (preferredGenres.contains(g.toLowerCase())) scoreA += 3;
      }
      for (final g in b.genres) {
        if (preferredGenres.contains(g.toLowerCase())) scoreB += 3;
      }

      return scoreB.compareTo(scoreA);
    });

    // 4. Combine: Selected artists first, followed by dynamically smart-ranked artists
    _displayedArtists = [...selectedArtists, ...unselected];
  }

  Future<void> _finishOnboarding() async {
    final selected =
        _allArtists.where((a) => _selectedArtistIds.contains(a.id)).toList();

    // Persist to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('spotivibes_is_onboarded', true);
    await prefs.setStringList(
        'favorite_artist_ids', _selectedArtistIds.toList());
    await prefs.setStringList(
        'favorite_artists_data',
        selected.map((a) => json.encode(a.toJson())).toList());

    if (!mounted) return;

    // Train provider & UserBehaviorService
    final provider = context.read<MusicPlayerProvider>();
    provider.updateFavoriteArtists(selected);

    if (widget.isFromSettings) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil musik Anda berhasil disesuaikan!'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = _selectedArtistIds.length;
    final isDoneEnabled = count >= 6;
    final remaining = 6 - count;

    return Scaffold(
      backgroundColor: SpotifyTheme.background,
      body: Stack(
        children: [
          // Background Gradient (Screenshot 1: Rich purple/indigo gradient fading to black)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 380,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF6A1B9A), // Deep vibrant violet
                    Color(0xFF38006B),
                    Color(0xFF121212),
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top App Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      if (widget.isFromSettings || Navigator.canPop(context))
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                          onPressed: () => Navigator.pop(context),
                        )
                      else
                        const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          LanguageService.isIndonesian
                              ? 'Pilih minimal 6 artis'
                              : 'Select at least 6',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48), // Balance leading icon
                    ],
                  ),
                ),

                // Search Bar matching screenshot
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 10.0),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearch,
                      style: const TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w600),
                      cursorColor: SpotifyTheme.spotifyGreenLight,
                      decoration: InputDecoration(
                        hintText: LanguageService.isIndonesian ? 'Cari artis...' : 'Search',
                        hintStyle: const TextStyle(color: Color(0xFF6A6A6A), fontSize: 15, fontWeight: FontWeight.w500),
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF222222), size: 24),
                        suffixIcon: _isSearchingOnline
                            ? const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black87,
                                  ),
                                ),
                              )
                            : (_searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, color: Colors.black54, size: 20),
                                    onPressed: () {
                                      _searchController.clear();
                                      _onSearch('');
                                    },
                                  )
                                : null),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // 3-Column Grid matching Screenshot media_1791871313623_1be2b5de.png
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                    physics: const BouncingScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 20,
                      childAspectRatio: 0.76,
                    ),
                    itemCount: _displayedArtists.length,
                    itemBuilder: (ctx, idx) {
                      final artist = _displayedArtists[idx];
                      final isSelected = _selectedArtistIds.contains(artist.id);

                      return GestureDetector(
                        onTap: () => _toggleArtist(artist),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Circular Avatar with Selected Ring & Checkmark Badge
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 220),
                                  width: 94,
                                  height: 94,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? SpotifyTheme.spotifyGreenLight
                                          : Colors.transparent,
                                      width: 3.5,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: SpotifyTheme.spotifyGreenLight.withValues(alpha: 0.45),
                                              blurRadius: 12,
                                              spreadRadius: 2,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.all(isSelected ? 3.0 : 0.0),
                                    child: ClipOval(
                                      child: Builder(
                                        builder: (context) {
                                          final effectiveUrl = (artist.imageUrl.isNotEmpty &&
                                                  !artist.imageUrl.contains('d41d8cd98f00b204e9800998ecf8427e'))
                                              ? artist.imageUrl
                                              : (artist.topTracks.isNotEmpty
                                                  ? artist.topTracks.first.albumArtUrl
                                                  : artist.imageUrl);
                                          final fallbackCover = artist.topTracks.isNotEmpty
                                              ? artist.topTracks.first.albumArtUrl
                                              : null;

                                          Widget buildMonogram() {
                                            final initial = artist.name.trim().isNotEmpty
                                                ? artist.name.trim().substring(0, 1).toUpperCase()
                                                : '?';
                                            return Container(
                                              decoration: const BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                  colors: [Color(0xFF3E3E3E), Color(0xFF1E1E1E)],
                                                ),
                                              ),
                                              alignment: Alignment.center,
                                              child: Text(
                                                initial,
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 30,
                                                ),
                                              ),
                                            );
                                          }

                                          return CachedNetworkImage(
                                            imageUrl: effectiveUrl,
                                            fit: BoxFit.cover,
                                            placeholder: (_, _) => Container(
                                              color: const Color(0xFF282828),
                                              child: const Center(
                                                child: SizedBox(
                                                  width: 22,
                                                  height: 22,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white24,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            errorWidget: (_, _, _) {
                                              if (fallbackCover != null && fallbackCover != effectiveUrl) {
                                                return CachedNetworkImage(
                                                  imageUrl: fallbackCover,
                                                  fit: BoxFit.cover,
                                                  errorWidget: (_, _, _) => buildMonogram(),
                                                );
                                              }
                                              return buildMonogram();
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),

                                // Checkmark Badge when Selected
                                if (isSelected)
                                  Positioned(
                                    bottom: 0,
                                    right: 4,
                                    child: Container(
                                      width: 24,
                                      height: 24,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: SpotifyTheme.spotifyGreenLight,
                                      ),
                                      child: const Icon(
                                        Icons.check,
                                        color: Colors.black,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Artist Name
                            Text(
                              artist.name,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white70,
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Floating Bottom Button (Screenshot style)
          Positioned(
            left: 20,
            right: 20,
            bottom: 24,
            child: SafeArea(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: 1.0,
                child: GestureDetector(
                  onTap: isDoneEnabled ? _finishOnboarding : null,
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: isDoneEnabled
                          ? SpotifyTheme.spotifyGreenLight
                          : const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: isDoneEnabled
                          ? [
                              BoxShadow(
                                color: SpotifyTheme.spotifyGreenLight.withValues(alpha: 0.35),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        isDoneEnabled
                            ? (LanguageService.isIndonesian
                                ? 'Selesai ($count terpilih)'
                                : 'Done ($count selected)')
                            : (LanguageService.isIndonesian
                                ? 'Pilih $remaining artis lagi'
                                : 'Select $remaining more artists'),
                        style: TextStyle(
                          color: isDoneEnabled ? Colors.black : Colors.white38,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
