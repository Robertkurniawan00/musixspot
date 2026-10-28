import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/song.dart';
import 'youtube_api_service.dart';
import 'deezer_api_service.dart';
import 'title_normalizer.dart';

/// Multi-source music search pipeline combining:
///   1. Deezer    → 100M+ global catalog, high-res square covers & direct streams
///   2. iTunes    → Official Apple Music catalog, clean 1000x1000 artwork
///   3. YouTube   → Direct video IDs with multi-stream extraction (fallback)
///
/// All queries run in parallel. Results are deduplicated, scored, and merged.
class MultiSourceSearchService {
  static const _itunes = 'https://itunes.apple.com';

  // In-memory dedup cache: "artist_title" -> Song
  static final Map<String, Song> _searchCache = {};

  /// Unescapes HTML entities commonly returned by web APIs
  static String unescapeHtml(String text) {
    return text
        .replaceAll('&#39;', "'")
        .replaceAll('&#039;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ');
  }

  /// Main entry point.
  /// Priority: Deezer (100M catalog) + iTunes (Apple Music) + YouTube API
  static Future<List<Song>> search(String query, {int limit = 30}) async {
    if (query.trim().isEmpty) return [];

    final q = unescapeHtml(query.trim());
    final results = <Song>[];
    final seenKeys = <String>{};

    void addIfNew(Song song) {
      final cleanSong = TitleNormalizer.normalizeSong(song);
      final key = TitleNormalizer.dedupKey(cleanSong.artist, cleanSong.title);
      if (!seenKeys.contains(key)) {
        seenKeys.add(key);
        results.add(cleanSong);
        _searchCache[key] = cleanSong;
      }
    }

    // Generate query variants for punctuation-tolerant searching
    final variants = <String>[q];

    // Intent expansion for Turkish and Indian / Bollywood searches
    final lowerQ = q.toLowerCase();
    if (lowerQ.contains('turki') || lowerQ.contains('turkish') || lowerQ.contains('turkce')) {
      variants.addAll(['Tarkan', 'Mustafa Ceceli', 'Simge', 'Burak Bulut', 'Turkish Hits']);
    } else if (lowerQ.contains('india') || lowerQ.contains('bollywood') || lowerQ.contains('hindi')) {
      variants.addAll(['Bollywood Hits', 'Arijit Singh', 'Shreya Ghoshal', 'Tum Hi Ho', 'Hindi Hits']);
    }

    final normalizedIs = q
        .replaceAll(RegExp(r"['’`´]s\b", caseSensitive: false), ' is')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (normalizedIs != q) variants.add(normalizedIs);

    final normalizedSpace = q
        .replaceAll(RegExp(r"['’`´]"), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (normalizedSpace != q && normalizedSpace != normalizedIs) {
      variants.add(normalizedSpace);
    }

    // 1. Query Deezer with query variants
    List<Song> dzSongs = [];
    for (final v in variants) {
      dzSongs = await DeezerApiService.searchTracks(v, limit: limit);
      if (dzSongs.isNotEmpty) break;
    }

    // 2. Query iTunes with query variants
    List<Song> itunesSongs = [];
    for (final v in variants) {
      itunesSongs = await _searchItunes(v, limit: limit);
      if (itunesSongs.isNotEmpty) break;
    }

    // Merge Deezer tracks first (genuine high-res square covers & tags)
    for (final song in dzSongs) {
      addIfNew(song);
    }

    // Followed by iTunes tracks (official Apple Music 1000x1000 square artwork)
    for (final song in itunesSongs) {
      addIfNew(song);
    }

    // 3. Fallback: Only call YouTube scraper if Deezer + iTunes returned fewer than 5 results
    if (results.length < 5) {
      try {
        final ytSongs = await YouTubeApiService.search(q, limit: limit);
        for (final song in ytSongs) {
          // Avoid dirty scraper channels if we have authentic songs
          if (song.artist.toLowerCase() == 'release' ||
              song.artist.toLowerCase() == 'various artists') {
            continue;
          }
          addIfNew(song);
        }
      } catch (e) {
        debugPrint('YouTube fallback error: $e');
      }
    }

    return results.take(limit).toList();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SOURCE 2: iTunes Search API (Free, no key, global catalog)
  // Returns 30s preview URLs; actual stream resolved via YouTube at play time
  // ─────────────────────────────────────────────────────────────────────────
  static Future<List<Song>> _searchItunes(String query, {int limit = 25}) async {
    try {
      final url = Uri.parse(
        '$_itunes/search?term=${Uri.encodeComponent(query)}'
        '&media=music&entity=song&limit=$limit',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return [];

      final data = json.decode(response.body);
      final items = (data['results'] as List?) ?? [];

      return items
          .where((item) =>
              item['trackName'] != null &&
              item['artistName'] != null &&
              _isNotBlacklisted(item['trackName'] as String, item['artistName'] as String))
          .map<Song?>((item) {
            try {
              return _parseItunesSong(item);
            } catch (e) {
              return null;
            }
          })
          .whereType<Song>()
          .toList();
    } catch (e) {
      debugPrint('iTunes search error: $e');
      return [];
    }
  }

  static Song _parseItunesSong(Map<String, dynamic> item) {
    final trackId = (item['trackId'] ?? DateTime.now().millisecondsSinceEpoch).toString();
    final rawTrackName = (item['trackName'] as String?) ?? 'Unknown';
    final rawArtistName = (item['artistName'] as String?) ?? 'Unknown Artist';
    final rawAlbumName = (item['collectionName'] as String?) ?? '';
    final durMs = (item['trackTimeMillis'] as int?) ?? 210000;

    final trackName = TitleNormalizer.cleanTitle(unescapeHtml(rawTrackName));
    final artistName = TitleNormalizer.cleanArtist(unescapeHtml(rawArtistName));
    final albumName = TitleNormalizer.cleanTitle(unescapeHtml(rawAlbumName));

    // Get high-res artwork: replace 100x100 → 1000x1000
    String art = (item['artworkUrl100'] as String?) ?? '';
    art = art.replaceAll('100x100bb.jpg', '1000x1000bb.jpg');
    if (art.isEmpty) {
      art = 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&q=80';
    }

    // iTunes streams resolved via YouTube at play time to ensure full song playback
    return Song(
      id: 'itunes_$trackId',
      title: trackName,
      artist: artistName,
      album: albumName,
      albumArtUrl: art,
      audioUrl: 'youtube:$artistName $trackName',
      duration: Duration(milliseconds: durMs),
      lyrics: null,
    );
  }

  static bool _isNotBlacklisted(String title, String artist) {
    final t = title.toLowerCase();
    final a = artist.toLowerCase();
    const blacklist = [
      'karaoke', 'tribute', 'cover', 'instrumental version',
      'album terbaik', 'greatest hits compilation', 'best of collection',
      'slowed', 'reverb', 'nightcore',
    ];
    return !blacklist.any((bad) => t.contains(bad) || a.contains(bad));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Fetch trending / popular chart tracks (for Home screen)
  // ─────────────────────────────────────────────────────────────────────────
  static Future<List<Song>> getTrending({String lang = 'global', int limit = 20}) async {
    return DeezerApiService.getChartTracks(limit: limit);
  }

  /// Fetch songs by a specific artist from Deezer
  static Future<List<Song>> getArtistSongs(String artistName, {int limit = 20}) async {
    return DeezerApiService.getArtistTopTracks(artistName, limit: limit);
  }

  /// Fetch songs from a specific album via Deezer
  static Future<List<Song>> getAlbumSongs(String albumName, String artistName) async {
    return DeezerApiService.searchTracks('album:"$albumName" artist:"$artistName"', limit: 25);
  }

  static void clearCache() => _searchCache.clear();
}
