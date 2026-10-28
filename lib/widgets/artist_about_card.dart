import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/artist.dart';
import '../models/song.dart';
import '../services/music_api_service.dart';
import '../screens/artist_detail_screen.dart';
import '../services/artist_navigation_service.dart';

class ArtistAboutCard extends StatefulWidget {
  final Song song;
  final Artist? artist;

  const ArtistAboutCard({
    super.key,
    required this.song,
    this.artist,
  });

  @override
  State<ArtistAboutCard> createState() => _ArtistAboutCardState();
}

class _ArtistAboutCardState extends State<ArtistAboutCard> {
  bool _isFollowing = false;
  bool _isBioExpanded = false;

  @override
  Widget build(BuildContext context) {
    // Resolve artist from service or passed artist
    final resolvedArtist = widget.artist ??
        MusicApiService.getArtistByName(widget.song.artist) ??
        Artist(
          id: 'art_${widget.song.artist.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
          name: widget.song.artist,
          country: 'Global',
          genres: const ['Pop', 'Hits'],
          imageUrl: widget.song.albumArtUrl,
          headerImageUrl: widget.song.albumArtUrl,
          monthlyListeners: '3.450.200 pendengar bulanan',
          bio: '${widget.song.artist} adalah musisi berbakat dengan karya-karya hits yang dinikmati jutaan pendengar di seluruh dunia.',
          isVerified: true,
          topTracks: [widget.song],
        );

    final bgImage = resolvedArtist.headerImageUrl.isNotEmpty
        ? resolvedArtist.headerImageUrl
        : resolvedArtist.imageUrl;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF242424),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Hero Image with "Tentang artis" overlay
          GestureDetector(
            onTap: () {
              if (widget.artist != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ArtistDetailScreen(artist: widget.artist!),
                  ),
                );
              } else {
                ArtistNavigationService.navigateToArtist(context, widget.song.artist);
              }
            },
            child: Stack(
              children: [
                SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: CachedNetworkImage(
                    imageUrl: bgImage,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => Container(color: const Color(0xFF2E2E2E)),
                    errorWidget: (_, _, _) => Container(
                      color: const Color(0xFF2E2E2E),
                      child: const Icon(Icons.person, color: Colors.white24, size: 48),
                    ),
                  ),
                ),
                // Gradient overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.5),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.8),
                        ],
                      ),
                    ),
                  ),
                ),
                // "Tentang artis" label at top-left
                const Positioned(
                  top: 14,
                  left: 14,
                  child: Text(
                    'Tentang artis',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      shadows: [
                        Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Artist Details & Actions (Name, Verified, Listeners, Follow Button)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  resolvedArtist.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (resolvedArtist.isVerified) ...[
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.verified,
                                  color: Color(0xFF1DB954),
                                  size: 18,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            resolvedArtist.monthlyListeners,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // "Ikuti" (Follow) Button
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: _isFollowing ? const Color(0xFF1DB954) : Colors.white60,
                          width: 1.2,
                        ),
                        backgroundColor: _isFollowing ? const Color(0xFF1DB954).withValues(alpha: 0.15) : Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      ),
                      onPressed: () {
                        setState(() {
                          _isFollowing = !_isFollowing;
                        });
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(_isFollowing
                                ? 'Mengikuti ${resolvedArtist.name}'
                                : 'Batal mengikuti ${resolvedArtist.name}'),
                            duration: const Duration(milliseconds: 900),
                          ),
                        );
                      },
                      child: Text(
                        _isFollowing ? 'Mengikuti' : 'Ikuti',
                        style: TextStyle(
                          color: _isFollowing ? const Color(0xFF1DB954) : Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // 3. Bio Text with "lihat semua" expander
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isBioExpanded = !_isBioExpanded;
                    });
                  },
                  child: RichText(
                    maxLines: _isBioExpanded ? null : 3,
                    overflow: _isBioExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                    text: TextSpan(
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.45,
                      ),
                      children: [
                        TextSpan(
                          text: resolvedArtist.bio,
                        ),
                        if (!_isBioExpanded)
                          const TextSpan(
                            text: '... lihat semua',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
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
