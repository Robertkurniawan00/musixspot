import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/song.dart';
import '../screens/artist_shorts_screen.dart';

class ExploreArtistSection extends StatelessWidget {
  final Song song;

  const ExploreArtistSection({
    super.key,
    required this.song,
  });

  @override
  Widget build(BuildContext context) {
    final artistName = song.artist;
    final trackTitle = song.title;

    final cards = [
      {
        'title': 'Lagu oleh\n$artistName',
        'sub': 'MV & Teaser',
        'image': song.albumArtUrl,
        'hashtags': ['#hits', '#pop', '#audio', '#music'],
        'screenTitle': 'Lagu oleh $artistName',
        'mode': 'artist_songs',
      },
      {
        'title': 'Serupa\ndengan $artistName',
        'sub': 'Rekomendasi Artis',
        'image': 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&q=80',
        'hashtags': ['#serupa', '#vibes', '#rekomendasi'],
        'screenTitle': 'Serupa dengan $artistName',
        'mode': 'similar_artist',
      },
      {
        'title': 'Serupa\ndengan $trackTitle',
        'sub': 'Eksplorasi Lagu',
        'image': 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=600&q=80',
        'hashtags': ['#mood', '#trending', '#indie'],
        'screenTitle': 'Serupa dengan $trackTitle',
        'mode': 'similar_track',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Text(
          'Jelajahi $artistName',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 12),

        // Horizontal Carousel of Vertical Preview Cards (Screenshots 2 & 4)
        SizedBox(
          height: 190,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: cards.length,
            itemBuilder: (ctx, i) {
              final c = cards[i];
              final titleText = c['title'] as String;
              final imgUrl = c['image'] as String;

              return Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ArtistShortsScreen(
                          artistName: artistName,
                          initialSong: song,
                          mode: c['mode'] as String? ?? 'similar_artist',
                        ),
                      ),
                    );
                  },
                  child: Container(
                    width: 125,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: const Color(0xFF242424),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Background image
                        CachedNetworkImage(
                          imageUrl: imgUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => Container(color: const Color(0xFF2E2E2E)),
                        ),

                        // Gradient vignette
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.3),
                                Colors.black.withValues(alpha: 0.85),
                              ],
                              stops: const [0.0, 0.4, 1.0],
                            ),
                          ),
                        ),

                        // Title text at bottom
                        Positioned(
                          left: 10,
                          right: 10,
                          bottom: 12,
                          child: Text(
                            titleText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
