import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song.dart';
import '../models/playlist.dart';
import '../models/spotify_platinum_profile.dart';

class SpotifyPlatinumService {
  static const String _keyPlatinumActive = 'sp_platinum_active';
  static const String _keyAudioFidelity = 'sp_audio_fidelity';
  static const String _keyActiveProfileId = 'sp_active_profile_id';
  static const String _keyProfilesJson = 'sp_profiles_json';
  static const String _keyCrossfadeSeconds = 'sp_crossfade_seconds';
  static const String _keyDjModeEnabled = 'sp_dj_mode_enabled';

  static bool _isPlatinum = true;
  static bool get isPlatinum => _isPlatinum;

  static AudioFidelityTier _fidelity = AudioFidelityTier.platinumLossless24Bit;
  static AudioFidelityTier get fidelity => _fidelity;

  static int _crossfadeSeconds = 4;
  static int get crossfadeSeconds => _crossfadeSeconds;

  static bool _isDjModeEnabled = false;
  static bool get isDjModeEnabled => _isDjModeEnabled;

  static double _playbackPitch = 1.0;
  static double get playbackPitch => _playbackPitch;

  static List<PlatinumProfile> _profiles = [
    PlatinumProfile(
      id: 'prof_primary',
      name: 'Akun Utama',
      subtitle: 'Seleramu: Pop & Indie Indonesia',
      avatarLetter: 'K',
      preferredGenres: ['Pop Indonesia', 'Indie', 'Acoustic'],
      isPrimary: true,
    ),
    PlatinumProfile(
      id: 'prof_studio',
      name: 'Studio & Hi-Fi',
      subtitle: 'Seleramu: K-Pop & Soundtracks',
      avatarLetter: 'S',
      preferredGenres: ['K-Pop', 'Korean Drama OST', 'International'],
      isPrimary: false,
    ),
    PlatinumProfile(
      id: 'prof_chill',
      name: 'Santai Malam',
      subtitle: 'Seleramu: J-Pop & Sleep Waves',
      avatarLetter: 'M',
      preferredGenres: ['J-Pop', 'Sleep', 'Ambient'],
      isPrimary: false,
    ),
  ];

  static String _activeProfileId = 'prof_primary';

  static List<PlatinumProfile> get profiles => List.unmodifiable(_profiles);
  static PlatinumProfile get activeProfile =>
      _profiles.firstWhere((p) => p.id == _activeProfileId, orElse: () => _profiles.first);

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isPlatinum = prefs.getBool(_keyPlatinumActive) ?? true;
      final fidIndex = prefs.getInt(_keyAudioFidelity);
      if (fidIndex != null && fidIndex >= 0 && fidIndex < AudioFidelityTier.values.length) {
        _fidelity = AudioFidelityTier.values[fidIndex];
      }
      _crossfadeSeconds = prefs.getInt(_keyCrossfadeSeconds) ?? 4;
      _isDjModeEnabled = prefs.getBool(_keyDjModeEnabled) ?? false;

      final savedProfileId = prefs.getString(_keyActiveProfileId);
      if (savedProfileId != null) {
        _activeProfileId = savedProfileId;
      }

      final rawProfiles = prefs.getString(_keyProfilesJson);
      if (rawProfiles != null) {
        final decoded = jsonDecode(rawProfiles) as List<dynamic>;
        if (decoded.isNotEmpty) {
          _profiles = decoded.map((e) => PlatinumProfile.fromJson(e as Map<String, dynamic>)).toList();
        }
      }
    } catch (e) {
      debugPrint('SpotifyPlatinumService init error: $e');
    }
  }

  static Future<void> setPlatinumActive(bool active) async {
    _isPlatinum = active;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyPlatinumActive, active);
    } catch (_) {}
  }

  static Future<void> setAudioFidelity(AudioFidelityTier tier) async {
    _fidelity = tier;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyAudioFidelity, tier.index);
    } catch (_) {}
  }

  static Future<void> setCrossfadeSeconds(int seconds) async {
    _crossfadeSeconds = seconds.clamp(0, 12);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyCrossfadeSeconds, _crossfadeSeconds);
    } catch (_) {}
  }

  static Future<void> setDjModeEnabled(bool enabled) async {
    _isDjModeEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyDjModeEnabled, enabled);
    } catch (_) {}
  }

  static void setPlaybackPitch(double pitch) {
    _playbackPitch = pitch.clamp(0.8, 1.2);
  }

  static Future<void> switchProfile(String profileId) async {
    if (_profiles.any((p) => p.id == profileId)) {
      _activeProfileId = profileId;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyActiveProfileId, profileId);
      } catch (_) {}
    }
  }

  static Future<void> updateProfile(String profileId, {String? name, String? subtitle, String? letter}) async {
    final idx = _profiles.indexWhere((p) => p.id == profileId);
    if (idx != -1) {
      if (name != null && name.trim().isNotEmpty) {
        _profiles[idx].name = name.trim();
      }
      if (subtitle != null && subtitle.trim().isNotEmpty) {
        _profiles[idx].subtitle = subtitle.trim();
      }
      if (letter != null && letter.trim().isNotEmpty) {
        _profiles[idx].avatarLetter = letter.trim().substring(0, 1).toUpperCase();
      }
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyProfilesJson, jsonEncode(_profiles.map((p) => p.toJson()).toList()));
      } catch (_) {}
    }
  }

  // --- Mix Playlist-mu (Playlist Blend) ---
  static Playlist blendPlaylists({
    required Playlist playlistA,
    required Playlist playlistB,
    String? blendTitle,
  }) {
    final List<Song> blended = [];
    final maxLen = playlistA.songs.length > playlistB.songs.length
        ? playlistA.songs.length
        : playlistB.songs.length;

    for (int i = 0; i < maxLen; i++) {
      if (i < playlistA.songs.length && !blended.any((s) => s.id == playlistA.songs[i].id)) {
        blended.add(playlistA.songs[i]);
      }
      if (i < playlistB.songs.length && !blended.any((s) => s.id == playlistB.songs[i].id)) {
        blended.add(playlistB.songs[i]);
      }
      if (blended.length >= 12) break;
    }

    final title = blendTitle ?? '${playlistA.title} + ${playlistB.title} Blend';

    return Playlist(
      id: 'custom_blend_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      subtitle: 'Kombinasi harmonis 2 playlist • Mix Platinum • 12 lagu',
      coverUrl: playlistA.coverUrl,
      songs: blended.take(12).toList(),
    );
  }
}

class DjVibe {
  final String id;
  final String name;
  final String commentary;
  final List<String> hashtags;
  final List<Song> Function() songLoader;

  const DjVibe({
    required this.id,
    required this.name,
    required this.commentary,
    required this.hashtags,
    required this.songLoader,
  });
}
