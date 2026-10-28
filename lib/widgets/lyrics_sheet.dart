import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/music_player_provider.dart';
import '../services/lyrics_service.dart';
import '../services/native_bridge.dart';
import '../services/artist_navigation_service.dart';

class LyricsSheet extends StatefulWidget {
  final Song song;

  const LyricsSheet({super.key, required this.song});

  @override
  State<LyricsSheet> createState() => _LyricsSheetState();
}

class _LyricsSheetState extends State<LyricsSheet> {
  List<SyncedLyricLine> _lyrics = [];
  bool _isLoading = true;
  String? _loadedSongId;
  final ScrollController _scrollController = ScrollController();
  int _lastActiveIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadLyrics();
  }

  @override
  void didUpdateWidget(covariant LyricsSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.id != widget.song.id) {
      _loadLyrics();
    }
  }

  Future<void> _loadLyrics() async {
    final song = widget.song;
    if (_loadedSongId == song.id) return;
    _loadedSongId = song.id;

    setState(() {
      _isLoading = true;
    });

    final fallback = song.lyrics != null && song.lyrics!.isNotEmpty
        ? song.lyrics!.map((l) => l.text).join('\n')
        : null;

    final lines = await LyricsService.fetchSyncedLyrics(
      trackName: song.title,
      artistName: song.artist,
      songDuration: song.duration,
      fallbackLyrics: fallback,
    );

    if (mounted && _loadedSongId == song.id) {
      setState(() {
        _lyrics = lines;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToIndex(int index) {
    if (!_scrollController.hasClients || index < 0) return;
    const itemHeight = 36.0;
    final targetOffset = (index * itemHeight) - 36.0;
    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MusicPlayerProvider>();
    final currentPos = provider.position;

    // Spotify Card Tint: Dominant color darkened with saturation
    final cardColor = Color.lerp(
          provider.dominantColor,
          const Color(0xFF1E2022),
          0.45,
        ) ??
        const Color(0xFF282828);

    // Find active lyric index
    int activeIndex = -1;
    for (int i = 0; i < _lyrics.length; i++) {
      if (currentPos >= _lyrics[i].timestamp) {
        activeIndex = i;
      } else {
        break;
      }
    }

    if (activeIndex != _lastActiveIndex && activeIndex >= 0) {
      _lastActiveIndex = activeIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToIndex(activeIndex);
      });
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openFullscreenLyrics(context, provider, cardColor),
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! < -150) {
          _openFullscreenLyrics(context, provider, cardColor);
        }
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 8, bottom: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header: "Lirik" + Fullscreen Expand Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Lirik',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                GestureDetector(
                  onTap: () => _openFullscreenLyrics(context, provider, cardColor),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.fullscreen, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Perbesar',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Lyric Lines Container (Compact Spotify Preview ~120dp)
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20.0),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Menyelaraskan lirik...',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              )
            else if (_lyrics.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Center(
                  child: Text(
                    'Lirik tidak tersedia untuk lagu ini.',
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ),
              )
            else
              SizedBox(
                height: 120,
                child: ListView.builder(
                  controller: _scrollController,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _lyrics.length,
                  itemBuilder: (ctx, index) {
                    final line = _lyrics[index];
                    final isCurrent = index == activeIndex;
                    final isPast = index < activeIndex;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                        style: TextStyle(
                          color: isCurrent
                              ? Colors.white
                              : isPast
                                  ? Colors.white.withValues(alpha: 0.65)
                                  : Colors.white.withValues(alpha: 0.30),
                          fontSize: isCurrent ? 20 : 16,
                          fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                          height: 1.35,
                          letterSpacing: -0.3,
                        ),
                        child: Text(
                          line.text,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openFullscreenLyrics(
    BuildContext context,
    MusicPlayerProvider provider,
    Color backgroundColor,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _FullscreenLyricsModal(
          song: widget.song,
          lyrics: _lyrics,
          backgroundColor: backgroundColor,
        );
      },
    );
  }
}

class _FullscreenLyricsModal extends StatefulWidget {
  final Song song;
  final List<SyncedLyricLine> lyrics;
  final Color backgroundColor;

  const _FullscreenLyricsModal({
    required this.song,
    required this.lyrics,
    required this.backgroundColor,
  });

  @override
  State<_FullscreenLyricsModal> createState() => _FullscreenLyricsModalState();
}

class _FullscreenLyricsModalState extends State<_FullscreenLyricsModal> {
  final ScrollController _fullscreenScroll = ScrollController();
  int _lastActiveIndex = -1;
  DateTime? _lastUserTouchTime;

  @override
  void dispose() {
    _fullscreenScroll.dispose();
    super.dispose();
  }

  void _scrollToIndex(int index) {
    if (!_fullscreenScroll.hasClients || index < 0) return;
    if (_lastUserTouchTime != null &&
        DateTime.now().difference(_lastUserTouchTime!).inSeconds < 4) {
      return;
    }
    const itemHeight = 70.0;
    final screenHeight = MediaQuery.of(context).size.height;
    final targetOffset = (index * itemHeight) - (screenHeight * 0.35);
    _fullscreenScroll.animateTo(
      targetOffset.clamp(0.0, _fullscreenScroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MusicPlayerProvider>();
    final currentPos = provider.position;

    int activeIndex = -1;
    for (int i = 0; i < widget.lyrics.length; i++) {
      if (currentPos >= widget.lyrics[i].timestamp) {
        activeIndex = i;
      } else {
        break;
      }
    }

    if (activeIndex != _lastActiveIndex && activeIndex >= 0) {
      _lastActiveIndex = activeIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToIndex(activeIndex);
      });
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.94,
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Top Bar: Dismiss down arrow + Song info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down, size: 32, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            Navigator.pop(context);
                            ArtistNavigationService.navigateToArtist(context, widget.song.artist);
                          },
                          child: Text(
                            widget.song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.share_outlined, color: Colors.white, size: 22),
                    tooltip: 'Bagikan Lirik',
                    onPressed: () {
                      final currentLine = activeIndex >= 0 && activeIndex < widget.lyrics.length
                          ? widget.lyrics[activeIndex].text
                          : '';
                      NativeBridge.shareSong(
                        title: widget.song.title,
                        text: currentLine.isNotEmpty
                            ? '♫ "$currentLine" — ${widget.song.title} (${widget.song.artist}) di musixspot'
                            : 'Lirik lagu "${widget.song.title}" (${widget.song.artist}) di musixspot',
                      );
                    },
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),

            // Fullscreen Karaoke Lyrics List
            Expanded(
              child: widget.lyrics.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                              child: const Icon(
                                Icons.lyrics_outlined,
                                color: Colors.white60,
                                size: 32,
                              ),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'Lirik belum tersedia',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Kami sedang memperbarui database lirik secara berkala untuk lagu ini.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : NotificationListener<UserScrollNotification>(
                      onNotification: (notif) {
                        _lastUserTouchTime = DateTime.now();
                        return false;
                      },
                      child: ListView.builder(
                        controller: _fullscreenScroll,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                itemCount: widget.lyrics.length,
                itemBuilder: (ctx, index) {
                  final line = widget.lyrics[index];
                  final isCurrent = index == activeIndex;
                  final isPast = index < activeIndex;

                  return GestureDetector(
                    onTap: () {
                      provider.seek(line.timestamp);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                        style: TextStyle(
                          color: isCurrent
                              ? Colors.white
                              : isPast
                                  ? Colors.white.withValues(alpha: 0.80)
                                  : Colors.white.withValues(alpha: 0.38),
                          fontSize: isCurrent ? 30 : 24,
                          fontWeight: isCurrent ? FontWeight.w900 : FontWeight.w700,
                          height: 1.4,
                          letterSpacing: -0.5,
                        ),
                        child: Text(line.text),
                      ),
                    ),
                  );
                },
              ),
            ),
            ),
          ],
        ),
      ),
    );
  }
}
