import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import '../models/song.dart';

class MusixspotAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  static MusixspotAudioHandler? _instance;
  static MusixspotAudioHandler get instance => _instance ??= MusixspotAudioHandler._();

  MusixspotAudioHandler._() {
    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.custom(
          androidIcon: 'drawable/ic_stat_add',
          label: 'Sukai Lagu',
          name: 'toggle_like',
        ),
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.setRating,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: AudioProcessingState.idle,
      playing: false,
    ));
  }

  factory MusixspotAudioHandler() => instance;

  VoidCallback? onPlay;
  VoidCallback? onPause;
  VoidCallback? onSkipToNext;
  VoidCallback? onSkipToPrevious;
  void Function(Duration)? onSeek;
  void Function(Song)? onToggleLike;

  Song? currentSong;
  bool isCurrentLiked = false;

  void updatePlaybackState({
    required bool isPlaying,
    required Duration position,
    required Duration duration,
    required Duration bufferedPosition,
    required bool hasNext,
    required bool hasPrevious,
    required bool isLiked,
  }) {
    isCurrentLiked = isLiked;
    final controls = [
      if (hasPrevious) MediaControl.skipToPrevious,
      if (isPlaying) MediaControl.pause else MediaControl.play,
      if (hasNext) MediaControl.skipToNext,
      MediaControl.custom(
        androidIcon: isLiked ? 'drawable/ic_stat_favorite' : 'drawable/ic_stat_add',
        label: isLiked ? 'Hapus Suka' : 'Sukai Lagu',
        name: 'toggle_like',
      ),
    ];

    final compactIndices = <int>[];
    for (int i = 0; i < controls.length; i++) {
      if (controls[i].action == MediaAction.skipToPrevious ||
          controls[i].action == MediaAction.play ||
          controls[i].action == MediaAction.pause ||
          controls[i].action == MediaAction.skipToNext) {
        compactIndices.add(i);
      }
    }

    playbackState.add(playbackState.value.copyWith(
      controls: controls,
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.setRating,
      },
      androidCompactActionIndices: compactIndices.take(3).toList(),
      processingState: AudioProcessingState.ready,
      playing: isPlaying,
      updatePosition: position,
      bufferedPosition: bufferedPosition,
      speed: 1.0,
    ));
  }

  void updateSongItem(Song song, {bool isLiked = false}) {
    currentSong = song;
    isCurrentLiked = isLiked;
    final validArtUri = (song.albumArtUrl.startsWith('http://') ||
            song.albumArtUrl.startsWith('https://'))
        ? Uri.tryParse(song.albumArtUrl)
        : null;

    mediaItem.add(MediaItem(
      id: song.id,
      album: song.album,
      title: song.title,
      artist: song.artist,
      artUri: validArtUri,
      duration: song.duration,
      rating: Rating.newHeartRating(isLiked),
    ));
  }

  @override
  Future<void> play() async {
    onPlay?.call();
  }

  @override
  Future<void> pause() async {
    onPause?.call();
  }

  @override
  Future<void> skipToNext() async {
    onSkipToNext?.call();
  }

  @override
  Future<void> skipToPrevious() async {
    onSkipToPrevious?.call();
  }

  @override
  Future<void> seek(Duration position) async {
    onSeek?.call(position);
  }

  @override
  Future<dynamic> customAction(String name, [Map<String, dynamic>? extras]) async {
    if (name == 'toggle_like' && currentSong != null) {
      onToggleLike?.call(currentSong!);
    }
    return null;
  }

  @override
  Future<void> setRating(Rating rating, [Map<String, dynamic>? extras]) async {
    if (currentSong != null) {
      onToggleLike?.call(currentSong!);
    }
  }
}
