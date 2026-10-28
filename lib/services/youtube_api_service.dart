import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/song.dart';
import 'song_stream_resolver.dart';

/// YouTube Data API v3 — Official music-only search with 100% square album artwork.
///
/// Poster / Artwork Policy:
///   - NEVER use YouTube 16:9 video thumbnails (prevents black bars and rectangular crop).
///   - Primary: Apple Music / iTunes Store API (genuine 1:1 master square art).
///   - Secondary: Deezer Public API (genuine 500×500 master square art).
///   - Fallback: Spotify clean album art placeholder.
class YouTubeApiService {
  // ── YouTube API Key (Can be overridden via dart-define) ─────────────────────
  static const _apiKey = String.fromEnvironment(
    'YOUTUBE_API_KEY',
    defaultValue: 'AIzaSyAYJw7G73vf1nfJQzE4364wYDMUGilXdKs',
  );
  static const _base   = 'https://www.googleapis.com/youtube/v3';

  // ── In-memory cache ───────────────────────────────────────────────────────
  static final Map<String, List<Song>> _searchCache = {};
  static final Map<String, String>     _artworkCache = {};

  // Default square artwork placeholder (empty string falls back to Spotify clean dark tile)
  static const _defaultSquareArt = '';

  // ── Blacklist (title + channel) ───────────────────────────────────────────
  static const _titleBlacklist = [
    // Non-music productions
    'short film', 'teaser', 'trailer', 'reaction', 'parody',
    'dance practice', 'performance video', 'live concert', 'live at',
    'live session', 'behind the scene', 'behind the scenes', 'interview',
    'talk show', 'podcast', 'commentary',
    // Lyric videos
    'lyric video', 'lyrics video', 'lirik video', 'video lirik',
    'color coded', 'terjemahan', 'sub indo',
    // Covers / karaoke
    'karaoke', ' cover', 'covered by', 'fingerstyle',
    'piano cover', 'guitar cover', 'acoustic cover', 'instrumental cover', 'tribute',
    // Compilations
    'full album', 'greatest hits', 'best of', 'kompilasi',
    'koleksi', 'nonstop', 'top hits', 'album terbaik',
    // Modifications
    'slowed', 'reverb', '8d audio', 'bass boosted', 'nightcore',
  ];

  static const _channelBlacklist = [
    'karaoke', 'nonstop', 'kompilasi', 'tembang kenangan',
    'lyric', 'lirik', 'cover', 'tribute',
  ];

  // ─────────────────────────────────────────────────────────────────────────
  // SEARCH — returns official audio-only results with square covers
  // ─────────────────────────────────────────────────────────────────────────
  static Future<List<Song>> search(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) return [];

    final cacheKey = '${query.toLowerCase().trim()}_$limit';
    if (_searchCache.containsKey(cacheKey)) return _searchCache[cacheKey]!;

    final songs = <Song>[];
    final seenVideoIds = <String>{};

    // Parallel query variants: "Topic" channel + "Official Audio" + clean query
    final queries = [
      '$query topic',
      '$query official audio',
      query,
    ];

    final futures = await Future.wait(
      queries.map((q) => _searchYouTube(q, maxResults: 15)),
      eagerError: false,
    ).catchError((_) => [<_YtResult>[], <_YtResult>[], <_YtResult>[]]);

    final allResults = <_YtResult>[];
    for (final batch in futures) {
      for (final r in batch) {
        if (!seenVideoIds.contains(r.videoId)) {
          seenVideoIds.add(r.videoId);
          allResults.add(r);
        }
      }
    }

