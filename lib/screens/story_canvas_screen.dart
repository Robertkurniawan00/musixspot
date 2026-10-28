import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/music_player_provider.dart';
import '../theme/spotify_theme.dart';

class StoryCanvasScreen extends StatefulWidget {
  final String title;
  final Song song;
  final List<String> hashtags;
  final List<String> backgroundImages;

  const StoryCanvasScreen({
    super.key,
    required this.title,
    required this.song,
    this.hashtags = const ['#pop', '#hits', '#trending'],
    this.backgroundImages = const [],
  });

  @override
  State<StoryCanvasScreen> createState() => _StoryCanvasScreenState();
}

class _StoryCanvasScreenState extends State<StoryCanvasScreen> with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  int _currentSegmentIndex = 0;
  bool _isMuted = false;
  bool _isFollowing = false;
  late List<String> _scenes;

  @override
  void initState() {
    super.initState();
    _scenes = widget.backgroundImages.isNotEmpty
        ? widget.backgroundImages
        : [
            widget.song.albumArtUrl,
            'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=800&q=80',
            'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=800&q=80',
          ];

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    );

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (_currentSegmentIndex < _scenes.length - 1) {
          setState(() {
            _currentSegmentIndex++;
          });
          _progressController.reset();
          _progressController.forward();
        } else {
          // Loop or close
          setState(() {
            _currentSegmentIndex = 0;
          });
          _progressController.reset();
          _progressController.forward();
        }
      }
    });

    _progressController.forward();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  void _nextSegment() {
    if (_currentSegmentIndex < _scenes.length - 1) {
      setState(() {
        _currentSegmentIndex++;
      });
      _progressController.reset();
      _progressController.forward();
    }
  }

  void _prevSegment() {
    if (_currentSegmentIndex > 0) {
      setState(() {
        _currentSegmentIndex--;
      });
      _progressController.reset();
      _progressController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MusicPlayerProvider>();
    final isLiked = provider.isSongLiked(widget.song.id);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Fullscreen Background Image / Video Canvas
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              child: CachedNetworkImage(
                key: ValueKey(_currentSegmentIndex),
                imageUrl: _scenes[_currentSegmentIndex],
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorWidget: (_, _, _) => Container(color: const Color(0xFF1E2832)),
              ),
            ),
          ),

          // 2. Cinematic Dark Gradients (Top & Bottom for text legibility)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.7),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.85),
                  ],
                  stops: const [0.0, 0.2, 0.6, 1.0],
                ),
              ),
            ),
          ),

          // 3. Touch zones for stories navigation (Left = prev, Right = next)
          Positioned.fill(
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _prevSegment,
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _nextSegment,
                  ),
                ),
              ],
            ),
          ),

          // 4. Top Segmented Progress Bar & Title Controls
          SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                // Story Progress Segments
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: List.generate(_scenes.length, (index) {
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2.0),
                          height: 3,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: index < _currentSegmentIndex
                              ? Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                )
                              : (index == _currentSegmentIndex
                                  ? AnimatedBuilder(
                                      animation: _progressController,
                                      builder: (_, _) => FractionallySizedBox(
                                        alignment: Alignment.centerLeft,
                                        widthFactor: _progressController.value,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                      ),
                                    )
                                  : const SizedBox()),
                        ),
                      );
                    }),
                  ),
                ),

                const SizedBox(height: 8),

                // Top Navigation Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Text(
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _isMuted ? Icons.volume_off : Icons.volume_up,
                          color: Colors.white,
                          size: 22,
                        ),
                        onPressed: () {
                          setState(() {
                            _isMuted = !_isMuted;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 5. Bottom Overlay: Artist info, Hashtags, and Music pill card (Screenshot 3)
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Artist Row with "+2", "Ikuti", Share, and Options
                  Row(
                    children: [
                      // Artist Avatars
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundImage: CachedNetworkImageProvider(widget.song.albumArtUrl),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.black87,
                                shape: BoxShape.circle,
                              ),
                              child: const Text(
                                '+2',
                                style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 10),

                      // Artist Name
                      Expanded(
                        child: Text(
                          widget.song.artist,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      // "Ikuti" Button
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: _isFollowing ? const Color(0xFF1DB954) : Colors.white70,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          minimumSize: const Size(60, 32),
                        ),
                        onPressed: () {
                          setState(() {
                            _isFollowing = !_isFollowing;
                          });
                        },
                        child: Text(
                          _isFollowing ? 'Mengikuti' : 'Ikuti',
                          style: TextStyle(
                            color: _isFollowing ? const Color(0xFF1DB954) : Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Share icon
                      IconButton(
                        icon: const Icon(Icons.share_outlined, color: Colors.white, size: 22),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Tautan canvas dibagikan!'), duration: Duration(milliseconds: 900)),
                          );
                        },
                      ),

                      // More options
                      const Icon(Icons.more_vert, color: Colors.white, size: 22),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Hashtags Row (e.g., #edm #house #elektronik)
                  Wrap(
                    spacing: 8,
                    children: widget.hashtags.map((tag) {
                      return Text(
                        tag,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 12),

                  // Bottom Music Pill Card (Album art, Track Title, Artist, Like Button)
                  GestureDetector(
                    onTap: () {
                      provider.playSong(widget.song, contextTitle: widget.title);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF181818).withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: CachedNetworkImage(
                              imageUrl: widget.song.albumArtUrl,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.song.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  widget.song.artist,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          // Like button (+)
                          IconButton(
                            icon: Icon(
                              isLiked ? Icons.check_circle : Icons.add_circle_outline,
                              color: isLiked ? SpotifyTheme.spotifyGreenLight : Colors.white,
                              size: 26,
                            ),
                            onPressed: () {
                              provider.toggleLike(widget.song);
                            },
                          ),
                        ],
                      ),
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
