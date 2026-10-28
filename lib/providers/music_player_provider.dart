import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../models/song.dart';
import '../models/playlist.dart';
import '../services/audio_player_service.dart';
import '../services/music_api_service.dart';
import '../services/song_stream_resolver.dart';
import '../services/metadata_enricher_service.dart';
import '../services/deezer_api_service.dart';
import '../services/bluetooth_audio_service.dart';
import '../services/user_behavior_service.dart';
import '../services/background_audio_handler.dart';
import '../services/spotify_platinum_service.dart';
import '../services/dynamic_catalog_service.dart';
import '../models/spotify_platinum_profile.dart';
import '../theme/spotify_theme.dart';

class MusicPlayerProvider extends ChangeNotifier {
  final AudioPlayerService _audioService = AudioPlayerService();
  final DynamicCatalogService _dynamicCatalog = DynamicCatalogService();

  AppThemeMode _themeMode = AppThemeMode.spotifyDark;
  AppThemeMode get themeMode => _themeMode;
  AppThemeColors get themeColors => SpotifyTheme.current;

  Song? _currentSong;
  List<Song> _queue = [];
  List<Song> _originalQueue = [];
  int _currentIndex = 0;
  String _contextTitle = 'Playlist';

  bool _isPlaying = false;
  bool _isBuffering = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration _bufferedPosition = Duration.zero;

  final List<Song> _likedSongs = [];
  final List<Song> _recentlyPlayed = [];
  List<Playlist> _playlists = [];
  final Set<String> _downloadingSongIds = {};
  final Set<String> _downloadingPlaylistIds = {};
  final Set<String> _deletedPlaylistIds = {};
  final Map<String, double> _playlistDownloadProgress = {};

  // Dynamic dominant color from current track cover art
  Color _dominantColor = const Color(0xFF2C3E50);

  // Canvas Mode toggle
  bool _isCanvasMode = false;
  String _connectedDevice = 'Ponsel Ini';

  // Sleep Timer
  Timer? _sleepTimer;
  DateTime? _sleepTimerEndTime;
  bool _sleepAtSongEnd = false;
  int _prematureRetryCount = 0;

  // Stream subscriptions
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _bufSub;
  StreamSubscription? _stateSub;
  StreamSubscription? _btSub;

  // Filter chips in Home
  String _activeFilter = 'Semua';

  MusicPlayerProvider() {
    _init();
  }

  // Getters
  Song? get currentSong => _currentSong;
  List<Song> get queue => _queue;
  int get currentIndex => _currentIndex;
  String get contextTitle => _contextTitle;
  bool get isPlaying => _isPlaying;
  bool get isBuffering => _isBuffering;
  Duration get position => _position;
  Duration get duration => _duration;
  Duration get bufferedPosition => _bufferedPosition;
  List<Song> get likedSongs => _likedSongs;
  List<Song> get recentlyPlayed => _recentlyPlayed;
  List<Playlist> get playlists => _playlists;
  String get activeFilter => _activeFilter;
  SpotifyRepeatMode get repeatMode => _audioService.repeatMode;
  bool get isShuffle => _audioService.isShuffle;
  Color get dominantColor => _dominantColor;
  bool get isCanvasMode => _isCanvasMode;
  String get connectedDevice => _connectedDevice;

  // Bluetooth Audio Getters & Methods
  BluetoothAudioDevice? get bluetoothDevice => BluetoothAudioService.currentDevice;
  bool get isBluetoothConnected => BluetoothAudioService.currentDevice?.isConnected == true;
  List<BluetoothAudioDevice> get pairedBluetoothDevices => BluetoothAudioService.pairedDevices;
  List<BluetoothAudioDevice> get scannedBluetoothDevices => BluetoothAudioService.scannedDevices;
  bool get isBluetoothScanning => BluetoothAudioService.isScanning;

  Future<bool> connectBluetooth(BluetoothAudioDevice device) async {
    final success = await BluetoothAudioService.connect(device);
    if (success) {
      _connectedDevice = device.name;
    }
    notifyListeners();
    return success;
  }

  Future<void> disconnectBluetooth() async {
    await BluetoothAudioService.disconnect();
    _connectedDevice = 'Ponsel Ini';
    notifyListeners();
  }

  Future<List<BluetoothAudioDevice>> scanBluetooth() async {
    notifyListeners();
    final results = await BluetoothAudioService.scanForDevices();
    notifyListeners();
    return results;
  }

  // Personalized Dynamic Recommendations (User Behavior Learning Engine)
  List<Playlist> get personalizedPlaylists {
    final catalog = <Song>[
      ..._playlists.expand((p) => p.songs),
      ..._queue,
      ...MusicApiService.getFeaturedTracks(),
      ...MusicApiService.getNostalgiaTracks(),
    ];
    // Deduplicate catalog
    final seen = <String>{};
    final uniqueCatalog = <Song>[];
    for (final s in catalog) {
      if (!seen.contains(s.id)) {
        seen.add(s.id);
        uniqueCatalog.add(s);
      }
    }
    return UserBehaviorService.generatePersonalizedPlaylists(
      catalog: uniqueCatalog,
      likedSongs: _likedSongs,
      recentlyPlayed: _recentlyPlayed,
    );
  }

