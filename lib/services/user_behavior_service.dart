import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song.dart';
import '../models/playlist.dart';

class UserBehaviorProfile {
  final Map<String, int> artistAffinities;
  final Map<String, int> songPlayCounts;
  final Map<String, int> songCompletionCounts;
  final Map<String, int> songSkipCounts;
  final Set<String> likedSongIds;

  UserBehaviorProfile({
    required this.artistAffinities,
    required this.songPlayCounts,
    required this.songCompletionCounts,
    required this.songSkipCounts,
    required this.likedSongIds,
  });

  factory UserBehaviorProfile.empty() {
    return UserBehaviorProfile(
      artistAffinities: {},
      songPlayCounts: {},
      songCompletionCounts: {},
      songSkipCounts: {},
      likedSongIds: {},
    );
  }

  Map<String, dynamic> toJson() => {
        'artistAffinities': artistAffinities,
        'songPlayCounts': songPlayCounts,
        'songCompletionCounts': songCompletionCounts,
        'songSkipCounts': songSkipCounts,
        'likedSongIds': likedSongIds.toList(),
      };

  factory UserBehaviorProfile.fromJson(Map<String, dynamic> json) {
    return UserBehaviorProfile(
      artistAffinities: Map<String, int>.from(json['artistAffinities'] ?? {}),
      songPlayCounts: Map<String, int>.from(json['songPlayCounts'] ?? {}),
      songCompletionCounts: Map<String, int>.from(json['songCompletionCounts'] ?? {}),
      songSkipCounts: Map<String, int>.from(json['songSkipCounts'] ?? {}),
      likedSongIds: Set<String>.from(json['likedSongIds'] ?? []),
    );
  }
}

class UserBehaviorService {
  static const String _prefKey = 'spotify_user_behavior_profile_v1';
  static UserBehaviorProfile _profile = UserBehaviorProfile.empty();

  static UserBehaviorProfile get profile => _profile;

