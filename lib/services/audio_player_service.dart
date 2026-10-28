import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
// ignore: depend_on_referenced_packages
import 'package:audio_session/audio_session.dart';
import '../models/song.dart';
import 'song_stream_resolver.dart';

enum SpotifyRepeatMode { off, all, one }

class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();

  AudioPlayerService() {
    _initAudioSession();
    _player.playbackEventStream.listen(
      (_) {},
      onError: (Object e, StackTrace st) {
        debugPrint('PLAYER ERROR: $e');
      },
    );
  }

  Future<void> _initAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      await session.setActive(true);
      session.interruptionEventStream.listen((event) {
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.duck:
              _player.setVolume(0.5);
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              _player.pause();
              break;
          }
        } else {
          switch (event.type) {
            case AudioInterruptionType.duck:
              _player.setVolume(1.0);
              break;
            case AudioInterruptionType.pause:
              _player.play();
              break;
            case AudioInterruptionType.unknown:
              break;
          }
        }
      });
      session.becomingNoisyEventStream.listen((_) {
        _player.pause();
      });
    } catch (e) {
      debugPrint('AudioSession init error: $e');
    }
  }

  AudioPlayer get player => _player;

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<Duration> get bufferedPositionStream => _player.bufferedPositionStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  bool get isLoaded =>
      _player.audioSource != null &&
      _player.processingState != ProcessingState.idle &&
      _player.processingState != ProcessingState.completed;

  SpotifyRepeatMode _repeatMode = SpotifyRepeatMode.off;
  SpotifyRepeatMode get repeatMode => _repeatMode;

  bool _isShuffle = false;
  bool get isShuffle => _isShuffle;

  MediaItem _buildMediaItem(Song song) {
    final validArtUri = (song.albumArtUrl.startsWith('http://') ||
            song.albumArtUrl.startsWith('https://'))
        ? Uri.tryParse(song.albumArtUrl)
        : null;

    return MediaItem(
      id: song.id,
      album: song.album,
      title: song.title,
      artist: song.artist,
      artUri: validArtUri,
      duration: song.duration,
    );
  }

  int _playSequence = 0;
  Song? _currentLoadedSong;

  Future<void> playSong(Song song, {Duration? initialPosition}) async {
    final currentSeq = ++_playSequence;
    try {
      // Instant seek fast-path: if the requested song is already active in player, seek immediately with NO DELAY
      if (_currentLoadedSong?.id == song.id && _player.audioSource != null) {
        if (initialPosition != null && initialPosition > Duration.zero) {
          await _player.seek(initialPosition);
        }
        if (!_player.playing) {
          await _player.play();
        }
        return;
      }

      // Cleanly stop any existing playback to abort its buffer/generator
      await _player.stop();

      final mediaItem = _buildMediaItem(song);

      // Path 1: Local downloaded file (100% offline, zero network)
      if (song.isDownloaded && song.localFilePath != null) {
        final localFile = File(song.localFilePath!);
        if (localFile.existsSync()) {
          debugPrint('AudioPlayerService: [LocalFile] Playing "${song.title}"');
          final audioSource = AudioSource.uri(Uri.file(song.localFilePath!), tag: mediaItem);
          if (currentSeq != _playSequence) return;
          await _player.setAudioSource(audioSource, initialPosition: initialPosition);
          _currentLoadedSong = song;
          await _player.play();
          return;
        }
      }

      // Path 2: Bundled local asset (100% offline, zero network)
      if (song.audioUrl.startsWith('asset://') || song.audioUrl.startsWith('assets/')) {
        final assetPath = song.audioUrl.replaceFirst('asset://', '');
        debugPrint('AudioPlayerService: [Asset] Playing "${song.title}" from $assetPath');
        final audioSource = AudioSource.asset(assetPath, tag: mediaItem);
        if (currentSeq != _playSequence) return;
        await _player.setAudioSource(audioSource, initialPosition: initialPosition);
        _currentLoadedSong = song;
        await _player.play();
        return;
      }

      // Path 3: Direct CDN stream URL (Only for full direct streams, NOT 30s samples/previews!)
      final isPreviewOrSearchSong = song.id.startsWith('dz_') ||
          song.id.startsWith('itunes_') ||
          song.audioUrl.contains('preview') ||
          song.audioUrl.contains('dzcdn.net') ||
          song.audioUrl.contains('apple.com') ||
          song.audioUrl.startsWith('youtube:');

      final isDirectCdn = !isPreviewOrSearchSong &&
          song.audioUrl.startsWith('http') &&
          !song.audioUrl.contains('youtube.com') &&
          !song.audioUrl.contains('youtu.be');

      if (isDirectCdn) {
        debugPrint('AudioPlayerService: [DirectCDN] Playing "${song.title}"');
        final audioSource = AudioSource.uri(Uri.parse(song.audioUrl), tag: mediaItem);
        if (currentSeq != _playSequence) return;
        await _player.setAudioSource(audioSource, initialPosition: initialPosition);
        _currentLoadedSong = song;
        await _player.play();
        return;
      }

      // Path 4: Remote full stream resolution (Multi-candidate real YouTube audio streaming)
      List<String> streamCandidates = [];
      if (song.audioUrl.startsWith('youtube:')) {
        final searchQuery = song.audioUrl.substring('youtube:'.length);
        final tempSong = Song(
          id: song.id,
          title: song.title,
          artist: song.artist,
          album: song.album,
          albumArtUrl: song.albumArtUrl,
          audioUrl: 'https://www.youtube.com/results?search_query=${Uri.encodeComponent(searchQuery)}',
          duration: song.duration,
        );
        streamCandidates = await SongStreamResolver.resolveAudioStreamCandidates(tempSong);
      } else {
        streamCandidates = await SongStreamResolver.resolveAudioStreamCandidates(song);
      }

      // Abort if superseded by another song transition
      if (currentSeq != _playSequence) {
        debugPrint('AudioPlayerService: [Superseded] Discarding resolution for "${song.title}"');
        return;
      }

      if (streamCandidates.isEmpty) {
        throw Exception('Tidak ada stream audio yang tersedia untuk "${song.title}".');
      }

      // Try playing each candidate in order until genuine audio plays
      Exception? lastException;
      for (int i = 0; i < streamCandidates.length; i++) {
        if (currentSeq != _playSequence) return;
        final streamUrl = streamCandidates[i];
        try {
          final isGoogleVideo = streamUrl.contains('googlevideo.com');
          final AudioSource audioSource = AudioSource.uri(
            Uri.parse(streamUrl),
            headers: isGoogleVideo
                ? {
                    'User-Agent':
                        'com.google.android.youtube/19.29.37 (Linux; U; Android 14)',
                  }
                : null,
            tag: mediaItem,
          );

          if (currentSeq != _playSequence) return;
          await _player.setAudioSource(audioSource, initialPosition: initialPosition);
          _currentLoadedSong = song;
          await _player.play();
          debugPrint('AudioPlayerService: ✓ Successfully playing real audio for "${song.title}" (candidate ${i + 1}/${streamCandidates.length})');
          return;
        } catch (e) {
          debugPrint('AudioPlayerService: [CandidateFailed] candidate ${i + 1}/${streamCandidates.length} for "${song.title}": $e');
          SongStreamResolver.invalidateCache(song.id);
          lastException = e is Exception ? e : Exception(e.toString());
        }
      }

      if (lastException != null) {
        throw lastException;
      }
    } catch (e) {
      if (currentSeq == _playSequence) {
        debugPrint('AudioPlayerService: [PlaybackError] trackId=${song.id}: $e');
        rethrow;
      }
    }
  }

  double get volume => _player.volume;
  Future<void> setVolume(double val) async {
    await _player.setVolume(val.clamp(0.0, 1.0));
  }

  Future<void> playUrl(String url, {MediaItem? tag}) async {
    try {
      final mediaItem = tag ??
          MediaItem(
            id: url,
            title: 'Audio Stream',
            artist: 'MusicXSpot',
          );
      final source = AudioSource.uri(
        Uri.parse(url),
        tag: mediaItem,
      );
      await _player.setAudioSource(source);
      await _player.play();
    } catch (e) {
      debugPrint('Error playing audio url: $e');
    }
  }

  Future<void> resume() async {
    if (isLoaded) {
      await _player.play();
    }
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  void toggleRepeat() {
    if (_repeatMode == SpotifyRepeatMode.off) {
      _repeatMode = SpotifyRepeatMode.all;
      _player.setLoopMode(LoopMode.all);
    } else if (_repeatMode == SpotifyRepeatMode.all) {
      _repeatMode = SpotifyRepeatMode.one;
      _player.setLoopMode(LoopMode.one);
    } else {
      _repeatMode = SpotifyRepeatMode.off;
      _player.setLoopMode(LoopMode.off);
    }
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    _player.setShuffleModeEnabled(_isShuffle);
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}