  // Nostalgia & Popular Releases
  List<Playlist> get nostalgiaPlaylists => MusicApiService.getNostalgiaPlaylists();
  List<Song> get nostalgiaTracks => MusicApiService.getNostalgiaTracks();
  List<Playlist> get popularReleases =>
      _dynamicCatalog.popularReleases.isNotEmpty
          ? _dynamicCatalog.popularReleases
          : MusicApiService.getPopularReleases();
  List<Playlist> get kdramaPlaylists =>
      _dynamicCatalog.kdramaPlaylists.isNotEmpty
          ? _dynamicCatalog.kdramaPlaylists
          : MusicApiService.getKoreanDramaPlaylists();
  List<Playlist> get animePlaylists =>
      _dynamicCatalog.animePlaylists.isNotEmpty
          ? _dynamicCatalog.animePlaylists
          : MusicApiService.getJPopPlaylists();
  List<Playlist> get dynamicIndonesianPlaylists =>
      _dynamicCatalog.indonesianPlaylists.isNotEmpty
          ? _dynamicCatalog.indonesianPlaylists
          : MusicApiService.getMusikIndonesiaPlaylists();
  List<Playlist> get dynamicGlobalPopPlaylists =>
      _dynamicCatalog.globalPopPlaylists;

  DynamicCatalogService get dynamicCatalog => _dynamicCatalog;

  Future<void> refreshDynamicCatalog() async {
    await _dynamicCatalog.refreshCatalog(force: true);
    notifyListeners();
  }

  // Playback Error handling
  String? _playbackErrorMessage;
  String? get playbackErrorMessage => _playbackErrorMessage;
  void clearPlaybackErrorMessage() {
    _playbackErrorMessage = null;
    notifyListeners();
  }

  void setConnectedDevice(String device) {
    _connectedDevice = device;
    notifyListeners();
  }


  // Sleep Timer Getters
  bool get isSleepTimerActive => _sleepTimer != null || _sleepAtSongEnd;
  bool get sleepAtSongEnd => _sleepAtSongEnd;
  int get sleepTimerMinutesRemaining {
    if (_sleepTimerEndTime == null) return 0;
    final diff = _sleepTimerEndTime!.difference(DateTime.now()).inMinutes;
    return diff > 0 ? diff + 1 : 0;
  }

  bool isSongDownloading(String id) => _downloadingSongIds.contains(id);
  bool isPlaylistDownloading(String playlistId) => _downloadingPlaylistIds.contains(playlistId);
  double getPlaylistDownloadProgress(String playlistId) => _playlistDownloadProgress[playlistId] ?? 0.0;

  bool isPlaylistDownloaded(Playlist playlist) {
    if (playlist.songs.isEmpty) return false;
    return playlist.songs.every((s) => s.isDownloaded);
  }

  int getPlaylistDownloadedCount(Playlist playlist) {
    return playlist.songs.where((s) => s.isDownloaded).length;
  }

  bool isSongLiked(String id) => _likedSongs.any((s) => s.id == id);

  List<Song> get downloadedSongs {
    final Map<String, Song> map = {};
    for (final s in _queue) {
      if (s.isDownloaded) map[s.id] = s;
    }
    for (final s in _likedSongs) {
      if (s.isDownloaded) map[s.id] = s;
    }
    for (final p in _playlists) {
      for (final s in p.songs) {
        if (s.isDownloaded) map[s.id] = s;
      }
    }
    return map.values.toList();
  }

  void setActiveFilter(String filter) {
    _activeFilter = filter;
    notifyListeners();
  }

  void toggleCanvasMode() {
    _isCanvasMode = !_isCanvasMode;
    notifyListeners();
  }

  void updateFavoriteArtists(List<dynamic> artists) {
    UserBehaviorService.seedFavoriteArtists(artists);
    notifyListeners();
  }

