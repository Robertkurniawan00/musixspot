import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models/song.dart';

class _CachedStream {
  final String url;
  final DateTime cachedAt;
  _CachedStream(this.url, this.cachedAt);
  bool get isExpired => DateTime.now().difference(cachedAt) > const Duration(hours: 3);
}

class SongStreamResolver {
  static const _youtubeApiKey = String.fromEnvironment(
    'YOUTUBE_API_KEY',
    defaultValue: 'AIzaSyAYJw7G73vf1nfJQzE4364wYDMUGilXdKs',
  );

  static YoutubeExplode _createClient() => YoutubeExplode();
  static YoutubeExplode _yt = _createClient();
  static final Map<String, _CachedStream> _resolvedUrlCache = {};
  static final Map<String, Duration> _resolvedDurationCache = {};

  /// Strict blacklist to eliminate MVs, lyric videos, covers, and album compilations
  static const List<String> blacklistedTerms = [
    // 1. NO MV / Video productions
    'official music video', 'official video', 'music video',
    'video musik', 'video klip', 'video clip',
    'official mv', 'mv', 'm/v',
    'short film', 'behind the scene', 'behind the scenes',
    'making of', 'bloopers', 'teaser', 'trailer',
    'reaction', 'parody', 'dance practice', 'performance video',
    'live concert', 'live at', 'live session', 'live acoustic',

    // 2. NO LYRIC VIDEOS
    'lyric video', 'lyrics video', 'lirik video', 'video lirik',
    'color coded', 'terjemahan', 'sub indo',

    // 3. NO COVERS / KARAOKE / INSTRUMENTAL TRIBUTES
    'cover', 'covered', 'acoustic cover', 'fingerstyle',
    'karaoke', 'instrumental cover', 'piano cover',
    'guitar cover', 'tribute',

    // 4. NO COMPILATIONS
    'album terbaik', 'full album', 'greatest hits',
    'best of', 'kompilasi', 'koleksi lagu',
    'lagu terbaik', 'pilihan terbaik', 'tembang kenangan',
    'lagu lawas', 'nonstop', 'discography',
    'best songs', 'top hits',

    // 5. NO MODIFIED EDITS
    'slowed', 'reverb', '8d audio', 'bass boosted', 'nightcore', 'remix',

    // 6. NO TALK SHOWS / INTERVIEWS / PODCASTS / VLOGS
    'talkshow', 'talk show', 'interview', 'wawancara', 'podcast', 'podcats',
    'vlog', 'behind the mic', 'commentary', 'episode',
    'ep.', 'ep ', 'radio show', 'bincang', 'ngobrol',
  ];

  /// Cleans raw video title to display clean Spotify-style track title
  static String cleanTrackTitle(String rawTitle, String artist) {
    String clean = rawTitle
        .replaceAll('&#39;', "'")
        .replaceAll('&#039;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ');


    // Remove bracketed junk like (Official Audio), (HQ Audio), [HD], etc.
    final bracketJunk = RegExp(
      r'[\(\[\{]\s*(?:official\s+audio|hq\s+audio|hd\s+audio|official\s+video|music\s+video|official\s+track|official|original\s+audio|audio\s+only|audio|full\s+version|full\s+extended|extended\s+version|extended|studio\s+master|studio\s+version|master|remastered|remaster|hq|hd|ost|soundtrack|lyrics?|lirik|feat\.?\s+.*?)\s*[\)\]\}]',
      caseSensitive: false,
    );
    clean = clean.replaceAll(bracketJunk, '');

    // Remove unbracketed junk suffixes
    final suffixJunk = RegExp(
      r'(?:[-|/•:]?\s*)?\b(?:official\s+audio|hq\s+audio|hd\s+audio|official\s+video|music\s+video|official\s+track|original\s+audio|audio\s+only|studio\s+master|studio\s+version|full\s+version|full\s+extended|extended\s+version|remastered|remaster|hq\s+audio|hq|hd|audio)\b\s*$',
      caseSensitive: false,
    );
    clean = clean.replaceAll(suffixJunk, '');

    // Remove artist prefix if title starts with "Artist - "
    if (artist.isNotEmpty) {
      final artistPrefix = RegExp(
        '^\\s*${RegExp.escape(artist)}\\s*[-:–|•]\\s*',
        caseSensitive: false,
      );
      final withoutArtist = clean.replaceFirst(artistPrefix, '').trim();
      if (withoutArtist.isNotEmpty) clean = withoutArtist;
    }

    // Remove leftover empty brackets and trailing separators
    clean = clean.replaceAll(RegExp(r'\(\s*\)|\[\s*\]|\{\s*\}'), '');
    clean = clean.replaceAll(RegExp(r'[\s\-|/•:]+$'), '').trim();
    clean = clean.replaceAll(RegExp(r'\s+'), ' ');

    return clean.isEmpty ? rawTitle : clean;
  }

