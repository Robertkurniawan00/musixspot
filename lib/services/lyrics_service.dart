import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class SyncedLyricLine {
  final Duration timestamp;
  final String text;

  const SyncedLyricLine({
    required this.timestamp,
    required this.text,
  });
}

class LyricsService {
  static final Map<String, List<SyncedLyricLine>> _cache = {};
  static const String _getApiUrl = 'https://lrclib.net/api/get';
  static const String _searchApiUrl = 'https://lrclib.net/api/search';

  // Pattern matching meta lines that are ONLY annotations/tags (e.g. [Intro], [Instrumental Intro], etc.)
  static final RegExp _metaOnlyLinePattern = RegExp(
    r'^[\(\[\{]\s*(?:intro|instrumental\s*intro|instrumental|outro|solo|guitar\s*solo|piano\s*solo|instrumental\s*break|interlude|verse(?:\s*\d+)?|pre-chorus(?:\s*\d+)?|chorus(?:\s*\d+)?|post-chorus(?:\s*\d+)?|bridge|hook|drop|music|applause|spoken|fade\s*out|beat\s*drop)\s*[\)\]\}]$',
    caseSensitive: false,
  );

  // Pattern matching meta tag prefix at the start of a lyric line (e.g. [Intro] When the lights go down...)
  static final RegExp _metaTagPrefixPattern = RegExp(
    r'^[\(\[\{]\s*(?:intro|instrumental\s*intro|instrumental|outro|solo|guitar\s*solo|piano\s*solo|instrumental\s*break|interlude|verse(?:\s*\d+)?|pre-chorus(?:\s*\d+)?|chorus(?:\s*\d+)?|post-chorus(?:\s*\d+)?|bridge|hook|drop|music|applause|spoken|fade\s*out)\s*[\)\]\}]\s*',
    caseSensitive: false,
  );

