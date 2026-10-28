import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/artist.dart';
import '../services/music_api_service.dart';
import '../services/native_bridge.dart';
import '../screens/artist_detail_screen.dart';
import '../models/song.dart';
import '../providers/music_player_provider.dart';
import '../theme/spotify_theme.dart';

class SongTile extends StatelessWidget {
  final Song song;
  final List<Song>? playlistContext;
  final String? contextTitle;
  final bool showLaguPrefix;

  const SongTile({
    super.key,
    required this.song,
    this.playlistContext,
    this.contextTitle,
    this.showLaguPrefix = false,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MusicPlayerProvider>();
    final isCurrent = provider.currentSong?.id == song.id;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: CachedNetworkImage(
          imageUrl: song.albumArtUrl,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            width: 48,
            height: 48,
            color: SpotifyTheme.cardSurfaceHighlight,
            child: const Icon(Icons.music_note, color: Colors.white30, size: 24),
          ),
          errorWidget: (context, url, error) => Container(
            width: 48,
            height: 48,
            color: SpotifyTheme.cardSurfaceHighlight,
            child: const Icon(Icons.music_note, color: Colors.white30, size: 24),
          ),
        ),
      ),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isCurrent ? SpotifyTheme.spotifyGreenLight : SpotifyTheme.textPrimary,
          fontSize: 15,
          fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      subtitle: Row(
        children: [
          if (provider.isSongDownloading(song.id)) ...[
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: provider.themeColors.primaryLight),
            ),
            const SizedBox(width: 5),
          ] else if (song.isDownloaded) ...[
            Icon(Icons.download_done, color: provider.themeColors.primaryLight, size: 14),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(
              showLaguPrefix
                  ? (song.album.toLowerCase().contains('single')
                      ? 'Single • ${song.artist}'
                      : (song.album.toLowerCase().contains('ep')
                          ? 'EP • ${song.artist}'
                          : 'Lagu • ${song.artist}'))
                  : (song.album.isNotEmpty &&
                          !song.album.toLowerCase().contains('official') &&
                          song.album.toLowerCase() != 'unknown album'
                      ? '${song.artist} • ${song.album}'
                      : song.artist),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: SpotifyTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: const Icon(Icons.more_vert, color: SpotifyTheme.textSecondary, size: 20),
            onPressed: () {
              _showSongOptions(context, provider, song);
            },
          ),
          const SizedBox(width: 4),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: Icon(
              song.isLiked ? Icons.check_circle : Icons.add_circle_outline,
              color: song.isLiked ? SpotifyTheme.spotifyGreenLight : SpotifyTheme.textSecondary,
              size: 20,
            ),
            onPressed: () => provider.toggleLike(song),
          ),
        ],
      ),
      onTap: () {
        provider.playSong(
          song,
          queue: playlistContext,
          contextTitle: contextTitle,
        );
      },
    );
  }

  void _showSongOptions(BuildContext context, MusicPlayerProvider provider, Song song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: SpotifyTheme.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: CachedNetworkImage(
                    imageUrl: song.albumArtUrl,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                  ),
                ),
                title: Text(
                  song.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(song.artist),
              ),
              const Divider(color: SpotifyTheme.divider),
              ListTile(
                leading: const Icon(Icons.playlist_add, color: Colors.white),
                title: const Text('Tambahkan ke Playlist'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAddToPlaylistDialog(context, provider, song);
                },
              ),
              ListTile(
                leading: Icon(
                  song.isDownloaded ? Icons.download_done : Icons.download_for_offline_outlined,
                  color: song.isDownloaded ? SpotifyTheme.spotifyGreen : Colors.white,
                ),
                title: Text(song.isDownloaded ? 'Hapus Unduhan' : 'Unduh Lagu Offline'),
                onTap: () async {
                  Navigator.pop(ctx);
                  if (song.isDownloaded) {
                    await provider.removeDownloadedSong(song);
                  } else {
                    await provider.downloadSong(song);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_outlined, color: Colors.white),
                title: const Text('Bagikan'),
                onTap: () {
                  Navigator.pop(ctx);
                  NativeBridge.shareSong(
                    title: song.title,
                    text: 'Dengarkan "${song.title}" oleh ${song.artist} di musixspot!\nhttps://open.spotify.com/track/${song.id}',
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_outline, color: Colors.white),
                title: const Text('Lihat Artis'),
                onTap: () {
                  Navigator.pop(ctx);
                  final artists = MusicApiService.getComprehensiveArtists();
                  final matched = artists.firstWhere(
                    (a) => a.name.toLowerCase() == song.artist.toLowerCase(),
                    orElse: () => Artist(
                      id: 'art_${song.artist.toLowerCase().replaceAll(' ', '_')}',
                      name: song.artist,
                      imageUrl: song.albumArtUrl,
                      headerImageUrl: song.albumArtUrl,
                      monthlyListeners: '1.250.000 pendengar bulanan',
                      bio: 'Profil resmi ${song.artist} di musixspot.',
                      topTracks: [song],
                    ),
                  );
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ArtistDetailScreen(artist: matched)),
                  );
                },
              ),
              const SizedBox(height: 12),
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
