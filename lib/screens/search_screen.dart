import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/song.dart';
import '../models/category.dart';
import '../models/artist.dart';
import '../models/playlist.dart';
import '../services/music_api_service.dart';
import '../services/playlist_backup_service.dart';
import '../theme/spotify_theme.dart';
import '../widgets/browse_card.dart';
import '../widgets/song_tile.dart';
import 'artist_detail_screen.dart';
import 'playlist_detail_screen.dart';
import 'category_detail_screen.dart';
import '../services/language_service.dart';
import '../services/title_normalizer.dart';
import '../widgets/user_profile_avatar.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<Song> _searchResults = [];
  Artist? _matchedArtist;
  bool _isLoading = false;
  bool _hasSearched = false;
  String _activeFilter = 'Semua';
  bool _isFollowingMatchedArtist = false;
  late final List<BrowseCategory> _categories;
  Timer? _debounceTimer;
  int _searchToken = 0;

  @override
  void initState() {
    super.initState();
    _categories = MusicApiService.getBrowseCategories();
    _searchFocusNode.addListener(() {
      setState(() {});
    });
  }

  void _onSearch(String query) {
    _debounceTimer?.cancel();
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      _searchToken++;
      setState(() {
        _searchResults = [];
        _matchedArtist = null;
        _hasSearched = false;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    final currentToken = ++_searchToken;

    // Spotify link parsing directly via public oEmbed
    if (cleanQuery.contains('spotify.com/')) {
      PlaylistBackupService.importFromSpotifyUrl(cleanQuery).then((imported) {
        if (mounted && currentToken == _searchToken) {
          setState(() {
            _searchResults = imported?.songs ?? [];
            _matchedArtist = null;
            _isLoading = false;
          });
        }
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted || currentToken != _searchToken) return;

      // Search tracks and matching artist in parallel
      final futureTracks = MusicApiService.searchTracks(cleanQuery);
      final futureArtist = MusicApiService.searchArtist(cleanQuery);

      final results = await Future.wait([futureTracks, futureArtist]);

      if (mounted && currentToken == _searchToken) {
        final tracks = results[0] as List<Song>;
        final artist = results[1] as Artist?;

        // If an artist was matched, prioritize their authentic tracks at top of results
        final mergedTracks = <Song>[];
        final seenKeys = <String>{};

        void addTrack(Song s) {
          final cleanSong = TitleNormalizer.normalizeSong(s);
          final key = TitleNormalizer.dedupKey(cleanSong.artist, cleanSong.title);
          if (!seenKeys.contains(key)) {
            seenKeys.add(key);
            mergedTracks.add(cleanSong);
          }
        }

        if (artist != null) {
          for (final s in artist.topTracks) {
            addTrack(s);
          }
        }
        for (final s in tracks) {
          addTrack(s);
        }

        setState(() {
          _searchResults = mergedTracks;
          _matchedArtist = artist;
          _isLoading = false;
        });
      }
    });
  }

  void _cancelSearch() {
    _debounceTimer?.cancel();
    _searchToken++;
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _searchResults = [];
      _matchedArtist = null;
      _activeFilter = 'Semua';
      _isFollowingMatchedArtist = false;
      _hasSearched = false;
      _isLoading = false;
    });
  }

  List<Song> _buildThisIsSongs(Artist artist) {
    final songs = <Song>[];
    final seen = <String>{};
    void add(Song s) {
      if (!seen.contains(s.id)) {
        seen.add(s.id);
        songs.add(s);
      }
    }
    for (final s in artist.topTracks) {
      add(s);
    }
    for (final alb in artist.albums) {
      for (final s in alb.songs) {
        add(s);
      }
    }
    for (final s in MusicApiService.getFeaturedTracks()) {
      if (s.artist.toLowerCase().contains(artist.name.toLowerCase())) {
        add(s);
      }
    }
    return songs.isNotEmpty ? songs : artist.topTracks;
  }

  List<Song> _buildRadioSongs(Artist artist) {
    final songs = <Song>[];
    final seen = <String>{};
    void add(Song s) {
      if (!seen.contains(s.id)) {
        seen.add(s.id);
        songs.add(s);
      }
    }
    // Start with top tracks from target artist
    for (final s in artist.topTracks.take(2)) {
      add(s);
    }
    // Blend with hits from similar artists sharing genre or country
    final allArtists = MusicApiService.getComprehensiveArtists();
    for (final other in allArtists) {
      if (other.name.toLowerCase() != artist.name.toLowerCase()) {
        final shareGenre = other.genres.any((g) => artist.genres.contains(g));
        final shareCountry = other.country.toLowerCase() == artist.country.toLowerCase();
        if (shareGenre || shareCountry) {
          for (final s in other.topTracks.take(2)) {
            add(s);
          }
        }
      }
    }
    for (final s in artist.topTracks.skip(2)) {
      add(s);
    }
    return songs.take(25).toList();
  }

  List<Song> _buildMixSongs(Artist artist) {
    final songs = <Song>[];
    final seen = <String>{};
    void add(Song s) {
      if (!seen.contains(s.id)) {
        seen.add(s.id);
        songs.add(s);
      }
    }
    for (final s in artist.topTracks) {
      add(s);
    }
    final allArtists = MusicApiService.getComprehensiveArtists();
    for (final other in allArtists) {
      if (other.name.toLowerCase() != artist.name.toLowerCase()) {
        if (other.genres.any((g) => artist.genres.contains(g))) {
          for (final s in other.topTracks.take(1)) {
            add(s);
          }
        }
      }
    }
    return songs.take(20).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isFocused = _searchFocusNode.hasFocus;
    final hasQuery = _searchController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: SpotifyTheme.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Top App Bar & Search Input Box
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header when not searching (Screenshot 3: Profile avatar + "Cari" + Camera scanner)
                    if (!isFocused && !hasQuery) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              UserProfileAvatar(
                                size: 36,
                                onProfileUpdated: () {
                                  if (mounted) setState(() {});
                                },
                              ),
                              const SizedBox(width: 12),
                              Text(
                                LanguageService.tr('search_title'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.7,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 24),
                            tooltip: 'Pindai Kode MusicXSpot',
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Kamera siap memindai kode lagu MusicXSpot'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Search Input Row (1:1 with Spotify: dark pill when focused/searching, no Batal button)
                    Row(
                      children: [
                        if (isFocused || hasQuery) ...[
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                            onPressed: _cancelSearch,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Container(
                            height: (isFocused || hasQuery) ? 42 : 48,
                            decoration: BoxDecoration(
                              color: (isFocused || hasQuery)
                                  ? const Color(0xFF242424)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(
                                (isFocused || hasQuery) ? 8 : 6,
                              ),
                            ),
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              style: TextStyle(
                                color: (isFocused || hasQuery) ? Colors.white : Colors.black,
                                fontSize: 14,
                                fontWeight: (isFocused || hasQuery) ? FontWeight.w500 : FontWeight.w600,
                              ),
                              cursorColor: (isFocused || hasQuery)
                                  ? SpotifyTheme.spotifyGreenLight
                                  : Colors.black,
                              textInputAction: TextInputAction.search,
                              onSubmitted: _onSearch,
                              onChanged: (text) {
                                if (text.isEmpty) {
                                  _onSearch('');
                                } else {
                                  _onSearch(text);
                                }
                              },
                              decoration: InputDecoration(
                                hintText: LanguageService.tr('search_hint'),
                                hintStyle: TextStyle(
                                  color: (isFocused || hasQuery)
                                      ? const Color(0xFF757575)
                                      : const Color(0xFF6A6A6A),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                prefixIcon: (isFocused || hasQuery)
                                    ? null
                                    : const Icon(Icons.search, color: Color(0xFF121212), size: 24),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        visualDensity: VisualDensity.compact,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                        icon: const Icon(Icons.cancel, color: Color(0xFFB3B3B3), size: 18),
                                        onPressed: () {
                                          _searchController.clear();
                                          _onSearch('');
                                        },
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: (isFocused || hasQuery) ? 12 : 0,
                                  vertical: (isFocused || hasQuery) ? 10 : 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),

            // Content Area: 3 States:
            // 1. Loading State
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(
                    color: SpotifyTheme.spotifyGreenLight,
                  ),
                ),
              )
            // 2. Focused but query is empty -> Screenshot 3 ("Putar yang kamu suka")
            else if ((isFocused || _hasSearched) && !hasQuery)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.music_note_rounded, size: 54, color: Colors.white24),
                      const SizedBox(height: 16),
                      const Text(
                        'Putar yang kamu suka',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Cari artis, lagu, podcast, dan lainnya.',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              )
            // 3. Has Searched with Query Results -> Match Spotify 1:1
            else if (hasQuery) ...[
              // Top Artist Match (Exact Spotify layout if an artist was searched)
              if (_matchedArtist != null && (_activeFilter == 'Semua' || _activeFilter == 'Artis'))
                SliverToBoxAdapter(
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ArtistDetailScreen(artist: _matchedArtist!),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Row(
                        children: [
                          // Circular Artist Photo with reliable placeholder/fallback
                          ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: _matchedArtist!.imageUrl,
                              width: 62,
                              height: 62,
                              fit: BoxFit.cover,
                              placeholder: (_, _) => Container(
                                width: 62,
                                height: 62,
                                color: const Color(0xFF282828),
                                child: const Icon(Icons.person, color: Colors.white54, size: 30),
                              ),
                              errorWidget: (_, _, _) => Container(
                                width: 62,
                                height: 62,
                                color: const Color(0xFF282828),
                                child: const Icon(Icons.person, color: Colors.white54, size: 30),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          // Name & "Artis"
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        _matchedArtist!.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: -0.3,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (_matchedArtist!.isVerified) ...[
                                      const SizedBox(width: 6),
                                      const Icon(
                                        Icons.verified,
                                        color: Color(0xFF1ED760),
                                        size: 16,
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 3),
                                const Text(
                                  'Artis',
                                  style: TextStyle(
                                    color: Color(0xFFA7A7A7),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // "Ikuti" / "Mengikuti" capsule button
                          OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _isFollowingMatchedArtist = !_isFollowingMatchedArtist;
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: _isFollowingMatchedArtist ? Colors.white38 : Colors.white,
                                width: 1.2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              visualDensity: VisualDensity.compact,
                            ),
                            child: Text(
                              _isFollowingMatchedArtist ? 'Mengikuti' : 'Ikuti',
                              style: TextStyle(
                                color: _isFollowingMatchedArtist ? Colors.white70 : Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // "Menampilkan [Artist Name]" Horizontal Cards Row (Screenshot: This Is, Radio, Santai Sejenak)
              if (_matchedArtist != null && (_activeFilter == 'Semua' || _activeFilter == 'Playlist')) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Text(
                      'Menampilkan ${_matchedArtist!.name}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 200,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        // Card 1: "This Is [Artist]"
                        _buildArtistCard(
                          title: 'This Is ${_matchedArtist!.name}',
                          backgroundColor: const Color(0xFFE88A1A),
                          headerTag: 'THIS IS',
                          artistName: _matchedArtist!.name,
                          imageUrl: _matchedArtist!.imageUrl,
                          onTap: () {
                            final playlist = Playlist(
                              id: 'this_is_${_matchedArtist!.id}',
                              title: 'This Is ${_matchedArtist!.name}',
                              subtitle: 'Koleksi karya terbaik dan lagu populer dari ${_matchedArtist!.name}',
                              coverUrl: _matchedArtist!.imageUrl,
                              songs: _buildThisIsSongs(_matchedArtist!),
                            );
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PlaylistDetailScreen(playlist: playlist),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 14),
                        // Card 2: "Radio [Artist]"
                        _buildArtistRadioCard(
                          title: 'Radio ${_matchedArtist!.name}',
                          backgroundColor: const Color(0xFF8ADAB2),
                          artistName: _matchedArtist!.name,
                          imageUrl: _matchedArtist!.imageUrl,
                          onTap: () {
                            final playlist = Playlist(
                              id: 'radio_${_matchedArtist!.id}',
                              title: 'Radio ${_matchedArtist!.name}',
                              subtitle: 'Menampilkan ${_matchedArtist!.name} dan artis-artis serupa',
                              coverUrl: _matchedArtist!.imageUrl,
                              songs: _buildRadioSongs(_matchedArtist!),
                            );
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PlaylistDetailScreen(playlist: playlist),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 14),
                        // Card 3: "[Artist] Mix" (Authentic Spotify Artist Mix)
                        _buildCuratedMixCard(
                          title: '${_matchedArtist!.name} Mix',
                          imageUrl: _matchedArtist!.imageUrl,
                          onTap: () {
                            final playlist = Playlist(
                              id: 'mix_${_matchedArtist!.id}',
                              title: '${_matchedArtist!.name} Mix',
                              subtitle: 'Kombinasi lagu ${_matchedArtist!.name} dan hits seirama',
                              coverUrl: _matchedArtist!.imageUrl,
                              songs: _buildMixSongs(_matchedArtist!),
                            );
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PlaylistDetailScreen(playlist: playlist),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
              ],

              // Song List formatted as "Lagu • Artist" (Screenshot 2: direct list without section header)
              if (_searchResults.isNotEmpty) ...[
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final song = _searchResults[i];
                      return SongTile(
                        song: song,
                        playlistContext: _searchResults,
                        contextTitle: 'Hasil Pencarian "${_searchController.text}"',
                        showLaguPrefix: true, // Screenshot 2: "Lagu • Artist"
                      );
                    },
                    childCount: _searchResults.length,
                  ),
                ),
              ] else if (_matchedArtist == null)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: 48.0),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.search_off, size: 48, color: SpotifyTheme.textSecondary),
                          SizedBox(height: 12),
                          Text(
                            'Lagu tidak ditemukan',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Coba cari judul lagu atau nama artis lain.',
                            style: TextStyle(color: SpotifyTheme.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ]
            // 4. Default Explore View: Jelajahi Semua Categories (Screenshot 4 & 5)
            else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Text(
                    LanguageService.tr('search_browse_all'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.6,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final cat = _categories[i];
                      return BrowseCard(
                        category: cat,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CategoryDetailScreen(category: cat),
                            ),
                          );
                        },
                      );
                    },
                    childCount: _categories.length,
                  ),
                ),
              ),
            ],

            // Bottom Spacing for MiniPlayer & Bottom Nav
            const SliverToBoxAdapter(
              child: SizedBox(height: 120),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArtistCard({
    required String title,
    required Color backgroundColor,
    required String headerTag,
    required String artistName,
    required String imageUrl,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 145,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 145,
              height: 145,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Stack(
                children: [
                  // Top Header: Spotify graphic eq icon & THIS IS text
                  Positioned(
                    top: 10,
                    left: 10,
                    right: 10,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Icon(Icons.graphic_eq, color: Colors.black, size: 16),
                        Text(
                          headerTag,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Center: Square Artist Photo
                  Positioned(
                    top: 32,
                    left: 18,
                    right: 18,
                    bottom: 28,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => Container(color: Colors.black12),
                        errorWidget: (_, _, _) => Container(color: Colors.black12),
                      ),
                    ),
                  ),
                  // Bottom Artist Name
                  Positioned(
                    bottom: 8,
                    left: 8,
                    right: 8,
                    child: Text(
                      artistName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArtistRadioCard({
    required String title,
    required Color backgroundColor,
    required String artistName,
    required String imageUrl,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 145,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 145,
              height: 145,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Positioned(
                    top: 10,
                    left: 10,
                    right: 10,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(Icons.graphic_eq, color: Colors.black, size: 16),
                        Text(
                          'RADIO',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Concentric circle with avatar in center
                  Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black.withValues(alpha: 0.15), width: 3),
                    ),
                    alignment: Alignment.center,
                    child: ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        width: 66,
                        height: 66,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => Container(color: Colors.black12),
                        errorWidget: (_, _, _) => Container(color: Colors.black12),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    right: 8,
                    child: Text(
                      artistName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCuratedMixCard({
    required String title,
    required String imageUrl,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 145,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 145,
              height: 145,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(color: const Color(0xFF282828)),
                      errorWidget: (_, _, _) => Container(color: const Color(0xFF282828)),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.2),
                            Colors.black.withValues(alpha: 0.65),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      left: 10,
                      right: 10,
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
