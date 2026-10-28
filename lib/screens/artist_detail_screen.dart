import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/artist.dart';
import '../models/song.dart';
import '../models/playlist.dart';
import '../providers/music_player_provider.dart';
import '../services/deezer_api_service.dart';
import '../theme/spotify_theme.dart';
import '../widgets/mini_player.dart';
import '../services/title_normalizer.dart';
import '../services/music_api_service.dart';
import 'playlist_detail_screen.dart';
import '../services/native_bridge.dart';

class ArtistDetailScreen extends StatefulWidget {
  final Artist artist;

  const ArtistDetailScreen({
    super.key,
    required this.artist,
  });

  @override
  State<ArtistDetailScreen> createState() => _ArtistDetailScreenState();
}

class _ArtistDetailScreenState extends State<ArtistDetailScreen> {
  bool _isFollowing = false;
  bool _hasNotification = false;
  bool _isBioExpanded = false;
  List<ArtistAlbum> _albums = [];
  List<Song> _topTracks = [];
  List<Artist> _relatedArtists = [];
  bool _isLoadingAlbums = false;
  String _selectedAlbumFilter = 'Semua'; // 'Semua', 'Album', 'Single & EP'

  @override
  void initState() {
    super.initState();
    _albums = List.from(widget.artist.albums);
    _topTracks = List.from(widget.artist.topTracks);
    if (_albums.isEmpty) {
      _loadAlbums();
    }
    if (_topTracks.isEmpty) {
      _loadTopTracks();
    }
    _loadRelatedArtists();
  }

  Future<void> _loadTopTracks() async {
    // 1. Check if artist exists in curated comprehensive catalog (Spotify-authentic)
    final comprehensive = MusicApiService.getComprehensiveArtists();
    for (final a in comprehensive) {
      if (a.name.toLowerCase() == widget.artist.name.toLowerCase() ||
          TitleNormalizer.cleanArtist(a.name).toLowerCase() == TitleNormalizer.cleanArtist(widget.artist.name).toLowerCase()) {
        if (a.topTracks.isNotEmpty) {
          if (mounted) {
            setState(() {
              _topTracks = List.from(a.topTracks);
            });
          }
          return;
        }
      }
    }

    try {
      final tracks = await DeezerApiService.getArtistTopTracks(widget.artist.name, limit: 15);
      if (mounted && tracks.isNotEmpty) {
        setState(() {
          _topTracks = tracks;
        });
      }
    } catch (e) {
      debugPrint('ArtistDetailScreen: Error loading top tracks: $e');
    }
  }