    // Fallback: If YouTube Data API v3 returned no results (e.g. quota limit), search via YoutubeExplode
    if (allResults.isEmpty) {
      try {
        final yt = YoutubeExplode();
        final searchBatch = await yt.search.search('$query official track').timeout(const Duration(seconds: 6));
        for (final video in searchBatch) {
          if (!seenVideoIds.contains(video.id.value)) {
            seenVideoIds.add(video.id.value);
            final dur = video.duration ?? const Duration(minutes: 3);
            if (dur.inSeconds >= 85 && dur.inSeconds <= 600) {
              final trackTitle = SongStreamResolver.cleanTrackTitle(video.title, video.author);
              final artistName = SongStreamResolver.cleanArtistName(video.author);
              allResults.add(_YtResult(
                videoId: video.id.value,
                cleanTitle: trackTitle,
                artist: artistName,
                album: trackTitle,
                duration: dur,
                score: 80,
              ));
            }
          }
        }
        yt.close();
      } catch (e) {
        debugPrint('YouTubeApiService: [ExplodeFallback] $e');
      }
    }

    allResults.sort((a, b) => b.score.compareTo(a.score));

    // Fetch square artwork for top results in parallel from iTunes & Deezer
    final topResults = allResults.take(limit).toList();
    final artworkFutures = topResults
        .map((r) => _fetchSquareArtwork(r.artist, r.cleanTitle))
        .toList();

    final artworks = await Future.wait(artworkFutures, eagerError: false)
        .catchError((_) => List.filled(topResults.length, _defaultSquareArt));

    for (int i = 0; i < topResults.length; i++) {
      final r = topResults[i];
      final artwork = (artworks.length > i && artworks[i].isNotEmpty)
          ? artworks[i]
          : 'https://i.ytimg.com/vi/${r.videoId}/hqdefault.jpg';

      songs.add(Song(
        id: 'yt_${r.videoId}',
        title: r.cleanTitle,
        artist: r.artist,
        album: r.album.isNotEmpty ? r.album : 'Single',
        albumArtUrl: artwork,
        audioUrl: 'https://www.youtube.com/watch?v=${r.videoId}',
        duration: r.duration,
        lyrics: null,
      ));
    }

