import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spotify_music_player/models/song.dart';
import 'package:spotify_music_player/services/music_api_service.dart';
import 'package:spotify_music_player/services/song_credits_service.dart';
import 'package:flutter/services.dart';
import 'package:spotify_music_player/services/background_audio_handler.dart';
import 'package:spotify_music_player/providers/music_player_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    const MethodChannel pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (MethodCall methodCall) async {
      return '.';
    });
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('User Request Verification: 12-Track Playlists & Official Top Global Cover', () {
    test('Daily Mix 1, 2, 3, 4, Discover Weekly, and Release Radar each contain 12 songs', () {
      final playlists = MusicApiService.getHomePlaylists();
      final dailyMix1 = playlists.firstWhere((p) => p.id == 'pl_daily_mix_1');
      final dailyMix2 = playlists.firstWhere((p) => p.id == 'pl_daily_mix_2');
      final dailyMix3 = playlists.firstWhere((p) => p.id == 'pl_daily_mix_3');
      final dailyMix4 = playlists.firstWhere((p) => p.id == 'pl_daily_mix_4');
      final discoverWeekly = playlists.firstWhere((p) => p.id == 'pl_discover_weekly');
      final releaseRadar = playlists.firstWhere((p) => p.id == 'pl_release_radar');

      expect(dailyMix1.songs.length >= 12, true, reason: 'Daily Mix 1 must contain at least 12 songs');
      expect(dailyMix2.songs.length >= 12, true, reason: 'Daily Mix 2 must contain at least 12 songs');
      expect(dailyMix3.songs.length >= 12, true, reason: 'Daily Mix 3 must contain at least 12 songs');
      expect(dailyMix4.songs.length >= 12, true, reason: 'Daily Mix 4 must contain at least 12 songs');
      expect(discoverWeekly.songs.length >= 12, true, reason: 'Discover Weekly must contain at least 12 songs');
      expect(releaseRadar.songs.length >= 12, true, reason: 'Release Radar must contain at least 12 songs');
    });

    test('Top 50 - Global uses official Spotify Charts artwork and has 12 songs', () {
      final playlists = MusicApiService.getHomePlaylists();
      final topGlobal = playlists.firstWhere((p) => p.id == 'pl_top_50_global');

      expect(topGlobal.coverUrl, contains('charts-images.scdn.co/assets/locale_en/regional/daily/region_global_default.jpg'));
      expect(topGlobal.songs.length >= 12, true);
    });

    test('Category Made For You playlists each contain 12 songs', () {
      final cat = MusicApiService.getBrowseCategories().firstWhere((c) => c.id == 'made_for_you');
      final data = MusicApiService.getCategoryDetails(cat);

      expect(data.heroPlaylist, isNotNull);
      expect(data.heroPlaylist!.songs.length >= 12, true);
      for (final section in data.sections) {
        for (final pl in section.playlists) {
          expect(pl.songs.length >= 12, true, reason: '${pl.title} in Made For You must contain at least 12 songs');
        }
      }
    });

    test('Category K-Pop playlists each contain 12 songs', () {
      final cat = MusicApiService.getBrowseCategories().firstWhere((c) => c.id == 'kpop');
      final data = MusicApiService.getCategoryDetails(cat);

      expect(data.heroPlaylist, isNotNull);
      expect(data.heroPlaylist!.songs.length, 12);
      for (final section in data.sections) {
        for (final pl in section.playlists) {
          expect(pl.songs.length, 12, reason: '${pl.title} in K-Pop must contain 12 songs');
        }
      }
    });

    test('Category Japanese Song (J-Pop) playlists each contain 12 songs', () {
      final cat = MusicApiService.getBrowseCategories().firstWhere((c) => c.id == 'jpop');
      final data = MusicApiService.getCategoryDetails(cat);

      expect(data.heroPlaylist, isNotNull);
      expect(data.heroPlaylist!.songs.length, 12);
      for (final section in data.sections) {
        for (final pl in section.playlists) {
          expect(pl.songs.length, 12, reason: '${pl.title} in J-Pop must contain 12 songs');
        }
      }
    });

    test('Category Indie playlists each contain 12 songs', () {
      final cat = MusicApiService.getBrowseCategories().firstWhere((c) => c.id == 'indie');
      final data = MusicApiService.getCategoryDetails(cat);

      expect(data.heroPlaylist, isNotNull);
      expect(data.heroPlaylist!.songs.length, 12);
      for (final section in data.sections) {
        for (final pl in section.playlists) {
          expect(pl.songs.length, 12, reason: '${pl.title} in Indie must contain 12 songs');
        }
      }
    });

    test('Category Tidur (Sleep & Delta Waves) playlists each contain 12 songs', () {
      final cat = MusicApiService.getBrowseCategories().firstWhere((c) => c.id == 'tidur');
      final data = MusicApiService.getCategoryDetails(cat);

      expect(data.heroPlaylist, isNotNull);
      expect(data.heroPlaylist!.songs.length, 12);
      for (final section in data.sections) {
        for (final pl in section.playlists) {
          expect(pl.songs.length, 12, reason: '${pl.title} in Tidur must contain 12 songs');
        }
      }
    });

    test('Category Musik Indonesia playlists each contain 12 songs', () {
      final cat = MusicApiService.getBrowseCategories().firstWhere((c) => c.id == 'musik_indonesia');
      final data = MusicApiService.getCategoryDetails(cat);

      expect(data.heroPlaylist, isNotNull);
      expect(data.heroPlaylist!.songs.length, 12);
      for (final section in data.sections) {
        for (final pl in section.playlists) {
          expect(pl.songs.length, 12, reason: '${pl.title} in Musik Indonesia must contain 12 songs');
        }
      }
    });

    test('Category Korean Drama OST playlists each contain 12 songs', () {
      final cat = MusicApiService.getBrowseCategories().firstWhere((c) => c.id == 'ost_drakor');
      final data = MusicApiService.getCategoryDetails(cat);

      expect(data.heroPlaylist, isNotNull);
      expect(data.heroPlaylist!.songs.length, 12);
      for (final section in data.sections) {
        for (final pl in section.playlists) {
          expect(pl.songs.length, 12, reason: '${pl.title} in OST Drakor must contain 12 songs');
        }
      }
    });
  });

  group('Song Credits Verification', () {
    test('SongCreditsService produces authentic production credits', () {
      final bernadyaSong = Song(
        id: 'feat_bernadya_satubulan',
        title: 'Satu Bulan',
        artist: 'Bernadya',
        album: 'Sialnya, Hidup Harus Tetap Berjalan',
        albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/f5809041de170abd4c84dcdede0d202a/1000x1000-000000-80-0-0.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=yjnSX_iUFVo',
        duration: const Duration(minutes: 3, seconds: 12),
        lyrics: const [],
      );

      final credits = SongCreditsService.getCreditsForSong(bernadyaSong);
      expect(credits.trackTitle, 'Satu Bulan');
      expect(credits.performers.any((p) => p.name.contains('Bernadya')), isTrue);
      expect(credits.writers.isNotEmpty, isTrue);
      expect(credits.producers.isNotEmpty, isTrue);
      expect(credits.source, contains('JUNI Records'));
      expect(credits.copyright, contains('JUNI Records'));
    });
  });

  group('Background Controls & Lockscreen Like Action Verification', () {
    test('MusixspotAudioHandler initializes with like toggle custom action', () {
      final handler = MusixspotAudioHandler.instance;
      expect(handler, isNotNull);

      handler.updatePlaybackState(
        isPlaying: true,
        position: const Duration(seconds: 45),
        duration: const Duration(minutes: 3, seconds: 20),
        bufferedPosition: const Duration(minutes: 1),
        hasNext: true,
        hasPrevious: true,
        isLiked: false,
      );

      final state = handler.playbackState.value;
      final customControl = state.controls.firstWhere((c) => c.label == 'Sukai Lagu');
      expect(customControl.label, 'Sukai Lagu');
      expect(customControl.androidIcon, 'drawable/ic_stat_add');
    });

    test('MusixspotAudioHandler reflects liked state with favorite icon', () {
      final handler = MusixspotAudioHandler.instance;
      handler.updatePlaybackState(
        isPlaying: true,
        position: const Duration(seconds: 45),
        duration: const Duration(minutes: 3, seconds: 20),
        bufferedPosition: const Duration(minutes: 1),
        hasNext: true,
        hasPrevious: true,
        isLiked: true,
      );

      final state = handler.playbackState.value;
      final customControl = state.controls.firstWhere((c) => c.label == 'Hapus Suka');
      expect(customControl.label, 'Hapus Suka');
      expect(customControl.androidIcon, 'drawable/ic_stat_favorite');
    });
  });

  group('Library CRUD & Liked Songs Guard Verification', () {
    test('Add playlist creates custom user playlist in provider', () async {
      final provider = MusicPlayerProvider();
      final initialCount = provider.playlists.length;

      await provider.createPlaylist('Playlist Lari Pagi', subtitle: 'Pemicu semangat pagi');

      expect(provider.playlists.length, initialCount + 1);
      expect(provider.playlists.first.title, 'Playlist Lari Pagi');
      expect(provider.playlists.first.id.startsWith('custom_'), isTrue);
    });

    test('Edit playlist updates title and subtitle', () async {
      final provider = MusicPlayerProvider();
      await provider.createPlaylist('Playlist Awal', subtitle: 'Deskripsi Awal');
      final newPl = provider.playlists.first;

      await provider.editPlaylist(
        newPl.id,
        newTitle: 'Playlist Baru',
        newSubtitle: 'Deskripsi Baru',
      );

      final updated = provider.playlists.firstWhere((p) => p.id == newPl.id);
      expect(updated.title, 'Playlist Baru');
      expect(updated.subtitle, 'Deskripsi Baru');
    });

    test('Delete playlist removes playlist from provider', () async {
      final provider = MusicPlayerProvider();
      await provider.createPlaylist('Playlist Sementara', subtitle: 'Akan dihapus');
      final newPl = provider.playlists.first;

      expect(provider.playlists.any((p) => p.id == newPl.id), isTrue);

      await provider.deletePlaylist(newPl.id);
      expect(provider.playlists.any((p) => p.id == newPl.id), isFalse);
    });

    test('Lagu yang Disukai is permanently guarded against edit and delete', () async {
      final provider = MusicPlayerProvider();
      final initialCount = provider.playlists.length;

      // Guarded against edit
      await provider.editPlaylist(
        'liked_songs',
        newTitle: 'Nama Ganti',
        newSubtitle: 'Ganti',
      );
      expect(provider.playlists.any((p) => p.title == 'Nama Ganti'), isFalse);

      await provider.editPlaylist(
        'liked_songs_virtual',
        newTitle: 'Nama Ganti Virtual',
        newSubtitle: 'Ganti',
      );
      expect(provider.playlists.any((p) => p.title == 'Nama Ganti Virtual'), isFalse);

      // Guarded against delete
      await provider.deletePlaylist('liked_songs');
      expect(provider.playlists.length, initialCount);

      await provider.deletePlaylist('liked_songs_virtual');
      expect(provider.playlists.length, initialCount);
    });
  });
}
