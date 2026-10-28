import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/playlist.dart';

/// Renders a Spotify-authentic playlist cover:
/// - Daily Mix: 2×2 collage of 4 album art squares + Spotify brand badge + bottom title banner
/// - Release Radar: single album art with Spotify radar overlay badge
/// - Regular playlist: single cover image
class PlaylistCoverWidget extends StatelessWidget {
  final Playlist playlist;
  final double size;
  final double borderRadius;

  const PlaylistCoverWidget({
    super.key,
    required this.playlist,
    this.size = 130,
    this.borderRadius = 6,
  });

  @override
  Widget build(BuildContext context) {
    if (playlist.isDiscoverWeekly) {
      return _buildDiscoverWeeklyCover();
    }
    if (playlist.isDailyMix) {
      return _buildDailyMixCover();
    }
    if (playlist.isReleaseRadar) {
      return _buildReleaseRadarCover();
    }
    if (playlist.isCollageCover) {
      return _buildCollageCover();
    }
    return _buildSingleCover(playlist.coverUrl);
  }

  // ── Discover Weekly Cover (Spotify 1:1 Aesthetic) ────────────────────
  Widget _buildDiscoverWeeklyCover() {
    if (playlist.coverUrl.isNotEmpty) {
      return _buildSingleCover(playlist.coverUrl);
    }
    return _buildSingleCover('assets/images/discover_weekly.png');
  }

