import 'package:flutter_test/flutter_test.dart';
import 'package:spotify_music_player/services/lyrics_service.dart';
import 'package:spotify_music_player/models/song.dart';
import 'package:spotify_music_player/services/music_api_service.dart';
import 'package:spotify_music_player/services/song_stream_resolver.dart';
import 'package:spotify_music_player/services/title_normalizer.dart';
import 'package:spotify_music_player/services/playlist_backup_service.dart';
import 'package:spotify_music_player/services/language_service.dart';

void main() {
  group('LyricsService Verification', () {
    test('filters out [intro], [instrumental intro], [solo], [outro] correctly', () {
      const sampleLrc = '''
[00:05.00] [Intro]
[00:10.00] [Instrumental Intro]
[00:15.00] ♪
[00:20.00] [Intro] Aku yang jatuh cinta
[00:25.00] Haruskah kau tahu
[00:30.00] [Guitar Solo]
[00:35.00] Bila nanti kita bersama
[00:40.00] (Instrumental)
[00:45.00] [Outro]
''';

      final parsed = LyricsService.parseLrc(sampleLrc);

      // Verify pure meta tags were removed
      expect(parsed.any((l) => l.text.toLowerCase() == '[intro]'), isFalse);
      expect(parsed.any((l) => l.text.toLowerCase() == '[instrumental intro]'), isFalse);
      expect(parsed.any((l) => l.text.toLowerCase() == '[guitar solo]'), isFalse);
      expect(parsed.any((l) => l.text.toLowerCase() == '(instrumental)'), isFalse);
      expect(parsed.any((l) => l.text.toLowerCase() == '[outro]'), isFalse);
      expect(parsed.any((l) => l.text == '♪'), isFalse);

      // Verify line with tag prefix was stripped to clean text
      expect(parsed.any((l) => l.text == 'Aku yang jatuh cinta'), isTrue);
      expect(parsed.any((l) => l.text == 'Haruskah kau tahu'), isTrue);
      expect(parsed.any((l) => l.text == 'Bila nanti kita bersama'), isTrue);

      expect(parsed.length, equals(3));
    });
  });

  group('Artist Model & Search Verification', () {
    test('curated artists have discography albums and EPs', () {
      final bernadya = MusicApiService.getArtistByName('Bernadya');
      expect(bernadya, isNotNull);
      expect(bernadya!.albums.isNotEmpty, isTrue);

      final album = bernadya.albums.firstWhere((a) => a.title.contains('Sialnya'));
      expect(album.title, equals('Sialnya, Hidup Harus Tetap Berjalan'));
      expect(album.type, equals('Album'));

      final ep = bernadya.albums.firstWhere((a) => a.title.contains('Terlintas'));
      expect(ep.type, equals('EP'));
    });

    test('Tulus has albums populated', () {
      final tulus = MusicApiService.getArtistByName('Tulus');
      expect(tulus, isNotNull);
      expect(tulus!.albums.length, greaterThanOrEqualTo(3));
      expect(tulus.albums.any((a) => a.title == 'Manusia'), isTrue);
    });

    test('Raim Laode profile exists with sunset silhouette avatar, top tracks, and albums', () async {
      final raim = MusicApiService.getArtistByName('Raim Laode');
      expect(raim, isNotNull);
      expect(raim!.name, equals('Raim Laode'));
      expect(raim.imageUrl.isNotEmpty, isTrue);
      expect(raim.imageUrl, contains('mzstatic.com'));
      expect(raim.isVerified, isTrue);
      expect(raim.topTracks.length, greaterThanOrEqualTo(5));
      expect(raim.topTracks.any((s) => s.title == 'Komang'), isTrue);
      expect(raim.topTracks.any((s) => s.title == 'Dunia Yang Nanti'), isTrue);
      expect(raim.albums.any((a) => a.title == 'Komang'), isTrue);

      // Verify searchArtist matches "raim laode" and "raim"
      final searchedExact = await MusicApiService.searchArtist('Raim Laode');
      expect(searchedExact, isNotNull);
      expect(searchedExact!.name, equals('Raim Laode'));

      final searchedPartial = await MusicApiService.searchArtist('raim');
      expect(searchedPartial, isNotNull);
      expect(searchedPartial!.name, equals('Raim Laode'));
    });
  });

  group('30-Second Cutoff Elimination Verification', () {
    test('SongStreamResolver.isPreviewUrl correctly detects and bans preview clips', () {
      expect(SongStreamResolver.isPreviewUrl('https://cdnt-preview.dzcdn.net/api/1/1/a/5/preview.mp3'), isTrue);
      expect(SongStreamResolver.isPreviewUrl('https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview125/v4/preview.m4a'), isTrue);
      expect(SongStreamResolver.isPreviewUrl('https://cdn-preview.dzcdn.net/stream/123.mp3'), isTrue);

      // Full streams should NOT be flagged as preview
      expect(SongStreamResolver.isPreviewUrl('https://rr1---sn-oxun-xx.googlevideo.com/videoplayback?itag=140'), isFalse);
      expect(SongStreamResolver.isPreviewUrl('asset://assets/audio/song.flac'), isFalse);
      expect(SongStreamResolver.isPreviewUrl('https://mycdn.com/music/full_song.mp3'), isFalse);
    });

    test('SongStreamResolver strictly filters out MV, Lyric Videos, and Covers', () {
      expect(SongStreamResolver.isBlacklisted('Bernadya - Satu Bulan (Official Music Video)'), isTrue);
      expect(SongStreamResolver.isBlacklisted('Bernadya - Satu Bulan (Official Lyric Video)'), isTrue);
      expect(SongStreamResolver.isBlacklisted('Bernadya - Satu Bulan (Karaoke Version)'), isTrue);
      expect(SongStreamResolver.isBlacklisted('Bernadya - Satu Bulan (Official Audio)'), isFalse);
    });

    test('SongStreamResolver.cleanTrackTitle produces clean title without scraper clutter', () {
      expect(SongStreamResolver.cleanTrackTitle('Bernadya - Satu Bulan (Official Audio)', 'Bernadya'), equals('Satu Bulan'));
      expect(SongStreamResolver.cleanTrackTitle('Sheila On 7 - Dan... [HQ Audio]', 'Sheila On 7'), equals('Dan...'));
    });
  });

  group('Comprehensive Regional Artists & Trends Verification', () {
    test('getComprehensiveArtists includes Indonesia, Philippines, Thailand, Malaysia, and Screenshot artists', () {
      final all = MusicApiService.getComprehensiveArtists();
      expect(all.length, greaterThanOrEqualTo(25));

      // Indonesia
      expect(all.any((a) => a.name == 'Sal Priadi' && a.country == 'Indonesia'), isTrue);
      expect(all.any((a) => a.name == 'Donne Maula' && a.country == 'Indonesia'), isTrue);
      expect(all.any((a) => a.name == 'Nadin Amizah' && a.country == 'Indonesia'), isTrue);

      // Philippines
      expect(all.any((a) => a.name == 'Zack Tabudlo' && a.country == 'Filipina'), isTrue);
      expect(all.any((a) => a.name == 'SB19' && a.country == 'Filipina'), isTrue);
      expect(all.any((a) => a.name == 'Ben&Ben' && a.country == 'Filipina'), isTrue);

      // Thailand
      expect(all.any((a) => a.name == 'Jeff Satur' && a.country == 'Thailand'), isTrue);
      expect(all.any((a) => a.name == 'NONT TANONT' && a.country == 'Thailand'), isTrue);
      expect(all.any((a) => a.name == 'Three Man Down' && a.country == 'Thailand'), isTrue);

      // Malaysia
      expect(all.any((a) => a.name == 'Masdo' && a.country == 'Malaysia'), isTrue);
      expect(all.any((a) => a.name == 'Insomniacks' && a.country == 'Malaysia'), isTrue);
      expect(all.any((a) => a.name == 'Siti Nurhaliza' && a.country == 'Malaysia'), isTrue);

      // Screenshot Artists
      expect(all.any((a) => a.name == 'Icona Pop' && a.country == 'Swedia'), isTrue);
      expect(all.any((a) => a.name == 'Urban Cone' && a.country == 'Swedia'), isTrue);
      expect(all.any((a) => a.name == 'Zara Larsson' && a.country == 'Swedia'), isTrue);
      expect(all.any((a) => a.name == 'Alan Walker'), isTrue);
    });

    test('getTrendingByRegion returns distinct tracks per region', () {
      final idTracks = MusicApiService.getTrendingByRegion('id');
      final phTracks = MusicApiService.getTrendingByRegion('ph');
      final thTracks = MusicApiService.getTrendingByRegion('th');
      final myTracks = MusicApiService.getTrendingByRegion('my');
      final globalTracks = MusicApiService.getTrendingByRegion('all');

      expect(idTracks.isNotEmpty, isTrue);
      expect(phTracks.isNotEmpty, isTrue);
      expect(thTracks.isNotEmpty, isTrue);
      expect(myTracks.isNotEmpty, isTrue);
      expect(globalTracks.isNotEmpty, isTrue);

      // ID has Indonesian hits
      expect(idTracks.any((s) => s.artist == 'Bernadya' || s.artist == 'Raim Laode' || s.artist == 'Donne Maula'), isTrue);
      // PH has Zack Tabudlo or SB19
      expect(phTracks.any((s) => s.artist.contains('Zack') || s.artist.contains('SB19')), isTrue);
      // TH has Jeff Satur or NONT TANONT
      expect(thTracks.any((s) => s.artist.contains('Jeff Satur') || s.artist.contains('NONT TANONT')), isTrue);
      // MY has Masdo or Insomniacks
      expect(myTracks.any((s) => s.artist.contains('Masdo') || s.artist.contains('Insomniacks')), isTrue);
    });

    test('The Weeknd - Blinding Lights uses verified official studio track ID 4NRXx6U8ABQ', () {
      final featuredWeeknd = MusicApiService.getFeaturedTracks().firstWhere((s) => s.title == 'Blinding Lights');
      expect(featuredWeeknd.audioUrl, contains('4NRXx6U8ABQ'));

      final artistWeeknd = MusicApiService.getArtistByName('The Weeknd');
      expect(artistWeeknd, isNotNull);
      final artistTrack = artistWeeknd!.topTracks.firstWhere((s) => s.title == 'Blinding Lights');
      expect(artistTrack.audioUrl, contains('4NRXx6U8ABQ'));
    });

    test('Song.generateSampleLyrics returns null so no dummy Indonesian placeholder lyrics are shown', () {
      final lyrics = Song.generateSampleLyrics('Test Track');
      expect(lyrics, isNull);
    });
  });

  group('Title Normalization & Deduplication Verification', () {
    test('TitleNormalizer strips parenthetical native scripts when Latin exists', () {
      expect(TitleNormalizer.cleanTitle('The man (그남자)'), equals('That Man'));
      expect(TitleNormalizer.cleanTitle('The woman (그여자)'), equals('That Woman'));
      expect(TitleNormalizer.cleanTitle('Ordinary (보통)'), equals('Ordinary'));
      expect(TitleNormalizer.cleanTitle('Here I Am (들리나요)'), equals('Here I Am'));
      expect(TitleNormalizer.cleanTitle('Love Is (사랑은)'), equals('Love Is'));
      expect(TitleNormalizer.cleanTitle('Tears (눈물이 많은 이유)'), equals('Tears'));
    });

    test('TitleNormalizer preserves native-only titles when no Latin title is provided', () {
      expect(TitleNormalizer.cleanTitle('무시로'), equals('무시로'));
      expect(TitleNormalizer.cleanTitle('그남자'), equals('그남자'));
      expect(TitleNormalizer.cleanTitle('사랑 안해'), equals('사랑 안해'));
    });

    test('TitleNormalizer dedupKey equates romanized and bilingual titles', () {
      final key1 = TitleNormalizer.dedupKey('Baek Ji Young', 'The man');
      final key2 = TitleNormalizer.dedupKey('Baek Ji Young', 'The man (그남자)');
      final key3 = TitleNormalizer.dedupKey('백지영 (Baek Z Young)', 'That Man');

      expect(key1, equals(key2));
      expect(key1, equals(key3));
    });

    test('TitleNormalizer cleanArtist normalizes bilingual artist names', () {
      expect(TitleNormalizer.cleanArtist('백지영 (Baek Z Young)'), equals('Baek Ji Young'));
      expect(TitleNormalizer.cleanArtist('현빈 (Hyun Bin)'), equals('Hyun Bin'));
      expect(TitleNormalizer.cleanArtist('거미 (Gummy)'), equals('Gummy'));
    });
  });

  group('Korean Drama OST & Artist Discography Verification', () {
    test('Korean Drama OST tracks are populated with rich clean titles', () {
      final kdramaTracks = MusicApiService.getKoreanDramaTracks();
      expect(kdramaTracks.length, greaterThanOrEqualTo(15));

      // No hybrid native script bracket titles (e.g. That Woman (그 여자))
      for (final song in kdramaTracks) {
        if (song.title.contains('Ver.') || song.title.contains('Inst')) continue;
        expect(song.title.contains('(') && song.title.contains(')'), isFalse,
            reason: 'Title should not contain parenthetical scripts: ${song.title}');
        expect(song.albumArtUrl.isNotEmpty, isTrue);
      }

      // Check iconic tracks presence
      expect(kdramaTracks.any((s) => s.title == 'That Woman' && s.artist == 'Baek Ji Young'), isTrue);
      expect(kdramaTracks.any((s) => s.title == 'That Man' && s.artist == 'Hyun Bin'), isTrue);
      expect(kdramaTracks.any((s) => s.title == 'Stay With Me' && s.artist.contains('Punch')), isTrue);
      expect(kdramaTracks.any((s) => s.title == 'You Are My Everything' && s.artist == 'Gummy'), isTrue);
      expect(kdramaTracks.any((s) => s.title == 'Beautiful' && s.artist == 'Crush'), isTrue);
      expect(kdramaTracks.any((s) => s.title == 'Start Over' && s.artist == 'Gaho'), isTrue);
    });

    test('Korean Drama Playlists exist for iconic dramas', () {
      final kdramaPlaylists = MusicApiService.getKoreanDramaPlaylists();
      expect(kdramaPlaylists.length, greaterThanOrEqualTo(6));

      expect(kdramaPlaylists.any((p) => p.title.contains('Secret Garden')), isTrue);
      expect(kdramaPlaylists.any((p) => p.title.contains('Goblin')), isTrue);
      expect(kdramaPlaylists.any((p) => p.title.contains('Crash Landing on You')), isTrue);
      expect(kdramaPlaylists.any((p) => p.title.contains('Descendants of the Sun')), isTrue);
    });

    test('Category ost_drakor is registered and provides full content', () {
      final categories = MusicApiService.getBrowseCategories();
      expect(categories.any((c) => c.id == 'ost_drakor'), isTrue);

      final cat = categories.firstWhere((c) => c.id == 'ost_drakor');
      final details = MusicApiService.getCategoryDetails(cat);
      expect(details.heroPlaylist, isNotNull);
      expect(details.sections.isNotEmpty, isTrue);
      expect(details.sections.first.playlists.isNotEmpty, isTrue);
    });

    test('Baek Ji Young and Hyun Bin have complete discographies and top tracks', () {
      final bjy = MusicApiService.getArtistByName('Baek Ji Young');
      expect(bjy, isNotNull);
      expect(bjy!.albums.length, greaterThanOrEqualTo(3));
      expect(bjy.topTracks.length, greaterThanOrEqualTo(8));
      expect(bjy.topTracks.any((s) => s.title == 'That Man'), isTrue);

      final hyunBin = MusicApiService.getArtistByName('Hyun Bin');
      expect(hyunBin, isNotNull);
      expect(hyunBin!.topTracks.any((s) => s.title == 'That Man'), isTrue);
    });
  });

  group('Spotify Embed & Jay Chou Playlist Import Verification', () {
    test('PlaylistBackupService imports Jay Chou 2000-2017 playlist without error', () async {
      final result = await PlaylistBackupService.importFromSpotifyUrl(
        'https://open.spotify.com/playlist/5UW1ZjcbK1nRYhX7zaFt8E?si=wAcfDAkpSrehHt492rKi3A&utm_source=copy-link&pi=hGC1F5d_QPOZY',
      );

      expect(result, isNotNull);
      expect(result!.title, contains('Jay Chou'));
      final songs = result.songs;
      expect(songs.length, equals(66));

      // Validate titles are clean and not empty
      for (final song in songs) {
        expect(song.title.isNotEmpty, isTrue);
        expect(song.artist.isNotEmpty, isTrue);
        expect(song.albumArtUrl.isNotEmpty, isTrue);
      }
    });
  });

  group('Rebranding to musixspot Verification', () {
    test('LanguageService reflects musixspot brand', () {
      LanguageService.setLanguage(AppLanguage.indonesian);
      expect(LanguageService.tr('settings_about_app'), equals('Tentang musixspot'));

      LanguageService.setLanguage(AppLanguage.english);
      expect(LanguageService.tr('settings_about_app'), equals('About musixspot'));
    });
  });
}