  void _loadRelatedArtists() {
    final all = MusicApiService.getComprehensiveArtists();
    final current = widget.artist;

    if (current.name.toLowerCase().contains('kyuhyun')) {
      _relatedArtists = [
        const Artist(
          id: 'art_kwill',
          name: 'K.Will',
          imageUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/44/e9/fc/44e9fc5c-dfb7-d3eb-ee11-b45508a8e1cb/cover.jpg/600x600bb.jpg',
          headerImageUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/44/e9/fc/44e9fc5c-dfb7-d3eb-ee11-b45508a8e1cb/cover.jpg/600x600bb.jpg',
          monthlyListeners: '2.140.000 pendengar bulanan',
          bio: 'K.Will adalah penyanyi balada legendaris Korea Selatan pelantun "Please Don\'t...", "Talk Love", dan "Love Blossom".',
          topTracks: [],
          country: 'Korea Selatan',
        ),
        const Artist(
          id: 'art_paul_kim',
          name: 'Paul Kim',
          imageUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music122/v4/c3/99/33/c3993309-8db2-2f3c-5353-d142d76579a3/198704093952.jpg/600x600bb.jpg',
          headerImageUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music122/v4/c3/99/33/c3993309-8db2-2f3c-5353-d142d76579a3/198704093952.jpg/600x600bb.jpg',
          monthlyListeners: '3.420.000 pendengar bulanan',
          bio: 'Paul Kim adalah penyanyi-penulis lagu Korea Selatan dengan vokal emosional pelantun "Me After You" dan "Every Day, Every Moment".',
          topTracks: [],
          country: 'Korea Selatan',
        ),
        const Artist(
          id: 'art_ryeowook',
          name: 'Ryeowook',
          imageUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/ce/2d/a2/ce2da283-bc2e-ce71-d610-d029517178c1/191018042456.jpg/600x600bb.jpg',
          headerImageUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/ce/2d/a2/ce2da283-bc2e-ce71-d610-d029517178c1/191018042456.jpg/600x600bb.jpg',
          monthlyListeners: '680.000 pendengar bulanan',
          bio: 'Vokalis utama Super Junior dan solois balada Korea Selatan pelantun "The Little Prince".',
          topTracks: [],
          country: 'Korea Selatan',
        ),
      ];
      return;
    }

    final scored = <Artist, int>{};

    for (final other in all) {
      if (other.name.toLowerCase() == current.name.toLowerCase()) continue;
      int score = 0;

      // 1. Genre overlap (30 pts per common genre)
      final commonGenres = other.genres
          .where((g) => current.genres.any((cg) => cg.toLowerCase() == g.toLowerCase()))
          .length;
      score += commonGenres * 30;

      // 2. Cultural / country alignment (25 pts)
      if (current.country.isNotEmpty && other.country.isNotEmpty) {
        if (current.country.toLowerCase() == other.country.toLowerCase()) {
          score += 25;
        }
      }

      // 3. Authentically clustered musical movements
      final curLow = '${current.name} ${current.country} ${current.genres.join(" ")}'.toLowerCase();
      final othLow = '${other.name} ${other.country} ${other.genres.join(" ")}'.toLowerCase();

      final isCurKorean = curLow.contains('korea') || curLow.contains('k-pop') || curLow.contains('k-drama') || curLow.contains('ost');
      final isOthKorean = othLow.contains('korea') || othLow.contains('k-pop') || othLow.contains('k-drama') || othLow.contains('ost');
      if (isCurKorean && isOthKorean) score += 40;

      final isCurJapanese = curLow.contains('jepang') || curLow.contains('japan') || curLow.contains('anime') || curLow.contains('j-pop');
      final isOthJapanese = othLow.contains('jepang') || othLow.contains('japan') || othLow.contains('anime') || othLow.contains('j-pop');
      if (isCurJapanese && isOthJapanese) score += 40;

      final isCurIndo = curLow.contains('indonesia');
      final isOthIndo = othLow.contains('indonesia');
      if (isCurIndo && isOthIndo) score += 40;

      final isCurWestern = curLow.contains('amerika') || curLow.contains('inggris') || curLow.contains('irlandia');
      final isOthWestern = othLow.contains('amerika') || othLow.contains('inggris') || othLow.contains('irlandia');
      if (isCurWestern && isOthWestern) score += 30;

      if (score >= 25) {
        scored[other] = score;
      }
    }

    final sorted = scored.keys.toList()..sort((a, b) => scored[b]!.compareTo(scored[a]!));
    if (sorted.isNotEmpty) {
      _relatedArtists = sorted.take(8).toList();
    } else {
      _relatedArtists = [];
    }
  }

