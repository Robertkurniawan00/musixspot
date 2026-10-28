import 'package:flutter_test/flutter_test.dart';
import 'package:spotify_music_player/models/song.dart';
import 'package:spotify_music_player/models/playlist.dart';
import 'package:spotify_music_player/services/playlist_backup_service.dart';

void main() {
  group('PlaylistBackupService Tests', () {
    final sampleSong1 = Song(
      id: 'track_1',
      title: 'Yellow',
      artist: 'Coldplay',
      album: 'Parachutes',
      albumArtUrl: 'https://example.com/yellow.jpg',
      audioUrl: 'https://example.com/yellow.flac',
      duration: const Duration(seconds: 269),
      isFlac: true,
      audioFormat: 'FLAC',
      bitDepth: '24-bit',
      sampleRate: '96 kHz',
    );

    final sampleSong2 = Song(
      id: 'track_2',
      title: 'Hati-Hati di Jalan',
      artist: 'Tulus',
      album: 'Manusia',
      albumArtUrl: 'https://example.com/tulus.jpg',
      audioUrl: 'https://example.com/tulus.mp3',
      duration: const Duration(seconds: 242),
    );

    final samplePlaylist = Playlist(
      id: 'pl_favorites',
      title: 'My Daily Favorites',
      subtitle: 'Best acoustic & indie songs',
      coverUrl: 'https://example.com/cover.jpg',
      songs: [sampleSong1, sampleSong2],
    );

    test('Export playlist to Exportify-compatible CSV format', () {
      final csv = PlaylistBackupService.exportPlaylistToCsv(samplePlaylist);
      expect(csv.contains('Spotify ID,Track Name,Artist Name,Album Name,Duration (ms),Quality,Added At'), true);
      expect(csv.contains('track_1,Yellow,Coldplay,Parachutes,269000,Standard 320kbps'), true);
      expect(csv.contains('track_2,Hati-Hati di Jalan,Tulus,Manusia,242000,Standard 320kbps'), true);
    });

    test('Parse Exportify CSV back to Song list', () {
      final csv = '''
Spotify ID,Track Name,Artist Name,Album Name,Duration (ms),Quality,Added At
sp_101,"Viva La Vida","Coldplay","Viva La Vida or Death and All His Friends",242000,FLAC,2026-10-08T12:00:00.000Z
sp_102,"Monokrom","Tulus","Monokrom",214000,HQ Standard,2026-10-08T12:00:00.000Z
''';
      final songs = PlaylistBackupService.parseCsv(csv);
      expect(songs.length, 2);
      expect(songs[0].title, 'Viva La Vida');
      expect(songs[0].artist, 'Coldplay');
      expect(songs[0].album, 'Viva La Vida or Death and All His Friends');
      expect(songs[0].duration.inSeconds, 242);
      expect(songs[0].isFlac, true);

      expect(songs[1].title, 'Monokrom');
      expect(songs[1].artist, 'Tulus');
      expect(songs[1].duration.inSeconds, 214);
    });

    test('Parse text tracklist (Artist - Title)', () {
      const textList = '''
Coldplay - Fix You
Sheila On 7 - Dan...
The Weeknd - Blinding Lights
''';
      final songs = PlaylistBackupService.parseTextTracklist(textList);
      expect(songs.length, 3);
      expect(songs[0].artist, 'Coldplay');
      expect(songs[0].title, 'Fix You');
      expect(songs[1].artist, 'Sheila On 7');
      expect(songs[1].title, 'Dan...');
      expect(songs[2].artist, 'The Weeknd');
      expect(songs[2].title, 'Blinding Lights');
    });

    test('Export entire library to JSON and verify structure', () {
      final jsonStr = PlaylistBackupService.exportLibraryToJson([samplePlaylist], [sampleSong1]);
      expect(jsonStr.contains('"version": "1.0"'), true);
      expect(jsonStr.contains('"playlists":'), true);
      expect(jsonStr.contains('"likedSongs":'), true);
      expect(jsonStr.contains('My Daily Favorites'), true);
    });
  });
}
