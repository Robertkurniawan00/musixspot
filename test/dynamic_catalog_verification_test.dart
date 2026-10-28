import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spotify_music_player/services/dynamic_catalog_service.dart';
import 'package:spotify_music_player/providers/music_player_provider.dart';
import 'package:spotify_music_player/models/playlist.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('DynamicCatalogService Verification Tests', () {
    test('DynamicCatalogService initializes with non-empty baseline catalogs', () async {
      final service = DynamicCatalogService();
      await service.init();

      expect(service.popularReleases, isNotEmpty);
      expect(service.kdramaPlaylists, isNotEmpty);
      expect(service.animePlaylists, isNotEmpty);
      expect(service.indonesianPlaylists, isNotEmpty);
      expect(service.globalPopPlaylists, isNotEmpty);
    });

    test('All baseline K-Drama & Anime playlists have valid titles, covers, and playable tracks', () async {
      final service = DynamicCatalogService();
      await service.init();

      for (final pl in service.kdramaPlaylists) {
        expect(pl.title.isNotEmpty, isTrue);
        expect(pl.coverUrl.startsWith('http'), isTrue);
        expect(pl.songs.isNotEmpty, isTrue);
        for (final s in pl.songs) {
          expect(s.title.isNotEmpty, isTrue);
          expect(s.artist.isNotEmpty, isTrue);
          expect(s.audioUrl.isNotEmpty, isTrue);
        }
      }

      for (final pl in service.animePlaylists) {
        expect(pl.title.isNotEmpty, isTrue);
        expect(pl.coverUrl.startsWith('http'), isTrue);
        expect(pl.songs.isNotEmpty, isTrue);
        for (final s in pl.songs) {
          expect(s.title.isNotEmpty, isTrue);
          expect(s.artist.isNotEmpty, isTrue);
          expect(s.audioUrl.isNotEmpty, isTrue);
        }
      }
    });

    test('Popular releases preserve essential albums like Bruno Mars 24K Magic', () async {
      final service = DynamicCatalogService();
      await service.init();

      final has24k = service.popularReleases.any((p) =>
          p.title.toLowerCase().contains('24k magic') ||
          p.subtitle.toLowerCase().contains('bruno mars'));
      expect(has24k, isTrue, reason: 'Bruno Mars 24K Magic must be preserved in popular releases');
    });

    test('Playlist JSON serialization and deserialization roundtrip preserves all metadata', () {
      final testPl = Playlist(
        id: 'test_kdrama_qot',
        title: 'Queen of Tears OST',
        subtitle: 'BSS, 10CM, Kim Soo Hyun',
        coverUrl: 'https://cdn-images.dzcdn.net/images/cover/example.jpg',
        songs: [],
      );

      final jsonMap = testPl.toJson();
      final roundtrip = Playlist.fromJson(jsonMap);

      expect(roundtrip.id, equals('test_kdrama_qot'));
      expect(roundtrip.title, equals('Queen of Tears OST'));
      expect(roundtrip.subtitle, equals('BSS, 10CM, Kim Soo Hyun'));
      expect(roundtrip.coverUrl, equals('https://cdn-images.dzcdn.net/images/cover/example.jpg'));
    });

    test('MusicPlayerProvider exposes dynamic catalog getters and refresh capability', () async {
      final provider = MusicPlayerProvider();
      await provider.dynamicCatalog.init();

      expect(provider.popularReleases, isNotEmpty);
      expect(provider.kdramaPlaylists, isNotEmpty);
      expect(provider.animePlaylists, isNotEmpty);
      expect(provider.dynamicIndonesianPlaylists, isNotEmpty);
      expect(provider.dynamicGlobalPopPlaylists, isNotEmpty);
    });
  });
}
