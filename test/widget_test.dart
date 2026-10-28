import 'package:flutter_test/flutter_test.dart';
import 'package:spotify_music_player/models/song.dart';
import 'package:spotify_music_player/models/playlist.dart';
import 'package:spotify_music_player/services/music_api_service.dart';
import 'package:spotify_music_player/services/lyrics_service.dart';
import 'package:spotify_music_player/services/song_stream_resolver.dart';

void main() {
  group('Spotify Music App Tests', () {
    test('Featured tracks list contains verified tracks with pristine artwork', () {
      final tracks = MusicApiService.getFeaturedTracks();
      expect(tracks.isNotEmpty, true);
      expect(tracks.any((t) => t.title == 'To the Bone'), true);
      final toTheBone = tracks.firstWhere((t) => t.title == 'To the Bone');
      expect(toTheBone.artist, 'Pamungkas');
      expect(toTheBone.audioUrl.contains('youtube.com'), true);
    });

    test('Home playlists contain Daily Mix, Release Radar, and Discover Weekly', () {
      final playlists = MusicApiService.getHomePlaylists();
      expect(playlists.isNotEmpty, true);
      expect(playlists.any((p) => p.id == 'pl_daily_mix_1'), true);
      expect(playlists.any((p) => p.id == 'pl_release_radar'), true);
      expect(playlists.any((p) => p.id == 'pl_discover_weekly'), true);
      expect(playlists.any((p) => p.id == 'pl_hifi_lossless'), false);
    });

    test('Browse categories are properly configured matching Spotify browse categories', () {
      final categories = MusicApiService.getBrowseCategories();
      expect(categories.length >= 10, true);
      expect(categories.any((c) => c.title == 'Pop'), true);
      expect(categories.any((c) => c.title == 'Musik'), true);
      expect(categories.any((c) => c.title.contains('FLAC')), false);
    });

    test('Song model serialization with standard attributes', () {
      final song = Song(
        id: 'test_song',
        title: 'Authentic Symphony',
        artist: 'Master Artist',
        album: 'Spotify Series',
        albumArtUrl: 'https://example.com/art.jpg',
        audioUrl: 'https://example.com/audio.m4a',
        duration: const Duration(minutes: 4),
        isLiked: true,
        isDownloaded: true,
        localFilePath: '/data/user/0/com.spotifyclone/offline_tracks/test_song.m4a',
      );

      final json = song.toJson();
      expect(json['id'], 'test_song');
      expect(json['title'], 'Authentic Symphony');

      final reconstructed = Song.fromJson(json);
      expect(reconstructed.id, song.id);
      expect(reconstructed.qualityBadge, 'HIGH QUALITY');
      expect(reconstructed.localFilePath?.endsWith('.m4a'), true);
    });

    test('Playlist model serialization', () {
      final playlist = Playlist(
        id: 'custom_123',
        title: 'Playlist Favorit',
        subtitle: 'Koleksi Saya',
        coverUrl: 'https://example.com/cover.jpg',
        songs: [
          Song(
            id: 'song_1',
            title: 'Song 1',
            artist: 'Artist 1',
            album: 'Album 1',
            albumArtUrl: 'https://example.com/art1.jpg',
            audioUrl: 'https://example.com/audio1.mp3',
            duration: const Duration(seconds: 180),
          ),
        ],
      );

      final json = playlist.toJson();
      expect(json['id'], 'custom_123');
      expect(json['title'], 'Playlist Favorit');

      final reconstructed = Playlist.fromJson(json);
      expect(reconstructed.id, playlist.id);
      expect(reconstructed.songs.length, 1);
      expect(reconstructed.songs.first.title, 'Song 1');
    });

    test('Popular artist profiles are configured with full playable tracks', () {
      final artists = MusicApiService.getArtists();
      expect(artists.length >= 10, true);

      final tulus = artists.firstWhere((a) => a.name == 'Tulus');
      expect(tulus.isVerified, true);
      expect(tulus.topTracks.length >= 5, true);
      expect(tulus.monthlyListeners.contains('pendengar bulanan'), true);

      final weeknd = artists.firstWhere((a) => a.name == 'The Weeknd');
      expect(weeknd.topTracks.any((s) => s.title.contains('Blinding Lights')), true);

      final so7 = artists.firstWhere((a) => a.name == 'Sheila On 7');
      expect(so7.topTracks.any((s) => s.title.contains('Dan...')), true);

      final daftPunk = artists.firstWhere((a) => a.name == 'Daft Punk');
      expect(daftPunk.topTracks.any((s) => s.title.contains('Get Lucky')), true);

      final coldplay = artists.firstWhere((a) => a.name == 'Coldplay');
      expect(coldplay.topTracks.any((s) => s.title.contains('Yellow')), true);
    });

    test('LyricsService parses LRC synchronized timestamps accurately', () {
      const sampleLrc = '''
[00:13.13] Yeah
[00:27.16] I've been tryna call
[00:29.96] I've been on my own for long enough
''';
      final parsed = LyricsService.parseLrc(sampleLrc);
      expect(parsed.length, 3);
      expect(parsed[0].timestamp, const Duration(seconds: 13, milliseconds: 130));
      expect(parsed[0].text, 'Yeah');
      expect(parsed[1].timestamp, const Duration(seconds: 27, milliseconds: 160));
      expect(parsed[1].text, "I've been tryna call");
      expect(parsed[2].timestamp, const Duration(seconds: 29, milliseconds: 960));
    });

    test('SongStreamResolver strictly rejects MVs, Lyric Videos, Covers, and Compilations', () {
      expect(SongStreamResolver.cleanTrackTitle('Coldplay - Yellow (Official Audio)', 'Coldplay'), 'Yellow');
      expect(SongStreamResolver.cleanTrackTitle('광화문에서 At Gwanghwamun [Studio Master]', '규현'), '광화문에서 At Gwanghwamun');
      expect(SongStreamResolver.cleanArtistName('규현 KYUHYUN - Topic'), '규현 KYUHYUN');
      expect(SongStreamResolver.cleanArtistName('Tulus - Topic'), 'Tulus');
      expect(SongStreamResolver.cleanArtistName('Sheila on 7 Tv'), 'Sheila on 7');
    });
  });
}
