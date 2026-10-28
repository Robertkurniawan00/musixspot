import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/song.dart';
import '../models/playlist.dart';
import '../providers/music_player_provider.dart';
import '../theme/spotify_theme.dart';
import '../widgets/song_tile.dart';
import '../services/music_api_service.dart';
import '../services/playlist_backup_service.dart';
import '../widgets/playlist_cover_widget.dart';
import '../widgets/user_profile_avatar.dart';
import '../services/spotify_platinum_service.dart';
import 'artist_detail_screen.dart';
import 'search_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String _selectedFilter = 'Semua';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MusicPlayerProvider>();
    final likedSongs = provider.likedSongs;
    final playlists = provider.playlists;
    final downloadedSongs = provider.downloadedSongs;

    return Scaffold(
      backgroundColor: SpotifyTheme.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Top App Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // User Avatar (synced 36x36 with active profile)
                        UserProfileAvatar(
                          size: 36,
                          onProfileUpdated: () {
                            if (mounted) setState(() {});
                          },
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Koleksi Kamu',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.search, color: Colors.white, size: 24),
                          tooltip: 'Cari di Koleksi',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const SearchScreen()),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, color: Colors.white, size: 28),
                          tooltip: 'Tambah ke Koleksi',
                          onPressed: () {
                            _showLibraryAddOrBackupSheet(context, provider);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Filter Chips (Playlist, Artis, Album, Diunduh)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ['Semua', 'Playlist', 'Artis', 'Diunduh'].map((filter) {
                          final isSelected = _selectedFilter == filter;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedFilter = filter;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                decoration: BoxDecoration(
                                  color: isSelected ? SpotifyTheme.spotifyGreenLight : const Color(0xFF282828),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  filter,
                                  style: TextStyle(
                                    color: isSelected ? Colors.black : Colors.white,
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Sort Row: Terbaru + View Icon
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.swap_vert, color: Colors.white, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              _selectedFilter == 'Diunduh' ? 'Lagu Tersimpan Offline' : 'Terbaru',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.grid_view, color: Colors.white70, size: 20),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // If "Diunduh" filter is active, show downloaded songs list
            if (_selectedFilter == 'Diunduh') ...[
              if (downloadedSongs.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.download_done, color: Colors.white24, size: 48),
                          SizedBox(height: 12),
                          Text(
                            'Belum ada lagu yang diunduh',
                            style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Sentuh ikon download pada lagu untuk memutar offline tanpa kuota internet.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: SpotifyTheme.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF282828),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.storage_rounded, color: SpotifyTheme.spotifyGreen, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FutureBuilder<int>(
                              future: provider.getDownloadedTotalBytes(),
                              builder: (context, snapshot) {
                                final bytes = snapshot.data ?? 0;
                                final mb = (bytes / (1024 * 1024)).toStringAsFixed(1);
                                return Text(
                                  '${downloadedSongs.length} Lagu • $mb MB terpakai',
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                );
                              },
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (dCtx) => AlertDialog(
                                  backgroundColor: const Color(0xFF282828),
                                  title: const Text('Hapus Semua Unduhan?', style: TextStyle(color: Colors.white)),
                                  content: const Text(
                                    'Semua file audio yang tersimpan di memori perangkat akan dihapus.',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(dCtx),
                                      child: const Text('Batal', style: TextStyle(color: Colors.white70)),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        Navigator.pop(dCtx);
                                        await provider.clearAllDownloadedSongs();
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Semua unduhan offline telah dibersihkan.')),
                                          );
                                        }
                                      },
                                      child: const Text('Hapus', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              );
                            },
                            child: const Text('Hapus Semua', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final song = downloadedSongs[i];
                      return SongTile(
                        song: song,
                        playlistContext: downloadedSongs,
                        contextTitle: 'Lagu Offline Diunduh',
                      );
                    },
                    childCount: downloadedSongs.length,
                  ),
                ),
              ],
            ] else if (_selectedFilter == 'Artis') ...[
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final artist = MusicApiService.getArtists()[i];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                      leading: CircleAvatar(
                        radius: 28,
                        backgroundImage: CachedNetworkImageProvider(artist.imageUrl),
                      ),
                      title: Text(
                        artist.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        'Artis • ${artist.monthlyListeners}',
                        style: const TextStyle(color: SpotifyTheme.textSecondary, fontSize: 13),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ArtistDetailScreen(artist: artist),
                          ),
                        );
                      },
                    );
                  },
                  childCount: MusicApiService.getArtists().length,
                ),
              ),
            ] else ...[
              // Pinned Item: Lagu yang Disukai (Spotify Signature Liked Songs Row)
              SliverToBoxAdapter(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                  leading: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [SpotifyTheme.likedSongsGradientStart, SpotifyTheme.likedSongsGradientEnd],
                      ),
                    ),
                    child: const Icon(Icons.favorite, color: Colors.white, size: 28),
                  ),
                  title: const Text(
                    'Lagu yang Disukai',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Row(
                    children: [
                      const Icon(Icons.push_pin, color: SpotifyTheme.spotifyGreenLight, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Playlist • ${likedSongs.length} lagu',
                        style: const TextStyle(color: SpotifyTheme.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                  onTap: () {
                    _showLikedSongsSheet(context, provider);
                  },
                ),
              ),

              // User Playlists List
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final pl = playlists[i];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                      leading: PlaylistCoverWidget(
                        playlist: pl,
                        size: 56,
                        borderRadius: 4,
                      ),
                      title: Text(
                        pl.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        pl.subtitle.contains('lagu') || pl.subtitle.contains('track')
                            ? pl.subtitle
                            : (pl.subtitle.isNotEmpty
                                ? '${pl.subtitle} • ${pl.songs.length} lagu'
                                : '${pl.songs.length} lagu'),
                        style: const TextStyle(color: SpotifyTheme.textSecondary, fontSize: 13),
                      ),
                      trailing: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.white54, size: 20),
                        color: const Color(0xFF282828),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        onSelected: (val) {
                          if (val == 'edit') {
                            _showEditPlaylistDialog(context, provider, pl);
                          } else if (val == 'delete') {
                            _showDeletePlaylistDialog(context, provider, pl);
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, color: Colors.white, size: 18),
                                SizedBox(width: 10),
                                Text('Ubah Nama & Info', style: TextStyle(color: Colors.white, fontSize: 13)),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                SizedBox(width: 10),
                                Text('Hapus Playlist', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      onTap: () {
                        _showPlaylistDetailSheet(context, provider, pl);
                      },
                    );
                  },
                  childCount: playlists.length,
                ),
              ),
            ],

            // Bottom Spacing for MiniPlayer & Bottom Nav
            const SliverToBoxAdapter(
              child: SizedBox(height: 120),
            ),
          ],
        ),
      ),
    );
  }

  void _showPlaylistDetailSheet(BuildContext context, MusicPlayerProvider provider, Playlist playlist) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: provider.themeColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            final isDownloading = provider.isPlaylistDownloading(playlist.id);
            final isDownloaded = provider.isPlaylistDownloaded(playlist);
            final progress = provider.getPlaylistDownloadProgress(playlist.id);

            return Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      PlaylistCoverWidget(
                        playlist: playlist,
                        size: 64,
                        borderRadius: 6,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(playlist.title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('${playlist.songs.length} lagu • ${playlist.subtitle}', style: TextStyle(color: provider.themeColors.textSecondary, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Spotify Action Toolbar: Batch Download, Exportify CSV, Shuffle, Play
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                  child: Row(
                    children: [
                      // Spotify Batch Download Action Button
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () async {
                          if (isDownloading) return;
                          if (isDownloaded) {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (dCtx) => AlertDialog(
                                backgroundColor: provider.themeColors.cardSurface,
                                title: const Text('Hapus Unduhan?', style: TextStyle(color: Colors.white)),
                                content: Text('Hapus semua file unduhan untuk "${playlist.title}"?', style: const TextStyle(color: Colors.white70)),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Batal', style: TextStyle(color: Colors.white70))),
                                  TextButton(onPressed: () => Navigator.pop(dCtx, true), child: const Text('Hapus', style: TextStyle(color: Colors.redAccent))),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await provider.removeDownloadedPlaylist(playlist);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Semua unduhan playlist dihapus'), duration: Duration(milliseconds: 1000)),
                                );
                              }
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Mulai mengunduh ${playlist.songs.length} lagu offline...'), duration: const Duration(milliseconds: 1200)),
                            );
                            await provider.downloadPlaylist(playlist);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Selesai mengunduh playlist "${playlist.title}"!')),
                              );
                            }
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDownloaded
                                ? provider.themeColors.primaryLight.withValues(alpha: 0.15)
                                : const Color(0xFF282828),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDownloaded
                                  ? provider.themeColors.primaryLight
                                  : Colors.white24,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isDownloading)
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: provider.themeColors.primaryLight),
                                )
                              else
                                Icon(
                                  isDownloaded
                                      ? Icons.arrow_circle_down
                                      : Icons.arrow_circle_down_outlined,
                                  size: 16,
                                  color: isDownloaded
                                      ? provider.themeColors.primaryLight
                                      : Colors.white70,
                                ),
                              const SizedBox(width: 6),
                              Text(
                                isDownloading
                                    ? 'Mengunduh ${(progress * 100).toInt()}%'
                                    : (isDownloaded
                                        ? 'Diunduh'
                                        : 'Unduh Semua'),
                                style: TextStyle(
                                  color: isDownloaded
                                      ? provider.themeColors.primaryLight
                                      : Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Export to CSV (Exportify format)
                      IconButton(
                        icon: const Icon(Icons.file_download_outlined, color: Colors.white70, size: 22),
                        tooltip: 'Ekspor ke CSV (Exportify)',
                        onPressed: () async {
                          final csv = PlaylistBackupService.exportPlaylistToCsv(playlist);
                          Clipboard.setData(ClipboardData(text: csv));
                          await PlaylistBackupService.saveBackupToFile(csv, '${playlist.title.replaceAll(' ', '_')}.csv');
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Playlist diekspor ke CSV (tersalin ke clipboard & tersimpan)')),
                            );
                          }
                        },
                      ),
                      const SizedBox(width: 4),

                      // Edit Playlist button
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Colors.white70, size: 22),
                        tooltip: 'Ubah Nama & Info',
                        onPressed: () {
                          _showEditPlaylistDialog(context, provider, playlist);
                        },
                      ),

                      // Delete Playlist button
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                        tooltip: 'Hapus Playlist',
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showDeletePlaylistDialog(context, provider, playlist);
                        },
                      ),
                      const Spacer(),

                      // Shuffle Play Button
                      if (playlist.songs.isNotEmpty)
                        IconButton(
                          icon: Icon(
                            Icons.shuffle,
                            color: provider.isShuffle ? provider.themeColors.primaryLight : Colors.white70,
                            size: 24,
                          ),
                          onPressed: () {
                            if (!provider.isShuffle) provider.toggleShuffle();
                            provider.playSong(playlist.songs.first, queue: playlist.songs, contextTitle: playlist.title);
                            Navigator.pop(ctx);
                          },
                        ),

                      // Play All Button
                      if (playlist.songs.isNotEmpty)
                        IconButton(
                          icon: Icon(Icons.play_circle_fill, size: 44, color: provider.themeColors.primaryLight),
                          onPressed: () {
                            provider.playSong(playlist.songs.first, queue: playlist.songs, contextTitle: playlist.title);
                            Navigator.pop(ctx);
                          },
                        ),
                    ],
                  ),
                ),
                const Divider(color: SpotifyTheme.divider),
                Expanded(
                  child: playlist.songs.isEmpty
                      ? Center(
                          child: Text(
                            'Belum ada lagu di playlist ini.\nTambahkan lagu dari menu titik tiga pada lagu!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: provider.themeColors.textSecondary),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: playlist.songs.length,
                          itemBuilder: (_, i) {
                            return SongTile(
                              song: playlist.songs[i],
                              playlistContext: playlist.songs,
                              contextTitle: playlist.title,
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showLikedSongsSheet(BuildContext context, MusicPlayerProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: provider.themeColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final songs = provider.likedSongs;
        final dummyPl = Playlist(
          id: 'liked_songs_virtual',
          title: 'Lagu yang Disukai',
          subtitle: '${songs.length} lagu',
          coverUrl: '',
          songs: songs,
        );
        final isDownloading = provider.isPlaylistDownloading(dummyPl.id);
        final isDownloaded = provider.isPlaylistDownloaded(dummyPl);
        final progress = provider.getPlaylistDownloadProgress(dummyPl.id);

        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Column(
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
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          gradient: const LinearGradient(
                            colors: [SpotifyTheme.likedSongsGradientStart, SpotifyTheme.likedSongsGradientEnd],
                          ),
                        ),
                        child: const Icon(Icons.favorite, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Lagu yang Disukai',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${songs.length} lagu tersimpan',
                            style: TextStyle(color: provider.themeColors.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Spotify Action Toolbar: Batch Download, Exportify CSV, Shuffle, Play
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                  child: Row(
                    children: [
                      // Batch Download Liked Songs
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () async {
                          if (isDownloading) return;
                          if (isDownloaded) {
                            await provider.removeDownloadedPlaylist(dummyPl);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Semua unduhan lagu yang disukai dihapus')),
                              );
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Mengunduh ${songs.length} lagu yang disukai...')),
                            );
                            await provider.downloadPlaylist(dummyPl);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Semua lagu yang disukai berhasil diunduh offline!')),
                              );
                            }
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDownloaded
                                ? provider.themeColors.primaryLight.withValues(alpha: 0.15)
                                : const Color(0xFF282828),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDownloaded
                                  ? provider.themeColors.primaryLight
                                  : Colors.white24,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isDownloading)
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: provider.themeColors.primaryLight),
                                )
                              else
                                Icon(
                                  isDownloaded
                                      ? Icons.arrow_circle_down
                                      : Icons.arrow_circle_down_outlined,
                                  size: 16,
                                  color: isDownloaded
                                      ? provider.themeColors.primaryLight
                                      : Colors.white70,
                                ),
                              const SizedBox(width: 6),
                              Text(
                                isDownloading
                                    ? 'Mengunduh ${(progress * 100).toInt()}%'
                                    : (isDownloaded
                                        ? 'Diunduh'
                                        : 'Unduh Semua'),
                                style: TextStyle(
                                  color: isDownloaded
                                      ? provider.themeColors.primaryLight
                                      : Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Export Liked Songs to CSV
                      IconButton(
                        icon: const Icon(Icons.file_download_outlined, color: Colors.white70, size: 22),
                        tooltip: 'Ekspor Lagu yang Disukai (CSV Exportify)',
                        onPressed: () async {
                          final csv = PlaylistBackupService.exportPlaylistToCsv(dummyPl);
                          Clipboard.setData(ClipboardData(text: csv));
                          await PlaylistBackupService.saveBackupToFile(csv, 'Lagu_yang_Disukai.csv');
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Lagu yang disukai diekspor ke CSV (tersalin & tersimpan)')),
                            );
                          }
                        },
                      ),
                      const Spacer(),

                      // Play All Liked Songs
                      if (songs.isNotEmpty)
                        IconButton(
                          icon: Icon(Icons.play_circle_fill, size: 44, color: provider.themeColors.primaryLight),
                          onPressed: () {
                            provider.playSong(songs.first, queue: songs, contextTitle: 'Lagu yang Disukai');
                            Navigator.pop(ctx);
                          },
                        ),
                    ],
                  ),
                ),
                const Divider(color: SpotifyTheme.divider),
                Expanded(
                  child: songs.isEmpty
                      ? Center(
                          child: Text(
                            'Belum ada lagu yang disukai',
                            style: TextStyle(color: provider.themeColors.textSecondary),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: songs.length,
                          itemBuilder: (_, i) {
                            return SongTile(
                              song: songs[i],
                              playlistContext: songs,
                              contextTitle: 'Lagu yang Disukai',
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- Modal Bottom Sheet: Add Playlist, Import, Backup & Restore ---
  void _showLibraryAddOrBackupSheet(BuildContext context, MusicPlayerProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: provider.themeColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    'Kelola Koleksi & Cadangan',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.shuffle_rounded, color: Color(0xFFE5FB52)),
                  title: const Text('Mix Playlist-mu (Blend Platinum)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Kombinasikan 2 playlist menjadi 1 set DJ harmonis', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showBlendPlaylistsDialog(context, provider);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.playlist_add, color: Colors.white),
                  title: const Text('Buat Playlist Baru', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: Text('Buat playlist kustom lokal', style: TextStyle(color: provider.themeColors.textSecondary, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showCreatePlaylistDialog(context, provider);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.link, color: provider.themeColors.primaryLight),
                  title: const Text('Impor Tautan MusicXSpot / Web (Tanpa Login)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: Text('Tempel link lagu/playlist MusicXSpot publik', style: TextStyle(color: provider.themeColors.textSecondary, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showImportSpotifyDialog(context, provider);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.file_upload_outlined, color: Colors.lightBlueAccent),
                  title: const Text('Impor Playlist CSV / Teks (Exportify)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: Text('Impor file CSV Exportify atau daftar teks', style: TextStyle(color: provider.themeColors.textSecondary, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showImportCsvOrTextDialog(context, provider);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.backup_outlined, color: Colors.orangeAccent),
                  title: const Text('Cadangkan Seluruh Koleksi (CSV / JSON)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: Text('Simpan cadangan playlist & lagu yang disukai', style: TextStyle(color: provider.themeColors.textSecondary, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showBackupExportModal(context, provider);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.restore, color: Colors.tealAccent),
                  title: const Text('Pulihkan Koleksi dari Cadangan (JSON)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: Text('Pulihkan data dari file atau teks cadangan JSON', style: TextStyle(color: provider.themeColors.textSecondary, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showRestoreBackupDialog(context, provider);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showBlendPlaylistsDialog(BuildContext context, MusicPlayerProvider provider) {
    if (provider.playlists.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF282828),
          content: Text('Minimal butuh 2 playlist untuk membuat Mix Playlist (Blend).'),
        ),
      );
      return;
    }

    Playlist? selectedA = provider.playlists.first;
    Playlist? selectedB = provider.playlists.length > 1 ? provider.playlists[1] : provider.playlists.first;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF222222),
              title: const Row(
                children: [
                  Icon(Icons.shuffle_rounded, color: Color(0xFFE5FB52)),
                  SizedBox(width: 8),
                  Text('Mix Playlist-mu (Blend)', style: TextStyle(color: Colors.white, fontSize: 18)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Pilih 2 playlist untuk dicampur harmonis:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 12),
                  const Text('Playlist 1:', style: TextStyle(color: Colors.white54, fontSize: 11)),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: selectedA?.id,
                    dropdownColor: const Color(0xFF2C2C2C),
                    items: provider.playlists.map((p) => DropdownMenuItem(
                      value: p.id,
                      child: Text(p.title, style: const TextStyle(color: Colors.white, fontSize: 13), overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: (val) {
                      setDlgState(() {
                        selectedA = provider.playlists.firstWhere((p) => p.id == val);
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  const Text('Playlist 2:', style: TextStyle(color: Colors.white54, fontSize: 11)),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: selectedB?.id,
                    dropdownColor: const Color(0xFF2C2C2C),
                    items: provider.playlists.map((p) => DropdownMenuItem(
                      value: p.id,
                      child: Text(p.title, style: const TextStyle(color: Colors.white, fontSize: 13), overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: (val) {
                      setDlgState(() {
                        selectedB = provider.playlists.firstWhere((p) => p.id == val);
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Batal', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE5FB52),
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () {
                    if (selectedA != null && selectedB != null) {
                      final blended = SpotifyPlatinumService.blendPlaylists(
                        playlistA: selectedA!,
                        playlistB: selectedB!,
                      );
                      provider.insertPlaylist(blended);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: const Color(0xFF282828),
                          content: Text('Mix Playlist "${blended.title}" berhasil dibuat!'),
                        ),
                      );
                    }
                  },
                  child: const Text('Buat Mix (Blend)', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCreatePlaylistDialog(BuildContext context, MusicPlayerProvider provider) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: provider.themeColors.cardSurface,
        title: const Text('Beri nama playlist Anda', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: textController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Misal: Lagu Semangat Pagi',
            hintStyle: const TextStyle(color: Colors.white38),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: provider.themeColors.primaryLight)),
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Batal', style: TextStyle(color: Colors.white70)),
            onPressed: () => Navigator.pop(ctx),
          ),
          TextButton(
            child: Text('Buat', style: TextStyle(color: provider.themeColors.primaryLight, fontWeight: FontWeight.bold)),
            onPressed: () {
              final name = textController.text.trim().isEmpty ? 'Playlist Saya' : textController.text.trim();
              provider.createPlaylist(name);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Playlist "$name" berhasil dibuat!')),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showEditPlaylistDialog(BuildContext context, MusicPlayerProvider provider, Playlist playlist) {
    final titleController = TextEditingController(text: playlist.title);
    final subtitleController = TextEditingController(text: playlist.subtitle);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: provider.themeColors.cardSurface,
        title: const Text('Ubah Nama & Info Playlist', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Judul Playlist', style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 4),
            TextField(
              controller: titleController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Nama playlist',
                hintStyle: const TextStyle(color: Colors.white38),
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: provider.themeColors.primaryLight)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Deskripsi / Info', style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 4),
            TextField(
              controller: subtitleController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Deskripsi playlist',
                hintStyle: const TextStyle(color: Colors.white38),
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: provider.themeColors.primaryLight)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Batal', style: TextStyle(color: Colors.white70)),
            onPressed: () => Navigator.pop(ctx),
          ),
          TextButton(
            child: Text('Simpan', style: TextStyle(color: provider.themeColors.primaryLight, fontWeight: FontWeight.bold)),
            onPressed: () {
              final newTitle = titleController.text.trim();
              final newSubtitle = subtitleController.text.trim();
              if (newTitle.isNotEmpty) {
                provider.editPlaylist(playlist.id, newTitle: newTitle, newSubtitle: newSubtitle);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Playlist "$newTitle" berhasil diperbarui!')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _showDeletePlaylistDialog(BuildContext context, MusicPlayerProvider provider, Playlist playlist) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: provider.themeColors.cardSurface,
        title: const Text('Hapus Playlist?', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        content: Text(
          'Apakah kamu yakin ingin menghapus playlist "${playlist.title}" dari Koleksi Kamu? Tindakan ini tidak dapat dibatalkan.',
          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            child: const Text('Batal', style: TextStyle(color: Colors.white70)),
            onPressed: () => Navigator.pop(ctx),
          ),
          TextButton(
            child: const Text('Hapus', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            onPressed: () {
              provider.deletePlaylist(playlist.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Playlist "${playlist.title}" telah dihapus')),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- Dialog: Import Public Spotify Link Without Login ---
  void _showImportSpotifyDialog(BuildContext context, MusicPlayerProvider provider) {
    final textController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: provider.themeColors.cardSurface,
          title: const Text('Impor Tautan MusicXSpot', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tanpa login akun! Cukup tempelkan link lagu, album, atau playlist publik MusicXSpot / Spotify:',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'https://open.spotify.com/playlist/... atau musicxspot link',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                  enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: provider.themeColors.primaryLight)),
                ),
              ),
              if (isLoading) ...[
                const SizedBox(height: 16),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: provider.themeColors.primaryLight)),
                      const SizedBox(width: 10),
                      const Text('Mengambil metadata MusicXSpot...', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final url = textController.text.trim();
                      if (url.isEmpty || (!url.contains('spotify.com/') && !url.contains('musicxspot'))) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Masukkan tautan MusicXSpot atau web yang valid!')),
                        );
                        return;
                      }

                      setState(() => isLoading = true);
                      final importedPlaylist = await PlaylistBackupService.importFromSpotifyUrl(url);
                      if (context.mounted) {
                        setState(() => isLoading = false);
                        Navigator.pop(ctx);
                        if (importedPlaylist != null) {
                          await provider.addImportedPlaylist(importedPlaylist);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Berhasil mengimpor "${importedPlaylist.title}" ke koleksi!')),
                            );
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Gagal membaca tautan MusicXSpot. Pastikan playlist/lagu bersifat publik.')),
                          );
                        }
                      }
                    },
              child: Text('Impor', style: TextStyle(color: provider.themeColors.primaryLight, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // --- Dialog: Import Exportify CSV or Text Tracklist ---
  void _showImportCsvOrTextDialog(BuildContext context, MusicPlayerProvider provider) {
    final titleController = TextEditingController(text: 'Playlist Impor Exportify');
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: provider.themeColors.cardSurface,
        title: const Text('Impor CSV / Daftar Lagu', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: titleController,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  labelText: 'Nama Playlist',
                  labelStyle: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Tempelkan isi file CSV Exportify, atau daftar lagu per baris (Artis - Judul):',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: textController,
                maxLines: 6,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                decoration: const InputDecoration(
                  hintText: 'Coldplay - Yellow\nThe Beach Boys - Caroline, No\natau tempel data CSV Exportify...',
                  hintStyle: TextStyle(color: Colors.white30, fontSize: 11),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () async {
              final raw = textController.text.trim();
              if (raw.isEmpty) return;

              List<Song> songs;
              if (raw.contains('Spotify ID,') || raw.contains('Track Name,')) {
                songs = PlaylistBackupService.parseCsv(raw);
              } else {
                songs = PlaylistBackupService.parseTextTracklist(raw);
              }

              if (songs.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tidak ada lagu yang berhasil dikenali dalam teks.')),
                );
                return;
              }

              final newPlaylist = Playlist(
                id: 'custom_import_${DateTime.now().millisecondsSinceEpoch}',
                title: titleController.text.trim().isEmpty ? 'Playlist Impor' : titleController.text.trim(),
                subtitle: '${songs.length} lagu diimpor (Exportify)',
                coverUrl: songs.first.albumArtUrl,
                songs: songs,
              );

              await provider.addImportedPlaylist(newPlaylist);
              if (context.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Berhasil mengimpor playlist dengan ${songs.length} lagu!')),
                );
              }
            },
            child: Text('Impor Playlist', style: TextStyle(color: provider.themeColors.primaryLight, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- Modal: Export Full Library to CSV / JSON ---
  void _showBackupExportModal(BuildContext context, MusicPlayerProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: provider.themeColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cadangkan Koleksi (Tanpa Login)',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Cadangan dapat disimpan sebagai file atau disalin ke papan klip untuk dipindahkan ke perangkat lain:',
                  style: TextStyle(color: provider.themeColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.table_chart_outlined, color: Colors.greenAccent),
                  title: const Text('Ekspor Seluruh Koleksi ke CSV (Exportify)', style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Format CSV kompatibel dengan Exportify & Excel', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  onTap: () async {
                    final csv = PlaylistBackupService.exportAllToCsv(provider.playlists, provider.likedSongs);
                    Clipboard.setData(ClipboardData(text: csv));
                    await PlaylistBackupService.saveBackupToFile(csv, 'Spotify_Koleksi_${DateTime.now().millisecondsSinceEpoch}.csv');
                    if (context.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Koleksi berhasil diekspor format CSV (tersimpan & tersalin)!')),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.data_object, color: Colors.amberAccent),
                  title: const Text('Cadangkan Lengkap ke Format JSON', style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Cadangan komprehensif untuk dipulihkan kembali', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  onTap: () async {
                    final jsonStr = PlaylistBackupService.exportLibraryToJson(provider.playlists, provider.likedSongs);
                    Clipboard.setData(ClipboardData(text: jsonStr));
                    await PlaylistBackupService.saveBackupToFile(jsonStr, 'Spotify_Backup_${DateTime.now().millisecondsSinceEpoch}.json');
                    if (context.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Cadangan JSON dibuat (tersalin ke clipboard & tersimpan di storage)!')),
                      );
                    }
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Dialog: Restore Library from JSON Backup ---
  void _showRestoreBackupDialog(BuildContext context, MusicPlayerProvider provider) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: provider.themeColors.cardSurface,
        title: const Text('Pulihkan dari Cadangan JSON', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tempelkan teks cadangan JSON yang sebelumnya Anda ekspor:',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              maxLines: 6,
              style: const TextStyle(color: Colors.white, fontSize: 11),
              decoration: const InputDecoration(
                hintText: '{\n  "likedSongs": [...],\n  "playlists": [...]\n}',
                hintStyle: TextStyle(color: Colors.white30, fontSize: 11),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () async {
              final raw = textController.text.trim();
              if (raw.isEmpty) return;

              try {
                final Map<String, dynamic> data = json.decode(raw);
                final List<Playlist> playlists = [];
                final List<Song> likedSongs = [];

                if (data['playlists'] != null) {
                  for (final p in data['playlists']) {
                    playlists.add(Playlist.fromJson(p));
                  }
                }
                if (data['likedSongs'] != null) {
                  for (final s in data['likedSongs']) {
                    likedSongs.add(Song.fromJson(s));
                  }
                }

                await provider.restoreLibrary(playlists, likedSongs);
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Berhasil memulihkan ${playlists.length} playlist dan ${likedSongs.length} lagu yang disukai!')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Format JSON tidak valid: $e')),
                  );
                }
              }
            },
            child: Text('Pulihkan', style: TextStyle(color: provider.themeColors.primaryLight, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

