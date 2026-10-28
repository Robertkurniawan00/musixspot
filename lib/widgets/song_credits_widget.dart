import 'package:flutter/material.dart';
import '../models/song.dart';
import '../models/song_credits.dart';
import '../services/song_credits_service.dart';
import '../theme/spotify_theme.dart';

class SongCreditsWidget extends StatefulWidget {
  final Song song;

  const SongCreditsWidget({
    super.key,
    required this.song,
  });

  @override
  State<SongCreditsWidget> createState() => _SongCreditsWidgetState();
}

class _SongCreditsWidgetState extends State<SongCreditsWidget> {
  bool _isFollowingMainArtist = false;

  void _showAllCreditsModal(BuildContext context, SongCredits credits) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF181818),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                const SizedBox(height: 20),
                Text(
                  widget.song.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.song.artist,
                  style: const TextStyle(
                    color: SpotifyTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),

                // Performer Section
                const Text(
                  'Dibawakan Oleh',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                ...credits.performers.map((p) => _buildCreditRow(p.name, p.role)),
                const Divider(color: Colors.white12, height: 32),

                // Writers Section
                const Text(
                  'Ditulis Oleh',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                ...credits.writers.map((w) => _buildCreditRow(w.name, w.role)),
                const Divider(color: Colors.white12, height: 32),

                // Producers Section
                const Text(
                  'Diproduksi Oleh',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                ...credits.producers.map((pr) => _buildCreditRow(pr.name, pr.role)),
                const Divider(color: Colors.white12, height: 32),

                // Source & Copyright Section
                const Text(
                  'Sumber & Hak Cipta',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                _buildCreditRow(credits.source, 'Label Rekaman / Rilis'),
                const SizedBox(height: 6),
                Text(
                  credits.copyright,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 32),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCreditRow(String name, String role) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            role,
            style: const TextStyle(
              color: SpotifyTheme.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final credits = SongCreditsService.getCreditsForSong(widget.song);
    final mainPerformer = credits.performers.isNotEmpty
        ? credits.performers.first
        : SongCreditItem(name: widget.song.artist, role: 'Artis Utama');
    final mainWriter = credits.writers.isNotEmpty
        ? credits.writers.first
        : SongCreditItem(name: widget.song.artist, role: 'Komposer • Penulis Lirik');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF242424),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: "Kredit" + "Tampilkan semua" (Screenshots 2 & 4)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Kredit',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              GestureDetector(
                onTap: () => _showAllCreditsModal(context, credits),
                child: const Text(
                  'Tampilkan semua',
                  style: TextStyle(
                    color: SpotifyTheme.spotifyGreenLight,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Line 1: Main Artist + "Ikuti" Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mainPerformer.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      mainPerformer.role,
                      style: const TextStyle(
                        color: SpotifyTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(
                    color: _isFollowingMainArtist ? const Color(0xFF1DB954) : Colors.white60,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  minimumSize: const Size(60, 32),
                ),
                onPressed: () {
                  setState(() {
                    _isFollowingMainArtist = !_isFollowingMainArtist;
                  });
                },
                child: Text(
                  _isFollowingMainArtist ? 'Mengikuti' : 'Ikuti',
                  style: TextStyle(
                    color: _isFollowingMainArtist ? const Color(0xFF1DB954) : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Line 2: Composer / Songwriter
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mainWriter.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                mainWriter.role,
                style: const TextStyle(
                  color: SpotifyTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