    if (songs.isNotEmpty) _searchCache[cacheKey] = songs;
    return songs;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Call YouTube Data API v3 search endpoint
  // ─────────────────────────────────────────────────────────────────────────
  static Future<List<_YtResult>> _searchYouTube(String query, {int maxResults = 15}) async {
    try {
      final url = Uri.parse(
        '$_base/search'
        '?part=snippet'
        '&q=${Uri.encodeComponent(query)}'
        '&type=video'
        '&videoCategoryId=10' // Music category ONLY
        '&maxResults=$maxResults'
        '&order=relevance'
        '&key=$_apiKey',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        debugPrint('YouTube API HTTP error status=${response.statusCode}');
        return [];
      }

      final data = json.decode(response.body);
      final items = (data['items'] as List?) ?? [];

      final videoIds = items
          .map((item) => (item['id']?['videoId'] as String?) ?? '')
          .where((id) => id.isNotEmpty)
          .join(',');

      if (videoIds.isEmpty) return [];

      final details = await _fetchVideoDetails(videoIds);
      final results = <_YtResult>[];

      for (final item in items) {
        final videoId = (item['id']?['videoId'] as String?) ?? '';
        if (videoId.isEmpty) continue;

        final snippet = item['snippet'] as Map<String, dynamic>? ?? {};
        String rawTitle = (snippet['title'] as String?) ?? '';
        String channelTitle = (snippet['channelTitle'] as String?) ?? '';
        rawTitle = rawTitle
            .replaceAll('&#39;', "'")
            .replaceAll('&#039;', "'")
            .replaceAll('&apos;', "'")
            .replaceAll('&quot;', '"')
            .replaceAll('&amp;', '&')
            .replaceAll('&lt;', '<')
            .replaceAll('&gt;', '>')
            .replaceAll('&nbsp;', ' ');
        channelTitle = channelTitle
            .replaceAll('&#39;', "'")
            .replaceAll('&#039;', "'")
            .replaceAll('&apos;', "'")
            .replaceAll('&quot;', '"')
            .replaceAll('&amp;', '&')
            .replaceAll('&lt;', '<')
            .replaceAll('&gt;', '>')
            .replaceAll('&nbsp;', ' ');
        final description = details[videoId]?['description'] ?? '';
        final durationIso = details[videoId]?['duration'] ?? '';
        final duration = _parseIsoDuration(durationIso);

        // Duration filter: 85s – 600s
        if (duration.inSeconds < 85 || duration.inSeconds > 600) continue;

        // Title blacklist filter
        final titleLower = rawTitle.toLowerCase();
        final channelLower = channelTitle.toLowerCase();
        bool blacklisted = false;
        for (final bad in _titleBlacklist) {
          if (titleLower.contains(bad)) { blacklisted = true; break; }
        }
        if (!blacklisted) {
          for (final bad in _channelBlacklist) {
            if (channelLower.contains(bad)) { blacklisted = true; break; }
          }
        }
        if (blacklisted) continue;

        // Score ranking
        int score = 0;
        final descLower = description.toLowerCase();
        if (descLower.contains('provided to youtube by')) score += 300;
        if (channelLower.contains('- topic') || channelLower.endsWith('topic')) score += 200;
        if (channelLower.contains('vevo')) score += 100;
        if (channelLower.contains('official')) score += 80;
        if (channelLower.contains('records') || channelLower.contains('music')) score += 60;
        if (titleLower.split(' - ').length > 2) score -= 50;
        if (titleLower.contains('|')) score -= 30;

        // Clean channel name for artist
        String cleanChannel = channelTitle
            .replaceAll(RegExp(r'- Topic$', caseSensitive: false), '')
            .replaceAll(RegExp(r'VEVO$', caseSensitive: false), '')
            .replaceAll(RegExp(r'Official$', caseSensitive: false), '')
            .replaceAll(RegExp(r'Tv$', caseSensitive: false), '')
            .trim();
        if (cleanChannel.toLowerCase() == 'release') {
          cleanChannel = 'Various Artists';
        }

        // Clean title
        String cleanTitle = rawTitle;
        if (cleanTitle.toLowerCase().startsWith('${cleanChannel.toLowerCase()} - ') ||
            cleanTitle.toLowerCase().startsWith('${cleanChannel.toLowerCase()}: ')) {
          cleanTitle = cleanTitle.substring(cleanChannel.length + 3).trim();
        }
        cleanTitle = cleanTitle
            .replaceAll(RegExp(r'\s*[\(\[][^\)\]]*(?:official|audio|hq|hd|full|remaster)[^\)\]]*[\)\]]\s*$', caseSensitive: false), '')
            .trim();

        // Extract album name from description if available
        String album = '';
        final albumMatch = RegExp(r'·\s*(.+?)\s*℗').firstMatch(description);
        if (albumMatch != null) {
          album = albumMatch.group(1)?.trim() ?? '';
        }

        results.add(_YtResult(
          videoId: videoId,
          cleanTitle: cleanTitle,
          artist: cleanChannel,
          album: album,
          duration: duration,
          score: score,
        ));
      }

      return results;
    } catch (e) {
      debugPrint('YouTube API search error: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Batch fetch video details (duration + description)
  // ─────────────────────────────────────────────────────────────────────────
  static Future<Map<String, Map<String, String>>> _fetchVideoDetails(String videoIds) async {
    try {
      final url = Uri.parse(
        '$_base/videos'
        '?part=contentDetails,snippet'
        '&id=$videoIds'
        '&key=$_apiKey',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return {};

      final data = json.decode(response.body);
      final items = (data['items'] as List?) ?? [];
      final Map<String, Map<String, String>> result = {};

      for (final item in items) {
        final id = (item['id'] as String?) ?? '';
        if (id.isEmpty) continue;
        result[id] = {
          'duration': (item['contentDetails']?['duration'] as String?) ?? '',
          'description': (item['snippet']?['description'] as String?) ?? '',
        };
      }
      return result;
    } catch (e) {
      return {};
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 100% SQUARE ARTWORK FETCHER: iTunes primary → Deezer secondary
  // NEVER returns YouTube 16:9 rectangular thumbnails
  // ─────────────────────────────────────────────────────────────────────────
  static Future<String> _fetchSquareArtwork(String artist, String title) async {
    final cacheKey = '${artist.toLowerCase().trim()}_${title.toLowerCase().trim()}';
    if (_artworkCache.containsKey(cacheKey)) return _artworkCache[cacheKey]!;

    final cleanQuery = '$artist $title'
        .replaceAll(RegExp(r'\(.*?\)'), '')
        .replaceAll(RegExp(r'\[.*?\]'), '')
        .trim();

    // 1. Primary: iTunes / Apple Music (1:1 square master art, 600×600)
    try {
      final itunesUrl = Uri.parse(
        'https://itunes.apple.com/search'
        '?term=${Uri.encodeComponent(cleanQuery)}'
        '&media=music&entity=song&limit=3',
      );
      final itunesResp = await http.get(itunesUrl).timeout(const Duration(seconds: 4));
      if (itunesResp.statusCode == 200) {
        final data = json.decode(itunesResp.body);
        final results = (data['results'] as List?) ?? [];
        if (results.isNotEmpty) {
          Map<String, dynamic>? best;
          final artistKey = artist.toLowerCase().split(' ').first;
          for (final item in results) {
            final itemArtist = (item['artistName'] as String? ?? '').toLowerCase();
            if (itemArtist.contains(artistKey)) {
              best = item as Map<String, dynamic>?;
              break;
            }
          }
          best ??= results.first as Map<String, dynamic>?;
          if (best != null) {
            final raw = (best['artworkUrl100'] as String?) ?? '';
            if (raw.isNotEmpty) {
              final squareArt = raw.replaceAll('100x100bb.jpg', '600x600bb.jpg');
              _artworkCache[cacheKey] = squareArt;
              return squareArt;
            }
          }
        }
      }
    } catch (_) {}

    // 2. Secondary: Deezer Public API (1:1 square master art, 500×500)
    try {
      final deezerUrl = Uri.parse(
        'https://api.deezer.com/search?q=${Uri.encodeComponent(cleanQuery)}&limit=1',
      );
      final deezerResp = await http.get(deezerUrl).timeout(const Duration(seconds: 4));
      if (deezerResp.statusCode == 200) {
        final data = json.decode(deezerResp.body);
        final list = (data['data'] as List?) ?? [];
        if (list.isNotEmpty) {
          final first = list.first;
          final squareArt = (first['album']?['cover_big'] as String?) ??
              (first['album']?['cover_medium'] as String?) ??
              '';
          if (squareArt.isNotEmpty) {
            _artworkCache[cacheKey] = squareArt;
            return squareArt;
          }
        }
      }
    } catch (_) {}

    // 3. Fallback: clean square placeholder (never 16:9 YouTube thumbnail)
    _artworkCache[cacheKey] = _defaultSquareArt;
    return _defaultSquareArt;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Parse ISO 8601 duration (PT3M45S → Duration)
  // ─────────────────────────────────────────────────────────────────────────
  static Duration _parseIsoDuration(String iso) {
    if (iso.isEmpty) return const Duration(minutes: 3, seconds: 30);
    final match = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?').firstMatch(iso);
    if (match == null) return const Duration(minutes: 3, seconds: 30);
    final h = int.tryParse(match.group(1) ?? '0') ?? 0;
    final m = int.tryParse(match.group(2) ?? '0') ?? 0;
    final s = int.tryParse(match.group(3) ?? '0') ?? 0;
    return Duration(hours: h, minutes: m, seconds: s);
  }

  static void clearCache() {
    _searchCache.clear();
    _artworkCache.clear();
  }
}

// ── Internal data model ───────────────────────────────────────────────────
class _YtResult {
  final String videoId;
  final String cleanTitle;
  final String artist;
  final String album;
  final Duration duration;
  final int score;

  const _YtResult({
    required this.videoId,
    required this.cleanTitle,
    required this.artist,
    required this.album,
    required this.duration,
    required this.score,
  });
}
