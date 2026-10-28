import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/native_bridge.dart';
import '../models/playlist.dart';
import '../providers/music_player_provider.dart';
import '../theme/spotify_theme.dart';
import '../widgets/playlist_cover_widget.dart';
import '../widgets/mini_player.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final Playlist playlist;

  const PlaylistDetailScreen({
    super.key,
    required this.playlist,
  });

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  late final ScrollController _scrollController;
  bool _isCollapsed = false;
  late Playlist _currentPlaylist = widget.playlist;
  bool _isRefreshingRadar = false;

  Future<void> _handleRefreshRadar() async {
    if (_isRefreshingRadar) return;
    setState(() => _isRefreshingRadar = true);

    try {
      final updated = await context.read<MusicPlayerProvider>().refreshReleaseRadar();
      if (mounted) {
        setState(() {
          _isRefreshingRadar = false;
          if (updated != null) {
            _currentPlaylist = updated;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: SpotifyTheme.spotifyGreen, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Release Radar berhasil diperbarui dengan 30 lagu rilisan terbaru!',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: Color(0xFF282828),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isRefreshingRadar = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final collapsed = _scrollController.hasClients && _scrollController.offset > 240;
    if (collapsed != _isCollapsed) {
      setState(() => _isCollapsed = collapsed);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MusicPlayerProvider>();
    final playlist = _currentPlaylist;
    final isCurrentPlaylistPlaying = provider.contextTitle == playlist.title && provider.isPlaying;

    return Scaffold(
      backgroundColor: SpotifyTheme.background,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Dynamic Spotify App Bar ─────────────────────────────────
              SliverAppBar(
                pinned: true,
                expandedHeight: 385,
                backgroundColor: _isCollapsed ? const Color(0xFF181818) : Colors.transparent,
                elevation: _isCollapsed ? 3 : 0,
                leading: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _isCollapsed ? Colors.transparent : Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                title: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _isCollapsed ? 1.0 : 0.0,
                  child: Text(
                    playlist.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                centerTitle: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          _getPlaylistColor(playlist),
                          SpotifyTheme.background,
                        ],
                        stops: const [0.0, 1.0],
                      ),
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 18),
                            // Big Poster / 2x2 Collage with shadow
                            Hero(
                              tag: 'playlist_${playlist.id}',
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.4),
                                      blurRadius: 16,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: PlaylistCoverWidget(
                                  playlist: playlist,
                                  size: 165,
                                  borderRadius: 8,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            // Playlist Title (Clean, bold, non-overlapping)
                            Text(
                              playlist.title,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (playlist.subtitle.trim().isNotEmpty) ...[
                              // Subtitle (Artist list)
                              Text(
                                playlist.subtitle,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: SpotifyTheme.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            // Spotify Branding Badge
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: SpotifyTheme.spotifyGreen,
                                ),
                                child: const Icon(Icons.play_arrow, color: Colors.black, size: 10),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'MusicXSpot • Dibuat untuk Kamu',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          if (playlist.isReleaseRadar) ...[
                            const SizedBox(height: 10),
                            InkWell(
                              onTap: _isRefreshingRadar ? null : _handleRefreshRadar,
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  color: SpotifyTheme.spotifyGreen.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: SpotifyTheme.spotifyGreen.withValues(alpha: 0.4)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _isRefreshingRadar
                                        ? const SizedBox(
                                            width: 12,
                                            height: 12,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 1.8,
                                              color: SpotifyTheme.spotifyGreen,
                                            ),
                                          )
                                        : const Icon(Icons.sync_rounded, size: 14, color: SpotifyTheme.spotifyGreen),
                                    const SizedBox(width: 6),
                                    Text(
                                      _isRefreshingRadar ? 'Memperbarui...' : 'Perbarui Rilisan Sekarang',
                                      style: const TextStyle(
                                        color: SpotifyTheme.spotifyGreen,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

              // ── Action Bar (Heart, Download, Shuffle, Big Play FAB) ─────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Row(
                    children: [
                      // Like / Save Playlist to Library
                      Builder(builder: (ctx) {
                        final isSaved = provider.playlists.any((p) => p.id == playlist.id);
                        return IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            isSaved ? Icons.favorite : Icons.favorite_border,
                            color: isSaved ? SpotifyTheme.spotifyGreen : SpotifyTheme.textSecondary,
                            size: 24,
                          ),
                          onPressed: () {
                            if (isSaved) {
                              provider.deletePlaylist(playlist.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Dihapus dari Koleksi Kamu'),
                                  duration: Duration(milliseconds: 900),
                                ),
                              );
                            } else {
                              provider.addImportedPlaylist(playlist);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Disimpan ke Koleksi Kamu'),
                                  duration: Duration(milliseconds: 900),
                                ),
                              );
                            }
                          },
                        );
                      }),

                      // Manual Refresh for Release Radar
                      if (playlist.isReleaseRadar)
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Perbarui Rilisan Sekarang',
                          icon: _isRefreshingRadar
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: SpotifyTheme.spotifyGreen,
                                  ),
                                )
                              : const Icon(Icons.sync_rounded, color: SpotifyTheme.spotifyGreen, size: 24),
                          onPressed: _isRefreshingRadar ? null : _handleRefreshRadar,
                        ),

                      // Download Playlist (Real offline downloading)
                      Builder(builder: (ctx) {
                        final isDownloaded = provider.isPlaylistDownloaded(playlist);
                        final isDownloading = provider.isPlaylistDownloading(playlist.id);
                        final progress = provider.getPlaylistDownloadProgress(playlist.id);

                        if (isDownloading) {
                          return Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                value: progress > 0 ? progress : null,
                                strokeWidth: 2,
                                color: SpotifyTheme.spotifyGreen,
                              ),
                            ),
                          );
                        }

                        return IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            isDownloaded ? Icons.download_done : Icons.download_for_offline_outlined,
                            color: isDownloaded ? SpotifyTheme.spotifyGreen : SpotifyTheme.textSecondary,
                            size: 24,
                          ),
                          onPressed: () async {
                            if (isDownloaded) {
                              await provider.removeDownloadedPlaylist(playlist);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Unduhan offline playlist dihapus'),
                                    duration: Duration(milliseconds: 900),
                                  ),
                                );
                              }
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Mengunduh ${playlist.title} (${playlist.songs.length} lagu)...'),
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                              await provider.downloadPlaylist(playlist);
                            }
                          },
                        );
                      }),

                      // More options
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.more_vert, color: SpotifyTheme.textSecondary, size: 24),
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: const Color(0xFF282828),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                            ),
                            builder: (bCtx) => SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: const Icon(Icons.share_outlined, color: Colors.white),
                                    title: const Text('Bagikan Playlist', style: TextStyle(color: Colors.white)),
                                    onTap: () {
                                      Navigator.pop(bCtx);
                                      NativeBridge.shareSong(
                                        title: playlist.title,
                                        text: 'Dengarkan playlist "${playlist.title}" di musixspot!\n${playlist.subtitle}',
                                      );
                                    },
                                  ),
                                  if (playlist.isReleaseRadar)
                                    ListTile(
                                      leading: const Icon(Icons.sync_rounded, color: SpotifyTheme.spotifyGreen),
                                      title: const Text('Perbarui Release Radar', style: TextStyle(color: Colors.white)),
                                      subtitle: const Text('Segarkan daftar 30 lagu rilis terbaru', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                      onTap: () {
                                        Navigator.pop(bCtx);
                                        _handleRefreshRadar();
                                      },
                                    ),
                                  ListTile(
                                    leading: const Icon(Icons.shuffle, color: Colors.white),
                                    title: const Text('Putar Acak Playlist Ini', style: TextStyle(color: Colors.white)),
                                    onTap: () {
                                      Navigator.pop(bCtx);
                                      if (playlist.songs.isNotEmpty) {
                                        provider.playSong(
                                          playlist.songs.first,
                                          queue: playlist.songs,
                                          contextTitle: playlist.title,
                                        );
                                        provider.reshuffleQueue();
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      const Spacer(),

                      // Shuffle Toggle
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          Icons.shuffle,
                          color: provider.isShuffle ? SpotifyTheme.spotifyGreen : SpotifyTheme.textSecondary,
                          size: 24,
                        ),
                        onPressed: () => provider.toggleShuffle(),
                      ),
                      const SizedBox(width: 8),

                      // Big Signature Spotify Green Play Button
                      GestureDetector(
                        onTap: () {
                          if (playlist.songs.isNotEmpty) {
                            if (isCurrentPlaylistPlaying) {
                              provider.togglePlayPause();
                            } else {
                              provider.playSong(
                                playlist.songs.first,
                                queue: playlist.songs,
                                contextTitle: playlist.title,
                              );
                            }
                          }
                        },
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: SpotifyTheme.spotifyGreen,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black45,
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              isCurrentPlaylistPlaying ? Icons.pause : Icons.play_arrow,
                              color: Colors.black,
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Track List ──────────────────────────────────────────────
              if (playlist.songs.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40.0, horizontal: 24.0),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.music_off_outlined, color: Colors.white24, size: 48),
                          SizedBox(height: 12),
                          Text(
                            'Belum ada lagu di playlist ini',
                            style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Tambahkan lagu favorit kamu ke dalam playlist ini',
                            style: TextStyle(color: SpotifyTheme.textSecondary, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                    final song = playlist.songs[index];
                    final isPlayingThisSong = provider.currentSong?.id == song.id;

                    return InkWell(
                      onTap: () {
                        provider.playSong(
                          song,
                          queue: playlist.songs,
                          contextTitle: playlist.title,
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Row(
                          children: [
                            // Track Thumbnail / Index
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: CachedNetworkImage(
                                imageUrl: song.albumArtUrl,
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: SpotifyTheme.cardSurfaceHighlight,
                                  child: const Icon(Icons.music_note, color: Colors.white24, size: 24),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: SpotifyTheme.cardSurfaceHighlight,
                                  child: const Icon(Icons.music_note, color: Colors.white24, size: 24),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Song Title & Artist
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    song.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isPlayingThisSong
                                          ? SpotifyTheme.spotifyGreen
                                          : SpotifyTheme.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${song.artist} • ${song.album.isNotEmpty ? song.album : "Single"}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: SpotifyTheme.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Playing animation indicator OR three-dots option
                            if (isPlayingThisSong)
                              const Icon(Icons.equalizer, color: SpotifyTheme.spotifyGreen, size: 22)
                            else
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.more_vert, color: SpotifyTheme.textSecondary, size: 20),
                                onPressed: () {},
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: playlist.songs.length,
                ),
              ),

              // Bottom padding for MiniPlayer
              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          ),

          // Mini player at bottom if song playing
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

  Color _getPlaylistColor(Playlist pl) {
    if (pl.id.contains('daily_mix_1')) return const Color(0xFF1E3264);
    if (pl.id.contains('daily_mix_2')) return const Color(0xFF8D67AB);
    if (pl.id.contains('daily_mix_3')) return const Color(0xFFBA5D07);
    if (pl.isReleaseRadar) return const Color(0xFF1E3264);
    if (pl.isDiscoverWeekly) return const Color(0xFF2E77D0);
    return const Color(0xFF333333);
  }
}