  /// Cleans raw channel name to display artist name
  static String cleanArtistName(String rawAuthor) {
    String clean = rawAuthor
        .replaceAll('&#39;', "'")
        .replaceAll('&#039;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'- Topic$', caseSensitive: false), '')
        .replaceAll(RegExp(r'Topic$', caseSensitive: false), '')
        .replaceAll(RegExp(r'VEVO$', caseSensitive: false), '')
        .replaceAll(RegExp(r'Official$', caseSensitive: false), '')
        .replaceAll(RegExp(r'Tv$', caseSensitive: false), '')
        .trim();
    if (clean.toLowerCase() == 'release') return 'Various Artists';
    return clean.isEmpty ? rawAuthor : clean;
  }

  /// Strictly checks if a URL is a 30-second preview clip from Deezer/Apple/Spotify
  static bool isPreviewUrl(String url) {
    if (url.isEmpty) return false;
    final lower = url.toLowerCase();
    return lower.contains('preview') ||
        lower.contains('cdnt-preview') ||
        lower.contains('dzcdn.net/stream') ||
        lower.contains('audio-ssl.itunes.apple.com') ||
        lower.contains('mzstatic.com') ||
        lower.contains('/itunes-assets/audiopreview');
  }

  /// Checks if a title or channel contains MV, Lyric Video, Cover, or Compilation markers
  static bool isBlacklisted(String title, [String author = '']) {
    final lower = '$title $author'.toLowerCase();
    for (final term in blacklistedTerms) {
      if (lower.contains(term)) return true;
    }
    return false;
  }

  /// Direct YouTube Data API v3 search for high-relevance official audio video IDs
  static Future<List<String>> _fetchAudioCandidatesFromYouTubeApi(
      String artist, String title) async {
    try {
      final query = '$artist $title topic';
      final searchUrl = Uri.parse(
        'https://www.googleapis.com/youtube/v3/search'
        '?part=snippet'
        '&q=${Uri.encodeComponent(query)}'
        '&type=video'
        '&maxResults=8'
        '&key=$_youtubeApiKey',
      );
      final res = await http.get(searchUrl).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final items = (data['items'] as List?) ?? [];
        final ids = <String>[];
        for (final item in items) {
          final id = item['id']?['videoId'] as String?;
          final itemTitle = item['snippet']?['title'] as String? ?? '';
          final channelTitle = item['snippet']?['channelTitle'] as String? ?? '';
          if (id != null && id.isNotEmpty) {
            // Strictly reject MV and lyric videos
            if (isBlacklisted(itemTitle, channelTitle)) {
              debugPrint('SongStreamResolver: Filtered out MV/Lyric video candidate: "$itemTitle"');
              continue;
            }
            ids.add(id);
          }
        }
        return ids;
      }
    } catch (e) {
      debugPrint('SongStreamResolver: YouTube API candidate search error: $e');
    }
    return [];
  }