  // ── Daily Mix Cover (Spotify Colorways 1-6) ──────────────────────────
  Widget _buildDailyMixCover() {
    final mixNum = playlist.dailyMixNumber > 0 ? playlist.dailyMixNumber : 1;
    final List<List<Color>> mixGradients = [
      [const Color(0xFF006450), const Color(0xFF1E3264)], // Mix 1: Teal to Navy
      [const Color(0xFFBA5D07), const Color(0xFF3B1E08)], // Mix 2: Amber to Dark Brown
      [const Color(0xFFE91429), const Color(0xFF5B101E)], // Mix 3: Crimson to Burgundy
      [const Color(0xFF1DB954), const Color(0xFF0D4722)], // Mix 4: Spotify Green to Forest
      [const Color(0xFF7358FF), const Color(0xFF261A63)], // Mix 5: Purple to Deep Violet
      [const Color(0xFFE8115B), const Color(0xFF570722)], // Mix 6: Pink to Dark Maroon
    ];
    final grad = mixGradients[(mixNum - 1) % mixGradients.length];
    final urls = playlist.collageUrls;
    final mainArt = urls.isNotEmpty ? urls.first : playlist.coverUrl;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: grad,
          ),
        ),
        child: Stack(
          children: [
            if (mainArt.isNotEmpty && !mainArt.startsWith('collage:'))
              Positioned.fill(
                child: Opacity(
                  opacity: 0.42,
                  child: CachedNetworkImage(
                    imageUrl: mainArt,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) => const SizedBox(),
                  ),
                ),
              )
            else if (urls.isNotEmpty)
              Positioned.fill(
                child: Opacity(
                  opacity: 0.38,
                  child: Row(
                    children: [
                      Expanded(child: _collageCell(urls[0])),
                      if (urls.length > 1) Expanded(child: _collageCell(urls[1])),
                    ],
                  ),
                ),
              ),

            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black38, Colors.transparent, Colors.black87],
                  stops: [0.0, 0.4, 1.0],
                ),
              ),
            ),

            if (size < 75) ...[
              // Compact tile mode: never crush text over logo
              Positioned(
                top: (size * 0.08).clamp(3.0, 6.0),
                left: (size * 0.08).clamp(3.0, 6.0),
                child: Image.asset(
                  'assets/images/spotify_logo.png',
                  width: (size * 0.22).clamp(11.0, 14.0),
                  height: (size * 0.22).clamp(11.0, 14.0),
                  fit: BoxFit.contain,
                ),
              ),
              Positioned(
                left: (size * 0.08).clamp(3.0, 6.0),
                bottom: (size * 0.08).clamp(3.0, 6.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: grad[0].withValues(alpha: 0.75),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'MIX',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: (size * 0.14).clamp(8.0, 10.0),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '$mixNum',
                        style: TextStyle(
                          color: const Color(0xFF1DB954),
                          fontSize: (size * 0.17).clamp(9.0, 11.5),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // Standard card mode: spacious, cleanly proportioned
              Positioned(
                top: (size * 0.07).clamp(8.0, 16.0),
                left: (size * 0.07).clamp(8.0, 16.0),
                child: Image.asset(
                  'assets/images/spotify_logo.png',
                  width: (size * 0.12).clamp(14.0, 20.0),
                  height: (size * 0.12).clamp(14.0, 20.0),
                  fit: BoxFit.contain,
                ),
              ),
              Positioned(
                left: (size * 0.08).clamp(8.0, 16.0),
                right: (size * 0.08).clamp(8.0, 16.0),
                bottom: (size * 0.08).clamp(8.0, 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'DAILY MIX',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: (size * 0.095).clamp(10.0, 15.0),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '$mixNum',
                      style: TextStyle(
                        color: const Color(0xFF1DB954),
                        fontSize: (size * 0.14).clamp(14.0, 22.0),
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── 2×2 Collage (Daily Mix, Discover Weekly) ──────────────────────────
  Widget _buildCollageCover() {
    final urls = playlist.collageUrls;
    // Fill to exactly 4 slots (repeat last if not enough)
    while (urls.length < 4) {
      urls.add(urls.isNotEmpty ? urls.last : '');
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Stack(
        children: [
          SizedBox(
            width: size,
            height: size,
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: _collageCell(urls[0])),
                      Expanded(child: _collageCell(urls[1])),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: _collageCell(urls[2])),
                      Expanded(child: _collageCell(urls[3])),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Spotify Daily Mix Overlay Banner
          if (playlist.isDailyMix) ...[
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: size * 0.45,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xDD000000), Colors.transparent],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 8,
              bottom: 6,
              child: Text(
                'Daily Mix ${playlist.dailyMixNumber > 0 ? playlist.dailyMixNumber : ""}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: (size * 0.11).clamp(11.0, 16.0),
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                  shadows: const [
                    Shadow(color: Colors.black, blurRadius: 4),
                  ],
                ),
              ),
            ),
            // Spotify mini icon in top left corner
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black54,
                ),
                padding: const EdgeInsets.all(2),
                child: Image.asset(
                  'assets/images/spotify_logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _collageCell(String url) {
    if (url.isEmpty) {
      return Container(color: const Color(0xFF282828));
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(color: const Color(0xFF282828)),
      errorWidget: (context, url, error) => Container(
        color: const Color(0xFF282828),
        child: const Icon(Icons.music_note, color: Colors.white24, size: 20),
      ),
    );
  }

  // ── Release Radar (single art + radar badge overlay) ─────────────────
  Widget _buildReleaseRadarCover() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Stack(
        children: [
          _buildSingleCover(playlist.coverUrl),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: size * 0.35,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xCC000000), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 6,
            left: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF1ED760),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                'RELEASE RADAR',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: (size * 0.07).clamp(9.0, 12.0),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Single image ──────────────────────────────────────────────────────
  Widget _buildSingleCover(String url) {
    if (url.startsWith('assets/')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.asset(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            width: size,
            height: size,
            color: const Color(0xFF282828),
            child: const Center(child: Icon(Icons.music_note, color: Colors.white24, size: 36)),
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          width: size,
          height: size,
          color: const Color(0xFF282828),
          child: const Center(child: Icon(Icons.music_note, color: Colors.white24, size: 36)),
        ),
        errorWidget: (context, url, error) => Container(
          width: size,
          height: size,
          color: const Color(0xFF282828),
          child: const Center(child: Icon(Icons.music_note, color: Colors.white24, size: 36)),
        ),
      ),
    );
  }
}
