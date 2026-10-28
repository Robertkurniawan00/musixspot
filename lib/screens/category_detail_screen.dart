import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/category.dart';
import '../models/playlist.dart';
import '../providers/music_player_provider.dart';
import '../services/music_api_service.dart';
import '../theme/spotify_theme.dart';
import '../widgets/mini_player.dart';
import 'playlist_detail_screen.dart';

class CategoryDetailScreen extends StatefulWidget {
  final BrowseCategory category;

  const CategoryDetailScreen({
    super.key,
    required this.category,
  });

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  late final CategoryData _categoryData;

  @override
  void initState() {
    super.initState();
    _categoryData = MusicApiService.getCategoryDetails(widget.category);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MusicPlayerProvider>();
    final cat = widget.category;

    return Scaffold(
      backgroundColor: SpotifyTheme.background,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Spotify Header App Bar with Gradient ────────────────────────
              SliverAppBar(
                pinned: true,
                elevation: 0,
                backgroundColor: cat.backgroundColor.withValues(alpha: 0.9),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  cat.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                centerTitle: true,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.ios_share_rounded, color: Colors.white, size: 22),
                    tooltip: 'Bagikan',
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Tautan kategori "${cat.title}" disalin ke papan klip'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                ],
              ),

              // ── Top Gradient Mesh ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        cat.backgroundColor.withValues(alpha: 0.9),
                        SpotifyTheme.background,
                      ],
                    ),
                  ),
                ),
              ),

              // ── Hero Banner (e.g., NEW MUSIC FRIDAY INDONESIA - Screenshot 4) ──
              if (_categoryData.heroPlaylist != null) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: _buildHeroBanner(context, _categoryData.heroPlaylist!, provider),
                  ),
                ),
              ],

              // ── Section Carousels (Screenshot 2: K-Essentials, BTS, dsb.) ──
              ..._categoryData.sections.map((section) {
                return SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                        child: Text(
                          section.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 226,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: section.playlists.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 14),
                          itemBuilder: (ctx, i) {
                            final playlist = section.playlists[i];
                            return _buildPlaylistCard(context, playlist, provider);
                          },
                        ),
                      ),
                    ],
                  ),
                );
              }),

              // Bottom spacing for Mini Player
              const SliverToBoxAdapter(
                child: SizedBox(height: 120),
              ),
            ],
          ),

          // Mini Player
          if (provider.currentSong != null)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: MiniPlayer(),
            ),
        ],
      ),
    );
  }

  // Hero Banner matching Spotify Screenshot 4 (NEW MUSIC FRIDAY INDONESIA)
  Widget _buildHeroBanner(
    BuildContext context,
    Playlist hero,
    MusicPlayerProvider provider,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlaylistDetailScreen(playlist: hero),
          ),
        );
      },
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Background Artwork
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: hero.coverUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: const Color(0xFF282828)),
                errorWidget: (context, url, error) => Container(color: const Color(0xFF282828)),
              ),
            ),

            // Gradient Overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.2),
                      Colors.black.withValues(alpha: 0.85),
                    ],
                    stops: const [0.3, 1.0],
                  ),
                ),
              ),
            ),

            // Text Content (Bottom Left)
            Positioned(
              left: 16,
              right: 80,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    hero.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hero.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),

            // Circular Green Play Button (Bottom Right)
            Positioned(
              right: 16,
              bottom: 16,
              child: GestureDetector(
                onTap: () {
                  if (hero.songs.isNotEmpty) {
                    provider.playSong(
                      hero.songs.first,
                      queue: hero.songs,
                      contextTitle: hero.title,
                    );
                  }
                },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: const BoxDecoration(
                    color: SpotifyTheme.spotifyGreenLight,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black45,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.black,
                      size: 34,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Playlist Card matching Spotify Screenshot 2
  Widget _buildPlaylistCard(
    BuildContext context,
    Playlist playlist,
    MusicPlayerProvider provider,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlaylistDetailScreen(playlist: playlist),
          ),
        );
      },
      child: SizedBox(
        width: 145,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Square Cover Art
            Container(
              width: 145,
              height: 145,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: CachedNetworkImage(
                  imageUrl: playlist.coverUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: const Color(0xFF282828),
                    child: const Icon(Icons.music_note, color: Colors.white30, size: 40),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: const Color(0xFF282828),
                    child: const Icon(Icons.music_note, color: Colors.white30, size: 40),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Title
            Text(
              playlist.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 2),

            // Subtitle
            Text(
              playlist.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: SpotifyTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w400,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