  Future<void> _loadAlbums() async {
    if (widget.artist.albums.isNotEmpty) {
      if (mounted) {
        setState(() {
          _albums = List.from(widget.artist.albums);
        });
      }
      return;
    }

    // 1. Check curated comprehensive catalog first (Spotify-authentic)
    final comprehensive = MusicApiService.getComprehensiveArtists();
    for (final a in comprehensive) {
      if (a.name.toLowerCase() == widget.artist.name.toLowerCase() ||
          TitleNormalizer.cleanArtist(a.name).toLowerCase() == TitleNormalizer.cleanArtist(widget.artist.name).toLowerCase()) {
        if (a.albums.isNotEmpty) {
          if (mounted) {
            setState(() {
              _albums = List.from(a.albums);
            });
          }
          return;
        }
      }
    }

    setState(() {
      _isLoadingAlbums = true;
    });
    try {
      if (widget.artist.id.startsWith('dz_artist_')) {
        final rawId = widget.artist.id.replaceFirst('dz_artist_', '');
        final loaded = await DeezerApiService.getArtistAlbums(rawId);
        if (mounted && loaded.isNotEmpty) {
          setState(() {
            _albums = loaded;
          });
        }
      } else {
        final dzArtist = await DeezerApiService.searchArtist(widget.artist.name);
        if (mounted && dzArtist != null && dzArtist.albums.isNotEmpty) {
          setState(() {
            _albums = dzArtist.albums;
          });
        }
      }
    } catch (e) {
      debugPrint('ArtistDetailScreen: Error loading albums: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAlbums = false;
        });
      }
    }
  }

  List<ArtistAlbum> get _filteredAlbums {
    if (_selectedAlbumFilter == 'Album') {
      return _albums.where((a) => a.type.toLowerCase() == 'album').toList();
    } else if (_selectedAlbumFilter == 'Single & EP') {
      return _albums.where((a) => a.type.toLowerCase() != 'album').toList();
    }
    return _albums;
  }

  Future<void> _openAlbum(ArtistAlbum album) async {
    List<Song> albumTracks = List.from(album.songs);
    if (albumTracks.isEmpty) {
      // Show short loading indicator while fetching album tracks
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: SpotifyTheme.spotifyGreen),
        ),
      );
      try {
        albumTracks = await DeezerApiService.getAlbumTracks(
          album.id,
          coverUrl: album.coverUrl,
          artistName: widget.artist.name,
        );
      } catch (e) {
        debugPrint('ArtistDetailScreen: Error fetching album tracks: $e');
      } finally {
        if (mounted) Navigator.pop(context); // Dismiss loading dialog
      }
    }

    if (!mounted) return;

    final sourceTracks = albumTracks.isNotEmpty
        ? albumTracks
        : widget.artist.topTracks;

    final List<Song> enrichedTracks = [];
    final hasAnyInst = sourceTracks.any((s) =>
        s.title.toLowerCase().contains('(inst') ||
        s.title.toLowerCase().contains('instrumental'));

    if (hasAnyInst) {
      enrichedTracks.addAll(sourceTracks);
    } else {
      for (final s in sourceTracks) {
        enrichedTracks.add(s);
      }
      // In Spotify / official releases, singles, EPs, and OSTs feature the instrumental (Inst.) versions
      final isSingleOrEp = album.type.toLowerCase().contains('single') ||
          album.type.toLowerCase().contains('ep') ||
          album.title.toLowerCase().contains('ost') ||
          album.title.toLowerCase().contains('soundtrack') ||
          sourceTracks.length <= 6;

      if (isSingleOrEp) {
        for (final s in sourceTracks) {
          if (!s.title.toLowerCase().contains('inst')) {
            enrichedTracks.add(
              Song(
                id: '${s.id}_inst',
                title: '${TitleNormalizer.cleanTitle(s.title)} (Inst.)',
                artist: s.artist,
                album: album.title,
                albumArtUrl: s.albumArtUrl.isNotEmpty ? s.albumArtUrl : album.coverUrl,
                audioUrl: 'youtube:${s.artist} ${TitleNormalizer.cleanTitle(s.title)} instrumental',
                duration: s.duration,
                lyrics: Song.generateSampleLyrics('Instrumental'),
              ),
            );
          }
        }
      }
    }

    final playlist = Playlist(
      id: 'album_${album.id}',
      title: TitleNormalizer.cleanTitle(album.title),
      subtitle: '${widget.artist.name} • ${album.type.toUpperCase()} • ${album.releaseYear}',
      coverUrl: album.coverUrl,
      songs: enrichedTracks.map(TitleNormalizer.normalizeSong).toList(),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlaylistDetailScreen(playlist: playlist),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MusicPlayerProvider>();
    final artist = widget.artist;

    final List<Song> topTracks = [];
    final seenKeys = <String>{};
    final effectiveSourceTracks = _topTracks.isNotEmpty ? _topTracks : artist.topTracks;
    for (final s in effectiveSourceTracks) {
      final cleanS = TitleNormalizer.normalizeSong(s);
      final key = TitleNormalizer.dedupKey(cleanS.artist, cleanS.title);
      if (!seenKeys.contains(key)) {
        seenKeys.add(key);
        topTracks.add(cleanS);
      }
    }

    final isArtistPlaying = provider.currentSong != null &&
        provider.isPlaying &&
        topTracks.any((s) => s.id == provider.currentSong!.id);

    return Scaffold(
      backgroundColor: SpotifyTheme.background,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // 1. Collapsible Hero Header with Artist Cover & Name
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                backgroundColor: const Color(0xFF181818),
                elevation: 0,
                leading: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: false,
                  titlePadding: const EdgeInsets.only(left: 16, bottom: 16, right: 16),
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(
                          artist.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (artist.isVerified) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.verified,
                          color: Color(0xFF3D9BE9),
                          size: 18,
                        ),
                      ],
                    ],
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: artist.headerImageUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => Container(
                          color: const Color(0xFF282828),
                          child: const Icon(Icons.person, size: 80, color: Colors.white24),
                        ),
                      ),
                      // Spotify Gradient Vignette
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.2),
                              SpotifyTheme.background.withValues(alpha: 0.95),
                              SpotifyTheme.background,
                            ],
                            stops: const [0.0, 0.45, 0.85, 1.0],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Artist Details & Actions
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),

                      // Monthly listeners
                      Text(
                        artist.monthlyListeners,
                        style: const TextStyle(
                          color: SpotifyTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Action Bar: Follow, Bell, More, Play FAB
                      Row(
                        children: [
                          // Follow / Mengikuti Button
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: _isFollowing ? SpotifyTheme.spotifyGreen : Colors.white54,
                                width: 1.2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                              backgroundColor: _isFollowing
                                  ? SpotifyTheme.spotifyGreen.withValues(alpha: 0.15)
                                  : Colors.transparent,
                            ),
                            onPressed: () {
                              setState(() {
                                _isFollowing = !_isFollowing;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    _isFollowing
                                        ? 'Mengikuti ${artist.name}'
                                        : 'Berhenti mengikuti ${artist.name}',
                                  ),
                                  duration: const Duration(seconds: 1),
                                  backgroundColor: SpotifyTheme.cardSurface,
                                ),
                              );
                            },
                            child: Text(
                              _isFollowing ? 'Mengikuti' : 'Ikuti',
                              style: TextStyle(
                                color: _isFollowing ? SpotifyTheme.spotifyGreen : Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          // Notification Bell
                          IconButton(
                            icon: Icon(
                              _hasNotification ? Icons.notifications_active : Icons.notifications_none,
                              color: _hasNotification ? SpotifyTheme.spotifyGreen : Colors.white70,
                              size: 24,
                            ),
                            onPressed: () {
                              setState(() => _hasNotification = !_hasNotification);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(_hasNotification
                                      ? 'Notifikasi rilis baru dari ${artist.name} diaktifkan'
                                      : 'Notifikasi dari ${artist.name} dinonaktifkan'),
                                  duration: const Duration(seconds: 1),
                                  backgroundColor: SpotifyTheme.cardSurface,
                                ),
                              );
                            },
                          ),

                          // More Options
                          IconButton(
                            icon: const Icon(Icons.more_vert, color: Colors.white70, size: 24),
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                backgroundColor: const Color(0xFF282828),
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                                ),
                                builder: (bCtx) => SafeArea(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ListTile(
                                        leading: const Icon(Icons.share_outlined, color: Colors.white),
                                        title: Text('Bagikan profil ${artist.name}', style: const TextStyle(color: Colors.white)),
                                        onTap: () {
                                          Navigator.pop(bCtx);
                                          NativeBridge.shareSong(
                                            title: artist.name,
                                            text: 'Dengarkan lagu-lagu ${artist.name} di musixspot!\n${artist.monthlyListeners}',
                                          );
                                        },
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.shuffle, color: Colors.white),
                                        title: const Text('Putar Acak Lagu Artis Ini', style: TextStyle(color: Colors.white)),
                                        onTap: () {
                                          Navigator.pop(bCtx);
                                          if (topTracks.isNotEmpty) {
                                            provider.playSong(
                                              topTracks.first,
                                              queue: topTracks,
                                              contextTitle: artist.name,
                                            );
                                            provider.reshuffleQueue();
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),

                          const Spacer(),

                          // Green Spotify Big Play / Pause Button
                          GestureDetector(
                            onTap: () {
                              if (topTracks.isNotEmpty) {
                                if (isArtistPlaying) {
                                  provider.togglePlayPause();
                                } else {
                                  provider.playSong(
                                    topTracks.first,
                                    queue: topTracks,
                                    contextTitle: artist.name,
                                  );
                                }
                              }
                            },
                            child: Container(
                              width: 54,
                              height: 54,
                              decoration: const BoxDecoration(
                                color: SpotifyTheme.spotifyGreen,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black45,
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                isArtistPlaying ? Icons.pause : Icons.play_arrow,
                                color: Colors.black,
                                size: 32,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Section: Populer (Top Tracks)
                      const Text(
                        'Populer',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Top Tracks List
                      ...List.generate(topTracks.length, (index) {
                        final track = topTracks[index];
                        final isCurrentTrack = provider.currentSong?.id == track.id;
                        final isCurrentPlaying = isCurrentTrack && provider.isPlaying;

                        return InkWell(
                          onTap: () {
                            provider.playSong(
                              track,
                              queue: topTracks,
                              contextTitle: artist.name,
                            );
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                            child: Row(
                              children: [
                                // Track number or playing equalizer
                                SizedBox(
                                  width: 26,
                                  child: isCurrentPlaying
                                      ? const Icon(
                                          Icons.equalizer,
                                          color: SpotifyTheme.spotifyGreen,
                                          size: 18,
                                        )
                                      : Text(
                                          '${index + 1}',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: isCurrentTrack
                                                ? SpotifyTheme.spotifyGreen
                                                : SpotifyTheme.textSecondary,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),

                                const SizedBox(width: 8),

                                // Cover thumbnail
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: CachedNetworkImage(
                                    imageUrl: track.albumArtUrl,
                                    width: 46,
                                    height: 46,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, _, _) => Container(
                                      width: 46,
                                      height: 46,
                                      color: const Color(0xFF282828),
                                      child: const Icon(Icons.music_note, color: Colors.white54, size: 20),
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 12),

                                // Title and Stream Count
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        track.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: isCurrentTrack
                                              ? SpotifyTheme.spotifyGreen
                                              : Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        track.album,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: SpotifyTheme.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Song options
                                IconButton(
                                  icon: const Icon(Icons.more_vert, color: Colors.white54, size: 20),
                                  onPressed: () {
                                    _showTrackOptionsModal(context, provider, track);
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      }),

                      const SizedBox(height: 28),

                      // Section: Kumpulan Album & EP (Discography)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Kumpulan Album & EP',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                          ),
                          if (_albums.isNotEmpty)
                            Text(
                              '${_filteredAlbums.length} Rilisan',
                              style: const TextStyle(
                                color: SpotifyTheme.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Filter chips: Semua, Album, Single & EP
                      if (_albums.isNotEmpty) ...[
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: ['Semua', 'Album', 'Single & EP'].map((filter) {
                              final isSelected = _selectedAlbumFilter == filter;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: ChoiceChip(
                                  label: Text(
                                    filter,
                                    style: TextStyle(
                                      color: isSelected ? Colors.black : Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  selected: isSelected,
                                  selectedColor: SpotifyTheme.spotifyGreen,
                                  backgroundColor: const Color(0xFF282828),
                                  showCheckmark: false,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    side: BorderSide.none,
                                  ),
                                  onSelected: (_) {
                                    setState(() {
                                      _selectedAlbumFilter = filter;
                                    });
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Horizontal Scrollable Album Cards
                      if (_isLoadingAlbums)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24.0),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: SpotifyTheme.spotifyGreen,
                              strokeWidth: 2,
                            ),
                          ),
                        )
                      else if (_filteredAlbums.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.0),
                          child: Text(
                            'Belum ada album atau EP yang ditampilkan.',
                            style: TextStyle(color: SpotifyTheme.textSecondary, fontSize: 13),
                          ),
                        )
                      else
                        SizedBox(
                          height: 215,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            itemCount: _filteredAlbums.length,
                            itemBuilder: (ctx, i) {
                              final alb = _filteredAlbums[i];
                              return GestureDetector(
                                onTap: () => _openAlbum(alb),
                                child: Container(
                                  width: 145,
                                  margin: const EdgeInsets.only(right: 14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Album Cover Art
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: CachedNetworkImage(
                                          imageUrl: alb.coverUrl,
                                          width: 145,
                                          height: 145,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, _, _) => Container(
                                            width: 145,
                                            height: 145,
                                            color: const Color(0xFF282828),
                                            child: const Icon(Icons.album, size: 48, color: Colors.white24),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      // Title
                                      Text(
                                        alb.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      // Type & Year
                                      Text(
                                        '${alb.type} • ${alb.releaseYear}',
                                        style: const TextStyle(
                                          color: SpotifyTheme.textSecondary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                      const SizedBox(height: 28),

                      // Section: Tentang (About Hero Card matching Screenshot 1)
                      const Text(
                        'Tentang',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Spotify 1:1 Tentang Artist Card
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFF242424),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Artist Hero Image
                            SizedBox(
                              height: 180,
                              width: double.infinity,
                              child: CachedNetworkImage(
                                imageUrl: artist.headerImageUrl.isNotEmpty
                                    ? artist.headerImageUrl
                                    : artist.imageUrl,
                                fit: BoxFit.cover,
                                errorWidget: (_, _, _) => Container(
                                  color: const Color(0xFF282828),
                                  child: const Icon(Icons.person, size: 60, color: Colors.white24),
                                ),
                              ),
                            ),

                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    artist.name.toUpperCase(),
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.w900,
                                                      letterSpacing: -0.3,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (artist.isVerified) ...[
                                                  const SizedBox(width: 6),
                                                  const Icon(
                                                    Icons.verified,
                                                    color: Color(0xFF3D9BE9),
                                                    size: 16,
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              artist.monthlyListeners,
                                              style: const TextStyle(
                                                color: SpotifyTheme.textSecondary,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Ikuti Button
                                      OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(
                                            color: _isFollowing ? SpotifyTheme.spotifyGreen : Colors.white54,
                                            width: 1.2,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                          backgroundColor: _isFollowing
                                              ? SpotifyTheme.spotifyGreen.withValues(alpha: 0.15)
                                              : Colors.transparent,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _isFollowing = !_isFollowing;
                                          });
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                _isFollowing
                                                    ? 'Mengikuti ${artist.name}'
                                                    : 'Berhenti mengikuti ${artist.name}',
                                              ),
                                              duration: const Duration(seconds: 1),
                                              backgroundColor: SpotifyTheme.cardSurface,
                                            ),
                                          );
                                        },
                                        child: Text(
                                          _isFollowing ? 'Mengikuti' : 'Ikuti',
                                          style: TextStyle(
                                            color: _isFollowing ? SpotifyTheme.spotifyGreen : Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 12),

                                  // Bio with "lihat semua" toggle
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _isBioExpanded = !_isBioExpanded;
                                      });
                                    },
                                    child: RichText(
                                      text: TextSpan(
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                          height: 1.45,
                                        ),
                                        children: [
                                          TextSpan(
                                            text: _isBioExpanded
                                                ? artist.bio
                                                : (artist.bio.length > 130
                                                    ? '${artist.bio.substring(0, 130)}... '
                                                    : artist.bio),
                                          ),
                                          if (artist.bio.length > 130)
                                            TextSpan(
                                              text: _isBioExpanded ? ' sembunyikan' : 'lihat semua',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Section: Fans juga suka (Fans Also Like matching Screenshot 1)
                      if (_relatedArtists.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        const Text(
                          'Fans juga suka',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 165,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            itemCount: _relatedArtists.length,
                            itemBuilder: (ctx, i) {
                              final relArtist = _relatedArtists[i];
                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ArtistDetailScreen(artist: relArtist),
                                    ),
                                  );
                                },
                                child: Container(
                                  width: 115,
                                  margin: const EdgeInsets.only(right: 14),
                                  child: Column(
                                    children: [
                                      // Circular Avatar (radius 48)
                                      CircleAvatar(
                                        radius: 48,
                                        backgroundColor: const Color(0xFF282828),
                                        backgroundImage: CachedNetworkImageProvider(relArtist.imageUrl),
                                      ),
                                      const SizedBox(height: 8),
                                      // Name
                                      Text(
                                        relArtist.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      // Subtitle: Artis
                                      const Text(
                                        'Artis',
                                        style: TextStyle(
                                          color: SpotifyTheme.textSecondary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],

                      // Bottom spacing for miniplayer
                      const SizedBox(height: 150),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Persistent MiniPlayer at Bottom
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: MiniPlayer(),
          ),
        ],
      ),
    );
  }

  void _showTrackOptionsModal(BuildContext context, MusicPlayerProvider provider, Song song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF282828),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final isLiked = provider.isSongLiked(song.id);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: CachedNetworkImage(imageUrl: song.albumArtUrl, width: 44, height: 44, fit: BoxFit.cover),
                ),
                title: Text(song.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text(song.artist, style: const TextStyle(color: SpotifyTheme.textSecondary)),
              ),
              const Divider(color: Colors.white12),
              ListTile(
                leading: Icon(
                  isLiked ? Icons.favorite : Icons.favorite_border,
                  color: isLiked ? SpotifyTheme.spotifyGreen : Colors.white,
                ),
                title: Text(
                  isLiked ? 'Hapus dari Lagu yang Disukai' : 'Sukai',
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  provider.toggleLike(song);
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.playlist_add, color: Colors.white),
                title: const Text('Tambahkan ke Playlist', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAddToPlaylistDialog(context, provider, song);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_outlined, color: Colors.white),
                title: const Text('Bagikan', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  NativeBridge.shareSong(
                    title: song.title,
                    text: 'Dengarkan lagu "${song.title}" oleh ${song.artist} di musixspot!\nhttps://open.spotify.com/track/${song.id}',
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddToPlaylistDialog(BuildContext context, MusicPlayerProvider provider, Song song) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: SpotifyTheme.cardSurface,
          title: const Text('Pilih Playlist', style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: provider.playlists.length,
              itemBuilder: (ctx, i) {
                final p = provider.playlists[i];
                return ListTile(
                  title: Text(p.title, style: const TextStyle(color: Colors.white)),
                  subtitle: Text('${p.songs.length} lagu', style: const TextStyle(color: SpotifyTheme.textSecondary, fontSize: 12)),
                  trailing: const Icon(Icons.add, color: SpotifyTheme.spotifyGreen),
                  onTap: () {
                    provider.addSongToPlaylist(p.id, song);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Ditambahkan ke ${p.title}')),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal', style: TextStyle(color: SpotifyTheme.textSecondary)),
            ),
          ],
        );
      },
    );
  }
}
