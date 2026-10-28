import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/spotify_theme.dart';
import '../models/playlist.dart';
import 'playlist_cover_widget.dart';

/// Standard album/playlist card used in horizontal carousels on Home screen.
/// Supports:
///  - Regular image covers
///  - Collage covers ("collage:url1|url2|url3|url4")
///  - Circular image (artist profile)
///  - Playlist model for Spotify-authentic cover rendering
class AlbumCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String imageUrl;
  final VoidCallback onTap;
  final bool isCircular;
  final Playlist? playlist; // When provided, uses PlaylistCoverWidget

  const AlbumCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.onTap,
    this.isCircular = false,
    this.playlist,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 130,
        margin: const EdgeInsets.only(right: 14),
        child: Column(
          crossAxisAlignment:
              isCircular ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            // ── Artwork ───────────────────────────────────────────────
            if (playlist != null)
              PlaylistCoverWidget(playlist: playlist!, size: 130)
            else if (imageUrl.startsWith('collage:'))
              _buildCollage(imageUrl, 130)
            else
              ClipRRect(
                borderRadius: isCircular
                    ? BorderRadius.circular(65)
                    : BorderRadius.circular(6),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: 130,
                  height: 130,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => _placeholder(),
                  errorWidget: (context, url, error) => _placeholder(),
                ),
              ),
            const SizedBox(height: 8),

            // ── Title ─────────────────────────────────────────────────
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign:
                  isCircular ? TextAlign.center : TextAlign.start,
              style: const TextStyle(
                color: SpotifyTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),

            // ── Subtitle ──────────────────────────────────────────────
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign:
                  isCircular ? TextAlign.center : TextAlign.start,
              style: const TextStyle(
                color: SpotifyTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w400,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 130,
      height: 130,
      decoration: BoxDecoration(
        color: SpotifyTheme.cardSurfaceHighlight,
        borderRadius: BorderRadius.circular(isCircular ? 65 : 6),
      ),
      child: const Center(
        child: Icon(Icons.music_note, color: Colors.white24, size: 36),
      ),
    );
  }

  /// Builds a 2×2 collage grid from "collage:url1|url2|url3|url4" string
  static Widget _buildCollage(String collageUrl, double size) {
    final urlPart = collageUrl.substring('collage:'.length);
    final urls = urlPart.split('|');
    while (urls.length < 4) {
      urls.add(urls.isNotEmpty ? urls.last : '');
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
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
    );
  }

  static Widget _collageCell(String url) {
    if (url.isEmpty) return Container(color: const Color(0xFF282828));
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(color: const Color(0xFF282828)),
      errorWidget: (context, url, error) => Container(
        color: const Color(0xFF282828),
        child: const Icon(Icons.music_note, color: Colors.white24, size: 16),
      ),
    );
  }
}