  /// Initialize and load saved behavior profile
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        _profile = UserBehaviorProfile.fromJson(decoded);
      }
    } catch (e) {
      debugPrint('UserBehaviorService.init error: $e');
    }
  }

  /// Save profile to SharedPreferences
  static Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, jsonEncode(_profile.toJson()));
    } catch (e) {
      debugPrint('UserBehaviorService._save error: $e');
    }
  }

  /// Seed favorite artists from onboarding or settings (+25 affinity boost)
  static void seedFavoriteArtists(List<dynamic> artists) {
    for (final a in artists) {
      final name = (a is String ? a : (a as dynamic).name).toString().trim();
      if (name.isNotEmpty) {
        _profile.artistAffinities[name] = (_profile.artistAffinities[name] ?? 0) + 25;
      }
    }
    _save();
  }

  /// Track when a song starts playing (+2 affinity to artist, +1 play count)
  static void recordPlay(Song song) {
    final artist = song.artist.trim();
    if (artist.isNotEmpty) {
      _profile.artistAffinities[artist] = (_profile.artistAffinities[artist] ?? 0) + 2;
    }
    _profile.songPlayCounts[song.id] = (_profile.songPlayCounts[song.id] ?? 0) + 1;
    _save();
  }

  /// Track when user listens completely (>80% or finish) (+3 affinity boost)
  static void recordCompletion(Song song) {
    final artist = song.artist.trim();
    if (artist.isNotEmpty) {
      _profile.artistAffinities[artist] = (_profile.artistAffinities[artist] ?? 0) + 3;
    }
    _profile.songCompletionCounts[song.id] = (_profile.songCompletionCounts[song.id] ?? 0) + 1;
    _save();
  }

  /// Track when a song is skipped very quickly (<15s) (-1 penalty, min 0)
  static void recordSkip(Song song) {
    final artist = song.artist.trim();
    if (artist.isNotEmpty) {
      final current = _profile.artistAffinities[artist] ?? 0;
      if (current > 0) {
        _profile.artistAffinities[artist] = current - 1;
      }
    }
    _profile.songSkipCounts[song.id] = (_profile.songSkipCounts[song.id] ?? 0) + 1;
    _save();
  }

  /// Track when a song is liked (+5 affinity) or unliked (-5)
  static void recordLike(Song song, bool isLiked) {
    final artist = song.artist.trim();
    if (isLiked) {
      _profile.likedSongIds.add(song.id);
      if (artist.isNotEmpty) {
        _profile.artistAffinities[artist] = (_profile.artistAffinities[artist] ?? 0) + 5;
      }
    } else {
      _profile.likedSongIds.remove(song.id);
      if (artist.isNotEmpty) {
        final current = _profile.artistAffinities[artist] ?? 0;
        _profile.artistAffinities[artist] = (current - 5).clamp(0, 9999);
      }
    }
    _save();
  }

  /// Get top artists by user affinity score
  static List<String> getTopArtists({int limit = 5}) {
    if (_profile.artistAffinities.isEmpty) {
      return ['Bernadya', 'Sheila On 7', 'Tulus', 'Raim Laode', 'Bruno Mars'];
    }
    final sorted = _profile.artistAffinities.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).map((e) => e.key).toList();
  }

  /// Dynamically synthesize "Dibuat Untuk Kamu" recommendation playlists based on learned behavior
  static List<Playlist> generatePersonalizedPlaylists({
    required List<Song> catalog,
    required List<Song> likedSongs,
    required List<Song> recentlyPlayed,
  }) {
    if (catalog.isEmpty) return [];

    final topArtists = getTopArtists(limit: 4);
    final topArtistPrimary = topArtists.isNotEmpty ? topArtists[0] : 'Bernadya';
    final topArtistSecondary = topArtists.length > 1 ? topArtists[1] : 'Sheila On 7';

    // Helper: calculate song score
    double scoreSong(Song s) {
      double score = 0.0;
      final artistAffinity = _profile.artistAffinities[s.artist.trim()] ?? 0;
      score += artistAffinity * 3.0;

      final playCount = _profile.songPlayCounts[s.id] ?? 0;
      score += playCount * 2.0;

      final completionCount = _profile.songCompletionCounts[s.id] ?? 0;
      score += completionCount * 4.0;

      if (_profile.likedSongIds.contains(s.id) || s.isLiked) {
        score += 8.0;
      }

      final skipCount = _profile.songSkipCounts[s.id] ?? 0;
      score -= skipCount * 2.0;

      return score;
    }

    // 1. Radio Selera Musikmu (Dynamic blend of user's highest affinity tracks)
    final sortedByTaste = List<Song>.from(catalog)..sort((a, b) => scoreSong(b).compareTo(scoreSong(a)));
    final radioSeleraSongs = sortedByTaste.take(12).toList();

    // 2. Daily Mix 1 (Personalized around top primary artist - 12 tracks)
    final dailyMix1Songs = catalog.where((s) {
      final a = s.artist.toLowerCase();
      return a.contains(topArtistPrimary.toLowerCase()) ||
          a.contains(topArtistSecondary.toLowerCase()) ||
          topArtists.any((top) => a.contains(top.toLowerCase()));
    }).toList();
    if (dailyMix1Songs.length < 12) {
      for (final s in catalog) {
        if (!dailyMix1Songs.contains(s)) {
          dailyMix1Songs.add(s);
          if (dailyMix1Songs.length >= 12) break;
        }
      }
    }

    // 3. Kilas Balik Favoritmu (Songs frequently played & completed - 12 tracks)
    final kilasBalikSongs = <Song>[];
    for (final s in likedSongs) {
      if (!kilasBalikSongs.contains(s)) kilasBalikSongs.add(s);
    }
    for (final s in recentlyPlayed) {
      if (!kilasBalikSongs.contains(s)) kilasBalikSongs.add(s);
    }
    for (final s in catalog) {
      if (kilasBalikSongs.length >= 12) break;
      if (!kilasBalikSongs.contains(s)) {
        kilasBalikSongs.add(s);
      }
    }

    String collageUrl(List<Song> songs) {
      final urls = songs.map((s) => s.albumArtUrl).where((u) => u.isNotEmpty).take(4).toList();
      if (urls.length >= 4) return 'collage:${urls.join("|")}';
      return urls.isNotEmpty ? urls.first : '';
    }

    final topNamesString = topArtists.take(3).join(', ');

    return [
      Playlist(
        id: 'pl_radio_selera',
        title: 'Radio Selera Musikmu',
        subtitle: 'Berdasarkan selera musikmu: $topNamesString',
        coverUrl: collageUrl(radioSeleraSongs),
        songs: radioSeleraSongs,
        isDailyMix: true,
        dailyMixNumber: 1,
      ),
      Playlist(
        id: 'pl_daily_mix_personal',
        title: 'Daily Mix 1',
        subtitle: '$topArtistPrimary, $topArtistSecondary, dan lainnya',
        coverUrl: collageUrl(dailyMix1Songs),
        songs: dailyMix1Songs,
        isDailyMix: true,
        dailyMixNumber: 2,
      ),
      Playlist(
        id: 'pl_kilas_balik',
        title: 'Kilas Balik Favoritmu',
        subtitle: 'Lagu-lagu yang paling sering kamu dengarkan sampai selesai',
        coverUrl: kilasBalikSongs.isNotEmpty ? kilasBalikSongs.first.albumArtUrl : '',
        songs: kilasBalikSongs,
      ),
    ];
  }
}
