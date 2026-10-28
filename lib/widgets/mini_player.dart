import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'spotify_marquee.dart';
import '../providers/music_player_provider.dart';
import '../theme/spotify_theme.dart';
import '../screens/now_playing_screen.dart';
import '../services/artist_navigation_service.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MusicPlayerProvider>();
    final song = provider.currentSong;

    if (song == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: GestureDetector(
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const NowPlayingScreen(),
          );
        },
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: Color.lerp(provider.themeColors.cardSurface, provider.dominantColor, 0.35) ?? provider.themeColors.cardSurface,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(
                    children: [
                      // Album Cover Thumbnail
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: CachedNetworkImage(
                          imageUrl: song.albumArtUrl,
                          width: 42,
                          height: 42,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: SpotifyTheme.cardSurfaceHighlight,
                            child: const Icon(Icons.music_note, color: Colors.white54, size: 20),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: SpotifyTheme.cardSurfaceHighlight,
                            child: const Icon(Icons.music_note, color: Colors.white54, size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Title & Artist
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: 18,
                              child: SpotifyMarquee(
                                text: song.title,
                                style: const TextStyle(
                                  color: SpotifyTheme.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => ArtistNavigationService.navigateToArtist(context, song.artist),
                              child: Text(
                                provider.playbackErrorMessage ?? song.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: provider.playbackErrorMessage != null
                                      ? Colors.orangeAccent
                                      : SpotifyTheme.textSecondary.withValues(alpha: 0.9),
                                  fontSize: 11,
                                  fontWeight: provider.playbackErrorMessage != null ? FontWeight.w500 : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Device / Connect Icon
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                        icon: Icon(
                          provider.isBluetoothConnected
                              ? Icons.bluetooth_audio
                              : Icons.devices_rounded,
                          color: provider.themeColors.primaryLight,
                          size: 18,
                        ),
                        tooltip: 'Terhubung ke ${provider.connectedDevice}',
                        onPressed: () {
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                provider.isBluetoothConnected
                                    ? 'Bluetooth Audio: ${provider.connectedDevice}'
                                    : 'Audio Output: ${provider.connectedDevice}',
                              ),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                      ),

                      // Like Button
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                        icon: Icon(
                          song.isLiked ? Icons.check_circle : Icons.add_circle_outline_rounded,
                          color: song.isLiked ? provider.themeColors.primaryLight : provider.themeColors.textSecondary,
                          size: 22,
                        ),
                        onPressed: () => provider.toggleLike(song),
                      ),

                      // Play / Pause Icon
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                        icon: provider.isBuffering
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                provider.isPlaying ? Icons.pause : Icons.play_arrow,
                                color: SpotifyTheme.textPrimary,
                                size: 28,
                              ),
                        onPressed: () => provider.togglePlayPause(),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Progress Bar Line (isolated selector to prevent whole widget rebuild)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
                child: Selector<MusicPlayerProvider, double>(
                  selector: (_, p) => p.duration.inMilliseconds > 0
                      ? (p.position.inMilliseconds / p.duration.inMilliseconds).clamp(0.0, 1.0)
                      : 0.0,
                  builder: (_, progress, child) => LinearProgressIndicator(
                    value: progress,
                    minHeight: 2.5,
                    backgroundColor: Colors.white10,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