  /// Resolve list of playable audio stream candidates for a song
  static Future<List<String>> resolveAudioStreamCandidates(Song song) async {
    // 1. Local asset / downloaded file
    if (song.audioUrl.startsWith('asset://') ||
        song.audioUrl.startsWith('assets/') ||
        song.isDownloaded) {
      return [song.audioUrl];
    }

    final candidates = <String>[];

    // 2. Direct CDN stream URL (Non-YouTube) - NEVER play 30s previews as full songs!
    if (song.audioUrl.startsWith('http') &&
        !song.audioUrl.contains('youtube.com') &&
        !song.audioUrl.contains('youtu.be') &&
        !isPreviewUrl(song.audioUrl)) {
      _resolvedUrlCache[song.id] = _CachedStream(song.audioUrl, DateTime.now());
      candidates.add(song.audioUrl);
      return candidates;
    }

    // 3. In-memory cache (checks 3h TTL)
    final cached = _resolvedUrlCache[song.id];
    if (cached != null && !cached.isExpired && !isPreviewUrl(cached.url)) {
      candidates.add(cached.url);
    }

    // 4. Extract YouTube Video ID & Curated Fast-Path Overrides
    String videoId = '';
    Duration? resolvedDuration;

    final lowerTitle = song.title.toLowerCase();
    final lowerArtist = song.artist.toLowerCase();

    // Winter (aespa / Dingo Music) - Speed of Summer (여름의 속도)
    if (lowerTitle.contains('speed of summer') || lowerTitle.contains('여름의 속도') ||
        (lowerArtist.contains('winter') && lowerTitle.contains('summer'))) {
      videoId = 'YTeFLKMnwjg';
    } else if (lowerTitle.contains('recharge me') ||
        (lowerArtist.contains('wendy') && lowerTitle.contains('recharge'))) {
      // Wendy - Recharge Me (Take Charge of My Heart OST Official Topic)
      videoId = 'MAIWvlrymlE';
    } else if (song.id.startsWith('yt_')) {
      videoId = song.id.substring(3);
    } else if (song.audioUrl.contains('youtube.com/watch?v=') ||
               song.audioUrl.contains('youtu.be/')) {
      final uri = Uri.tryParse(song.audioUrl);
      if (uri != null) {
        videoId = uri.queryParameters['v'] ?? uri.pathSegments.last;
      }
    }

    // 5. Try primary videoId first (if present and not blacklisted)
    if (videoId.isNotEmpty && !isBlacklisted(song.title)) {
      final streams = await _tryResolveManifestStreams(videoId, song, resolvedDuration);
      for (final s in streams) {
        if (!candidates.contains(s) && !isPreviewUrl(s)) candidates.add(s);
      }
    }

    // If we already have multiple candidates from the direct video ID, return early
    if (candidates.length >= 2) {
      return candidates;
    }

    // 6. Query via official YouTube Data API v3 for high-relevance video candidates
    final apiVideoIds = await _fetchAudioCandidatesFromYouTubeApi(song.artist, song.title);
    for (final candId in apiVideoIds) {
      if (candId == videoId) continue;
      final streams = await _tryResolveManifestStreams(candId, song, resolvedDuration);
      for (final s in streams) {
        if (!candidates.contains(s) && !isPreviewUrl(s)) candidates.add(s);
      }
      if (candidates.length >= 3) break;
    }

    if (candidates.isNotEmpty) {
      return candidates;
    }

    // 7. Secondary fallback: Search via YoutubeExplode with "topic" (Official Audio)
    try {
      final ytSearch = await _yt.search
          .search('${song.artist} ${song.title} topic')
          .timeout(const Duration(seconds: 6));
      for (final v in ytSearch.take(5)) {
        final vId = v.id.value;
        if (vId == videoId || apiVideoIds.contains(vId)) continue;
        if (isBlacklisted(v.title, v.author)) continue;
        final streams = await _tryResolveManifestStreams(vId, song, v.duration);
        for (final s in streams) {
          if (!candidates.contains(s) && !isPreviewUrl(s)) candidates.add(s);
        }
        if (candidates.isNotEmpty) break;
      }
    } catch (e) {
      debugPrint('SongStreamResolver: Explode primary search fallback failed: $e');
    }

    // 8. Tertiary fallback: Search with explicit "official audio"
    if (candidates.isEmpty && song.title.isNotEmpty) {
      try {
        final ytAudioSearch = await _yt.search
            .search('${song.artist} ${song.title} official audio')
            .timeout(const Duration(seconds: 6));
        for (final v in ytAudioSearch.take(4)) {
          final vId = v.id.value;
          if (isBlacklisted(v.title, v.author)) continue;
          final streams = await _tryResolveManifestStreams(vId, song, v.duration);
          for (final s in streams) {
            if (!candidates.contains(s) && !isPreviewUrl(s)) candidates.add(s);
          }
          if (candidates.isNotEmpty) break;
        }
      } catch (e) {
        debugPrint('SongStreamResolver: Explode audio search fallback failed: $e');
      }
    }

    // Never pass unplayable YouTube webpage URLs or 30s previews directly to ExoPlayer
    if (candidates.isEmpty) {
      if (song.audioUrl.contains('youtube.com/watch') ||
          song.audioUrl.contains('youtu.be/') ||
          song.audioUrl.isEmpty ||
          isPreviewUrl(song.audioUrl)) {
        throw Exception('Tidak dapat memutar audio otentik untuk "${song.title}". Silakan periksa koneksi internet Anda.');
      }
      candidates.add(song.audioUrl);
    }

    return candidates;
  }

