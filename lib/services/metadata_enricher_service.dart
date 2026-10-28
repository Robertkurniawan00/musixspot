import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/song.dart';

/// Service to fetch official 1:1 clean square album artwork
/// and genuine album titles from iTunes / Apple Music + Deezer (No login needed)
class MetadataEnricherService {
  static final Map<String, Map<String, String>> _cache = {};

  /// Enrich a Song object with official square album art and real album name
  static Future<bool> enrichSong(Song song) async {
    final isYtThumb = song.albumArtUrl.contains('ytimg.com') ||
        song.albumArtUrl.contains('youtube.com') ||
        song.albumArtUrl.isEmpty;
    final hasBogusAlbum = song.album.isEmpty ||
        song.album.toLowerCase().contains('official') ||
        song.album.toLowerCase() == 'unknown album';

    if (!isYtThumb && !hasBogusAlbum) {
      return false;
    }

    final cacheKey = '${song.artist}_${song.title}'.toLowerCase();
    if (_cache.containsKey(cacheKey)) {
      final cached = _cache[cacheKey]!;
      bool updated = false;
      if (isYtThumb && cached['artwork'] != null && cached['artwork']!.isNotEmpty) {
        song.albumArtUrl = cached['artwork']!;
        updated = true;
      }
      if (hasBogusAlbum && cached['album'] != null && cached['album']!.isNotEmpty) {
        song.album = cached['album']!;
        updated = true;
      }
      return updated;
    }

    final cleanTitle = song.title.replaceAll(RegExp(r'\s*\(.*?\)\s*'), '').trim();
    final cleanArtist = song.artist.replaceAll(RegExp(r'\s*\(.*?\)\s*'), '').trim();
    final queryStr = '$cleanArtist $cleanTitle';

    // 1. Try iTunes / Apple Music API
    try {
      final url = Uri.parse(
        'https://itunes.apple.com/search?term=${Uri.encodeComponent(queryStr)}&entity=song&limit=1',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['resultCount'] != null && data['resultCount'] > 0) {
          final item = data['results'][0];
          final rawArt = (item['artworkUrl100'] as String?) ?? '';
          final cleanArt = rawArt.replaceAll('100x100bb', '600x600bb');
          final collectionName = (item['collectionName'] as String?) ?? '';

          final result = <String, String>{};
          if (cleanArt.isNotEmpty) result['artwork'] = cleanArt;
          if (collectionName.isNotEmpty) result['album'] = collectionName;
          _cache[cacheKey] = result;

          bool updated = false;
          if (cleanArt.isNotEmpty) {
            song.albumArtUrl = cleanArt;
            updated = true;
          }
          if (collectionName.isNotEmpty) {
            song.album = collectionName;
            updated = true;
          }
          return updated;
        }
      }
    } catch (_) {}

    // 2. Secondary fallback: Deezer API
    try {
      final dzUrl = Uri.parse(
        'https://api.deezer.com/search?q=${Uri.encodeComponent(queryStr)}&limit=1',
      );
      final dzResp = await http.get(dzUrl).timeout(const Duration(seconds: 4));
      if (dzResp.statusCode == 200) {
        final data = json.decode(dzResp.body);
        final list = (data['data'] as List?) ?? [];
        if (list.isNotEmpty) {
          final first = list.first;
          final cleanArt = (first['album']?['cover_big'] as String?) ??
              (first['album']?['cover_medium'] as String?) ??
              '';
          final collectionName = (first['album']?['title'] as String?) ?? '';

          final result = <String, String>{};
          if (cleanArt.isNotEmpty) result['artwork'] = cleanArt;
          if (collectionName.isNotEmpty) result['album'] = collectionName;
          _cache[cacheKey] = result;

          bool updated = false;
          if (cleanArt.isNotEmpty) {
            song.albumArtUrl = cleanArt;
            updated = true;
          }
          if (collectionName.isNotEmpty) {
            song.album = collectionName;
            updated = true;
          }
          return updated;
        }
      }
    } catch (e) {
      debugPrint('MetadataEnricherService: could not enrich "${song.title}": $e');
    }

    return false;
  }
}