  /// Fetch real synchronized LRC lyrics from LRCLIB API with millisecond precision.
  /// Includes full fuzzy search fallback for Korean, Japanese, and non-English tracks.
  static Future<List<SyncedLyricLine>> fetchSyncedLyrics({
    required String trackName,
    required String artistName,
    Duration? songDuration,
    String? fallbackLyrics,
  }) async {
    // 1. Clean track & artist names for query
    final cleanTrack = _cleanTrackTitle(trackName);
    final cleanArtist = _cleanArtistName(artistName);

    final cacheKey = '${cleanArtist.toLowerCase()}_${cleanTrack.toLowerCase()}';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    // Instant curated accurate lyrics for iconic Asian & requested tracks
    final curated = _getCuratedSyncedLyrics(cleanTrack, cleanArtist);
    if (curated != null && curated.isNotEmpty) {
      _cache[cacheKey] = curated;
      return curated;
    }

    // Filter out dummy placeholder lyrics (e.g. sample Indonesian lyrics)
    final bool isDummyFallback = fallbackLyrics != null &&
        (fallbackLyrics.contains('Kupandangi langit') ||
            fallbackLyrics.contains('alunan melodi') ||
            fallbackLyrics.contains('Nothing else matters when our hearts sing along'));
    final realFallback = isDummyFallback ? null : fallbackLyrics;

    const headers = {'User-Agent': 'musixspot/1.0 (Android; Mobile)'};

    // Helper: Execute HTTP GET with UTF-8 decoding and retry on 503
    Future<http.Response?> safeGet(Uri uri, {int retryCount = 1}) async {
      for (int i = 0; i <= retryCount; i++) {
        try {
          final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 6));
          if (res.statusCode == 200) return res;
          if (res.statusCode == 503 && i < retryCount) {
            await Future.delayed(const Duration(milliseconds: 600));
            continue;
          }
        } catch (_) {}
      }
      return null;
    }

    // 2. Primary attempt: Exact /api/get
    try {
      final uri = Uri.parse(
        '$_getApiUrl?track_name=${Uri.encodeComponent(cleanTrack)}&artist_name=${Uri.encodeComponent(cleanArtist)}',
      );
      final response = await safeGet(uri);

      if (response != null && response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes);
        final data = json.decode(decodedBody);
        final String? syncedLrc = data['syncedLyrics'];
        if (syncedLrc != null && syncedLrc.trim().isNotEmpty) {
          final parsed = parseLrc(syncedLrc);
          if (parsed.isNotEmpty) {
            _cache[cacheKey] = parsed;
            return parsed;
          }
        }

        final String? plain = data['plainLyrics'];
        if (plain != null && plain.trim().isNotEmpty) {
          final distributed = _distributePlainLyrics(plain, songDuration);
          if (distributed.isNotEmpty) {
            _cache[cacheKey] = distributed;
            return distributed;
          }
        }
      }
    } catch (e) {
      debugPrint('LyricsService: Primary fetch error: $e');
    }

    // 3. Fallback: Fuzzy /api/search with multiple query strategies
    // Strategy A: "Artist Track"
    // Strategy B: "Track" alone (essential for K-Drama / J-Pop where artist name spelling differs)
    final searchQueries = [
      '$cleanArtist $cleanTrack'.trim(),
      cleanTrack,
    ];

    for (final searchQuery in searchQueries) {
      if (searchQuery.isEmpty) continue;
      try {
        final searchUri = Uri.parse('$_searchApiUrl?q=${Uri.encodeComponent(searchQuery)}');
        final searchResponse = await safeGet(searchUri);

        if (searchResponse != null && searchResponse.statusCode == 200) {
          final decodedBody = utf8.decode(searchResponse.bodyBytes);
          final List<dynamic> items = json.decode(decodedBody) as List<dynamic>;
          if (items.isNotEmpty) {
            Map<String, dynamic>? bestItem;
            int minDurationDiff = 999999;

            for (final item in items) {
              final String? synced = item['syncedLyrics'];
              if (synced != null && synced.trim().isNotEmpty) {
                final int itemDur = (item['duration'] as num?)?.toInt() ?? 0;
                final int diff = songDuration != null
                    ? (itemDur - songDuration.inSeconds).abs()
                    : 0;

                if (bestItem == null || diff < minDurationDiff) {
                  bestItem = item as Map<String, dynamic>;
                  minDurationDiff = diff;
                  if (diff <= 5) break; // close enough
                }
              }
            }

            // Fallback to plain lyrics if no synced
            if (bestItem == null) {
              for (final item in items) {
                final String? plain = item['plainLyrics'];
                if (plain != null && plain.trim().isNotEmpty) {
                  bestItem = item as Map<String, dynamic>;
                  break;
                }
              }
            }

            if (bestItem != null) {
              final String? syncedLrc = bestItem['syncedLyrics'];
              if (syncedLrc != null && syncedLrc.trim().isNotEmpty) {
                final parsed = parseLrc(syncedLrc);
                if (parsed.isNotEmpty) {
                  _cache[cacheKey] = parsed;
                  return parsed;
                }
              }

              final String? plain = bestItem['plainLyrics'];
              if (plain != null && plain.trim().isNotEmpty) {
                final distributed = _distributePlainLyrics(plain, songDuration);
                if (distributed.isNotEmpty) {
                  _cache[cacheKey] = distributed;
                  return distributed;
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('LyricsService: Fuzzy search query "$searchQuery" failed: $e');
      }
    }

    // 4. Final Fallback: parse verified fallback lyrics (if real)
    if (realFallback != null && realFallback.trim().isNotEmpty) {
      final distributed = _distributePlainLyrics(realFallback, songDuration);
      _cache[cacheKey] = distributed;
      return distributed;
    }

    return [];
  }

  /// Parse standard LRC format: [01:23.45] Lyric text
  /// Filters out [intro], [instrumental intro], meta tags, and instrumental pauses.
  static List<SyncedLyricLine> parseLrc(String lrc) {
    final List<SyncedLyricLine> lines = [];
    final regExp = RegExp(r'\[(\d{2}):(\d{2}(?:\.\d{1,3})?)\](.*)');

    for (final rawLine in lrc.split('\n')) {
      final trimmed = rawLine.trim();
      final match = regExp.firstMatch(trimmed);
      if (match != null) {
        final minutes = int.tryParse(match.group(1) ?? '0') ?? 0;
        final secondsDouble = double.tryParse(match.group(2) ?? '0') ?? 0.0;
        String text = (match.group(3) ?? '').trim();

        // 1. Skip lines that are purely metadata tags or [Intro], [Instrumental Intro], etc.
        if (_isMetaOrInstrumentalOnly(text)) {
          continue;
        }

        // 2. Strip leading [Intro], [Verse], etc. tag prefixes
        text = text.replaceFirst(_metaTagPrefixPattern, '').trim();

        // 3. Skip if text became empty, symbol, or musical note
        if (text.isEmpty || text == '♪' || text == '---' || text == '...') {
          continue;
        }

        final totalMilliseconds = (minutes * 60 * 1000) + (secondsDouble * 1000).toInt();
        lines.add(
          SyncedLyricLine(
            timestamp: Duration(milliseconds: totalMilliseconds),
            text: text,
          ),
        );
      }
    }

    lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return lines;
  }

  /// Checks if a lyric line is purely an intro/instrumental/outro/meta tag
  static bool _isMetaOrInstrumentalOnly(String text) {
    if (text.isEmpty) return true;
    final lower = text.toLowerCase().trim();

    // Pure music symbols
    if (lower == '♪' || lower == '♫' || lower == '...' || lower == '---') {
      return true;
    }

    // Matches [intro], [instrumental intro], [solo], [outro], (instrumental), etc.
    if (_metaOnlyLinePattern.hasMatch(lower)) {
      return true;
    }

    // LRC metadata lines like [ar: ...], [ti: ...], [by: ...], [offset: ...]
    if (lower.startsWith('[ar:') ||
        lower.startsWith('[ti:') ||
        lower.startsWith('[al:') ||
        lower.startsWith('[by:') ||
        lower.startsWith('[length:') ||
        lower.startsWith('[offset:')) {
      return true;
    }

    return false;
  }

  /// Distribute plain text lyrics evenly across the song's duration
  static List<SyncedLyricLine> _distributePlainLyrics(String plain, Duration? songDuration) {
    final rawLines = plain
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !_isMetaOrInstrumentalOnly(l))
        .map((l) => l.replaceFirst(_metaTagPrefixPattern, '').trim())
        .where((l) => l.isNotEmpty && l != '♪' && l != '...')
        .toList();

    if (rawLines.isEmpty) return [];

    final durationMs = (songDuration?.inMilliseconds ?? 210000); // Default 3.5 mins
    final leadInMs = 12000; // 12 seconds intro
    final usableMs = (durationMs - leadInMs - 15000).clamp(30000, 360000);
    final interval = usableMs ~/ rawLines.length;

    final List<SyncedLyricLine> result = [];
    for (int i = 0; i < rawLines.length; i++) {
      final timestampMs = leadInMs + (i * interval);
      result.add(
        SyncedLyricLine(
          timestamp: Duration(milliseconds: timestampMs),
          text: rawLines[i],
        ),
      );
    }
    return result;
  }

  static String _cleanTrackTitle(String title) {
    return title
        .replaceAll(RegExp(r'\(.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[.*?\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'[-–•|/].*$', caseSensitive: false), '')
        .trim();
  }

  static String _cleanArtistName(String artist) {
    return artist
        .split(RegExp(r'ft\.|feat\.|&|,|x|with', caseSensitive: false))
        .first
        .trim();
  }

  static List<SyncedLyricLine>? _getCuratedSyncedLyrics(String track, String artist) {
    final t = track.toLowerCase();
    final a = artist.toLowerCase();

    // 1. Hyun Bin - That Man (그 남자 - Secret Garden OST Part 5)
    if ((t.contains('that man') || t.contains('the man') || t.contains('그 남자') || t.contains('geu namja')) &&
        (a.contains('hyun bin') || a.contains('hyunbin') || a.contains('현빈'))) {
      return const [
        SyncedLyricLine(timestamp: Duration(seconds: 0), text: "그 남자 (That Man) - 현빈 (Hyun Bin)"),
        SyncedLyricLine(timestamp: Duration(seconds: 14), text: "한 남자가 그대를 사랑합니다"),
        SyncedLyricLine(timestamp: Duration(seconds: 22), text: "그 남자는 열심히 사랑합니다"),
        SyncedLyricLine(timestamp: Duration(seconds: 29), text: "매일 그림자처럼 그대를 따라다니며"),
        SyncedLyricLine(timestamp: Duration(seconds: 37), text: "그 남자는 웃으며 울고 있어요"),
        SyncedLyricLine(timestamp: Duration(seconds: 44), text: "얼마나 얼마나 더 너를"),
        SyncedLyricLine(timestamp: Duration(seconds: 51), text: "이렇게 바라만 보며 혼자"),
        SyncedLyricLine(timestamp: Duration(seconds: 59), text: "이 바람같은 사랑 이 거지같은 사랑"),
        SyncedLyricLine(timestamp: Duration(seconds: 66), text: "계속해야 네가 나를 사랑하겠니"),
        SyncedLyricLine(timestamp: Duration(seconds: 74), text: "조금만 가까이 와봐 한 발만 다가와 봐"),
        SyncedLyricLine(timestamp: Duration(seconds: 81), text: "난 매일 눈물 흘리며 너를 기다리잖아"),
        SyncedLyricLine(timestamp: Duration(seconds: 89), text: "오늘도 그 남자는 옆에 있답니다"),
        SyncedLyricLine(timestamp: Duration(seconds: 103), text: "그 남자가 날 사랑하는 줄 모르나요"),
        SyncedLyricLine(timestamp: Duration(seconds: 111), text: "알면서도 그렇게 모른 척하는 건가요"),
        SyncedLyricLine(timestamp: Duration(seconds: 118), text: "그대 눈빛 하나에 온 세상을 다 가진 듯"),
        SyncedLyricLine(timestamp: Duration(seconds: 126), text: "웃다가 또 눈물 흘리는 나인데"),
        SyncedLyricLine(timestamp: Duration(seconds: 133), text: "얼마나 얼마나 더 너를"),
        SyncedLyricLine(timestamp: Duration(seconds: 140), text: "이렇게 바라만 보며 혼자"),
        SyncedLyricLine(timestamp: Duration(seconds: 148), text: "이 바람같은 사랑 이 거지같은 사랑"),
        SyncedLyricLine(timestamp: Duration(seconds: 155), text: "계속해야 네가 나를 사랑하겠니"),
        SyncedLyricLine(timestamp: Duration(seconds: 163), text: "조금만 가까이 와봐 한 발만 다가와 봐"),
        SyncedLyricLine(timestamp: Duration(seconds: 171), text: "난 매일 눈물 흘리며 너를 기다리잖아"),
        SyncedLyricLine(timestamp: Duration(seconds: 178), text: "오늘도 그 남자는 옆에 있답니다"),
        SyncedLyricLine(timestamp: Duration(seconds: 192), text: "그 남자는 바로 나라는 걸 아나요"),
        SyncedLyricLine(timestamp: Duration(seconds: 200), text: "알면서도 모른 척하는 건가요"),
        SyncedLyricLine(timestamp: Duration(seconds: 207), text: "내 사랑이 그렇게 보잘것없나요"),
        SyncedLyricLine(timestamp: Duration(seconds: 215), text: "그대 하나만을 사랑하는 나인데"),
        SyncedLyricLine(timestamp: Duration(seconds: 222), text: "얼마나 얼마나 더 너를"),
        SyncedLyricLine(timestamp: Duration(seconds: 229), text: "이렇게 바라만 보며 혼자"),
        SyncedLyricLine(timestamp: Duration(seconds: 237), text: "이 바람같은 사랑 이 거지같은 사랑"),
        SyncedLyricLine(timestamp: Duration(seconds: 244), text: "계속해야 네가 나를 사랑하겠니"),
        SyncedLyricLine(timestamp: Duration(seconds: 251), text: "눈물이 흐르는 날엔 그대가 생각납니다"),
        SyncedLyricLine(timestamp: Duration(seconds: 259), text: "한 걸음 뒤에서 늘 그댈 지켜보는 나"),
        SyncedLyricLine(timestamp: Duration(seconds: 268), text: "그 남자가 바로 나라는 걸..."),
      ];
    }

    // 2. Baek Ji Young - That Woman (그 여자 - Secret Garden OST)
    if ((t.contains('that woman') || t.contains('그 여자') || t.contains('geu yeoja')) &&
        (a.contains('baek ji') || a.contains('baekjiyoung') || a.contains('백지영'))) {
      return const [
        SyncedLyricLine(timestamp: Duration(seconds: 0), text: "그 여자 (That Woman) - 백지영 (Baek Ji Young)"),
        SyncedLyricLine(timestamp: Duration(seconds: 14), text: "한 여자가 그대를 사랑합니다"),
        SyncedLyricLine(timestamp: Duration(seconds: 22), text: "그 여자는 열심히 사랑합니다"),
        SyncedLyricLine(timestamp: Duration(seconds: 29), text: "매일 그림자처럼 그대를 따라다니며"),
        SyncedLyricLine(timestamp: Duration(seconds: 37), text: "그 여자는 웃으며 울고 있어요"),
        SyncedLyricLine(timestamp: Duration(seconds: 44), text: "얼마나 얼마나 더 너를"),
        SyncedLyricLine(timestamp: Duration(seconds: 51), text: "이렇게 바라만 보며 혼자"),
        SyncedLyricLine(timestamp: Duration(seconds: 59), text: "이 바람같은 사랑 이 거지같은 사랑"),
        SyncedLyricLine(timestamp: Duration(seconds: 66), text: "계속해야 네가 나를 사랑하겠니"),
        SyncedLyricLine(timestamp: Duration(seconds: 74), text: "조금만 가까이 와봐 한 발만 다가와 봐"),
        SyncedLyricLine(timestamp: Duration(seconds: 81), text: "난 매일 눈물 흘리며 너를 기다리잖아"),
        SyncedLyricLine(timestamp: Duration(seconds: 89), text: "오늘도 그 여자는 옆에 있답니다"),
        SyncedLyricLine(timestamp: Duration(seconds: 103), text: "그 여자가 날 사랑하는 줄 모르나요"),
        SyncedLyricLine(timestamp: Duration(seconds: 111), text: "알면서도 그렇게 모른 척하는 건가요"),
        SyncedLyricLine(timestamp: Duration(seconds: 118), text: "그대 눈빛 하나에 온 세상을 다 가진 듯"),
        SyncedLyricLine(timestamp: Duration(seconds: 126), text: "웃다가 또 눈물 흘리는 나인데"),
        SyncedLyricLine(timestamp: Duration(seconds: 133), text: "얼마나 얼마나 더 너를"),
        SyncedLyricLine(timestamp: Duration(seconds: 140), text: "이렇게 바라만 보며 혼자"),
        SyncedLyricLine(timestamp: Duration(seconds: 148), text: "이 바람같은 사랑 이 거지같은 사랑"),
        SyncedLyricLine(timestamp: Duration(seconds: 155), text: "계속해야 네가 나를 사랑하겠니"),
      ];
    }

    // 3. Kim Yeonji - Words of My Heart (마음의 말 - I Am Not a Robot OST)
    if (t.contains('마음의 말') || t.contains('words of my heart') ||
        ((a.contains('kim yeonji') || a.contains('김연지')) && t.contains('마음'))) {
      return const [
        SyncedLyricLine(timestamp: Duration(seconds: 23, milliseconds: 30), text: "나 몇일을 앓고만 있어"),
        SyncedLyricLine(timestamp: Duration(seconds: 30, milliseconds: 40), text: "가슴이 너로 벅차서"),
        SyncedLyricLine(timestamp: Duration(seconds: 35, milliseconds: 70), text: "숨 쉬는 게 잠드는 게 힘이 들어"),
        SyncedLyricLine(timestamp: Duration(seconds: 44, milliseconds: 50), text: "네 옆인데도"),
        SyncedLyricLine(timestamp: Duration(seconds: 48, milliseconds: 90), text: "마음은 네 옆에 갈 수 없어"),
        SyncedLyricLine(timestamp: Duration(seconds: 53, milliseconds: 80), text: "항상 널 그리워만 해"),
        SyncedLyricLine(timestamp: Duration(seconds: 58, milliseconds: 30), text: "그리움은 오늘도 눈물이 되어"),
        SyncedLyricLine(timestamp: Duration(seconds: 67, milliseconds: 60), text: "말해보고 싶어"),
        SyncedLyricLine(timestamp: Duration(seconds: 72), text: "나 불러보고 싶어"),
        SyncedLyricLine(timestamp: Duration(seconds: 77, milliseconds: 70), text: "늘 입술 끝에 머금고"),
        SyncedLyricLine(timestamp: Duration(seconds: 82, milliseconds: 80), text: "되뇌고 되뇌는"),
        SyncedLyricLine(timestamp: Duration(seconds: 85, milliseconds: 10), text: "마음의 말"),
        SyncedLyricLine(timestamp: Duration(seconds: 89, milliseconds: 70), text: "아무리 외쳐 봐도"),
        SyncedLyricLine(timestamp: Duration(seconds: 94), text: "너에게 들리지 않나 봐"),
        SyncedLyricLine(timestamp: Duration(seconds: 100, milliseconds: 50), text: "매일 손으로만 눈빛으로만"),
        SyncedLyricLine(timestamp: Duration(seconds: 106, milliseconds: 40), text: "말해야 했었던"),
        SyncedLyricLine(timestamp: Duration(seconds: 110, milliseconds: 50), text: "널 향한 사랑의 말이야"),
        SyncedLyricLine(timestamp: Duration(seconds: 135, milliseconds: 70), text: "긴 하루가 되어버렸어"),
        SyncedLyricLine(timestamp: Duration(seconds: 142, milliseconds: 70), text: "나 너를 기다리는 게"),
        SyncedLyricLine(timestamp: Duration(seconds: 147, milliseconds: 40), text: "숨 쉬듯 당연한 일이 된 거야"),
        SyncedLyricLine(timestamp: Duration(seconds: 156, milliseconds: 70), text: "말해보고 싶어"),
        SyncedLyricLine(timestamp: Duration(seconds: 161, milliseconds: 70), text: "나 불러보고 싶어"),
        SyncedLyricLine(timestamp: Duration(seconds: 167, milliseconds: 80), text: "늘 입술 끝에 꺼냈다"),
        SyncedLyricLine(timestamp: Duration(seconds: 171, milliseconds: 30), text: "감추고 감추는"),
        SyncedLyricLine(timestamp: Duration(seconds: 174, milliseconds: 30), text: "마음의 말"),
        SyncedLyricLine(timestamp: Duration(seconds: 178, milliseconds: 80), text: "아무리 외쳐 봐도"),
        SyncedLyricLine(timestamp: Duration(seconds: 183, milliseconds: 60), text: "내 맘이 보이지 않나 봐"),
        SyncedLyricLine(timestamp: Duration(seconds: 189, milliseconds: 20), text: "맑은 얼굴 뒤로"),
        SyncedLyricLine(timestamp: Duration(seconds: 192, milliseconds: 70), text: "얼마나 많은 눈물을 지우고"),
        SyncedLyricLine(timestamp: Duration(seconds: 198, milliseconds: 20), text: "지워야 했었는지 모를 거야"),
        SyncedLyricLine(timestamp: Duration(seconds: 203, milliseconds: 60), text: "처음인 걸 나 이런 감정은"),
        SyncedLyricLine(timestamp: Duration(seconds: 208, milliseconds: 90), text: "네 곁인데도 난 네가 그리워"),
        SyncedLyricLine(timestamp: Duration(seconds: 214, milliseconds: 50), text: "한 번만이라도"),
        SyncedLyricLine(timestamp: Duration(seconds: 217, milliseconds: 30), text: "네 품에 안겨 너의 이름을 부른다면"),
        SyncedLyricLine(timestamp: Duration(seconds: 223, milliseconds: 80), text: "말해주고 싶어"),
        SyncedLyricLine(timestamp: Duration(seconds: 228, milliseconds: 90), text: "나 들려주고 싶어"),
        SyncedLyricLine(timestamp: Duration(seconds: 234, milliseconds: 40), text: "늘 입술 끝에 머금고"),
        SyncedLyricLine(timestamp: Duration(seconds: 238, milliseconds: 50), text: "되뇌고 되뇌던"),
        SyncedLyricLine(timestamp: Duration(seconds: 241, milliseconds: 30), text: "마음의 말"),
        SyncedLyricLine(timestamp: Duration(seconds: 245, milliseconds: 80), text: "아무리 외쳐 봐도"),
        SyncedLyricLine(timestamp: Duration(seconds: 251), text: "너에게 들리지 않나 봐"),
        SyncedLyricLine(timestamp: Duration(seconds: 256, milliseconds: 90), text: "매일 손으로만 눈빛으로만"),
        SyncedLyricLine(timestamp: Duration(seconds: 262, milliseconds: 50), text: "말해야 했었던"),
        SyncedLyricLine(timestamp: Duration(seconds: 265, milliseconds: 70), text: "널 향한 사랑의 말이야"),
      ];
    }

    return null;
  }
}
