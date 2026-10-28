import 'package:flutter_test/flutter_test.dart';
import 'package:spotify_music_player/services/music_api_service.dart';
import 'package:spotify_music_player/services/spotify_platinum_service.dart';

void main() {
  setUp(() {
    MusicApiService.forcePhilippineLocaleForTesting = false;
  });

  tearDown(() {
    MusicApiService.forcePhilippineLocaleForTesting = false;
  });

  group('Regional Charts & Posters Tests', () {
    test('Default (Indonesia) home playlists contain authentic Spotify posters and exact 50 tracks', () {
      MusicApiService.forcePhilippineLocaleForTesting = false;
      final playlists = MusicApiService.getHomePlaylists();

      final topIndo = playlists.firstWhere((p) => p.id == 'pl_top_50_indo');
      expect(topIndo.title, 'Top 50 - Indonesia');
      expect(topIndo.coverUrl, 'assets/images/top50_indonesia.jpg');
      expect(topIndo.songs.length, 50);

      final viralIndo = playlists.firstWhere((p) => p.id == 'pl_viral_hits');
      expect(viralIndo.title, 'Viral Hits Indonesia');
      expect(viralIndo.coverUrl, 'assets/images/viral50_indonesia.jpg');
      expect(viralIndo.songs.length, 50);
    });

    test('Philippines locale produces Top 50 and Viral 50 Philippines with authentic Spotify artwork', () {
      MusicApiService.forcePhilippineLocaleForTesting = true;
      final playlists = MusicApiService.getHomePlaylists();

      final topPH = playlists.firstWhere((p) => p.id == 'pl_top_50_indo');
      expect(topPH.title, 'Top 50 - Philippines');
      expect(topPH.coverUrl, 'assets/images/top50_philippines.jpg');
      expect(topPH.songs.length, 50);

      final viralPH = playlists.firstWhere((p) => p.id == 'pl_viral_hits');
      expect(viralPH.title, 'Viral 50 - Philippines');
      expect(viralPH.coverUrl, 'assets/images/viral50_philippines.jpg');
      expect(viralPH.songs.length, 50);

      // Verify chart playlists
      final charts = MusicApiService.getTopChartsPlaylists();
      final chartTopPH = charts.firstWhere((p) => p.id == 'chart_top_50_ph');
      expect(chartTopPH.title, 'Top 50 - Philippines');
      expect(chartTopPH.coverUrl, 'assets/images/top50_philippines.jpg');
      expect(chartTopPH.songs.length, 50);

      final chartViralPH = charts.firstWhere((p) => p.id == 'chart_viral_ph');
      expect(chartViralPH.title, 'Viral 50 - Philippines');
      expect(chartViralPH.coverUrl, 'assets/images/viral50_philippines.jpg');
      expect(chartViralPH.songs.length, 50);
    });

    test('Spotify Platinum profile avatar letters are consistent', () {
      final active = SpotifyPlatinumService.activeProfile;
      expect(active.avatarLetter.isNotEmpty, isTrue);
      expect(active.name.isNotEmpty, isTrue);
    });
  });
}