  Future<void> _init() async {
    // 1. Initial curated catalog
    final initialTracks = MusicApiService.getFeaturedTracks();
    _playlists = MusicApiService.getHomePlaylists();
    _queue = List.from(initialTracks);
    if (_queue.isNotEmpty) {
      _currentSong = _queue.first;
      _updateDominantColor(_currentSong!.albumArtUrl);
    }

    _recentlyPlayed.addAll(initialTracks.take(4));

    // 2. Load persistent data from SharedPreferences
    await _loadPersistentData();

    // 3. Initialize Bluetooth audio service & User Behavior Engine
    await BluetoothAudioService.init();
    await UserBehaviorService.init();
    await SpotifyPlatinumService.init();
    await _dynamicCatalog.init();

    _btSub = BluetoothAudioService.deviceStream.listen((dev) {
      _connectedDevice = dev != null ? dev.name : 'Ponsel Ini';
      notifyListeners();
    });

    // 4. Setup background audio notification controls & handlers
    final bgHandler = MusixspotAudioHandler.instance;
    bgHandler.onPlay = () => togglePlayPause();
    bgHandler.onPause = () => togglePlayPause();
    bgHandler.onSkipToNext = () => skipToNext();
    bgHandler.onSkipToPrevious = () => skipToPrevious();
    bgHandler.onSeek = (pos) => seek(pos);
    bgHandler.onToggleLike = (song) => toggleLike(song);

    // 5. Setup audio player listeners
    int lastSavedSec = -1;
    _posSub = _audioService.positionStream.listen((pos) {
      _position = pos;
      _syncBackgroundControls();
      notifyListeners();

      if (_currentSong != null && _isPlaying && pos.inSeconds != lastSavedSec && pos.inSeconds % 4 == 0) {
        lastSavedSec = pos.inSeconds;
        _savePlaybackPosition(pos);
      }
    });

    _durSub = _audioService.durationStream.listen((dur) {
      if (dur != null) {
        _duration = dur;
        _syncBackgroundControls();
        notifyListeners();
      }
    });

    _bufSub = _audioService.bufferedPositionStream.listen((buf) {
      _bufferedPosition = buf;
      _syncBackgroundControls();
      notifyListeners();
    });

    _stateSub = _audioService.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      _isBuffering = state.processingState == ProcessingState.buffering ||
          state.processingState == ProcessingState.loading;
      _syncBackgroundControls();

      if (state.processingState == ProcessingState.completed) {
        if (_sleepAtSongEnd) {
          cancelSleepTimer();
          _audioService.pause();
          notifyListeners();
          return;
        }

        // PREMATURE STREAM DROP GUARD:
        // If track completed when playback position was significantly less than duration
        // (position < 85% of duration, and track duration > 30s), ExoPlayer hit an EOF due to network drop.
        // Reconnect and resume seamlessly at current position without skipping (max 2 retries to prevent infinite loop)!
        final isPremature = _duration.inSeconds > 30 &&
            _position.inSeconds < (_duration.inSeconds * 0.85);

        if (isPremature && _currentSong != null && _prematureRetryCount < 2) {
          _prematureRetryCount++;
          debugPrint('MusicPlayerProvider: Premature completion detected ($_prematureRetryCount/2) at ${_position.inSeconds}s/${_duration.inSeconds}s, reconnecting...');
          SongStreamResolver.invalidateCache(_currentSong!.id);
          _audioService.seek(_position);
          _audioService.resume();
          notifyListeners();
          return;
        }

        _prematureRetryCount = 0;

        // Genuine track completion -> Record completion for user behavior learning
        if (!isPremature && _currentSong != null) {
          UserBehaviorService.recordCompletion(_currentSong!);
        }

        if (_audioService.repeatMode == SpotifyRepeatMode.one) {
          if (_currentSong != null) {
            playSong(_currentSong!, contextTitle: _contextTitle);
          }
        } else if (_audioService.repeatMode == SpotifyRepeatMode.off &&
            _currentIndex >= _queue.length - 1) {
          _audioService.pause();
          _isPlaying = false;
        } else {
          skipToNext();
        }
      }
      notifyListeners();
    });

    // 5. Fetch dynamic live charts in background
    _loadOnlineCharts();
  }

  Future<void> _loadOnlineCharts() async {
    try {
      if (_deletedPlaylistIds.contains('pl_live_global_chart') ||
          _playlists.any((p) => p.id == 'pl_live_global_chart')) {
        return;
      }
      final chartTracks = await DeezerApiService.getChartTracks(limit: 50);
      final List<Song> fullTracks = List.from(chartTracks);
      // Ensure exactly 50 songs matching the "Top 50" title
      if (fullTracks.length < 50) {
        final baseline = MusicApiService.getTop50GlobalTracks();
        final seen = fullTracks.map((s) => s.id).toSet();
        for (final b in baseline) {
          if (!seen.contains(b.id)) {
            fullTracks.add(b);
            seen.add(b.id);
            if (fullTracks.length >= 50) break;
          }
        }
      }

      if (fullTracks.isNotEmpty) {
        if (_deletedPlaylistIds.contains('pl_live_global_chart') ||
            _playlists.any((p) => p.id == 'pl_live_global_chart')) {
          return;
        }
        final liveGlobalChart = Playlist(
          id: 'pl_live_global_chart',
          title: 'Top 50 - Global (Live)',
          subtitle: 'Update harian • 50 tangga lagu terpopuler di dunia',
          coverUrl: 'assets/images/top50_global.png',
          songs: fullTracks,
        );
        _playlists.insert(0, liveGlobalChart);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading online charts: $e');
    }
  }

  // --- Synchronize Android Lockscreen & Background Notification Controls ---
  void _syncBackgroundControls() {
    if (_currentSong == null) return;
    MusixspotAudioHandler.instance.updatePlaybackState(
      isPlaying: _isPlaying,
      position: _position,
      duration: _duration,
      bufferedPosition: _bufferedPosition,
      hasNext: _currentIndex < _queue.length - 1 || _audioService.repeatMode != SpotifyRepeatMode.off,
      hasPrevious: _currentIndex > 0 || _audioService.repeatMode != SpotifyRepeatMode.off,
      isLiked: isSongLiked(_currentSong!.id),
    );
  }

  // --- Dynamic Color Extraction ---
  Future<void> _updateDominantColor(String imageUrl) async {
    if (imageUrl.isEmpty || Platform.environment.containsKey('FLUTTER_TEST')) return;
    try {
      final imageProvider = CachedNetworkImageProvider(imageUrl);
      final paletteGenerator = await PaletteGenerator.fromImageProvider(
        imageProvider,
        size: const Size(200, 200),
        maximumColorCount: 16,
        timeout: const Duration(seconds: 4),
      );

      final color = paletteGenerator.vibrantColor?.color ??
          paletteGenerator.dominantColor?.color ??
          paletteGenerator.darkMutedColor?.color ??
          const Color(0xFF2C3E50);

      // Slightly darken if too bright for Spotify aesthetic
      _dominantColor = _adjustColorForSpotify(color);
      notifyListeners();
    } catch (e) {
      debugPrint('Palette extraction error: $e');
    }
  }

  Color _adjustColorForSpotify(Color color) {
    final hsl = HSLColor.fromColor(color);
    // Keep lightness between 0.15 and 0.35 for authentic Spotify gradient look
    final clampedLightness = hsl.lightness.clamp(0.15, 0.35);
    return hsl.withLightness(clampedLightness).toColor();
  }

  // --- Playback Controls ---
  Future<void> playSong(Song song, {List<Song>? queue, String? contextTitle, Duration? initialPosition}) async {
    if (contextTitle != null) {
      _contextTitle = contextTitle;
    }

    if (queue != null && queue.isNotEmpty) {
      _originalQueue = List.from(queue);
      _queue = List.from(queue);
      _currentIndex = _queue.indexWhere((s) => s.id == song.id);
      if (_currentIndex == -1) {
        _queue.insert(0, song);
        _currentIndex = 0;
      }
    } else {
      if (_originalQueue.isEmpty) {
        _originalQueue = List.from(_queue);
      }
      _currentIndex = _queue.indexWhere((s) => s.id == song.id);
      if (_currentIndex == -1) {
        _queue.add(song);
        _currentIndex = _queue.length - 1;
        _originalQueue.add(song);
      }
    }

    // Instant refrain seek fast-path if current song is already loaded
    if (_currentSong?.id == song.id && _audioService.isLoaded) {
      if (initialPosition != null && initialPosition > Duration.zero) {
        _position = initialPosition;
        await _audioService.seek(initialPosition);
        if (!_isPlaying) {
          await _audioService.resume();
          _isPlaying = true;
        }
        notifyListeners();
        return;
      }
    }

    _currentSong = song;
    _prematureRetryCount = 0;

    // Apply Platinum Lossless 24-bit Studio Master attributes ONLY if the audio source is genuinely FLAC
    if (SpotifyPlatinumService.isPlatinum &&
        SpotifyPlatinumService.fidelity == AudioFidelityTier.platinumLossless24Bit) {
      if (song.audioUrl.toLowerCase().endsWith('.flac') || song.isFlac) {
        song.isFlac = true;
        song.audioFormat = 'FLAC';
        song.bitDepth = '24-bit';
        song.sampleRate = '44.1 kHz';
      }
    }

    // Record user behavior telemetry for dynamic recommendations
    UserBehaviorService.recordPlay(song);

    // Track recently played
    if (!_recentlyPlayed.any((s) => s.id == song.id)) {
      _recentlyPlayed.insert(0, song);
      if (_recentlyPlayed.length > 20) {
        _recentlyPlayed.removeLast();
      }
    }

    // Dynamic color update
    _updateDominantColor(song.albumArtUrl);

    // Asynchronously enrich song with official 1:1 clean album art and album name from iTunes
    MetadataEnricherService.enrichSong(song).then((updated) {
      if (updated) {
        _updateDominantColor(song.albumArtUrl);
        MusixspotAudioHandler.instance.updateSongItem(song, isLiked: isSongLiked(song.id));
        notifyListeners();
      }
    });

    MusixspotAudioHandler.instance.updateSongItem(song, isLiked: isSongLiked(song.id));
    _syncBackgroundControls();

    _playbackErrorMessage = null;
    if (initialPosition != null && initialPosition > Duration.zero) {
      _position = initialPosition;
    } else {
      _position = Duration.zero;
    }
    _bufferedPosition = Duration.zero;
    _duration = song.duration;
    _isBuffering = true;
    notifyListeners();

    if (song.audioUrl.isNotEmpty || song.localFilePath != null) {
      try {
        await _audioService.playSong(song, initialPosition: initialPosition);
        _playbackErrorMessage = null;
        _savePlaybackSession();
      } catch (e) {
        _isBuffering = false;
        _isPlaying = false;
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('socketexception') || errStr.contains('failed host lookup')) {
          _playbackErrorMessage = 'Koneksi internet tidak tersedia. Periksa jaringan Anda.';
        } else if (errStr.contains('403') || errStr.contains('forbidden')) {
          _playbackErrorMessage = 'Audio dibatasi oleh penyedia. Silakan coba lagi.';
        } else {
          _playbackErrorMessage = 'Tidak dapat memutar "${song.title}". Silakan coba lagi.';
        }
        notifyListeners();
        debugPrint('MusicPlayerProvider: [PlaybackFailed] trackId=${song.id}: $e');
      }
    }
  }

  double get deviceVolume => _audioService.volume;
  Future<void> setDeviceVolume(double val) async {
    await _audioService.setVolume(val);
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    if (_currentSong == null && _queue.isNotEmpty) {
      await playSong(_queue[0]);
      return;
    }

    if (_currentSong == null) return;

    if (_isPlaying) {
      await _audioService.pause();
      _isPlaying = false;
      _savePlaybackSession();
      notifyListeners();
      return;
    }

    if (_audioService.isLoaded) {
      await _audioService.resume();
      _isPlaying = true;
      _savePlaybackSession();
      notifyListeners();
    } else {
      await playSong(_currentSong!, initialPosition: _position);
    }
  }

  Future<void> skipToNext() async {
    if (_queue.isEmpty) return;

    // Record user skip telemetry if skipped within first 15 seconds
    if (_position.inSeconds < 15 && _currentSong != null) {
      UserBehaviorService.recordSkip(_currentSong!);
    }

    if (_currentIndex >= _queue.length - 1) {
      if (_audioService.repeatMode == SpotifyRepeatMode.off) {
        await _audioService.pause();
        _isPlaying = false;
        _savePlaybackSession();
        notifyListeners();
        return;
      }
      _currentIndex = 0;
    } else {
      _currentIndex = _currentIndex + 1;
    }

    await playSong(_queue[_currentIndex], contextTitle: _contextTitle);
  }

  Future<void> skipToPrevious() async {
    if (_queue.isEmpty) return;

    // If played more than 3 seconds, restart current track
    if (_position.inSeconds > 3) {
      await _audioService.seek(Duration.zero);
      _position = Duration.zero;
      _savePlaybackPosition(Duration.zero);
      notifyListeners();
      return;
    }

    _currentIndex = (_currentIndex - 1 + _queue.length) % _queue.length;
    await playSong(_queue[_currentIndex], contextTitle: _contextTitle);
  }

  Future<void> seek(Duration pos) async {
    await _audioService.seek(pos);
    _position = pos;
    _savePlaybackPosition(pos);
    notifyListeners();
  }

  void toggleRepeat() {
    _audioService.toggleRepeat();
    notifyListeners();
  }

  void toggleShuffle({bool forceReshuffle = false}) {
    if (forceReshuffle && _audioService.isShuffle) {
      if (_queue.length > 1 && _currentSong != null) {
        final current = _currentSong!;
        final source = _originalQueue.isNotEmpty ? _originalQueue : _queue;
        final remaining = source.where((s) => s.id != current.id).toList();
        remaining.shuffle(Random());
        _queue = [current, ...remaining];
        _currentIndex = 0;
      }
    } else {
      _audioService.toggleShuffle();
      if (_audioService.isShuffle) {
        if (_queue.length > 1 && _currentSong != null) {
          final current = _currentSong!;
          final source = _originalQueue.isNotEmpty ? _originalQueue : _queue;
          final remaining = source.where((s) => s.id != current.id).toList();
          remaining.shuffle(Random());
          _queue = [current, ...remaining];
          _currentIndex = 0;
        }
      } else {
        // Shuffle turned OFF: restore original queue order!
        if (_originalQueue.isNotEmpty) {
          _queue = List.from(_originalQueue);
          if (_currentSong != null) {
            final foundIdx = _queue.indexWhere((s) => s.id == _currentSong!.id);
            _currentIndex = foundIdx != -1 ? foundIdx : 0;
          }
        }
      }
    }
    notifyListeners();
  }

  void reshuffleQueue() {
    toggleShuffle(forceReshuffle: true);
  }

  void setThemeMode(AppThemeMode mode) async {
    _themeMode = mode;
    SpotifyTheme.current = AppThemeColors.fromMode(mode);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_theme_mode', SpotifyTheme.current.id);
    } catch (_) {}
  }

  void toggleLike(Song song) {
    song.isLiked = !song.isLiked;
    // Record user like telemetry for taste learning
    UserBehaviorService.recordLike(song, song.isLiked);

    if (song.isLiked) {
      if (!_likedSongs.any((s) => s.id == song.id)) {
        _likedSongs.insert(0, song);
      }
    } else {
      _likedSongs.removeWhere((s) => s.id == song.id);
    }
    if (_currentSong != null && _currentSong!.id == song.id) {
      MusixspotAudioHandler.instance.updateSongItem(_currentSong!, isLiked: song.isLiked);
      _syncBackgroundControls();
    }
    _savePersistentData();
    notifyListeners();
  }

  // --- Offline Download / Cache (Spotify Style Single & Batch) ---
  Future<void> downloadSong(Song song) async {
    if (song.isDownloaded || _downloadingSongIds.contains(song.id)) return;

    _downloadingSongIds.add(song.id);
    notifyListeners();

    try {
      final dir = await getApplicationDocumentsDirectory();
      final trackDir = Directory('${dir.path}/offline_tracks');
      if (!await trackDir.exists()) {
        await trackDir.create(recursive: true);
      }
      const ext = 'm4a';
      final filePath = '${trackDir.path}/${song.id}.$ext';

      final localFile = File(filePath);
      if (await localFile.exists()) {
        song.isDownloaded = true;
        song.localFilePath = filePath;
        await _savePersistentData();
        return;
      }

      // Resolve stream URL if empty or dynamic, or if it is preview/deezer/itunes/youtube
      String urlToDownload = song.audioUrl;
      final isPreviewOrSearchSong = song.id.startsWith('dz_') ||
          song.id.startsWith('itunes_') ||
          urlToDownload.contains('preview') ||
          urlToDownload.contains('dzcdn.net') ||
          urlToDownload.contains('apple.com') ||
          urlToDownload.startsWith('youtube:');

      if (urlToDownload.isEmpty || !urlToDownload.startsWith('http') || isPreviewOrSearchSong) {
        urlToDownload = await SongStreamResolver.resolveAudioStream(song);
      }

      if (urlToDownload.isNotEmpty && urlToDownload.startsWith('http')) {
        final uri = Uri.parse(urlToDownload);
        final client = http.Client();
        try {
          final request = http.Request('GET', uri);
          request.headers['User-Agent'] =
              'com.google.android.youtube/19.29.37 (Linux; U; Android 14)';
          final response = await client.send(request).timeout(const Duration(seconds: 45));
          if (response.statusCode == 200 || response.statusCode == 206) {
            final sink = localFile.openWrite();
            await response.stream.pipe(sink);
            await sink.flush();
            await sink.close();

            if (await localFile.length() > 20000) {
              song.isDownloaded = true;
              song.localFilePath = filePath;
              await _savePersistentData();
            } else {
              try {
                await localFile.delete();
              } catch (_) {}
            }
          }
        } finally {
          client.close();
        }
      }
    } catch (e) {
      debugPrint('Download song error: $e');
    } finally {
      _downloadingSongIds.remove(song.id);
      notifyListeners();
    }
  }

  Future<void> removeDownloadedSong(Song song) async {
    try {
      if (song.localFilePath != null) {
        final file = File(song.localFilePath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
      song.isDownloaded = false;
      song.localFilePath = null;
      await _savePersistentData();
      notifyListeners();
    } catch (e) {
      debugPrint('Remove downloaded song error: $e');
    }
  }

  /// Batch download entire playlist or album
  Future<void> downloadPlaylist(Playlist playlist) async {
    if (playlist.songs.isEmpty || _downloadingPlaylistIds.contains(playlist.id)) return;

    _downloadingPlaylistIds.add(playlist.id);
    _playlistDownloadProgress[playlist.id] = 0.0;
    notifyListeners();

    try {
      final total = playlist.songs.length;
      int completed = 0;
      for (final song in playlist.songs) {
        if (!song.isDownloaded) {
          await downloadSong(song);
        }
        completed++;
        _playlistDownloadProgress[playlist.id] = completed / total;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Batch download playlist error: $e');
    } finally {
      _downloadingPlaylistIds.remove(playlist.id);
      _playlistDownloadProgress.remove(playlist.id);
      notifyListeners();
    }
  }

  /// Batch remove downloads for entire playlist
  Future<void> removeDownloadedPlaylist(Playlist playlist) async {
    for (final song in playlist.songs) {
      if (song.isDownloaded) {
        await removeDownloadedSong(song);
      }
    }
    notifyListeners();
  }

  /// Get total file size of all downloaded songs in bytes
  Future<int> getDownloadedTotalBytes() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final trackDir = Directory('${dir.path}/offline_tracks');
      if (!await trackDir.exists()) return 0;
      int total = 0;
      await for (final file in trackDir.list()) {
        if (file is File) {
          total += await file.length();
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  /// Remove all downloaded tracks from disk and clear downloaded status
  Future<void> clearAllDownloadedSongs() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final trackDir = Directory('${dir.path}/offline_tracks');
      if (await trackDir.exists()) {
        await trackDir.delete(recursive: true);
      }
      for (final s in _queue) {
        s.isDownloaded = false;
        s.localFilePath = null;
      }
      for (final s in _likedSongs) {
        s.isDownloaded = false;
        s.localFilePath = null;
      }
      for (final p in _playlists) {
        for (final s in p.songs) {
          s.isDownloaded = false;
          s.localFilePath = null;
        }
      }
      await _savePersistentData();
      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing all downloads: $e');
    }
  }

  /// Add imported playlist from CSV, JSON, or Spotify URL
  Future<void> addImportedPlaylist(Playlist playlist) async {
    Playlist normalized = playlist;
    if (!playlist.id.startsWith('custom_')) {
      normalized = Playlist(
        id: 'custom_${playlist.id}',
        title: playlist.title,
        subtitle: playlist.subtitle,
        coverUrl: playlist.coverUrl,
        songs: playlist.songs,
        isPinned: playlist.isPinned,
        isDailyMix: playlist.isDailyMix,
        dailyMixNumber: playlist.dailyMixNumber,
        isReleaseRadar: playlist.isReleaseRadar,
        isDiscoverWeekly: playlist.isDiscoverWeekly,
      );
    }
    _playlists.insert(0, normalized);
    await _savePersistentData();
    notifyListeners();
  }

  /// Restore library from complete backup
  Future<void> restoreLibrary(List<Playlist> newPlaylists, List<Song> newLikedSongs) async {
    if (newPlaylists.isNotEmpty) {
      final normalized = newPlaylists.map((p) {
        if (!p.id.startsWith('custom_') &&
            !p.id.startsWith('pl_daily_mix_') &&
            !p.id.startsWith('pl_discover_') &&
            !p.id.startsWith('pl_release_')) {
          return Playlist(
            id: 'custom_${p.id}',
            title: p.title,
            subtitle: p.subtitle,
            coverUrl: p.coverUrl,
            songs: p.songs,
            isPinned: p.isPinned,
          );
        }
        return p;
      }).toList();
      _playlists = List.from(normalized);
    }
    if (newLikedSongs.isNotEmpty) {
      _likedSongs.clear();
      _likedSongs.addAll(newLikedSongs);
    }
    await _savePersistentData();
    notifyListeners();
  }

  // --- Sleep Timer ---
  void setSleepTimer(int minutes) {
    cancelSleepTimer();
    if (minutes <= 0) return;

    _sleepAtSongEnd = false;
    _sleepTimerEndTime = DateTime.now().add(Duration(minutes: minutes));
    _sleepTimer = Timer(Duration(minutes: minutes), () {
      _audioService.pause();
      cancelSleepTimer();
    });
    notifyListeners();
  }

  void setSleepTimerAtSongEnd() {
    cancelSleepTimer();
    _sleepAtSongEnd = true;
    notifyListeners();
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepTimerEndTime = null;
    _sleepAtSongEnd = false;
    notifyListeners();
  }

  // --- Custom Playlist Management ---
  Future<void> createPlaylist(String title, {String subtitle = 'Dibuat oleh Kamu'}) async {
    final newPlaylist = Playlist(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      title: title.trim().isEmpty ? 'Playlist Saya' : title.trim(),
      subtitle: subtitle,
      coverUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=300',
      songs: [],
    );
    _playlists.insert(0, newPlaylist);
    await _savePersistentData();
    notifyListeners();
  }

  void notifyAll() {
    notifyListeners();
  }

  void insertPlaylist(Playlist playlist) {
    final existingIdx = _playlists.indexWhere((p) => p.id == playlist.id);
    if (existingIdx != -1) {
      _playlists[existingIdx] = playlist;
    } else {
      _playlists.insert(0, playlist);
    }
    _savePersistentData();
    notifyListeners();
  }

  Future<void> addSongToPlaylist(String playlistId, Song song) async {
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index != -1) {
      final p = _playlists[index];
      if (!p.songs.any((s) => s.id == song.id)) {
        p.songs.add(song);
        await _savePersistentData();
        notifyListeners();
      }
    }
  }

  Future<void> removeSongFromPlaylist(String playlistId, Song song) async {
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index != -1) {
      _playlists[index].songs.removeWhere((s) => s.id == song.id);
      await _savePersistentData();
      notifyListeners();
    }
  }

  /// Edit existing playlist title and subtitle (protected: Lagu yang Disukai cannot be edited)
  Future<void> editPlaylist(String playlistId, {required String newTitle, String? newSubtitle}) async {
    if (playlistId == 'liked_songs' || playlistId == 'liked_songs_virtual') return;

    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index != -1) {
      final p = _playlists[index];
      _playlists[index] = Playlist(
        id: p.id,
        title: newTitle.trim().isEmpty ? p.title : newTitle.trim(),
        subtitle: newSubtitle != null ? newSubtitle.trim() : p.subtitle,
        coverUrl: p.coverUrl,
        songs: p.songs,
        isDailyMix: p.isDailyMix,
        dailyMixNumber: p.dailyMixNumber,
        isReleaseRadar: p.isReleaseRadar,
        isDiscoverWeekly: p.isDiscoverWeekly,
      );
      await _savePersistentData();
      notifyListeners();
    }
  }

  /// Delete existing playlist (protected: Lagu yang Disukai cannot be deleted)
  Future<void> deletePlaylist(String playlistId) async {
    if (playlistId == 'liked_songs' || playlistId == 'liked_songs_virtual') return;

    _deletedPlaylistIds.add(playlistId);
    _playlists.removeWhere((p) => p.id == playlistId);
    await _savePersistentData();
    notifyListeners();
  }

  // --- Local Data Persistence (SharedPreferences) ---
  Future<void> _savePersistentData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save deleted playlists blacklist
      await prefs.setStringList('spotify_deleted_playlist_ids', _deletedPlaylistIds.toList());

      // Save liked songs
      final likedJson = json.encode(_likedSongs.map((s) => s.toJson()).toList());
      await prefs.setString('spotify_liked_songs', likedJson);

      // Save custom playlists (only custom ones created by the user)
      final userPlaylists = _playlists.where((p) => p.id.startsWith('custom_')).toList();
      final playlistsJson = json.encode(userPlaylists.map((p) => p.toJson()).toList());
      await prefs.setString('spotify_user_playlists', playlistsJson);

      // Save edited metadata for default/imported playlists
      final editedMap = <String, Map<String, String>>{};
      for (final p in _playlists) {
        if (!p.id.startsWith('custom_')) {
          editedMap[p.id] = {'title': p.title, 'subtitle': p.subtitle};
        }
      }
      await prefs.setString('spotify_edited_playlists', json.encode(editedMap));

      // Save downloaded song records
      final downloadedList = downloadedSongs;
      final downloadedJson = json.encode(downloadedList.map((s) => s.toJson()).toList());
      await prefs.setString('spotify_downloaded_songs', downloadedJson);
    } catch (e) {
      debugPrint('Error saving persistent data: $e');
    }
  }

  Future<void> _loadPersistentData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 0. Filter out deleted playlists
      final deleted = prefs.getStringList('spotify_deleted_playlist_ids');
      if (deleted != null) {
        _deletedPlaylistIds.addAll(deleted);
        _playlists.removeWhere((p) => _deletedPlaylistIds.contains(p.id));
      }

      // 1. Liked songs
      final likedString = prefs.getString('spotify_liked_songs');
      if (likedString != null && likedString.isNotEmpty) {
        final List list = json.decode(likedString);
        _likedSongs.clear();
        for (final item in list) {
          final s = Song.fromJson(item)..isLiked = true;
          _likedSongs.add(s);
        }
      }

      // 2. Custom Playlists (only user-created playlists)
      final playlistsString = prefs.getString('spotify_user_playlists');
      if (playlistsString != null && playlistsString.isNotEmpty) {
        final List list = json.decode(playlistsString);
        for (final item in list) {
          final p = Playlist.fromJson(item);
          if (p.id.startsWith('custom_') &&
              !_deletedPlaylistIds.contains(p.id) &&
              !_playlists.any((exist) => exist.id == p.id)) {
            _playlists.insert(0, p);
          }
        }
      }

      // 3. Apply edited playlist info
      final editedStr = prefs.getString('spotify_edited_playlists');
      if (editedStr != null && editedStr.isNotEmpty) {
        try {
          final Map<String, dynamic> editedMap = json.decode(editedStr);
          for (int i = 0; i < _playlists.length; i++) {
            final p = _playlists[i];
            if (editedMap.containsKey(p.id)) {
              final info = editedMap[p.id];
              _playlists[i] = Playlist(
                id: p.id,
                title: info['title'] ?? p.title,
                subtitle: info['subtitle'] ?? p.subtitle,
                coverUrl: p.coverUrl,
                songs: p.songs,
                isDailyMix: p.isDailyMix,
                dailyMixNumber: p.dailyMixNumber,
                isReleaseRadar: p.isReleaseRadar,
                isDiscoverWeekly: p.isDiscoverWeekly,
              );
            }
          }
        } catch (_) {}
      }

      // 3. Downloaded songs validation (check files exist on disk)
      final downloadedString = prefs.getString('spotify_downloaded_songs');
      if (downloadedString != null && downloadedString.isNotEmpty) {
        final List list = json.decode(downloadedString);
        for (final item in list) {
          final savedSong = Song.fromJson(item);
          if (savedSong.localFilePath != null && File(savedSong.localFilePath!).existsSync()) {
            // Update queue or liked song if present
            for (final s in _queue) {
              if (s.id == savedSong.id) {
                s.isDownloaded = true;
                s.localFilePath = savedSong.localFilePath;
              }
            }
            for (final s in _likedSongs) {
              if (s.id == savedSong.id) {
                s.isDownloaded = true;
                s.localFilePath = savedSong.localFilePath;
              }
            }
          }
        }
      }

      // 4. Load persisted theme mode
      final themeId = prefs.getString('app_theme_mode');
      if (themeId != null) {
        final colors = AppThemeColors.fromId(themeId);
        _themeMode = colors.mode;
        SpotifyTheme.current = colors;
      }

      // 5. Restore last played song & timestamp (state persistence across app reopen / force close)
      final lastSongJson = prefs.getString('spotify_last_song');
      final lastPosMs = prefs.getInt('spotify_last_position_ms') ?? 0;
      final lastContext = prefs.getString('spotify_last_context_title');
      final lastQueueJson = prefs.getString('spotify_last_queue');
      final lastIndex = prefs.getInt('spotify_last_current_index');

      if (lastSongJson != null && lastSongJson.isNotEmpty) {
        try {
          final restoredSong = Song.fromJson(json.decode(lastSongJson));
          _currentSong = restoredSong;
          _position = Duration(milliseconds: lastPosMs);
          _duration = restoredSong.duration;
          if (lastContext != null && lastContext.isNotEmpty) {
            _contextTitle = lastContext;
          }
          if (lastQueueJson != null && lastQueueJson.isNotEmpty) {
            final List qList = json.decode(lastQueueJson);
            if (qList.isNotEmpty) {
              _queue = qList.map((e) => Song.fromJson(e)).toList();
            }
          }
          if (lastIndex != null && lastIndex >= 0 && lastIndex < _queue.length) {
            _currentIndex = lastIndex;
          }
          _updateDominantColor(restoredSong.albumArtUrl);
          MusixspotAudioHandler.instance.updateSongItem(restoredSong, isLiked: isSongLiked(restoredSong.id));
          _syncBackgroundControls();
        } catch (e) {
          debugPrint('Error restoring last playback session: $e');
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading persistent data: $e');
    }
  }

  Future<void> _savePlaybackPosition(Duration pos) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('spotify_last_position_ms', pos.inMilliseconds);
    } catch (_) {}
  }

  Future<void> _savePlaybackSession() async {
    if (_currentSong == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('spotify_last_song', json.encode(_currentSong!.toJson()));
      await prefs.setInt('spotify_last_position_ms', _position.inMilliseconds);
      await prefs.setString('spotify_last_context_title', _contextTitle);
      await prefs.setInt('spotify_last_current_index', _currentIndex);
      if (_queue.isNotEmpty) {
        final qSlice = _queue.take(50).map((s) => s.toJson()).toList();
        await prefs.setString('spotify_last_queue', json.encode(qSlice));
      }
    } catch (e) {
      debugPrint('Error saving playback session: $e');
    }
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    _bufSub?.cancel();
    _stateSub?.cancel();
    _btSub?.cancel();
    _audioService.dispose();
    super.dispose();
  }
}
