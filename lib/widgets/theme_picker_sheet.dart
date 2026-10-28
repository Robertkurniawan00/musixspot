import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/music_player_provider.dart';
import '../services/language_service.dart';
import '../services/spotify_platinum_service.dart';
import '../screens/favorite_artists_onboarding_screen.dart';
import '../theme/spotify_theme.dart';

class ThemePickerSheet extends StatefulWidget {
  const ThemePickerSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const ThemePickerSheet(),
    );
  }

  @override
  State<ThemePickerSheet> createState() => _ThemePickerSheetState();
}

class _ThemePickerSheetState extends State<ThemePickerSheet> {
  int _favArtistCount = 0;

  @override
  void initState() {
    super.initState();
    _loadFavArtistCount();
  }

  Future<void> _loadFavArtistCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('favorite_artist_ids') ?? [];
      if (mounted) {
        setState(() {
          _favArtistCount = list.length;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MusicPlayerProvider>();
    final currentMode = provider.themeMode;
    final isIndo = LanguageService.isIndonesian;

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Padding(
          padding: EdgeInsets.only(
            left: 20.0,
            right: 20.0,
            top: 12.0,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16.0,
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Grab Bar
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── 1. SPOTIFY USER PROFILE HEADER (Editable) ──
                InkWell(
                  onTap: () => _showEditProfileDialog(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFF3E5A70), Color(0xFF1E2B37)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              SpotifyPlatinumService.activeProfile.avatarLetter,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      SpotifyPlatinumService.activeProfile.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.edit_outlined, color: Colors.white54, size: 15),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isIndo ? 'Ketuk untuk ubah nama profil' : 'Tap to edit profile name',
                                style: const TextStyle(
                                  color: SpotifyTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                const Divider(color: Colors.white10, height: 1),
                const SizedBox(height: 12),

                // ── 2. PREFERENSI (Hanya jika belum memilih artis) ──
                if (_favArtistCount == 0) ...[
                  _buildSectionHeader(isIndo ? 'PREFERENSI' : 'PREFERENCES'),
                  const SizedBox(height: 4),
                  _buildSettingTile(
                    icon: Icons.person_search_outlined,
                    title: isIndo ? 'Pilih Artis Favorit' : 'Favorite Artists',
                    subtitle: isIndo
                        ? 'Personalisasi artis di beranda'
                        : 'Personalize artists on home',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FavoriteArtistsOnboardingScreen(
                            isFromSettings: true,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  const Divider(color: Colors.white10, height: 1),
                  const SizedBox(height: 12),
                ],

                // ── 3. BAHASA APLIKASI (Minimalist Inline Segmented Control) ──
                _buildSectionHeader(isIndo ? 'BAHASA' : 'LANGUAGE'),
                const SizedBox(height: 10),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.language_rounded, color: Colors.white70, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isIndo ? 'Bahasa Aplikasi' : 'App Language',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      // Sleek dual-pill toggle
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C2C2C),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildLanguagePill(
                              label: 'Indonesia',
                              isSelected: isIndo,
                              onTap: () async {
                                await LanguageService.setLanguage(AppLanguage.indonesian);
                                setState(() {});
                              },
                            ),
                            _buildLanguagePill(
                              label: 'English',
                              isSelected: !isIndo,
                              onTap: () async {
                                await LanguageService.setLanguage(AppLanguage.english);
                                setState(() {});
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),
                const Divider(color: Colors.white10, height: 1),
                const SizedBox(height: 12),

                // ── 4. TEMA TAMPILAN (Sleek Clean Radio List, No Hex Codes, No Bulky Boxes) ──
                _buildSectionHeader(isIndo ? 'TEMA TAMPILAN' : 'DISPLAY THEME'),
                const SizedBox(height: 4),

                _buildThemeTile(
                  title: 'Dark (Standar)',
                  colorDot: const Color(0xFF1DB954),
                  isSelected: currentMode == AppThemeMode.spotifyDark,
                  onTap: () => provider.setThemeMode(AppThemeMode.spotifyDark),
                ),
                _buildThemeTile(
                  title: 'AMOLED Black',
                  colorDot: Colors.black,
                  borderColor: Colors.white30,
                  isSelected: currentMode == AppThemeMode.amoledBlack,
                  onTap: () => provider.setThemeMode(AppThemeMode.amoledBlack),
                ),
                _buildThemeTile(
                  title: 'Soft Pink',
                  colorDot: const Color(0xFFFF70A6),
                  isSelected: currentMode == AppThemeMode.softPink,
                  onTap: () => provider.setThemeMode(AppThemeMode.softPink),
                ),

                const SizedBox(height: 14),
                const Divider(color: Colors.white10, height: 1),
                const SizedBox(height: 14),

                // ── 5. SUBTLE FOOTER ──
                Center(
                  child: Column(
                    children: [
                      Text(
                        'musixspot v1.0.0',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isIndo ? 'Audio Lossless • Tanpa Batas' : 'Lossless Audio • Limitless',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: SpotifyTheme.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9.0, horizontal: 4.0),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70, size: 21),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: SpotifyTheme.textSecondary,
                      fontSize: 11.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white38,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguagePill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? SpotifyTheme.spotifyGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildThemeTile({
    required String title,
    required Color colorDot,
    Color? borderColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9.0, horizontal: 4.0),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: colorDot,
                shape: BoxShape.circle,
                border: Border.all(
                  color: borderColor ?? Colors.white24,
                  width: 1.2,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check,
                color: SpotifyTheme.spotifyGreen,
                size: 19,
              ),
          ],
        ),
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context) {
    final active = SpotifyPlatinumService.activeProfile;
    final controller = TextEditingController(text: active.name);

    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: const Color(0xFF282828),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Ubah Nama Profil',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan nama tampilan profil kamu:',
              style: TextStyle(color: SpotifyTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF383838),
                hintText: 'Nama profil...',
                hintStyle: const TextStyle(color: Colors.white38),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: SpotifyTheme.spotifyGreen, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Batal', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: SpotifyTheme.spotifyGreen,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                final playerProvider = context.read<MusicPlayerProvider>();
                await SpotifyPlatinumService.updateProfile(
                  active.id,
                  name: newName,
                  letter: newName.substring(0, 1).toUpperCase(),
                );
                playerProvider.notifyAll();
                if (mounted) {
                  setState(() {});
                }
              }
              if (dCtx.mounted) Navigator.pop(dCtx);
            },
            child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