  /// Resolve single best audio stream URL
  static Future<String> resolveAudioStream(Song song) async {
    final list = await resolveAudioStreamCandidates(song);
    return list.first;
  }

  static Future<List<String>> _tryResolveManifestStreams(
      String vId, Song song, Duration? duration) async {
    for (int attempt = 1; attempt <= 2; attempt++) {
      try {
        final manifest = await _yt.videos.streamsClient
            .getManifest(vId)
            .timeout(const Duration(seconds: 8));

        final List<String> urls = [];

        // 1. TOP PRIORITY: Progressive Muxed MP4 (itag 18 / 22)
        // itag 18 is stereo AAC audio in a progressive MP4 container.
        // GoogleVideo NEVER limits or 403-blocks range requests on progressive itag 18,
        // allowing songs to stream continuously 100% through to the end without 40s cutoffs!
        final muxedStreams = manifest.muxed.where((s) => s.container.name.toLowerCase().contains('mp4'));
        if (muxedStreams.isNotEmpty) {
          final itag18 = muxedStreams.where((s) => s.tag == 18).firstOrNull;
          if (itag18 != null) {
            urls.add(itag18.url.toString());
          } else {
            urls.add(muxedStreams.first.url.toString());
          }
        }

        // 2. SECONDARY: Adaptive Audio-Only (MP4 itag 140 or WebM itag 251)
        final audioStreams = manifest.audioOnly;
        if (audioStreams.isNotEmpty) {
          // MP4 / AAC (hardware decoding on Android)
          final mp4Streams = audioStreams.where((s) => s.container.name.toLowerCase().contains('mp4'));
          if (mp4Streams.isNotEmpty) {
            final u = mp4Streams.withHighestBitrate().url.toString();
            if (!urls.contains(u)) urls.add(u);
          }

          // High-quality WebM / Opus
          final webmStreams = audioStreams.where((s) => s.container.name.toLowerCase().contains('webm'));
          if (webmStreams.isNotEmpty) {
            final webmUrl = webmStreams.withHighestBitrate().url.toString();
            if (!urls.contains(webmUrl)) {
              urls.add(webmUrl);
            }
          }

          // Fallback: Any remaining highest bitrate
          final highest = audioStreams.withHighestBitrate().url.toString();
          if (!urls.contains(highest)) {
            urls.add(highest);
          }
        }

        if (urls.isNotEmpty) {
          _resolvedUrlCache[song.id] = _CachedStream(urls.first, DateTime.now());
          if (duration != null && duration.inSeconds > 0) {
            _resolvedDurationCache[song.id] = duration;
            song.duration = duration;
          }
          debugPrint('SongStreamResolver: ✓ ${urls.length} stream(s) resolved for "${song.title}" ($vId)');
          return urls;
        }
      } catch (e) {
        debugPrint('SongStreamResolver: Manifest attempt $attempt failed for ($vId): $e');
        try {
          _yt.close();
          _yt = _createClient();
        } catch (_) {}
      }
    }
    return [];
  }

  static void invalidateCache(String songId) {
    _resolvedUrlCache.remove(songId);
    debugPrint('SongStreamResolver: Invalidated cache for "$songId"');
  }

  static Duration? getCachedDuration(String songId) => _resolvedDurationCache[songId];

  static void clearCache() => _resolvedUrlCache.clear();

  static void dispose() => _yt.close();
}
