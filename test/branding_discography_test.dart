import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spotify_music_player/services/music_api_service.dart';
import 'package:spotify_music_player/services/playlist_backup_service.dart';
import 'package:spotify_music_player/theme/spotify_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Rebranding to MusicXSpot', () {
    test('Default theme is rebranded to MusicXSpot Dark', () {
      expect(AppThemeColors.spotifyDark.name, 'MusicXSpot Dark');
    });

    test('Playlist backup service parses songs properly', () {
      final songs = PlaylistBackupService.parseTextTracklist(
        'Sheila On 7 - Dan\nAfgan - Panah Asmara',
      );
      expect(songs.length, 2);
      expect(songs[0].artist, 'Sheila On 7');
      expect(songs[1].artist, 'Afgan');
    });
  });

  group('Non-English Artists, Hyun Bin & Afgan Album Discography', () {
    test('Hyun Bin profile photo uses authentic direct Wikimedia URL', () {
      final artists = MusicApiService.getComprehensiveArtists();
      final hyunBin = artists.firstWhere(
        (a) => a.name.toLowerCase() == 'hyun bin',
        orElse: () => throw AssertionError('Hyun Bin not found'),
      );
      expect(hyunBin.imageUrl, contains('Hyun_Bin_at_the_2024_Toronto_International_Film_Festival_2_%28cropped%29.jpg'));
      expect(hyunBin.imageUrl, isNot(contains('/thumb/')));
    });

    test('Afgan profile has 6 complete studio albums with high-res Apple Music artwork', () {
      final artists = MusicApiService.getComprehensiveArtists();
      final afgan = artists.firstWhere(
        (a) => a.name.toLowerCase() == 'afgan',
        orElse: () => throw AssertionError('Afgan not found'),
      );
      expect(afgan.albums.length >= 6, isTrue, reason: 'Afgan must have at least 6 studio albums');
      
      final expectedAlbums = [
        'Dekade',
        'L1ve to Love, Love to L1ve',
        'Confession No.1',
        'The One',
        'Sides',
        'Wallflower',
      ];

      for (final albName in expectedAlbums) {
        final album = afgan.albums.firstWhere(
          (alb) => alb.title.toLowerCase() == albName.toLowerCase(),
          orElse: () => throw AssertionError('Missing Afgan album: $albName'),
        );
        expect(album.coverUrl.isNotEmpty, isTrue);
        expect(album.coverUrl, contains('mzstatic.com'));
      }
    });

    test('Japanese, Korean, Filipino, Thai, and Western Classic artists have verified high-res avatars', () {
      final artists = MusicApiService.getComprehensiveArtists();
      final targetArtists = [
        'Kenshi Yonezu',
        'Utada Hikaru',
        'YOASOBI',
        'Yuuri',
        'Hyun Bin',
        'Baek Ji Young',
        'Sal Priadi',
        'Nadin Amizah',
        'Pamungkas',
        'Tiara Andini',
        'Denny Caknan',
        'Juicy Luicy',
        'Donne Maula',
        'Zack Tabudlo',
        'SB19',
        'Ben&Ben',
        'Moira Dela Torre',
        'Arthur Nery',
        'Jeff Satur',
        'NONT TANONT',
        'Billkin',
        'BOWKYLION',
        'Oasis',
        'Backstreet Boys',
        'Westlife',
        'Afgan',
      ];

      for (final artistName in targetArtists) {
        final artist = artists.firstWhere(
          (a) => a.name.toLowerCase() == artistName.toLowerCase(),
          orElse: () => throw AssertionError('Missing artist: $artistName'),
        );
        expect(artist.imageUrl.isNotEmpty, isTrue, reason: '$artistName must have an avatar image');
        expect(artist.imageUrl.startsWith('https://'), isTrue, reason: '$artistName avatar must use HTTPS');
        expect(artist.topTracks.isNotEmpty, isTrue, reason: '$artistName must have top tracks');
      }
    });
  });
}
