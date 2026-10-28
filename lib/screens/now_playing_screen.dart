import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/services.dart';
import '../widgets/spotify_marquee.dart';
import '../models/song.dart';
import '../providers/music_player_provider.dart';
import '../services/audio_player_service.dart';
import '../services/bluetooth_audio_service.dart';
import '../theme/spotify_theme.dart';
import '../widgets/lyrics_sheet.dart';
import '../widgets/artist_about_card.dart';
import '../widgets/explore_artist_section.dart';
import '../widgets/song_credits_widget.dart';
import '../services/native_bridge.dart';
import '../services/artist_navigation_service.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _canvasAnimController;

  @override
  void initState() {
    super.initState();
    _canvasAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _canvasAnimController.dispose();
    super.dispose();
  }

  (String, String) _buildContextDisplay(String rawContext, Song song) {
    String clean = rawContext.trim();

    // 1. Strip any existing repeated "MEMUTAR DARI" or "PLAYING FROM" prefix
    final regexPrefix = RegExp(r'^(?:memutar\s+dari|playing\s+from)\s*', caseSensitive: false);
    while (regexPrefix.hasMatch(clean)) {
      clean = clean.replaceFirst(regexPrefix, '').trim();
    }

    // Default subtitle fallback
    final defaultSubtitle = (song.album.isNotEmpty &&
            !song.album.toLowerCase().contains('official') &&
            song.album.toLowerCase() != 'unknown album' &&
            song.album.toLowerCase() != 'single')
        ? song.album
        : (song.artist.isNotEmpty ? '${song.artist} • ${song.title}' : song.title);

    if (clean.isEmpty) {
      return ('MEMUTAR DARI', defaultSubtitle);
    }

    final cleanUpper = clean.toUpperCase();

    // Case 1: Search Query (e.g., 'Hasil Pencarian "Naruto"')
    if (cleanUpper.startsWith('HASIL PENCARIAN') || cleanUpper.startsWith('PENCARIAN')) {
      final queryMatch = RegExp(r'["“](.+?)["”]').firstMatch(clean);
      final query = queryMatch != null
          ? '"${queryMatch.group(1)}"'
          : clean.replaceFirst(RegExp(r'^(?:hasil\s+)?pencarian\s*:?\s*', caseSensitive: false), '').trim();
      return (
        'MEMUTAR DARI PENCARIAN',
        query.isNotEmpty ? query : defaultSubtitle,
      );
    }

    // Case 2: Liked Songs
    if (cleanUpper == 'LAGU YANG DISUKAI' || cleanUpper == 'LIKED SONGS') {
      return ('MEMUTAR DARI', 'Lagu yang Disukai');
    }

    // Case 3: Recently Played
    if (cleanUpper == 'BARU SAJA DIPUTAR' || cleanUpper == 'RECENTLY PLAYED') {
      return ('MEMUTAR DARI', 'Baru Saja Diputar');
    }

    // Case 4: Offline downloads
    if (cleanUpper.contains('OFFLINE') || cleanUpper.contains('DIUNDUH')) {
      return ('MEMUTAR DARI', 'Lagu Offline Diunduh');
    }

    // Case 5: Artist
    if (cleanUpper.startsWith('ARTIS:') || clean.toLowerCase() == song.artist.toLowerCase()) {
      final artistName = clean.startsWith(RegExp(r'artis\s*:\s*', caseSensitive: false))
          ? clean.substring(clean.indexOf(':') + 1).trim()
          : clean;
      return ('MEMUTAR DARI ARTIS', artistName.isNotEmpty ? artistName : song.artist);
    }

    // Case 6: Album
    if (cleanUpper.startsWith('ALBUM:') ||
        (song.album.isNotEmpty && clean.toLowerCase() == song.album.toLowerCase())) {
      final albumName = clean.startsWith(RegExp(r'album\s*:\s*', caseSensitive: false))
          ? clean.substring(clean.indexOf(':') + 1).trim()
          : clean;
      return ('MEMUTAR DARI ALBUM', albumName.isNotEmpty ? albumName : song.album);
    }

    // Case 7: Default "PLAYLIST" placeholder
    if (cleanUpper == 'PLAYLIST') {
      return ('MEMUTAR DARI PLAYLIST', defaultSubtitle);
    }

    // Case 8: Specific Playlist Title (e.g. "Top Hits", "Anime Ost")
    if (cleanUpper.startsWith('PLAYLIST:')) {
      final plName = clean.substring(clean.indexOf(':') + 1).trim();
      return ('MEMUTAR DARI PLAYLIST', plName.isNotEmpty ? plName : defaultSubtitle);
    }

    // By default, treat custom context string as playlist / collection title
    return ('MEMUTAR DARI PLAYLIST', clean);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MusicPlayerProvider>();
    final song = provider.currentSong;

    if (song == null) {
      return const Scaffold(backgroundColor: SpotifyTheme.background);
    }

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final padding = MediaQuery.of(context).padding;
    final availableHeight = screenHeight - padding.top - padding.bottom;

    // Responsive Album Artwork Sizing:
    // Fits cleanly on screen without overflowing or pushing album art off-screen
    final double maxCoverSize = screenWidth - 48;
    final double coverSize = (availableHeight * 0.38).clamp(200.0, maxCoverSize);

    return Container(
      width: screenWidth,
      height: screenHeight,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            provider.dominantColor, // Ekstraksi Warna Gradien Dinamis
            SpotifyTheme.background,
            Colors.black,
          ],
          stops: const [0.0, 0.45, 1.0],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Padded Top Header (Cleanly positioned below Android Status Bar)
              Padding(
                padding: const EdgeInsets.only(
                  top: 10.0,
                  left: 12,
                  right: 12,
                  bottom: 4,
                ),
                child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down, size: 32, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final (headerCategory, headerSubtitle) =
                            _buildContextDisplay(provider.contextTitle, song);
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              headerCategory,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: SpotifyTheme.textSecondary,
                                fontSize: 10,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              headerSubtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  if (provider.isSleepTimerActive)
                    GestureDetector(
                      onTap: () => _showSleepTimerModal(context, provider),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: SpotifyTheme.spotifyGreen.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: SpotifyTheme.spotifyGreen, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.bedtime, size: 14, color: SpotifyTheme.spotifyGreen),
                            const SizedBox(width: 4),
                            Text(
                              provider.sleepAtSongEnd ? '1 lagu' : '${provider.sleepTimerMinutesRemaining}m',
                              style: const TextStyle(
                                color: SpotifyTheme.spotifyGreen,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onPressed: () => _showSongOptionsSheet(context, provider, song),
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 12),

                // Gesture Swipeable Album Artwork / Canvas Animation
                GestureDetector(
                  onHorizontalDragEnd: (details) {
                    if (details.primaryVelocity != null) {
                      if (details.primaryVelocity! < -250) {
                        // Swipe Left: Next Song
                        provider.skipToNext();
                      } else if (details.primaryVelocity! > 250) {
                        // Swipe Right: Previous Song
                        provider.skipToPrevious();
                      }
                    }
                  },
                  child: Center(
                    child: provider.isCanvasMode
                        ? _buildCanvasView(coverSize, song, provider)
                        : _buildStandardCover(coverSize, song),
                  ),
                ),

                const SizedBox(height: 16),

                // Song Title & Artist + Heart Icon
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 28,
                            child: SpotifyMarquee(
                              text: song.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => ArtistNavigationService.navigateToArtist(context, song.artist),
                            child: Text(
                              song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: SpotifyTheme.textSecondary,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              if (song.isFlac) ...[
                                GestureDetector(
                                  onTap: () => _showLosslessInfoSheet(context, song),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE5FB52).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: const Color(0xFFE5FB52).withValues(alpha: 0.5),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.high_quality_rounded,
                                          size: 13,
                                          color: Color(0xFFE5FB52),
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'LOSSLESS 24-BIT / 44.1 kHz',
                                          style: TextStyle(
                                            color: Color(0xFFE5FB52),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                            ],
                          ),
                          if (provider.playbackErrorMessage != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.info_outline, color: Colors.orangeAccent, size: 14),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    provider.playbackErrorMessage!,
                                    style: const TextStyle(
                                      color: Colors.orangeAccent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        provider.toggleLike(song);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(song.isLiked
                                ? 'Ditambahkan ke Lagu yang Disukai'
                                : 'Dihapus dari Lagu yang Disukai'),
                            duration: const Duration(milliseconds: 1000),
                          ),
                        );
                      },
                      child: Icon(
                        song.isLiked ? Icons.check_circle : Icons.add_circle_outline_rounded,
                        color: song.isLiked ? provider.themeColors.primaryLight : provider.themeColors.textSecondary,
                        size: 28,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Spotify Scrubber / Seek Bar (Shows negative remaining duration like -2:36)
                ProgressBar(
                  progress: provider.position,
                  total: provider.duration.inSeconds > 0
                      ? provider.duration
                      : (song.duration.inSeconds > 0
                          ? song.duration
                          : const Duration(minutes: 3, seconds: 30)),
                  buffered: provider.bufferedPosition,
                  onSeek: (duration) {
                    provider.seek(duration);
                  },
                  timeLabelType: TimeLabelType.remainingTime,
                  baseBarColor: Colors.white.withValues(alpha: 0.2),
                  progressBarColor: Colors.white,
                  bufferedBarColor: Colors.white.withValues(alpha: 0.35),
                  thumbColor: Colors.white,
                  thumbRadius: 5.5,
                  thumbGlowRadius: 16.0,
                  timeLabelTextStyle: TextStyle(
                    color: provider.themeColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),

                // Playback Controls Row (1:1 Spotify: Shuffle w/ Reshuffle, Prev, Play/Pause, Next, Repeat)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Shuffle Button with Active Indicator Dot & Reshuffle Function
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (provider.isShuffle) {
                            // Reshuffle queue
                            provider.reshuffleQueue();
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('🔀 Antrean lagu diacak ulang (Reshuffled)'),
                                duration: Duration(milliseconds: 1000),
                              ),
                            );
                          } else {
                            provider.toggleShuffle();
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Mode Acak Aktif'),
                                duration: Duration(milliseconds: 800),
                              ),
                            );
                          }
                        },
                        onLongPress: () {
                          if (provider.isShuffle) {
                            provider.toggleShuffle();
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Mode Acak Dinonaktifkan'),
                                duration: Duration(milliseconds: 800),
                              ),
                            );
                          }
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.shuffle_rounded,
                              color: provider.isShuffle
                                  ? provider.themeColors.primaryLight
                                  : Colors.white,
                              size: 26,
                            ),
                            const SizedBox(height: 3),
                            Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: provider.isShuffle
                                    ? provider.themeColors.primaryLight
                                    : Colors.transparent,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Previous Track
                      IconButton(
                        icon: const Icon(
                          Icons.skip_previous_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
                        onPressed: () => provider.skipToPrevious(),
                      ),

                      // Play / Pause Circular Button (White filled circle)
                      GestureDetector(
                        onTap: () => provider.togglePlayPause(),
                        child: Container(
                          width: 66,
                          height: 66,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                          child: Center(
                            child: provider.isBuffering
                                ? const SizedBox(
                                    width: 26,
                                    height: 26,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.black,
                                    ),
                                  )
                                : Icon(
                                    provider.isPlaying
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    color: Colors.black,
                                    size: 42,
                                  ),
                          ),
                        ),
                      ),

                      // Next Track
                      IconButton(
                        icon: const Icon(
                          Icons.skip_next_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
                        onPressed: () => provider.skipToNext(),
                      ),

                      // Repeat Button with Active Indicator Dot
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          provider.toggleRepeat();
                          final modeText = provider.repeatMode == SpotifyRepeatMode.all
                              ? 'Ulangi Semua Lagu'
                              : (provider.repeatMode == SpotifyRepeatMode.one
                                  ? 'Ulangi Lagu Ini 1x'
                                  : 'Ulangi Nonaktif');
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(modeText),
                              duration: const Duration(milliseconds: 800),
                            ),
                          );
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              provider.repeatMode == SpotifyRepeatMode.one
                                  ? Icons.repeat_one_rounded
                                  : Icons.repeat_rounded,
                              color: provider.repeatMode != SpotifyRepeatMode.off
                                  ? provider.themeColors.primaryLight
                                  : Colors.white,
                              size: 26,
                            ),
                            const SizedBox(height: 3),
                            Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: provider.repeatMode != SpotifyRepeatMode.off
                                    ? provider.themeColors.primaryLight
                                    : Colors.transparent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Spotify Bottom Utility Bar (1:1 with Screenshot media_1791462938930.png)
                // Left: Speaker icon + "HK Onyx Studio 7" (green text & icon)
                // Right: Share button & Queue button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Connected Device (Spotify Connect)
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _showDevicePickerModal(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 2.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              provider.isBluetoothConnected
                                  ? Icons.bluetooth_audio
                                  : Icons.devices_rounded,
                              color: provider.themeColors.primaryLight,
                              size: 19,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              provider.connectedDevice,
                              style: TextStyle(
                                color: provider.themeColors.primaryLight,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Right Actions: Share & Queue
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.ios_share_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                          tooltip: 'Bagikan',
                          onPressed: () => _showShareModal(context, song),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.format_list_bulleted_rounded,
                            color: Colors.white,
                            size: 23,
                          ),
                          tooltip: 'Antrean',
                          onPressed: () => _showQueueModal(context, provider),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Lyrics Sheet Widget
                LyricsSheet(song: song),
                const SizedBox(height: 20),

                // ── TENTANG ARTIS (Screenshots 2 & 4) ──
                ArtistAboutCard(song: song),
                const SizedBox(height: 24),

                // ── JELAJAHI [NAMA ARTIS] (Screenshots 2 & 4) ──
                ExploreArtistSection(song: song),
                const SizedBox(height: 24),

                // ── KREDIT (Screenshots 2 & 4) ──
                SongCreditsWidget(song: song),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    ],
  ),
),
),
);
}

  // Standard square album art
  Widget _buildStandardCover(double size, Song song) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CachedNetworkImage(
          imageUrl: song.albumArtUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: SpotifyTheme.cardSurfaceHighlight,
            child: const Icon(Icons.music_note, color: Colors.white38, size: 72),
          ),
          errorWidget: (context, url, error) => Container(
            color: SpotifyTheme.cardSurfaceHighlight,
            child: const Icon(Icons.music_note, color: Colors.white38, size: 72),
          ),
        ),
      ),
    );
  }

  // Spotify Canvas: Motion vinyl rotating with ambient glowing pulse
  Widget _buildCanvasView(double size, Song song, MusicPlayerProvider provider) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: RadialGradient(
          colors: [
            provider.dominantColor.withValues(alpha: 0.8),
            Colors.black.withValues(alpha: 0.9),
          ],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ambient pulse waves
          AnimatedBuilder(
            animation: _canvasAnimController,
            builder: (context, child) {
              return Container(
                width: size * 0.9,
                height: size * 0.9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: provider.dominantColor.withValues(alpha: 0.5),
                      blurRadius: 35 + sin(_canvasAnimController.value * 2 * pi) * 15,
                      spreadRadius: 8 + cos(_canvasAnimController.value * 2 * pi) * 6,
                    ),
                  ],
                ),
              );
            },
          ),
          // Rotating Vinyl Disc
          AnimatedBuilder(
            animation: _canvasAnimController,
            builder: (context, child) {
              return Transform.rotate(
                angle: provider.isPlaying ? _canvasAnimController.value * 2 * pi : 0,
                child: child,
              );
            },
            child: Container(
              width: size * 0.82,
              height: size * 0.82,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF111111),
                border: Border.all(color: Colors.white12, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.8),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Center(
                // Center Album Thumbnail
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(size * 0.2),
                  child: CachedNetworkImage(
                    imageUrl: song.albumArtUrl,
                    width: size * 0.38,
                    height: size * 0.38,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
          // Canvas Badge
          Positioned(
            bottom: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, size: 12, color: SpotifyTheme.spotifyGreen),
                  SizedBox(width: 4),
                  Text('CANVAS', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Sleep Timer Modal Sheet
  void _showSleepTimerModal(BuildContext context, MusicPlayerProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: SpotifyTheme.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Timer Tidur',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              _sleepTimerTile(ctx, provider, '5 Menit', 5),
              _sleepTimerTile(ctx, provider, '10 Menit', 10),
              _sleepTimerTile(ctx, provider, '15 Menit', 15),
              _sleepTimerTile(ctx, provider, '30 Menit', 30),
              _sleepTimerTile(ctx, provider, '45 Menit', 45),
              _sleepTimerTile(ctx, provider, '1 Jam', 60),
              ListTile(
                leading: const Icon(Icons.music_off, color: Colors.white70),
                title: const Text('Akhir lagu ini', style: TextStyle(color: Colors.white)),
                trailing: provider.sleepAtSongEnd ? const Icon(Icons.check, color: SpotifyTheme.spotifyGreen) : null,
                onTap: () {
                  provider.setSleepTimerAtSongEnd();
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Musik akan berhenti setelah lagu ini selesai')),
                  );
                },
              ),
              if (provider.isSleepTimerActive)
                ListTile(
                  leading: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
                  title: const Text('Matikan Timer', style: TextStyle(color: Colors.redAccent)),
                  onTap: () {
                    provider.cancelSleepTimer();
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Timer tidur dimatikan')),
                    );
                  },
                ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _sleepTimerTile(BuildContext context, MusicPlayerProvider provider, String title, int minutes) {
    final isSelected = provider.isSleepTimerActive && !provider.sleepAtSongEnd && provider.sleepTimerMinutesRemaining <= minutes && provider.sleepTimerMinutesRemaining > (minutes - 10);
    return ListTile(
      leading: const Icon(Icons.bedtime_outlined, color: Colors.white70),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      trailing: isSelected ? const Icon(Icons.check, color: SpotifyTheme.spotifyGreen) : null,
      onTap: () {
        provider.setSleepTimer(minutes);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Timer tidur diatur selama $minutes menit')),
        );
      },
    );
  }

  // Song Options Sheet
  void _showSongOptionsSheet(BuildContext context, MusicPlayerProvider provider, Song song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: SpotifyTheme.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: CachedNetworkImage(imageUrl: song.albumArtUrl, width: 48, height: 48, fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SpotifyTheme.textSecondary, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              ListTile(
                leading: Icon(song.isLiked ? Icons.favorite : Icons.favorite_border, color: song.isLiked ? SpotifyTheme.heartActive : Colors.white),
                title: Text(song.isLiked ? 'Hapus dari Lagu yang Disukai' : 'Sukai Lagu', style: const TextStyle(color: Colors.white)),
                onTap: () {
                  provider.toggleLike(song);
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.playlist_add, color: Colors.white),
                title: const Text('Tambahkan ke Playlist', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAddToPlaylistDialog(context, provider, song);
                },
              ),
              ListTile(
                leading: Icon(song.isDownloaded ? Icons.download_done : Icons.download_for_offline_outlined, color: song.isDownloaded ? SpotifyTheme.spotifyGreen : Colors.white),
                title: Text(song.isDownloaded ? 'Hapus Unduhan' : 'Unduh Lagu', style: const TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(ctx);
                  if (song.isDownloaded) {
                    await provider.removeDownloadedSong(song);
                  } else {
                    await provider.downloadSong(song);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.bedtime_outlined, color: Colors.white),
                title: const Text('Timer Tidur', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showSleepTimerModal(context, provider);
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.animation,
                  color: provider.isCanvasMode ? provider.themeColors.primaryLight : Colors.white,
                ),
                title: Text(
                  provider.isCanvasMode ? 'Nonaktifkan MusicXSpot Canvas' : 'Aktifkan MusicXSpot Canvas',
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  provider.toggleCanvasMode();
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(provider.isCanvasMode
                          ? 'Canvas Dinamis Diaktifkan'
                          : 'Canvas Dinamis Dinonaktifkan'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.ios_share_rounded, color: Colors.white),
                title: const Text('Bagikan Lagu Ini', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showShareModal(context, song);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _showAddToPlaylistDialog(BuildContext context, MusicPlayerProvider provider, Song song) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: SpotifyTheme.cardSurface,
          title: const Text('Pilih Playlist', style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: provider.playlists.length,
              itemBuilder: (ctx, i) {
                final p = provider.playlists[i];
                return ListTile(
                  title: Text(p.title, style: const TextStyle(color: Colors.white)),
                  subtitle: Text('${p.songs.length} lagu', style: const TextStyle(color: SpotifyTheme.textSecondary, fontSize: 12)),
                  trailing: const Icon(Icons.add, color: SpotifyTheme.spotifyGreen),
                  onTap: () {
                    provider.addSongToPlaylist(p.id, song);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Ditambahkan ke ${p.title}')),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal', style: TextStyle(color: SpotifyTheme.textSecondary)),
            ),
          ],
        );
      },
    );
  }

  void _showQueueModal(BuildContext context, MusicPlayerProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: SpotifyTheme.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Antrean Pemutaran (Up Next)',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: provider.queue.length,
                  itemBuilder: (ctx, i) {
                    final item = provider.queue[i];
                    final isCurrent = i == provider.currentIndex;
                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: CachedNetworkImage(
                          imageUrl: item.albumArtUrl,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                        ),
                      ),
                      title: Text(
                        item.title,
                        style: TextStyle(
                          color: isCurrent ? SpotifyTheme.spotifyGreenLight : Colors.white,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        item.artist,
                        style: const TextStyle(color: SpotifyTheme.textSecondary, fontSize: 12),
                      ),
                      trailing: isCurrent
                          ? const Icon(Icons.graphic_eq, color: SpotifyTheme.spotifyGreenLight)
                          : null,
                      onTap: () {
                        provider.playSong(item);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDevicePickerModal(BuildContext context) {
    final provider = Provider.of<MusicPlayerProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      backgroundColor: provider.themeColors.cardSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final currentVolume = provider.deviceVolume;
            final isBtConnected = provider.isBluetoothConnected;
            final activeBtDevice = provider.bluetoothDevice;
            final paired = provider.pairedBluetoothDevices;
            final isScanning = provider.isBluetoothScanning;
            final scanned = provider.scannedBluetoothDevices;

            IconData getDeviceIcon(BluetoothDeviceType type) {
              switch (type) {
                case BluetoothDeviceType.headphones:
                  return Icons.headphones_rounded;
                case BluetoothDeviceType.earphones:
                  return Icons.earbuds_rounded;
                case BluetoothDeviceType.speaker:
                  return Icons.speaker_rounded;
                case BluetoothDeviceType.carAudio:
                  return Icons.directions_car_rounded;
                case BluetoothDeviceType.phoneSpeaker:
                  return Icons.phone_android_rounded;
              }
            }

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.82,
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Header (Screenshot 5: "Connect" on left, info icon on right)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Connect',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              icon: const Icon(Icons.info_outline, color: Colors.white70, size: 20),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('MusicXSpot Connect: Putar audio di speaker, headphone, atau TV Anda.'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Active Device Card (Screenshot 5: "Ponsel ini" + badge "Normal" + green song subtitle)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF282828),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  // Green Phone / Device Icon
                                  Icon(
                                    isBtConnected
                                        ? getDeviceIcon(activeBtDevice!.type)
                                        : Icons.phone_android,
                                    color: const Color(0xFF1DB954),
                                    size: 26,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              isBtConnected
                                                  ? activeBtDevice!.name
                                                  : 'Ponsel ini',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(width: 8),
                                            // Grey pill badge: "Normal"
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF3E3E3E),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                'Normal',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        // Vibrant Spotify green song title & artist
                                        Text(
                                          provider.currentSong != null
                                              ? '${provider.currentSong!.title} — ${provider.currentSong!.artist}'
                                              : 'Memutar audio',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Color(0xFF1DB954),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Animated sound waves / equalizer icon
                                  const Icon(
                                    Icons.graphic_eq,
                                    color: Color(0xFF1DB954),
                                    size: 22,
                                  ),
                                  if (isBtConnected)
                                    IconButton(
                                      tooltip: 'Putuskan sambungan',
                                      icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                                      onPressed: () async {
                                        await provider.disconnectBluetooth();
                                        setModalState(() {});
                                      },
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Interactive Volume Slider
                              Row(
                                children: [
                                  const Icon(Icons.volume_down, color: Colors.white70, size: 20),
                                  Expanded(
                                    child: Slider(
                                      value: currentVolume,
                                      activeColor: const Color(0xFF1DB954),
                                      inactiveColor: Colors.white24,
                                      onChanged: (val) {
                                        setModalState(() {});
                                        provider.setDeviceVolume(val);
                                      },
                                    ),
                                  ),
                                  const Icon(Icons.volume_up, color: Colors.white70, size: 20),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${(currentVolume * 100).round()}%',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),

                        // Section: Pilih perangkat lain (Screenshot 5)
                        const Text(
                          'Pilih perangkat lain',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Google Cast Device (Screenshot 5: KD-49X7500F)
                        InkWell(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Menghubungkan ke KD-49X7500F (Google Cast)...'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.tv_rounded, color: Colors.white70, size: 26),
                                SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'KD-49X7500F',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Google Cast',
                                        style: TextStyle(color: Colors.white54, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Section: Perangkat Bluetooth Tersimpan
                        ...paired.map((dev) {
                          final isThisConnected = isBtConnected && activeBtDevice?.id == dev.id;
                          return InkWell(
                            onTap: () async {
                              if (!isThisConnected) {
                                await provider.connectBluetooth(dev);
                                setModalState(() {});
                              }
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              margin: const EdgeInsets.only(bottom: 6),
                              decoration: BoxDecoration(
                                color: isThisConnected
                                    ? const Color(0xFF1DB954).withValues(alpha: 0.1)
                                    : Colors.white.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(8),
                                border: isThisConnected
                                    ? Border.all(color: const Color(0xFF1DB954).withValues(alpha: 0.4))
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    getDeviceIcon(dev.type),
                                    color: isThisConnected ? const Color(0xFF1DB954) : Colors.white70,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          dev.name,
                                          style: TextStyle(
                                            color: isThisConnected ? const Color(0xFF1DB954) : Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        if (dev.batteryLevel != null) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            'Baterai ${dev.batteryLevel}% • Bluetooth HD Audio',
                                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (isThisConnected)
                                    const Icon(Icons.check_circle, color: Color(0xFF1DB954), size: 20)
                                  else
                                    const Text(
                                      'Sambungkan',
                                      style: TextStyle(
                                        color: Color(0xFF1DB954),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }),

                        if (scanned.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          const Text(
                            'Perangkat Terdeteksi',
                            style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          ...scanned.map((dev) {
                            return InkWell(
                              onTap: () async {
                                await provider.connectBluetooth(dev);
                                setModalState(() {});
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                margin: const EdgeInsets.only(bottom: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(getDeviceIcon(dev.type), color: Colors.white70, size: 22),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        dev.name,
                                        style: const TextStyle(color: Colors.white, fontSize: 14),
                                      ),
                                    ),
                                    const Text(
                                      'Pasangkan',
                                      style: TextStyle(
                                        color: Color(0xFF1DB954),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],

                        const SizedBox(height: 18),

                        // Bottom Action: Temukan perangkat Bluetooth (Screenshot 5)
                        GestureDetector(
                          onTap: () async {
                            setModalState(() {});
                            await NativeBridge.openBluetoothSettings();
                            await provider.scanBluetooth();
                            setModalState(() {});
                          },
                          child: Container(
                            height: 48,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFF282828),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (isScanning)
                                  const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                else
                                  const Icon(Icons.bluetooth, color: Colors.white, size: 20),
                                const SizedBox(width: 10),
                                Text(
                                  isScanning ? 'Mencari perangkat...' : 'Temukan perangkat Bluetooth',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showShareModal(BuildContext context, Song song) {
    final provider = Provider.of<MusicPlayerProvider>(context, listen: false);
    final shareUrl = 'https://musicxspot.app/track/${song.id}';

    showModalBottomSheet(
      context: context,
      backgroundColor: provider.themeColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Song Preview Card
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: CachedNetworkImage(
                        imageUrl: song.albumArtUrl,
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: provider.themeColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 16),
                const Text(
                  'Bagikan ke',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                // Share Grid / Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _shareActionItem(
                      icon: Icons.link_rounded,
                      label: 'Salin Tautan',
                      color: provider.themeColors.primaryLight,
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: shareUrl));
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Tautan disalin ke papan klip!'),
                            duration: Duration(milliseconds: 1200),
                          ),
                        );
                      },
                    ),
                    _shareActionItem(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: 'WhatsApp',
                      color: const Color(0xFF25D366),
                      onTap: () {
                        Navigator.pop(ctx);
                        NativeBridge.shareSong(
                          title: song.title,
                          text: 'Dengarkan lagu "${song.title}" oleh ${song.artist} di musixspot 🎵\n$shareUrl',
                        );
                      },
                    ),
                    _shareActionItem(
                      icon: Icons.camera_alt_outlined,
                      label: 'Instagram',
                      color: const Color(0xFFE1306C),
                      onTap: () {
                        Navigator.pop(ctx);
                        NativeBridge.shareSong(
                          title: song.title,
                          text: 'Dengarkan lagu "${song.title}" oleh ${song.artist} di musixspot 🎵\n$shareUrl',
                        );
                      },
                    ),
                    _shareActionItem(
                      icon: Icons.more_horiz_rounded,
                      label: 'Lainnya',
                      color: Colors.white70,
                      onTap: () {
                        Navigator.pop(ctx);
                        NativeBridge.shareSong(
                          title: song.title,
                          text: 'Dengarkan lagu "${song.title}" oleh ${song.artist} di musixspot 🎵\n$shareUrl',
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _shareActionItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.15),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showLosslessInfoSheet(BuildContext context, Song song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF202020),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(22.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5FB52).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE5FB52)),
                      ),
                      child: Text(
                        song.isFlac ? 'Hi-Fi LOSSLESS' : 'STANDAR',
                        style: const TextStyle(
                          color: Color(0xFFE5FB52),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      song.isFlac ? 'Kualitas Audio Studio Master' : 'Kualitas Standar (AAC 320 kbps)',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildLosslessRow('Format Enkoding', song.audioFormat),
                _buildLosslessRow('Kedalaman Bit', song.bitDepth),
                _buildLosslessRow('Sample Rate', song.sampleRate),
                _buildLosslessRow('Bitrate Streaming', song.isFlac ? '~1411 - 2304 kbps' : '320 kbps'),
                _buildLosslessRow('Audio Engine', 'MusicXSpot Core Audio'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLosslessRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
