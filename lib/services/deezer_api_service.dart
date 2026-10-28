import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/song.dart';
import '../models/artist.dart';
import 'title_normalizer.dart';

class DeezerApiService {
  static const String _baseUrl = 'https://api.deezer.com';

  /// Search tracks on Deezer's 100M+ global catalog
  static Future<List<Song>> searchTracks(String query, {int limit = 25}) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    Future<List<Song>> queryRaw(String term) async {
      try {
        final uri = Uri.parse('$_baseUrl/search?q=${Uri.encodeComponent(term)}&limit=$limit');
        final resp = await http.get(uri).timeout(const Duration(seconds: 8));
        if (resp.statusCode == 200) {
          final data = json.decode(resp.body);
          final items = (data['data'] as List?) ?? [];
          return items.map((item) => _parseDeezerSong(item)).whereType<Song>().toList();
        }
      } catch (e) {
        debugPrint('DeezerApiService.searchTracks error: $e');
      }
      return [];
    }

    var list = await queryRaw(q);
    if (list.isEmpty && (q.contains("'") || q.contains("’") || q.contains("`"))) {
      final normalizedIs = q
          .replaceAll(RegExp(r"['’`´]s\b", caseSensitive: false), ' is')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      list = await queryRaw(normalizedIs);
      if (list.isEmpty) {
        final normalizedSpace = q
            .replaceAll(RegExp(r"['’`´]"), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        list = await queryRaw(normalizedSpace);
      }
    }
    return list;
  }

