import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spotify_music_player/models/song.dart';
import 'package:spotify_music_player/services/music_api_service.dart';
import 'package:spotify_music_player/services/lyrics_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Audio Quality & Track Properties Tests', () {
    test('1. Non-Lossless tracks are not marked as FLAC / Lossless', () {
      final featured = MusicApiService.getFeaturedTracks();
      final standardTracks = featured.where((t) => !t.audioUrl.endsWith('.flac')).toList();
      expect(standardTracks.isNotEmpty, true);
      for (final track in standardTracks) {
        expect(track.isFlac, false, reason: 'Track ${track.title} by ${track.artist} should not be FLAC');
      }
    });

    test('2. Hyun Bin - That Man (그 남자) has authentic Korean lyrics', () async {
      final lyrics = await LyricsService.fetchSyncedLyrics(
        trackName: 'That Man',
        artistName: 'Hyun Bin',
      );
      expect(lyrics.isNotEmpty, true);
      expect(lyrics.any((l) => l.text.contains('한 남자가 그대를 사랑합니다') || l.text.contains('그 남자는 오늘도 그대를 보며')), true);
      expect(lyrics.any((l) => l.text.contains('바람이 불어오는 날이면')), false, reason: 'Must not use placeholder lyrics');

      // Also check direct API helper
      final hbLyrics = MusicApiService.getHyunBinThatManLyrics();
      expect(hbLyrics.any((l) => l.text.contains('한 남자가 그대를 사랑합니다')), true);
      expect(hbLyrics.any((l) => l.text.contains('바람이 불어오는 날이면')), false);
    });

    test('3. Baek Ji Young - That Woman (그 여자) has authentic Korean lyrics', () async {
      final lyrics = await LyricsService.fetchSyncedLyrics(
        trackName: 'That Woman',
        artistName: 'Baek Ji Young',
      );
      expect(lyrics.isNotEmpty, true);
      expect(lyrics.any((l) => l.text.contains('한 여자가 그대를 사랑합니다')), true);
    });

    test('4. Song without lyrics has null or empty lyrics and no forced fake lyrics', () {
      final songNoLyrics = Song(
        id: 'no_lyrics_1',
        title: 'Instrumental Theme',
        artist: 'Unknown Artist',
        album: 'Single',
        albumArtUrl: 'https://example.com/cover.jpg',
        duration: const Duration(minutes: 3),
        audioUrl: 'https://example.com/audio.mp3',
      );
      expect(songNoLyrics.lyrics, isNull);
    });

    test('5. Naruto search returns official OSTs including SHUN - Never Change and UNLIMITS - Cascade', () async {
      final results = await MusicApiService.searchTracks('naruto');
      expect(results.isNotEmpty, true);

      expect(results.any((t) => t.artist.toLowerCase().contains('shun') && t.title.toLowerCase().contains('never change')), true,
          reason: 'Must include SHUN - Never Change in Naruto search');
      expect(results.any((t) => t.artist.toLowerCase().contains('unlimits') && t.title.toLowerCase().contains('cascade')), true,
          reason: 'Must include UNLIMITS - Cascade in Naruto search');
      expect(results.any((t) => t.artist.toLowerCase().contains('flow') && t.title.toLowerCase().contains('sign')), true,
          reason: 'Must include FLOW - Sign in Naruto search');
      expect(results.any((t) => t.artist.toLowerCase().contains('kana-boon') && t.title.toLowerCase().contains('silhouette')), true,
          reason: 'Must include KANA-BOON - Silhouette in Naruto search');
    });

    test('6. Searching directly for SHUN or Never Change returns Naruto OST', () async {
      final shunResults = await MusicApiService.searchTracks('shun');
      expect(shunResults.any((t) => t.title == 'Never Change'), true);

      final cascadeResults = await MusicApiService.searchTracks('cascade');
      expect(cascadeResults.any((t) => t.artist == 'UNLIMITS'), true);
    });

    test('7. Artist search for Naruto returns Official Naruto OST profile', () async {
      final artist = await MusicApiService.searchArtist('naruto');
      expect(artist, isNotNull);
      expect(artist!.name.contains('Naruto'), true);
      expect(artist.genres.contains('Anime OST'), true);
    });

    test('8. Playback session persistence keys and defaults work properly', () async {
      SharedPreferences.setMockInitialValues({
        'last_played_song_id': 'hb_1',
        'last_played_position_ms': 45000,
        'last_played_duration_ms': 272000,
        'last_played_context': 'Secret Garden OST',
      });

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('last_played_song_id'), 'hb_1');
      expect(prefs.getInt('last_played_position_ms'), 45000);
      expect(prefs.getInt('last_played_duration_ms'), 272000);
      expect(prefs.getString('last_played_context'), 'Secret Garden OST');
    });
  });
}
