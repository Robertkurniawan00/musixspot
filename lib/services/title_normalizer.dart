import '../models/song.dart';

/// Title & Artist Normalizer and Deduplication Engine
/// Guarantees:
/// 1. Title formatting consistency:
///    - If Romanji / English title is present: display ONLY clean Romanji (e.g. "The Man", "The Woman", "Ordinary").
///    - If only native language (Hangul, Thai, Japanese, Chinese) is present: display ONLY that native script (e.g. "무시로").
///    - NEVER produce dual-language hybrid titles like "The man (그남자)" or "The woman (그여자)" or "Ordinary (보통)".
/// 2. Clean artist names (e.g. "Baek Ji Young (백지영)" -> "Baek Ji Young").
/// 3. Robust deduplication key that normalizes romanized & native variants to identical keys.
class TitleNormalizer {
  // Asian scripts: Hangul, CJK (Hanzi/Kanji), Hiragana/Katakana, Thai
  static final _asianScriptRegex = RegExp(
    r'[\uAC00-\uD7AF\u1100-\u11FF\u3130-\u318F\u4E00-\u9FFF\u3400-\u4DBF\u3040-\u309F\u30A0-\u30FF\u0E00-\u0E7F]',
  );

  static final _latinCharRegex = RegExp(r'[a-zA-Z]');

