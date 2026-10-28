import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../models/artist.dart';
import '../providers/music_player_provider.dart';
import '../theme/spotify_theme.dart';
import '../services/music_api_service.dart';
import '../services/deezer_api_service.dart';
import '../services/native_bridge.dart';
import '../services/song_stream_resolver.dart';
import '../services/artist_navigation_service.dart';
import 'now_playing_screen.dart';

class ArtistShortsScreen extends StatefulWidget {
  final String artistName;
  final Song? initialSong;
  final List<Song>? customPlaylist;
  final String mode; // 'similar_artist', 'similar_track', 'artist_songs'

  const ArtistShortsScreen({
    super.key,
    required this.artistName,
    this.initialSong,
    this.customPlaylist,
    this.mode = 'similar_artist',
  });

  @override
  State<ArtistShortsScreen> createState() => _ArtistShortsScreenState();
}

class _ArtistShortsScreenState extends State<ArtistShortsScreen> with TickerProviderStateMixin {
  late PageController _pageController;
  late List<Song> _songs;
  int _currentIndex = 0;
  bool _isMuted = false;
  final Set<String> _followedArtists = {};
  bool _showSwipeHint = true;
  bool _isLoadingMore = false;

  late AnimationController _hintAnimController;
  late Animation<double> _hintOffsetAnim;
  Timer? _hintDismissTimer;

  // Track playback simulation progress (0.0 to 1.0)
  late AnimationController _progressController;

  // Canvas Ken Burns subtle zoom animation
  late AnimationController _canvasAnimController;
  late Animation<double> _canvasScaleAnim;

  // Rotating vinyl / disk animation
  late AnimationController _vinylAnimController;

