import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spotify_music_player/models/song.dart';
import 'package:spotify_music_player/models/playlist.dart';
import 'package:spotify_music_player/models/spotify_platinum_profile.dart';
import 'package:spotify_music_player/services/spotify_platinum_service.dart';
import 'package:spotify_music_player/services/music_api_service.dart';
import 'package:spotify_music_player/providers/music_player_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Spotify Platinum Core Service Verification', () {
    test('Spotify Platinum initializes with active status and lossless 24-bit tier', () async {
      await SpotifyPlatinumService.init();

      expect(SpotifyPlatinumService.isPlatinum, isTrue);
      expect(SpotifyPlatinumService.fidelity, AudioFidelityTier.platinumLossless24Bit);
      expect(SpotifyPlatinumService.profiles.length, 3, reason: 'Must provide up to 3 Platinum accounts');
      expect(SpotifyPlatinumService.activeProfile.id, 'prof_primary');
    });

    test('3 Platinum Accounts profile switching reflects active profile', () async {
      await SpotifyPlatinumService.init();

      // Switch to studio profile
      await SpotifyPlatinumService.switchProfile('prof_studio');
      expect(SpotifyPlatinumService.activeProfile.id, 'prof_studio');
      expect(SpotifyPlatinumService.activeProfile.avatarLetter, 'S');

      // Switch to chill profile
      await SpotifyPlatinumService.switchProfile('prof_chill');
      expect(SpotifyPlatinumService.activeProfile.id, 'prof_chill');
      expect(SpotifyPlatinumService.activeProfile.avatarLetter, 'M');

      // Switch back to primary
      await SpotifyPlatinumService.switchProfile('prof_primary');
      expect(SpotifyPlatinumService.activeProfile.id, 'prof_primary');
      expect(SpotifyPlatinumService.activeProfile.avatarLetter, 'K');
    });

    test('Audio Fidelity mode changes persist and update audio tier', () async {
      await SpotifyPlatinumService.init();

      await SpotifyPlatinumService.setAudioFidelity(AudioFidelityTier.veryHigh320k);
      expect(SpotifyPlatinumService.fidelity, AudioFidelityTier.veryHigh320k);

      await SpotifyPlatinumService.setAudioFidelity(AudioFidelityTier.platinumLossless24Bit);
      expect(SpotifyPlatinumService.fidelity, AudioFidelityTier.platinumLossless24Bit);
    });

    test('Crossfade and DJ software settings are configurable up to 12s', () async {
      await SpotifyPlatinumService.init();

      await SpotifyPlatinumService.setCrossfadeSeconds(8);
      expect(SpotifyPlatinumService.crossfadeSeconds, 8);

      // Verify clamping
      await SpotifyPlatinumService.setCrossfadeSeconds(25);
      expect(SpotifyPlatinumService.crossfadeSeconds, 12);

      await SpotifyPlatinumService.setDjModeEnabled(true);
      expect(SpotifyPlatinumService.isDjModeEnabled, isTrue);

      SpotifyPlatinumService.setPlaybackPitch(1.1);
      expect(SpotifyPlatinumService.playbackPitch, 1.1);
    });
  });

  group('Spotify Platinum Lossless Audio Badge Verification', () {
    test('Song model qualityBadge reflects LOSSLESS 24-BIT / 44.1 kHz when isFlac is true', () {
      final sampleSong = Song(
        id: 'track_lossless',
        title: 'Asmalibrasi',
        artist: 'Soegi Bornean',
        album: 'Atma',
        albumArtUrl: 'https://example.com/art.jpg',
        audioUrl: 'https://example.com/audio.flac',
        duration: const Duration(seconds: 245),
        isFlac: true,
        audioFormat: 'FLAC',
        bitDepth: '24-bit',
        sampleRate: '44.1 kHz',
      );

      expect(sampleSong.isFlac, isTrue);
      expect(sampleSong.audioFormat, 'FLAC');
      expect(sampleSong.bitDepth, '24-bit');
      expect(sampleSong.qualityBadge, 'LOSSLESS 24-BIT / 44.1 kHz');
    });

    test('Song model qualityBadge falls back to HIGH QUALITY when not flac', () {
      final standardSong = Song(
        id: 'track_standard',
        title: 'Sialnya, Hidup Harus Tetap Berjalan',
        artist: 'Bernadya',
        album: 'Single',
        albumArtUrl: 'https://example.com/art.jpg',
        audioUrl: 'https://example.com/audio.m4a',
        duration: const Duration(seconds: 200),
        isFlac: false,
      );

      expect(standardSong.qualityBadge, 'HIGH QUALITY');
    });
  });

  group('Playlist Mixer / Blend Verification', () {
    test('blendPlaylists interleaves tracks from two playlists into 12-song blend', () {
      final allPlaylists = MusicApiService.getHomePlaylists();
      final pl1 = allPlaylists.firstWhere((p) => p.id == 'pl_daily_mix_1');
      final pl2 = allPlaylists.firstWhere((p) => p.id == 'pl_daily_mix_2');

      final blend = SpotifyPlatinumService.blendPlaylists(playlistA: pl1, playlistB: pl2);

      expect(blend.songs.length, 12, reason: 'Blended playlist must have 12 tracks');
      expect(blend.title.contains('Blend'), isTrue);
      expect(blend.id.startsWith('custom_blend_'), isTrue);
    });
  });

  group('MusicPlayerProvider Integration with Platinum', () {
    test('insertPlaylist adds playlist to provider and allows instant playback', () async {
      final provider = MusicPlayerProvider();
      final initialCount = provider.playlists.length;

      final testPlaylist = Playlist(
        id: 'custom_test_123',
        title: 'Chill Sunset Blend',
        subtitle: '12 curated tracks',
        coverUrl: 'https://example.com/cover.jpg',
        songs: MusicApiService.getFeaturedTracks().take(12).toList(),
      );

      provider.insertPlaylist(testPlaylist);

      expect(provider.playlists.length, initialCount + 1);
      expect(provider.playlists.first.id, 'custom_test_123');
      expect(provider.playlists.first.title, 'Chill Sunset Blend');
    });
  });
}
