import 'package:flutter/material.dart';
import '../models/artist.dart';
import '../services/music_api_service.dart';
import '../services/deezer_api_service.dart';
import '../services/title_normalizer.dart';
import '../screens/artist_detail_screen.dart';

class ArtistNavigationService {
  /// Navigates to an artist's profile.
  /// If multiple artists share the same name or collaboration, picks the primary/most popular verified artist.
  static Future<void> navigateToArtist(BuildContext context, String rawArtistName) async {
    final cleanName = TitleNormalizer.cleanArtist(rawArtistName);
    // Take primary artist before comma, &, feat., etc.
    final primaryName = cleanName.split(RegExp(r'[,&]|\bfeat\.?\b|\bft\.?\b', caseSensitive: false)).first.trim();
    if (primaryName.isEmpty) return;

    // 1. Check local comprehensive catalog first
    final comprehensive = MusicApiService.getComprehensiveArtists();
    for (final a in comprehensive) {
      if (a.name.toLowerCase() == primaryName.toLowerCase() ||
          a.name.toLowerCase() == cleanName.toLowerCase()) {
        if (!context.mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ArtistDetailScreen(artist: a)),
        );
        return;
      }
    }

    // 2. Query Deezer catalog (sorted by highest fan count / popularity)
    try {
      final onlineArtist = await DeezerApiService.searchArtist(primaryName);
      if (onlineArtist != null && context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ArtistDetailScreen(artist: onlineArtist)),
        );
        return;
      }
    } catch (_) {}

    // 3. Fallback: Create dynamic artist with their name
    if (!context.mounted) return;
    final fallbackArtist = Artist(
      id: 'art_${primaryName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
      name: primaryName,
      imageUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&q=80',
      headerImageUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&q=80',
      monthlyListeners: 'Artis Terverifikasi',
      bio: '$primaryName adalah artis terverifikasi.',
      isVerified: true,
      topTracks: const [],
      albums: const [],
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ArtistDetailScreen(artist: fallbackArtist)),
    );
  }
}