  /// Get Top Chart Tracks (Global or Top Hits)
  static Future<List<Song>> getChartTracks({int limit = 30}) async {
    try {
      final uri = Uri.parse('$_baseUrl/chart/0/tracks?limit=$limit');
      final resp = await http.get(uri).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final items = (data['data'] as List?) ?? [];
        return items.map((item) => _parseDeezerSong(item)).whereType<Song>().toList();
      }
    } catch (e) {
      debugPrint('DeezerApiService.getChartTracks error: $e');
    }
    return [];
  }

  /// Get curated genre tracks (e.g. Pop, Rock, Hip-Hop, Anime, etc.)
  static Future<List<Song>> getGenreTracks(String genreQuery, {int limit = 25}) async {
    return searchTracks(genreQuery, limit: limit);
  }

  /// Get artist top tracks
  static Future<List<Song>> getArtistTopTracks(String artistName, {int limit = 20}) async {
    return searchTracks('artist:"$artistName"', limit: limit);
  }

  /// Search multiple artists by name from Deezer's 100M+ catalog
  static Future<List<Artist>> searchArtists(String query, {int limit = 15}) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    try {
      final uri = Uri.parse('$_baseUrl/search/artist?q=${Uri.encodeComponent(cleanQuery)}&limit=$limit');
      final resp = await http.get(uri).timeout(const Duration(seconds: 6));
      if (resp.statusCode != 200) return [];

      final data = json.decode(resp.body);
      final items = (data['data'] as List?) ?? [];
      final List<Artist> list = [];

      for (final item in items) {
        final artistId = (item['id'] ?? '').toString();
        final rawArtistName = (item['name'] ?? '').toString();
        final artistName = TitleNormalizer.cleanArtist(rawArtistName);
        if (artistName.isEmpty) continue;

        String pictureXl = (item['picture_xl'] ??
                item['picture_big'] ??
                item['picture_medium'] ??
                '')
            .toString();
        final fans = (item['nb_fan'] as int?) ?? 50000;
        final fansFormatted = _formatListeners(fans);

        list.add(
          Artist(
            id: 'dz_artist_$artistId',
            name: artistName,
            imageUrl: pictureXl.isNotEmpty
                ? pictureXl
                : 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&q=80',
            headerImageUrl: pictureXl.isNotEmpty
                ? pictureXl
                : 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&q=80',
            monthlyListeners: '$fansFormatted pendengar bulanan',
            bio: '$artistName adalah artis terverifikasi di katalog musik global.',
            isVerified: true,
            topTracks: const [],
            albums: const [],
            country: 'Global',
            genres: const ['Pop'],
          ),
        );
      }
      return list;
    } catch (e) {
      debugPrint('DeezerApiService.searchArtists error: $e');
      return [];
    }
  }

  /// Search artist by name, returning Artist profile with top tracks and albums/EPs
  static Future<Artist?> searchArtist(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return null;

    try {
      final uri = Uri.parse('$_baseUrl/search/artist?q=${Uri.encodeComponent(cleanQuery)}&limit=10');
      final resp = await http.get(uri).timeout(const Duration(seconds: 6));
      if (resp.statusCode != 200) return null;

      final data = json.decode(resp.body);
      final items = (data['data'] as List?) ?? [];
      if (items.isEmpty) return null;

      // When multiple artists share the same name, rank and pick the most famous/verified one (highest fan count)
      final candidateList = List<Map<String, dynamic>>.from(items);
      candidateList.sort((a, b) {
        final fansA = (a['nb_fan'] as int?) ?? 0;
        final fansB = (b['nb_fan'] as int?) ?? 0;
        return fansB.compareTo(fansA);
      });

      final artistItem = candidateList.first;
      final artistId = (artistItem['id'] ?? '').toString();
      final rawArtistName = (artistItem['name'] ?? '').toString();
      final artistName = TitleNormalizer.cleanArtist(rawArtistName);
      String pictureXl = (artistItem['picture_xl'] ??
              artistItem['picture_big'] ??
              artistItem['picture_medium'] ??
              '')
          .toString();
      final fans = (artistItem['nb_fan'] as int?) ?? 100000;
      final fansFormatted = _formatListeners(fans);

      // Fetch top tracks and albums in parallel
      final results = await Future.wait([
        _fetchArtistTopTracks(artistId, artistName, pictureXl),
        getArtistAlbums(artistId),
      ]);

      final topTracks = results[0] as List<Song>;
      final albums = results[1] as List<ArtistAlbum>;

      // If artist photo is empty or missing, fallback to first track album artwork
      if (pictureXl.isEmpty && topTracks.isNotEmpty) {
        pictureXl = topTracks.first.albumArtUrl;
      }

      return Artist(
        id: 'dz_artist_$artistId',
        name: artistName,
        imageUrl: pictureXl.isNotEmpty ? pictureXl : 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&q=80',
        headerImageUrl: pictureXl.isNotEmpty ? pictureXl : 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&q=80',
        monthlyListeners: '$fansFormatted pendengar bulanan',
        bio: '$artistName adalah artis terverifikasi dengan ribuan karya di katalog musik global. Temukan lagu terpopuler, album, dan rilisan terbarunya di sini.',
        isVerified: true,
        topTracks: topTracks,
        albums: albums,
      );
    } catch (e) {
      debugPrint('DeezerApiService.searchArtist error: $e');
      return null;
    }
  }

  /// Get artist's albums and EPs
  static Future<List<ArtistAlbum>> getArtistAlbums(String artistId) async {
    try {
      final uri = Uri.parse('$_baseUrl/artist/$artistId/albums?limit=30');
      final resp = await http.get(uri).timeout(const Duration(seconds: 6));
      if (resp.statusCode != 200) return [];

      final data = json.decode(resp.body);
      final items = (data['data'] as List?) ?? [];
      final List<ArtistAlbum> albums = [];

      for (final item in items) {
        final albumId = (item['id'] ?? '').toString();
        final rawTitle = (item['title'] ?? 'Album').toString();
        final title = TitleNormalizer.cleanTitle(rawTitle);
        final coverUrl = (item['cover_xl'] ??
                item['cover_big'] ??
                item['cover_medium'] ??
                '')
            .toString();
        final releaseDate = (item['release_date'] ?? '').toString();
        final releaseYear = releaseDate.isNotEmpty ? releaseDate.split('-').first : '2024';
        final rawType = (item['record_type'] ?? 'album').toString().toLowerCase();

        String typeStr = 'Album';
        if (rawType == 'single') {
          typeStr = 'Single';
        } else if (rawType == 'ep') {
          typeStr = 'EP';
        }

        albums.add(
          ArtistAlbum(
            id: albumId,
            title: title,
            coverUrl: coverUrl,
            releaseYear: releaseYear,
            type: typeStr,
          ),
        );
      }
      return albums;
    } catch (e) {
      debugPrint('DeezerApiService.getArtistAlbums error: $e');
      return [];
    }
  }

  /// Fetch tracks of a specific album
  static Future<List<Song>> getAlbumTracks(
    String albumId, {
    String? coverUrl,
    String? artistName,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/album/$albumId/tracks?limit=50');
      final resp = await http.get(uri).timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return [];

      final data = json.decode(resp.body);
      final items = (data['data'] as List?) ?? [];
      final List<Song> songs = [];

      for (final item in items) {
        final trackId = (item['id'] ?? '').toString();
        final rawTitle = (item['title'] ?? item['title_short'] ?? 'Unknown').toString();
        final rawTrackArtist = (item['artist']?['name'] ?? artistName ?? 'Unknown Artist').toString();
        final title = TitleNormalizer.cleanTitle(rawTitle);
        final trackArtist = TitleNormalizer.cleanArtist(rawTrackArtist);
        final durationSec = (item['duration'] as int?) ?? 200;

        songs.add(
          Song(
            id: 'dz_$trackId',
            title: title,
            artist: trackArtist,
            album: '',
            albumArtUrl: (coverUrl != null && coverUrl.isNotEmpty)
                ? coverUrl
                : 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&q=80',
            audioUrl: 'youtube:$trackArtist $title',
            duration: Duration(seconds: durationSec),
            lyrics: null,
          ),
        );
      }
      return songs;
    } catch (e) {
      debugPrint('DeezerApiService.getAlbumTracks error: $e');
      return [];
    }
  }

  static Future<List<Song>> _fetchArtistTopTracks(
    String artistId,
    String artistName,
    String defaultArtUrl,
  ) async {
    try {
      final uri = Uri.parse('$_baseUrl/artist/$artistId/top?limit=25');
      final resp = await http.get(uri).timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final items = (data['data'] as List?) ?? [];
        final List<Song> list = [];
        final seenKeys = <String>{};

        for (final item in items) {
          final s = _parseDeezerSong(item);
          if (s == null) continue;
          final key = TitleNormalizer.dedupKey(s.artist, s.title);
          if (!seenKeys.contains(key)) {
            seenKeys.add(key);
            final art = s.albumArtUrl.isNotEmpty ? s.albumArtUrl : defaultArtUrl;
            list.add(
              Song(
                id: s.id,
                title: s.title,
                artist: s.artist,
                album: s.album,
                albumArtUrl: art.isNotEmpty ? art : 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&q=80',
                audioUrl: s.audioUrl,
                duration: s.duration,
                lyrics: s.lyrics,
              ),
            );
          }
        }
        return list;
      }
    } catch (e) {
      debugPrint('DeezerApiService._fetchArtistTopTracks error: $e');
    }
    return [];
  }

  static String _formatListeners(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)} jt';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)} rb';
    }
    return count.toString();
  }

  /// Convert Deezer JSON track into Spotify clone Song model
  static Song? _parseDeezerSong(Map<String, dynamic> item) {
    try {
      final id = (item['id'] ?? '').toString();
      final rawTitle = (item['title'] ?? item['title_short'] ?? 'Unknown').toString();
      final title = TitleNormalizer.cleanTitle(rawTitle);
      final artistMap = item['artist'] as Map<String, dynamic>?;
      final rawArtist = (artistMap?['name'] ?? 'Unknown Artist').toString();
      final artistName = TitleNormalizer.cleanArtist(rawArtist);
      final albumMap = item['album'] as Map<String, dynamic>?;
      final rawAlbum = (albumMap?['title'] ?? '').toString();
      final albumName = TitleNormalizer.cleanTitle(rawAlbum);

      // Highest resolution album art
      String artUrl = (albumMap?['cover_xl'] ??
              albumMap?['cover_big'] ??
              albumMap?['cover_medium'] ??
              item['cover_xl'] ??
              item['cover_big'] ??
              '')
          .toString();

      if (artUrl.isEmpty) {
        artUrl = 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&q=80';
      }

      final durationSec = (item['duration'] as int?) ?? 210;

      return Song(
        id: 'dz_$id',
        title: title,
        artist: artistName,
        album: albumName,
        albumArtUrl: artUrl,
        audioUrl: 'youtube:$artistName $title',
        duration: Duration(seconds: durationSec),
        lyrics: null,
      );
    } catch (e) {
      debugPrint('DeezerApiService._parseDeezerSong error: $e');
      return null;
    }
  }
}