  /// Cleans a track or album title according to the strict consistency rule:
  /// No hybrid "Romanji (Native)" or "Native (Romanji)".
  static String cleanTitle(String rawTitle) {
    if (rawTitle.isEmpty) return rawTitle;
    var title = rawTitle.trim();

    // 1. Process parenthetical groups: ( ... ) or [ ... ]
    title = title.replaceAllMapped(
      RegExp(r'\s*[\(\[\{]([^\)\]\}]*)[\)\]\}]'),
      (match) {
        final inside = match.group(1)?.trim() ?? '';
        final fullMatch = match.group(0)!;
        final outside = title.replaceFirst(fullMatch, '').trim();

        // Case A: Outside has Latin and inside has Asian script
        // e.g., "The man (그남자)" -> strip "(그남자)"
        // e.g., "The woman (그여자)" -> strip "(그여자)"
        // e.g., "Ordinary (보통)" -> strip "(보통)"
        // e.g., "Tomorrow (SBS도전성공...)" -> strip parenthetical
        if (_asianScriptRegex.hasMatch(inside) && _latinCharRegex.hasMatch(outside)) {
          return '';
        }

        // Case B: Outside has Asian script and inside is clean Latin
        // e.g., "그남자 (The Man)" -> prefer the Romanji title "The Man"
        if (_asianScriptRegex.hasMatch(outside) && !_asianScriptRegex.hasMatch(inside) && _latinCharRegex.hasMatch(inside)) {
          return ' __USE_INSIDE__:$inside';
        }

        // Case C: Strip generic video / scraper clutter in brackets
        final insideLower = inside.toLowerCase();
        if (insideLower.contains('official') ||
            insideLower.contains('music video') ||
            insideLower.contains('video klip') ||
            insideLower.contains('lirik video') ||
            insideLower.contains('lyrics') ||
            insideLower == 'mv' ||
            insideLower == 'audio' ||
            insideLower == 'hd' ||
            insideLower == '4k') {
          return '';
        }

        return fullMatch;
      },
    ).trim();

    // If marker __USE_INSIDE__ was set, extract it
    if (title.contains('__USE_INSIDE__:')) {
      final parts = title.split('__USE_INSIDE__:');
      if (parts.length > 1 && parts[1].trim().isNotEmpty) {
        title = parts[1].trim();
      }
    }

    // 2. Remove common trailing video tags outside brackets
    title = title
        .replaceAll(RegExp(r'\s*[-–|:]\s*(?:Official\s+)?(?:Music\s+Video|MV|Audio|Lyrics|Lirik\s+Video|Video).*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // 3. Normalize common Korean OST titles to standard clean Romanji title case
    final lower = title.toLowerCase();
    if (lower == 'the man' || lower == 'that man') {
      return 'That Man';
    } else if (lower == 'the woman' || lower == 'that woman') {
      return 'That Woman';
    } else if (lower == 'ordinary') {
      return 'Ordinary';
    } else if (lower == 'stay with me') {
      return 'Stay With Me';
    } else if (lower == 'you are my everything') {
      return 'You Are My Everything';
    } else if (lower == 'give you my heart') {
      return 'Give You My Heart';
    }

    return title.isEmpty ? rawTitle : title;
  }

  /// Cleans artist names, removing dual-language annotations
  static String cleanArtist(String rawArtist) {
    if (rawArtist.isEmpty) return rawArtist;
    var artist = rawArtist.trim();

    artist = artist.replaceAllMapped(
      RegExp(r'\s*[\(\[\{]([^\)\]\}]*)[\)\]\}]'),
      (match) {
        final inside = match.group(1)?.trim() ?? '';
        final fullMatch = match.group(0)!;
        final outside = artist.replaceFirst(fullMatch, '').trim();

        if (_latinCharRegex.hasMatch(outside) && _asianScriptRegex.hasMatch(inside)) {
          return '';
        }
        if (_asianScriptRegex.hasMatch(outside) && !_asianScriptRegex.hasMatch(inside) && _latinCharRegex.hasMatch(inside)) {
          return ' __USE_INSIDE__:$inside';
        }
        return fullMatch;
      },
    ).trim();

    if (artist.contains('__USE_INSIDE__:')) {
      final parts = artist.split('__USE_INSIDE__:');
      if (parts.length > 1 && parts[1].trim().isNotEmpty) {
        artist = parts[1].trim();
      }
    }

    final lower = artist.toLowerCase();
    if (lower == 'wendy' || lower == 'wendi' || lower == '손승완') {
      return 'Wendy';
    } else if (lower == 'hyun bin' || lower == 'hyunbin' || lower == '현빈') {
      return 'Hyun Bin';
    } else if (lower == 'baek ji young' ||
        lower == 'baek ji-young' ||
        lower == 'baekjiyoung' ||
        lower == 'baek z young' ||
        lower == 'baekzyoung') {
      return 'Baek Ji Young';
    } else if (lower == 'gummy') {
      return 'Gummy';
    } else if (lower == 'dmeanor' || lower == '디미너') {
      return 'DMEANOR';
    }

    return artist.isEmpty ? rawArtist : artist;
  }

  /// Creates a normalized deduplication key
  /// Example:
  /// dedupKey("Baek Ji Young", "The man") == dedupKey("Baek Ji Young", "The man (그남자)")
  /// dedupKey("HYUN BIN", "The man (그남자)") == dedupKey("Hyun Bin", "That Man")
  static String dedupKey(String artist, String title) {
    var cArtist = cleanArtist(artist).toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    var cTitle = cleanTitle(title).toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

    // Canonical artist aliases
    if (cArtist == 'baekzyoung') cArtist = 'baekjiyoung';

    // Canonical aliases for K-OST tracks
    if (cTitle == 'theman') cTitle = 'thatman';
    if (cTitle == 'thewoman') cTitle = 'thatwoman';

    return '${cArtist}_$cTitle';
  }

  /// Return a normalized Song instance with clean title, artist, and album
  static Song normalizeSong(Song song) {
    final cleanT = cleanTitle(song.title);
    final cleanA = cleanArtist(song.artist);
    final cleanAlb = cleanTitle(song.album);

    // If albumArtUrl is empty, supply a high-quality fallback placeholder
    final art = song.albumArtUrl.isNotEmpty
        ? song.albumArtUrl
        : 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&q=80';

    return Song(
      id: song.id,
      title: cleanT,
      artist: cleanA,
      album: cleanAlb.isNotEmpty ? cleanAlb : 'Single',
      albumArtUrl: art,
      audioUrl: song.audioUrl,
      duration: song.duration,
      lyrics: song.lyrics,
      isFlac: song.isFlac,
      audioFormat: song.audioFormat,
      bitDepth: song.bitDepth,
      sampleRate: song.sampleRate,
    );
  }
}