  @override
  void initState() {
    super.initState();

    // Prepare playlist of similar/related songs
    _songs = _buildShortsPlaylist();

    // Find initial index if provided
    int initialPage = 1000; // Start at high multiple for infinite upward & downward scrolling
    if (widget.initialSong != null) {
      final idx = _songs.indexWhere((s) => s.id == widget.initialSong!.id);
      if (idx != -1) {
        _currentIndex = idx;
      }
    }

    _pageController = PageController(initialPage: initialPage + _currentIndex);

    // Hand hint animation
    _hintAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _hintOffsetAnim = Tween<double>(begin: 0.0, end: -14.0).animate(
      CurvedAnimation(parent: _hintAnimController, curve: Curves.easeInOut),
    );

    // Auto dismiss swipe hint after 5 seconds
    _hintDismissTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _showSwipeHint = false;
        });
      }
    });

    // Teaser playback progress loop (30s snippet)
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();

    // Spotify Canvas Ken Burns subtle breathing animation
    _canvasAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _canvasScaleAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _canvasAnimController, curve: Curves.easeInOut),
    );

    // Subtle vinyl rotation
    _vinylAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    // Pre-resolve candidate for initial and next song with no delay
    _preWarmStreams(_currentIndex);

    // Auto play current song teaser via provider with NO DELAY
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playCurrentSongTeaser();
    });
  }

  void _preWarmStreams(int index) {
    if (_songs.isEmpty) return;
    final curr = _songs[index % _songs.length];
    final next = _songs[(index + 1) % _songs.length];
    SongStreamResolver.resolveAudioStreamCandidates(curr).catchError((_) => <String>[]);
    SongStreamResolver.resolveAudioStreamCandidates(next).catchError((_) => <String>[]);
  }

  List<Song> _buildShortsPlaylist() {
    if (widget.customPlaylist != null && widget.customPlaylist!.isNotEmpty) {
      return List.from(widget.customPlaylist!);
    }

    final allSongs = <Song>[];
    final seen = <String>{};

    void addSong(Song s) {
      if (!seen.contains(s.id)) {
        seen.add(s.id);
        allSongs.add(s);
      }
    }

    if (widget.initialSong != null) {
      addSong(widget.initialSong!);
    }

    // Find matching artist in comprehensive artists
    final comprehensive = MusicApiService.getComprehensiveArtists();
    Artist? targetArtist;
    for (final a in comprehensive) {
      if (a.name.toLowerCase() == widget.artistName.toLowerCase()) {
        targetArtist = a;
        break;
      }
    }

    final songArt = (widget.initialSong?.artist ?? widget.artistName).toLowerCase();
    final songTitle = (widget.initialSong?.title ?? '').toLowerCase();
    final songAlbum = (widget.initialSong?.album ?? '').toLowerCase();
    final seedCombined = '$songArt $songTitle $songAlbum';

    // Cultural & Genre Affinity Detection
    final bool isKorean = (targetArtist?.country.toLowerCase() == 'korea selatan') ||
        (targetArtist?.genres.any((g) => g.toLowerCase().contains('k-') || g.toLowerCase().contains('korean')) ?? false) ||
        seedCombined.contains('korean') ||
        seedCombined.contains('ost') ||
        seedCombined.contains('drama') ||
        seedCombined.contains('hyun bin') ||
        seedCombined.contains('wendy') ||
        seedCombined.contains('dmeanor') ||
        seedCombined.contains('baek ji') ||
        seedCombined.contains('gummy') ||
        seedCombined.contains('taeyeon') ||
        seedCombined.contains('iu') ||
        seedCombined.contains('davichi') ||
        seedCombined.contains('gaho') ||
        seedCombined.contains('crush') ||
        seedCombined.contains('ailee') ||
        seedCombined.contains('chanyeol') ||
        seedCombined.contains('punch') ||
        seedCombined.contains('bts') ||
        seedCombined.contains('newjeans') ||
        seedCombined.contains('secret garden') ||
        seedCombined.contains('goblin') ||
        seedCombined.contains('crash landing') ||
        seedCombined.contains('descendants') ||
        seedCombined.contains('itaewon') ||
        seedCombined.contains('hotel del luna') ||
        seedCombined.contains('voice') ||
        seedCombined.contains('are you human') ||
        RegExp(r'[\uac00-\ud7af]').hasMatch('$songArt $songTitle');

    final bool isJapaneseOrAnime = (targetArtist?.country.toLowerCase() == 'jepang') ||
        seedCombined.contains('naruto') ||
        seedCombined.contains('shippuden') ||
        seedCombined.contains('anime') ||
        seedCombined.contains('j-pop') ||
        seedCombined.contains('j-rock') ||
        seedCombined.contains('flow') ||
        seedCombined.contains('lisa') ||
        seedCombined.contains('yoasobi') ||
        seedCombined.contains('shun') ||
        seedCombined.contains('unlimits');

    final bool isIndonesian = (targetArtist?.country.toLowerCase() == 'indonesia') ||
        seedCombined.contains('indonesia') ||
        seedCombined.contains('sheila') ||
        seedCombined.contains('dewa') ||
        seedCombined.contains('tulus') ||
        seedCombined.contains('mahalini') ||
        seedCombined.contains('bernadya') ||
        seedCombined.contains('nadin') ||
        seedCombined.contains('hindia') ||
        seedCombined.contains('sal priadi') ||
        seedCombined.contains('chrisye') ||
        seedCombined.contains('peterpan');

    if (widget.mode == 'artist_songs') {
      if (targetArtist != null) {
        for (final t in targetArtist.topTracks) {
          addSong(t);
        }
      }
    } else if (widget.mode == 'similar_track' && widget.initialSong != null) {
      if (isKorean) {
        // Korean drama OSTs & romantic ballads
        for (final s in MusicApiService.getKoreanDramaTracks()) {
          addSong(s);
        }
        for (final a in comprehensive) {
          if (a.country.toLowerCase() == 'korea selatan' ||
              a.genres.any((g) => g.toLowerCase().contains('k-') || g.toLowerCase().contains('ost'))) {
            for (final t in a.topTracks) {
              addSong(t);
            }
          }
        }
      } else if (isJapaneseOrAnime) {
        for (final s in MusicApiService.getNarutoOstTracks()) {
          addSong(s);
        }
        for (final s in MusicApiService.getJPopTracks()) {
          addSong(s);
        }
      } else if (isIndonesian) {
        for (final s in MusicApiService.getIndieTracks()) {
          addSong(s);
        }
        for (final s in MusicApiService.getTop50IndonesiaTracks()) {
          addSong(s);
        }
      } else if (targetArtist != null) {
        for (final other in comprehensive) {
          if (other.name.toLowerCase() != targetArtist.name.toLowerCase()) {
            final shareGenre = other.genres.any((g) => targetArtist!.genres.contains(g));
            if (shareGenre) {
              for (final t in other.topTracks) {
                addSong(t);
              }
            }
          }
        }
      }
    } else {
      // mode == 'similar_artist'
      if (isKorean) {
        for (final a in comprehensive) {
          if (a.country.toLowerCase() == 'korea selatan' ||
              a.genres.any((g) => g.toLowerCase().contains('k-'))) {
            for (final t in a.topTracks) {
              addSong(t);
            }
          }
        }
        for (final s in MusicApiService.getKoreanDramaTracks()) {
          addSong(s);
        }
      } else if (isJapaneseOrAnime) {
        for (final s in MusicApiService.getNarutoOstTracks()) {
          addSong(s);
        }
        for (final s in MusicApiService.getJPopTracks()) {
          addSong(s);
        }
      } else if (isIndonesian) {
        for (final a in comprehensive) {
          if (a.country.toLowerCase() == 'indonesia') {
            for (final t in a.topTracks) {
              addSong(t);
            }
          }
        }
        for (final s in MusicApiService.getIndieTracks()) {
          addSong(s);
        }
      } else if (targetArtist != null) {
        // Add songs from strictly similar artists (same genres or country)
        for (final other in comprehensive) {
          if (other.name.toLowerCase() != targetArtist.name.toLowerCase()) {
            final shareGenre = other.genres.any((g) => targetArtist!.genres.contains(g));
            final shareCountry = other.country.toLowerCase() == targetArtist.country.toLowerCase();
            if (shareGenre || shareCountry) {
              for (final t in other.topTracks) {
                addSong(t);
              }
            }
          }
        }
      }
    }

    // Culturally consistent catalog backfilling (NEVER leak Bruno Mars into Korean sad songs!)
    if (isKorean) {
      for (final s in MusicApiService.getKoreanDramaTracks()) {
        addSong(s);
      }
      for (final s in MusicApiService.getKPopTracks()) {
        addSong(s);
      }
      for (final a in comprehensive) {
        if (a.country.toLowerCase() == 'korea selatan') {
          for (final t in a.topTracks) {
            addSong(t);
          }
        }
      }
    } else if (isJapaneseOrAnime) {
      for (final s in MusicApiService.getNarutoOstTracks()) {
        addSong(s);
      }
      for (final s in MusicApiService.getJPopTracks()) {
        addSong(s);
      }
    } else if (isIndonesian) {
      for (final s in MusicApiService.getIndieTracks()) {
        addSong(s);
      }
      for (final s in MusicApiService.getNostalgiaTracks()) {
        if (!s.id.contains('westlife') && !s.id.contains('oasis') && !s.id.contains('queen')) {
          addSong(s);
        }
      }
      for (final s in MusicApiService.getTop50IndonesiaTracks()) {
        addSong(s);
      }
    } else {
      // Western / Global
      for (final s in MusicApiService.getFeaturedTracks()) {
        addSong(s);
      }
      for (final s in MusicApiService.getTop50GlobalTracks()) {
        addSong(s);
      }
    }

    return allSongs;
  }

  Future<void> _loadMoreOnlineTracks() async {
    if (_isLoadingMore) return;
    _isLoadingMore = true;
    try {
      final songArt = (widget.initialSong?.artist ?? widget.artistName).toLowerCase();
      final songTitle = (widget.initialSong?.title ?? '').toLowerCase();
      final songAlbum = (widget.initialSong?.album ?? '').toLowerCase();
      final seedCombined = '$songArt $songTitle $songAlbum';

      final bool isKorean = seedCombined.contains('korean') ||
          seedCombined.contains('ost') ||
          seedCombined.contains('drama') ||
          seedCombined.contains('hyun bin') ||
          seedCombined.contains('wendy') ||
          seedCombined.contains('dmeanor') ||
          seedCombined.contains('baek ji') ||
          seedCombined.contains('gummy') ||
          seedCombined.contains('taeyeon') ||
          seedCombined.contains('iu') ||
          seedCombined.contains('davichi') ||
          RegExp(r'[\uac00-\ud7af]').hasMatch(seedCombined);

      final bool isJapanese = seedCombined.contains('naruto') ||
          seedCombined.contains('anime') ||
          seedCombined.contains('j-pop') ||
          seedCombined.contains('flow') ||
          seedCombined.contains('lisa');

      final bool isIndonesian = seedCombined.contains('indonesia') ||
          seedCombined.contains('sheila') ||
          seedCombined.contains('dewa') ||
          seedCombined.contains('tulus') ||
          seedCombined.contains('mahalini') ||
          seedCombined.contains('bernadya');

      List<Song> moreTracks = [];
      if (isKorean) {
        moreTracks = await DeezerApiService.searchTracks('korean drama ost', limit: 25);
        if (moreTracks.isEmpty) {
          moreTracks = await DeezerApiService.searchTracks('kpop ballad', limit: 25);
        }
      } else if (isJapanese) {
        moreTracks = await DeezerApiService.searchTracks('anime ost', limit: 25);
      } else if (isIndonesian) {
        moreTracks = await DeezerApiService.searchTracks('indonesian pop', limit: 25);
      } else {
        moreTracks = await DeezerApiService.getChartTracks(limit: 25);
      }

      if (mounted && moreTracks.isNotEmpty) {
        setState(() {
          final seen = _songs.map((s) => s.id).toSet();
          for (final t in moreTracks) {
            if (!seen.contains(t.id)) {
              _songs.add(t);
              seen.add(t.id);
            }
          }
        });
      }
    } catch (_) {
    } finally {
      _isLoadingMore = false;
    }
  }

  void _playCurrentSongTeaser() {
    if (!mounted || _songs.isEmpty) return;
    final currentSong = _songs[_currentIndex % _songs.length];
    final provider = context.read<MusicPlayerProvider>();

    if (!_isMuted) {
      final isPreview = SongStreamResolver.isPreviewUrl(currentSong.audioUrl);
      Duration reffPos = Duration.zero;

      if (!isPreview) {
        // Full song: Jump directly to the energetic chorus/refrain (35% into song) with NO DELAY
        final durSec = currentSong.duration.inSeconds > 40 ? currentSong.duration.inSeconds : 210;
        final reffSec = (durSec * 0.35).round().clamp(40, 75);
        reffPos = Duration(seconds: reffSec);
      }

      String titleContext = 'Serupa dengan ${widget.artistName}';
      if (widget.mode == 'similar_track' && widget.initialSong != null) {
        titleContext = 'Serupa dengan ${widget.initialSong!.title}';
      } else if (widget.mode == 'artist_songs') {
        titleContext = 'Lagu oleh ${widget.artistName}';
      }

      provider.playSong(currentSong, contextTitle: titleContext, initialPosition: reffPos);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _hintAnimController.dispose();
    _progressController.dispose();
    _canvasAnimController.dispose();
    _vinylAnimController.dispose();
    _hintDismissTimer?.cancel();
    super.dispose();
  }

  void _onPageChanged(int index) {
    final realIndex = index % _songs.length;
    setState(() {
      _currentIndex = realIndex;
      if (index > 0) {
        _showSwipeHint = false;
      }
    });

    _progressController.reset();
    _progressController.forward();
    _playCurrentSongTeaser();
    _preWarmStreams(realIndex);

    // Dynamically append new online tracks when approaching the loop boundary
    if (realIndex >= _songs.length - 4) {
      _loadMoreOnlineTracks();
    }
  }

  List<String> _getHashtagsForSong(Song song) {
    final lower = '${song.artist} ${song.title} ${song.album}'.toLowerCase();

    if (lower.contains('audien') || lower.contains('future fires') || lower.contains('edm') || lower.contains('medz') || lower.contains('h4rris')) {
      return ['#melodic dubstep', '#future bass', '#elektronik'];
    }
    if (lower.contains('kenshi') || lower.contains('kick back') || lower.contains('lemon') || lower.contains('peace sign')) {
      return ['#jpop', '#anime', '#kenshiyonezu', '#rock'];
    }
    if (lower.contains('utada') || lower.contains('first love') || lower.contains('one last kiss')) {
      return ['#jpop', '#rnb', '#firstlove', '#evangelion'];
    }
    if (lower.contains('yoasobi') || lower.contains('idol') || lower.contains('yoru ni kakeru')) {
      return ['#jpop', '#anisong', '#yoasobi', '#idol'];
    }
    if (lower.contains('yuuri') || lower.contains('betelgeuse') || lower.contains('dried flower')) {
      return ['#jpop', '#acoustic', '#ballad', '#yuuri'];
    }
    if (lower.contains('oasis') || lower.contains('wonderwall')) {
      return ['#britpop', '#rock', '#oasis', '#anthem'];
    }
    if (lower.contains('westlife') || lower.contains('my love')) {
      return ['#boyband', '#pop', '#nostalgia', '#westlife'];
    }
    if (lower.contains('backstreet') || lower.contains('i want it that way')) {
      return ['#boyband', '#90s', '#pop', '#throwback'];
    }
    if (lower.contains('afgan') || lower.contains('tulus') || lower.contains('sheila') || lower.contains('komang')) {
      return ['#popindonesia', '#akustik', '#romantis', '#hits'];
    }
    if (lower.contains('kpop') || lower.contains('ost') || lower.contains('bts') || lower.contains('blackpink') || lower.contains('iu') || lower.contains('winter')) {
      return ['#kpop', '#kdrama', '#ost', '#trending'];
    }
    if (lower.contains('turki') || lower.contains('tarkan')) {
      return ['#turkcepop', '#turki', '#hits'];
    }
    if (lower.contains('india') || lower.contains('bollywood') || lower.contains('arijit')) {
      return ['#bollywood', '#india', '#hits'];
    }
    return ['#hits', '#trending', '#musixspot'];
  }

  String _getFollowerCountForArtist(String artist) {
    final hash = artist.hashCode.abs();
    final count = (hash % 18) + 1;
    if (count > 9) {
      return '$count JT pengikut';
    }
    return '${count * 50 + 20} RB pengikut';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MusicPlayerProvider>();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── VERTICAL INFINITE PAGE VIEW FEED (Reels Unlimited) ──
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            // Null itemCount enables genuine infinite vertical scrolling
            itemCount: null,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              if (_songs.isEmpty) return const SizedBox.shrink();
              final song = _songs[index % _songs.length];
              final isFirstSlide = index == 0 || index == 1000;
              final hashtags = _getHashtagsForSong(song);
              final isFollowing = _followedArtists.contains(song.artist);
              final isLiked = provider.isSongLiked(song.id);
              final followers = _getFollowerCountForArtist(song.artist);

              return Stack(
                fit: StackFit.expand,
                children: [
                  // 1. Ambient Blurred Background (Cinematic glow, no dump video)
                  Positioned.fill(
                    child: CachedNetworkImage(
                      imageUrl: song.albumArtUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(color: const Color(0xFF101010)),
                      errorWidget: (_, _, _) => Container(color: const Color(0xFF121212)),
                    ),
                  ),

                  // Heavy Backdrop Blur for Spotify Canvas Atmosphere
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 55, sigmaY: 55),
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.55),
                      ),
                    ),
                  ),

                  // 2. Central Spotify Canvas: Breathing Ken Burns Artwork
                  Center(
                    child: AnimatedBuilder(
                      animation: _canvasScaleAnim,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _canvasScaleAnim.value,
                          child: child,
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.54,
                          maxWidth: MediaQuery.of(context).size.width * 0.90,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.65),
                              blurRadius: 36,
                              spreadRadius: 8,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CachedNetworkImage(
                              imageUrl: song.albumArtUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, _) => Container(color: const Color(0xFF181818)),
                              errorWidget: (_, _, _) => Container(
                                color: const Color(0xFF202020),
                                child: const Center(
                                  child: Icon(Icons.music_note, color: Colors.white24, size: 64),
                                ),
                              ),
                            ),
                            // Gentle Canvas gradient overlay
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.4),
                                  ],
                                ),
                              ),
                            ),
                            // Rotating Vinyl Disc Badge at top-right
                            Positioned(
                              top: 14,
                              right: 14,
                              child: RotationTransition(
                                turns: _vinylAnimController,
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.black.withValues(alpha: 0.7),
                                    border: Border.all(color: Colors.white30, width: 1.2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.5),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.album_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 3. Cinematic Edge Vignette
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.75),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.35),
                          Colors.black.withValues(alpha: 0.95),
                        ],
                        stops: const [0.0, 0.20, 0.65, 1.0],
                      ),
                    ),
                  ),

                  // 4. First Slide Animated Swipe Up Hint
                  if (isFirstSlide && _showSwipeHint)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Center(
                          child: AnimatedBuilder(
                            animation: _hintAnimController,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(0, _hintOffsetAnim.value),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.45),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.pan_tool_alt_rounded,
                                        color: Colors.white,
                                        size: 38,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Geser ke atas untuk melihat lebih banyak',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.95),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.2,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black.withValues(alpha: 0.8),
                                            blurRadius: 8,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),

                  // 5. Bottom Content Overlay
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 22,
                    child: SafeArea(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Artist Row with Avatar, Name, Follow button, and Share icon
                          Row(
                            children: [
                              // Circular Avatar with direct navigation to artist profile
                              GestureDetector(
                                onTap: () => ArtistNavigationService.navigateToArtist(context, song.artist),
                                child: CircleAvatar(
                                  radius: 20,
                                  backgroundColor: const Color(0xFF282828),
                                  backgroundImage: CachedNetworkImageProvider(song.albumArtUrl),
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Artist Name & Follower Count (clickable)
                              Expanded(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => ArtistNavigationService.navigateToArtist(context, song.artist),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        song.artist,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.2,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        followers,
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.7),
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // "Ikuti" (Follow) pill button
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: isFollowing ? SpotifyTheme.spotifyGreen : Colors.white,
                                  side: BorderSide(
                                    color: isFollowing ? SpotifyTheme.spotifyGreen : Colors.white60,
                                    width: 1.1,
                                  ),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                  minimumSize: const Size(60, 32),
                                  backgroundColor: isFollowing
                                      ? SpotifyTheme.spotifyGreen.withValues(alpha: 0.15)
                                      : Colors.transparent,
                                ),
                                onPressed: () {
                                  setState(() {
                                    if (isFollowing) {
                                      _followedArtists.remove(song.artist);
                                    } else {
                                      _followedArtists.add(song.artist);
                                    }
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        !isFollowing
                                            ? 'Mengikuti ${song.artist}'
                                            : 'Berhenti mengikuti ${song.artist}',
                                      ),
                                      duration: const Duration(milliseconds: 900),
                                      backgroundColor: SpotifyTheme.cardSurface,
                                    ),
                                  );
                                },
                                child: Text(
                                  isFollowing ? 'Mengikuti' : 'Ikuti',
                                  style: TextStyle(
                                    color: isFollowing ? SpotifyTheme.spotifyGreen : Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Share icon
                              IconButton(
                                icon: const Icon(Icons.share_outlined, color: Colors.white, size: 22),
                                onPressed: () {
                                  NativeBridge.shareSong(
                                    title: song.title,
                                    text: 'Dengarkan "${song.title}" oleh ${song.artist} di musixspot 🎵\nhttps://musicxspot.app/track/${song.id}',
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Hashtags Row
                          Wrap(
                            spacing: 10,
                            runSpacing: 4,
                            children: hashtags.map((tag) {
                              return Text(
                                tag,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.75),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 12),

                          // Floating Track Card (Tap opens NowPlayingScreen)
                          GestureDetector(
                            onTap: () {
                              provider.playSong(song, contextTitle: 'Serupa dengan ${widget.artistName}');
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const NowPlayingScreen()),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF161616).withValues(alpha: 0.92),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: CachedNetworkImage(
                                      imageUrl: song.albumArtUrl,
                                      width: 46,
                                      height: 46,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          song.title,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          song.artist,
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.7),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Play / Open full song label
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16),
                                        SizedBox(width: 2),
                                        Text(
                                          'Lagu Penuh',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 4),

                                  // (+) Add to library / liked button
                                  IconButton(
                                    icon: Icon(
                                      isLiked ? Icons.check_circle : Icons.add_circle_outline,
                                      color: isLiked ? SpotifyTheme.spotifyGreenLight : Colors.white,
                                      size: 24,
                                    ),
                                    onPressed: () {
                                      provider.toggleLike(song);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Horizontal Playback Progress Bar
                          AnimatedBuilder(
                            animation: _progressController,
                            builder: (context, child) {
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: _progressController.value,
                                  backgroundColor: Colors.white24,
                                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                  minHeight: 2.5,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // ── TOP BAR (Back, Dashes, Title, Mute Toggle) ──
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 6),

                  // Horizontal Dash Indicators
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(8, (index) {
                        final isActive = index == (_currentIndex % 8);
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 2.5),
                          height: 3.5,
                          width: isActive ? 22 : 4.5,
                          decoration: BoxDecoration(
                            color: isActive ? Colors.white : Colors.white38,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Top Navigation Header Row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: Text(
                            'Serupa dengan ${widget.artistName}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            _isMuted ? Icons.volume_off : Icons.volume_up,
                            color: Colors.white,
                            size: 23,
                          ),
                          onPressed: () {
                            setState(() {
                              _isMuted = !_isMuted;
                            });
                            final provider = context.read<MusicPlayerProvider>();
                            if (_isMuted) {
                              if (provider.isPlaying) {
                                provider.togglePlayPause();
                              }
                            } else {
                              _playCurrentSongTeaser();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
