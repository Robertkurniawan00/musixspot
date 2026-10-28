import 'package:flutter_test/flutter_test.dart';
import 'package:spotify_music_player/services/music_api_service.dart';
import 'package:spotify_music_player/services/title_normalizer.dart';

void main() {
  group('Wendy, Dmeanor, Hyun Bin Spotify Discography Tests', () {
    test('TitleNormalizer maps artist name variants correctly', () {
      expect(TitleNormalizer.cleanArtist('wendi'), 'Wendy');
      expect(TitleNormalizer.cleanArtist('손승완'), 'Wendy');
      expect(TitleNormalizer.cleanArtist('hyunbin'), 'Hyun Bin');
      expect(TitleNormalizer.cleanArtist('현빈'), 'Hyun Bin');
      expect(TitleNormalizer.cleanArtist('dmeanor'), 'DMEANOR');
      expect(TitleNormalizer.cleanArtist('디미너'), 'DMEANOR');
    });

    test('Wendy has authentic Spotify profile, top tracks, and albums', () {
      final artists = MusicApiService.getComprehensiveArtists();
      final wendy = artists.firstWhere((a) => a.name.toLowerCase() == 'wendy');

      expect(wendy.country, 'Korea Selatan');
      expect(wendy.isVerified, isTrue);
      expect(wendy.topTracks.length, greaterThanOrEqualTo(5));

      final titles = wendy.topTracks.map((t) => t.title.toLowerCase()).toList();
      expect(titles.any((t) => t.contains('like water')), isTrue);
      expect(titles.any((t) => t.contains('when this rain stops')), isTrue);
      expect(titles.any((t) => t.contains('wish you hell')), isTrue);
      expect(titles.any((t) => t.contains('written in the stars')), isTrue);
      expect(titles.any((t) => t.contains('recharge me')), isTrue);

      expect(wendy.albums.length, greaterThanOrEqualTo(4));
      final albTitles = wendy.albums.map((a) => a.title.toLowerCase()).toList();
      expect(albTitles.any((t) => t.contains('wish you hell')), isTrue);
      expect(albTitles.any((t) => t.contains('like water')), isTrue);
      expect(albTitles.any((t) => t.contains('recharge')), isTrue);
    });

    test('Hyun Bin has authentic Spotify top tracks (That Man, Can\'t Have You, Inst.)', () {
      final artists = MusicApiService.getComprehensiveArtists();
      final hyunBin = artists.firstWhere((a) => a.name.toLowerCase() == 'hyun bin');

      expect(hyunBin.country, 'Korea Selatan');
      expect(hyunBin.topTracks.length, greaterThanOrEqualTo(3));

      final titles = hyunBin.topTracks.map((t) => t.title.toLowerCase()).toList();
      expect(titles.any((t) => t.contains('that man')), isTrue);
      expect(titles.any((t) => t.contains('can\'t have you')), isTrue);
      expect(titles.any((t) => t.contains('inst')), isTrue);
    });

    test('DMEANOR has authentic Spotify top tracks (Stay There, Why Do We, Right Here, Don\'t Hold Me)', () {
      final artists = MusicApiService.getComprehensiveArtists();
      final dmeanor = artists.firstWhere((a) => a.name.toLowerCase() == 'dmeanor');

      expect(dmeanor.country, 'Korea Selatan');
      expect(dmeanor.topTracks.length, greaterThanOrEqualTo(5));

      final titles = dmeanor.topTracks.map((t) => t.title.toLowerCase()).toList();
      expect(titles.any((t) => t.contains('stay there')), isTrue);
      expect(titles.any((t) => t.contains('why do we')), isTrue);
      expect(titles.any((t) => t.contains('right here')), isTrue);
      expect(titles.any((t) => t.contains('don\'t hold me')), isTrue);
      expect(titles.any((t) => t.contains('fool for loving')), isTrue);
    });

    test('Korean sad songs and drama OSTs do not leak Western pop (e.g. Bruno Mars) in similar tracks', () {
      final kdrama = MusicApiService.getKoreanDramaTracks();
      expect(kdrama.isNotEmpty, isTrue);

      // Verify no Bruno Mars, Coldplay, or western tracks in kdrama catalog
      for (final s in kdrama) {
        expect(s.artist.toLowerCase().contains('bruno mars'), isFalse);
        expect(s.artist.toLowerCase().contains('coldplay'), isFalse);
        expect(s.artist.toLowerCase().contains('daft punk'), isFalse);
      }
    });
  });
}
