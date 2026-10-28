import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spotify_music_player/services/music_api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Playlist Capacities & Friday Release Radar', () {
    test('Top 50 Global contains exactly 50 songs with official artwork', () {
      final top50Global = MusicApiService.getTop50GlobalTracks();
      expect(top50Global.length, 50, reason: 'Top 50 Global must contain 50 songs');
      expect(top50Global.every((s) => s.title.isNotEmpty && s.artist.isNotEmpty), isTrue);

      final playlists = MusicApiService.getHomePlaylists();
      final globalPlaylist = playlists.firstWhere((p) => p.id == 'pl_top_50_global');
      expect(globalPlaylist.songs.length, 50);
      expect(globalPlaylist.coverUrl, contains('charts-images.scdn.co/assets/locale_en/regional/daily/region_global_default.jpg'));
    });

    test('Top 50 Indonesia contains exactly 50 songs', () {
      final top50Indo = MusicApiService.getTop50IndonesiaTracks();
      expect(top50Indo.length, 50, reason: 'Top 50 Indonesia must contain 50 songs');
      expect(top50Indo.every((s) => s.title.isNotEmpty && s.artist.isNotEmpty), isTrue);
    });

    test('Daily Mix 1 through 6 each contain 24 cohesive tracks', () {
      for (int i = 1; i <= 6; i++) {
        final mixTracks = MusicApiService.getDailyMixTracks(i);
        expect(mixTracks.length, 24, reason: 'Daily Mix $i must contain 24 tracks');
        expect(mixTracks.every((s) => s.title.isNotEmpty && s.artist.isNotEmpty), isTrue);
      }
    });

    test('Release Radar contains 30 tracks and dynamic Friday release subtitle', () {
      final playlists = MusicApiService.getHomePlaylists();
      final releaseRadar = playlists.firstWhere((p) => p.id == 'pl_release_radar');
      expect(releaseRadar.songs.length, 30);
      expect(releaseRadar.subtitle, contains('Jumat'));
      expect(releaseRadar.subtitle, contains('30 lagu baru'));
    });
  });

  group('Verified Artist Profiles & Album Artwork', () {
    test('Requested Japanese, Western, Indonesian, and Electronic artists have verified high-res avatars & discographies', () {
      final artists = MusicApiService.getComprehensiveArtists();

      final requiredArtists = [
        'Kenshi Yonezu',
        'Utada Hikaru',
        'YOASOBI',
        'Yuuri',
        'Oasis',
        'Backstreet Boys',
        'Westlife',
        'Afgan',
        'Audien',
      ];

      for (final artistName in requiredArtists) {
        final artist = artists.firstWhere(
          (a) => a.name.toLowerCase() == artistName.toLowerCase(),
          orElse: () => throw AssertionError('Missing required artist: $artistName'),
        );

        // Verify high-res image
        expect(artist.imageUrl.isNotEmpty, isTrue, reason: '$artistName must have an image');
        expect(artist.imageUrl.startsWith('http'), isTrue, reason: '$artistName image must be a valid URL');
        expect(
          artist.imageUrl.contains('mzstatic.com') ||
              artist.imageUrl.contains('wikimedia.org') ||
              artist.imageUrl.contains('dzcdn.net'),
          isTrue,
          reason: '$artistName must use verified high-res CDN (mzstatic, wikimedia, or dzcdn)',
        );

        // Verify top tracks and albums
        expect(artist.topTracks.isNotEmpty, isTrue, reason: '$artistName must have top tracks');
        expect(artist.albums.isNotEmpty, isTrue, reason: '$artistName must have album/EP discography');

        // Verify track album art has valid image URL
        for (final track in artist.topTracks) {
          expect(track.albumArtUrl.isNotEmpty, isTrue);
          expect(track.albumArtUrl.startsWith('http'), isTrue);
        }
      }
    });

    test('J-Pop track catalog artwork uses high-res verified artwork without missing posters', () {
      final jpopTracks = MusicApiService.getJPopTracks();
      expect(jpopTracks.length >= 16, isTrue);
      for (final track in jpopTracks) {
        expect(track.albumArtUrl.isNotEmpty, isTrue);
        expect(track.albumArtUrl.startsWith('http'), isTrue);
        expect(track.albumArtUrl, isNot(contains('placeholder')));
      }
    });
  });
}
