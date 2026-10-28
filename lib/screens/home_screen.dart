import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/music_player_provider.dart';
import '../theme/spotify_theme.dart';
import '../widgets/album_card.dart';
import '../models/artist.dart';
import '../services/music_api_service.dart';
import '../services/language_service.dart';
import '../widgets/theme_picker_sheet.dart';
import '../widgets/user_profile_avatar.dart';
import 'artist_detail_screen.dart';
import 'playlist_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedRegion = 'all';
  List<Artist> _myFavoriteArtists = [];

  @override
  void initState() {
    super.initState();
    _loadUserFavoriteArtists();
  }

  Future<void> _loadUserFavoriteArtists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList('favorite_artist_ids') ?? [];
      final customData = prefs.getStringList('favorite_artists_data') ?? [];

      final Map<String, Artist> artistMap = {};
      // 1. Add all standard curated artists
      for (final a in MusicApiService.getComprehensiveArtists()) {
        artistMap[a.id] = a;
      }
      // 2. Add dynamically searched & selected artists
      for (final raw in customData) {
        try {
          final a = Artist.fromJson(json.decode(raw));
          artistMap[a.id] = a;
        } catch (_) {}
      }

      if (ids.isNotEmpty) {
        final List<Artist> selected = [];
        for (final id in ids) {
          if (artistMap.containsKey(id)) {
            selected.add(artistMap[id]!);
          }
        }
        if (mounted) {
          setState(() {
            _myFavoriteArtists = selected;
          });
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MusicPlayerProvider>();
    final playlists = provider.playlists;
    final recents = provider.recentlyPlayed;
    final allArtists = MusicApiService.getComprehensiveArtists();
    final popularReleases = provider.popularReleases;
    final nostalgiaPlaylists = provider.nostalgiaPlaylists;
    final nostalgiaTracks = provider.nostalgiaTracks;
    final kdramaPlaylists = provider.kdramaPlaylists;
    final animePlaylists = provider.animePlaylists;
    final personalizedPlaylists = provider.personalizedPlaylists;
    final trendingTracks = MusicApiService.getTrendingByRegion(_selectedRegion);

    return Scaffold(
      backgroundColor: SpotifyTheme.background,
      body: RefreshIndicator(
        color: SpotifyTheme.spotifyGreen,
        backgroundColor: SpotifyTheme.cardSurface,
        onRefresh: () => provider.refreshDynamicCatalog(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
          // ── Spotify Top Header with Profile Avatar (K) & Filter Pills (Screenshot 1) ──
          SliverAppBar(
            floating: true,
            pinned: false,
            backgroundColor: SpotifyTheme.background.withValues(alpha: 0.95),
            elevation: 0,
            titleSpacing: 16,
            title: Row(
              children: [
                // Circular Profile Avatar
                UserProfileAvatar(
                  size: 36,
                  onProfileUpdated: () async {
                    await _loadUserFavoriteArtists();
                    if (mounted) setState(() {});
                  },
                ),
                const SizedBox(width: 12),

                // Filter Pills [Semua] [Musik] [Podcast]
                Expanded(
                  child: _buildFilterPills(provider),
                ),

                // Theme / Settings Action
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.palette_outlined, color: Colors.white, size: 21),
                  tooltip: LanguageService.tr('settings_title'),
                  onPressed: () async {
                    ThemePickerSheet.show(context);
                    await _loadUserFavoriteArtists();
                  },
                ),
              ],
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),

                  // ── SECTION 1: REGIONAL TRENDING HIT TRACKS (Recommendation based on Region) ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionHeader(LanguageService.tr('home_trending_region')),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1DB954).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFF1DB954).withValues(alpha: 0.35),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.trending_up, color: Color(0xFF1DB954), size: 14),
                            SizedBox(width: 4),
                            Text(
                              'TRENDING',
                              style: TextStyle(
                                color: Color(0xFF1DB954),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    LanguageService.isIndonesian
                        ? 'Lagu paling hits di Asia Tenggara & Global berdasarkan region'
                        : 'Top trending hits across Southeast Asia & Global by region',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  const SizedBox(height: 12),

                  // Region Selector Pills
                  _buildRegionSelector(),
                  const SizedBox(height: 14),

                  // Regional Tracks Carousel
                  SizedBox(
                    height: 205,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: trendingTracks.length,
                      itemBuilder: (ctx, i) {
                        final song = trendingTracks[i];
                        return AlbumCard(
                          title: song.title,
                          subtitle: song.artist,
                          imageUrl: song.albumArtUrl,
                          onTap: () {
                            provider.playSong(
                              song,
                              queue: trendingTracks,
                              contextTitle: '${LanguageService.tr('home_trending_region')} (${_getRegionName(_selectedRegion)})',
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── SECTION 2: BERDASARKAN ARTIS PILIHANMU (User Favorite Artists Picks) ──
                  if (_myFavoriteArtists.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionHeader(LanguageService.tr('home_favorite_artists_picks')),
                        GestureDetector(
                          onTap: () => ThemePickerSheet.show(context),
                          child: const Icon(Icons.edit_note_rounded, color: Colors.white54, size: 22),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      LanguageService.isIndonesian
                          ? 'Disesuaikan dengan penyanyi favorit yang kamu pilih'
                          : 'Customized based on your favorite artists selection',
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 195,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _myFavoriteArtists.length,
                        itemBuilder: (ctx, i) {
                          final artist = _myFavoriteArtists[i];
                          return AlbumCard(
                            title: artist.name,
                            subtitle: artist.country,
                            imageUrl: artist.imageUrl,
                            isCircular: true,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ArtistDetailScreen(artist: artist),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],

                  // ── SECTION 3: Artis Populer (Southeast Asia & Global Icons) ──
                  _buildSectionHeader(LanguageService.isIndonesian ? 'Artis populer' : 'Popular artists'),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 195,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: allArtists.length,
                      itemBuilder: (ctx, i) {
                        final artist = allArtists[i];
                        return AlbumCard(
                          title: artist.name,
                          subtitle: artist.country,
                          imageUrl: artist.imageUrl,
                          isCircular: true,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ArtistDetailScreen(artist: artist),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── SECTION 4: Album dan single populer ──
                  _buildSectionHeader(LanguageService.isIndonesian ? 'Album dan single populer' : 'Popular albums & singles'),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 205,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: popularReleases.length,
                      itemBuilder: (ctx, i) {
                        final release = popularReleases[i];
                        return AlbumCard(
                          title: release.title,
                          subtitle: release.subtitle,
                          imageUrl: release.coverUrl,
                          playlist: release,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PlaylistDetailScreen(playlist: release),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── SECTION 5: Nostalgia & Kenangan Terindah ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionHeader(LanguageService.tr('home_nostalgia')),
                      const Icon(Icons.history_toggle_off, color: Colors.white54, size: 20),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    LanguageService.isIndonesian
                        ? 'Karya emas legendaris yang selalu menemani perjalanan hidupmu'
                        : 'Timeless classics that walk with you through every memory',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 205,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: nostalgiaPlaylists.length + nostalgiaTracks.length,
                      itemBuilder: (ctx, i) {
                        if (i < nostalgiaPlaylists.length) {
                          final pl = nostalgiaPlaylists[i];
                          return AlbumCard(
                            title: pl.title,
                            subtitle: pl.subtitle,
                            imageUrl: pl.coverUrl,
                            playlist: pl,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PlaylistDetailScreen(playlist: pl),
                                ),
                              );
                            },
                          );
                        } else {
                          final song = nostalgiaTracks[i - nostalgiaPlaylists.length];
                          return AlbumCard(
                            title: song.title,
                            subtitle: song.artist,
                            imageUrl: song.albumArtUrl,
                            onTap: () {
                              provider.playSong(song, queue: nostalgiaTracks, contextTitle: LanguageService.tr('home_nostalgia'));
                            },
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── SECTION 6: OST Drama Korea Terbaik (Korean Drama OSTs) ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionHeader(LanguageService.tr('home_kdrama_ost')),
                      const Icon(Icons.movie_filter_outlined, color: Colors.white54, size: 20),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    LanguageService.isIndonesian
                        ? 'Soundtrack legendaris Secret Garden, Goblin, CLOY, dan lainnya'
                        : 'Legendary soundtracks from Secret Garden, Goblin, CLOY, and more',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 205,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: kdramaPlaylists.length,
                      itemBuilder: (ctx, i) {
                        final pl = kdramaPlaylists[i];
                        return AlbumCard(
                          title: pl.title,
                          subtitle: pl.subtitle,
                          imageUrl: pl.coverUrl,
                          playlist: pl,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PlaylistDetailScreen(playlist: pl),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── SECTION 6B: Soundtrack Anime & J-Pop Legendaris ──
                  if (animePlaylists.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionHeader(LanguageService.tr('home_anime_ost')),
                        const Icon(Icons.animation_rounded, color: Colors.white54, size: 20),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      LanguageService.isIndonesian
                          ? 'Demon Slayer, Jujutsu Kaisen, Attack on Titan, RADWIMPS, dan lainnya'
                          : 'Demon Slayer, Jujutsu Kaisen, Attack on Titan, RADWIMPS, and more',
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 205,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: animePlaylists.length,
                        itemBuilder: (ctx, i) {
                          final pl = animePlaylists[i];
                          return AlbumCard(
                            title: pl.title,
                            subtitle: pl.subtitle,
                            imageUrl: pl.coverUrl,
                            playlist: pl,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PlaylistDetailScreen(playlist: pl),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],

                  // ── SECTION 7: Dibuat Untuk Kamu (Smart User Behavior Engine) ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionHeader(LanguageService.tr('cat_made_for_you')),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: SpotifyTheme.spotifyGreenLight.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          LanguageService.isIndonesian ? 'PINTAR & ADAPTIF' : 'SMART & ADAPTIVE',
                          style: const TextStyle(
                            color: SpotifyTheme.spotifyGreenLight,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    LanguageService.isIndonesian
                        ? 'Rekomendasi otomatis yang mempelajari kebiasaan dan artis favoritmu'
                        : 'Automatic recommendations learning your taste and favorite artists',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 205,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: personalizedPlaylists.length,
                      itemBuilder: (ctx, i) {
                        final pl = personalizedPlaylists[i];
                        return AlbumCard(
                          title: pl.title,
                          subtitle: pl.subtitle,
                          imageUrl: pl.coverUrl,
                          playlist: pl,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PlaylistDetailScreen(playlist: pl),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── SECTION 8: Barisan Playlist Andalan ──
                  _buildSectionHeader(LanguageService.isIndonesian ? 'Barisan Playlist Andalan' : 'Essential Playlists'),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 205,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: playlists.length,
                      itemBuilder: (ctx, i) {
                        final pl = playlists[i];
                        return AlbumCard(
                          title: pl.title,
                          subtitle: pl.subtitle,
                          imageUrl: pl.coverUrl,
                          playlist: pl,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PlaylistDetailScreen(playlist: pl),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── SECTION 9: Baru saja diputar (Recents) ──
                  if (recents.isNotEmpty) ...[
                    _buildSectionHeader(LanguageService.tr('home_recently_played')),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 195,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: recents.length,
                        itemBuilder: (ctx, i) {
                          final song = recents[i];
                          return AlbumCard(
                            title: song.title,
                            subtitle: song.artist,
                            imageUrl: song.albumArtUrl,
                            onTap: () {
                              provider.playSong(song, contextTitle: LanguageService.tr('home_recently_played'));
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],

                  // Bottom Spacing for MiniPlayer + Bottom Navigation
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildRegionSelector() {
    final regions = [
      {'code': 'all', 'label': LanguageService.tr('region_all')},
      {'code': 'id', 'label': LanguageService.tr('region_id')},
      {'code': 'ph', 'label': LanguageService.tr('region_ph')},
      {'code': 'th', 'label': LanguageService.tr('region_th')},
      {'code': 'my', 'label': LanguageService.tr('region_my')},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: regions.map((r) {
          final code = r['code']!;
          final label = r['label']!;
          final isSelected = _selectedRegion == code;

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedRegion = code;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? SpotifyTheme.spotifyGreenLight
                      : const Color(0xFF282828),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? SpotifyTheme.spotifyGreenLight
                        : Colors.white10,
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _getRegionName(String code) {
    switch (code) {
      case 'id': return 'Indonesia';
      case 'ph': return 'Filipina';
      case 'th': return 'Thailand';
      case 'my': return 'Malaysia';
      default: return 'Global';
    }
  }

  Widget _buildFilterPills(MusicPlayerProvider provider) {
    final filters = [
      LanguageService.isIndonesian ? 'Semua' : 'All',
      LanguageService.isIndonesian ? 'Musik' : 'Music',
      'Podcast',
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = provider.activeFilter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: GestureDetector(
              onTap: () => provider.setActiveFilter(f),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected ? SpotifyTheme.spotifyGreenLight : const Color(0xFF282828),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  f,
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
    );
  }
}
