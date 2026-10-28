import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/music_player_provider.dart';
import '../services/spotify_platinum_service.dart';
import '../models/spotify_platinum_profile.dart';
import '../theme/spotify_theme.dart';

class SpotifyPlatinumSheet extends StatefulWidget {
  const SpotifyPlatinumSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const SpotifyPlatinumSheet(),
    );
  }

  @override
  State<SpotifyPlatinumSheet> createState() => _SpotifyPlatinumSheetState();
}

class _SpotifyPlatinumSheetState extends State<SpotifyPlatinumSheet> {
  static const Color platinumLime = Color(0xFFE5FB52); // Exact Spotify Platinum Yellow/Lime

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MusicPlayerProvider>();
    final isPlatinum = SpotifyPlatinumService.isPlatinum;
    final activeProfile = SpotifyPlatinumService.activeProfile;

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        padding: EdgeInsets.only(
          left: 20.0,
          right: 20.0,
          top: 14.0,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20.0,
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pull bar indicator
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── SCREENSHOT 1:1 HEADER ──
              Row(
                children: [
                  // Spotify icon (3 waves)
                  Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.graphic_eq_rounded,
                        color: Colors.black,
                        size: 17,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Premium',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const Spacer(),
                  if (isPlatinum)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: platinumLime.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: platinumLime),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded, color: platinumLime, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'AKTIF',
                            style: TextStyle(
                              color: platinumLime,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // "Platinum" in bold Spotify lime
              const Text(
                'Platinum',
                style: TextStyle(
                  color: platinumLime,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 4),

              // "Rp 119.900/bulan"
              const Text(
                'Rp 119.900/bulan',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 22),

              // ── BULLET POINTS (MATCHING SCREENSHOT) ──
              _buildBulletPoint('Hingga 3 akun Platinum', icon: Icons.people_alt_rounded),
              _buildBulletPoint('Download untuk mendengarkan offline', icon: Icons.download_done_rounded),
              _buildBulletPoint('Kualitas audio lossless (hingga ~24-bit/44,1 kHz)', icon: Icons.high_quality_rounded),
              _buildBulletPoint('Mix playlist-mu', icon: Icons.shuffle_rounded),
              _buildBulletPoint('Studio Master Audio & Equalizer Pro', icon: Icons.graphic_eq_rounded),
              _buildBulletPoint('Hubungkan perangkat lunak DJ-mu', icon: Icons.album_rounded),
              _buildBulletPoint('Pembatalan kapan saja', icon: Icons.cancel_outlined),

              const SizedBox(height: 24),

              // ── CTA BUTTON (MATCHING SCREENSHOT) ──
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: platinumLime,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () async {
                    await SpotifyPlatinumService.setPlatinumActive(true);
                    provider.notifyAll();
                    setState(() {});
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: const Color(0xFF282828),
                          content: Row(
                            children: [
                              const Icon(Icons.stars_rounded, color: platinumLime),
                              const SizedBox(width: 10),
                              Text(
                                isPlatinum
                                    ? 'Fitur MusicXSpot Platinum siap digunakan!'
                                    : 'Selamat! Akunmu telah ditingkatkan ke MusicXSpot Platinum.',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                  },
                  child: Text(
                    isPlatinum ? 'Kelola Fitur Platinum' : 'Dapatkan Premium Platinum',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Footer notice (matching screenshot)
              const Center(
                child: Text(
                  'Untuk maksimal 3 individu yang tinggal di alamat yang sama.\nPersyaratan berlaku.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),

              const SizedBox(height: 24),
              const Divider(color: Colors.white12),
              const SizedBox(height: 16),

              // ── PLATINUM CONTROL SUITE (NO GIMMICKS) ──
              const Text(
                'KONTROL FITUR PLATINUM',
                style: TextStyle(
                  color: SpotifyTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 12),

              // 1. Akun Platinum Switcher (3 Akun)
              _buildFeatureTile(
                icon: Icons.people_outline_rounded,
                title: 'Akun Platinum Aktif (${activeProfile.name})',
                subtitle: activeProfile.subtitle,
                actionLabel: 'Ganti',
                onAction: () => _showProfileSwitcherDialog(context),
              ),

              // 2. Audio Fidelity (24-bit / 44.1 kHz Lossless)
              _buildFeatureTile(
                icon: Icons.graphic_eq_rounded,
                title: 'Audio Lossless (24-bit / 44,1 kHz)',
                subtitle: SpotifyPlatinumService.fidelity == AudioFidelityTier.platinumLossless24Bit
                    ? 'Studio Master FLAC (~1411-2304 kbps)'
                    : 'Standard / High Resolution AAC',
                actionLabel: 'Atur',
                onAction: () => _showAudioFidelitySheet(context, provider),
              ),

              // 5. DJ Mixer & Crossfader
              _buildFeatureTile(
                icon: Icons.tune_rounded,
                title: 'DJ Mixer & Automix',
                subtitle: 'Crossfade ${SpotifyPlatinumService.crossfadeSeconds}s • Link Pioneer/Virtual DJ',
                actionLabel: 'Setting',
                onAction: () => _showDjMixerDialog(context, provider),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBulletPoint(String text, {required IconData icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onAction,
    bool highlight = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlight ? platinumLime.withValues(alpha: 0.3) : Colors.white10,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: highlight ? platinumLime : Colors.white70, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: highlight ? platinumLime : Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              side: BorderSide(color: highlight ? platinumLime : Colors.white30),
              foregroundColor: highlight ? platinumLime : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ),
            onPressed: onAction,
            child: Text(
              actionLabel,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showProfileSwitcherDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF242424),
          title: const Row(
            children: [
              Icon(Icons.people_alt_rounded, color: platinumLime),
              SizedBox(width: 8),
              Text(
                'Pilih Akun Platinum',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: SpotifyPlatinumService.profiles.map((profile) {
              final isCurrent = profile.id == SpotifyPlatinumService.activeProfile.id;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isCurrent ? platinumLime.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isCurrent ? platinumLime : Colors.transparent,
                  ),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isCurrent ? platinumLime : Colors.grey[700],
                    child: Text(
                      profile.avatarLetter,
                      style: TextStyle(
                        color: isCurrent ? Colors.black : Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    profile.name,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    profile.subtitle,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  trailing: isCurrent
                      ? const Icon(Icons.check_circle_rounded, color: platinumLime)
                      : null,
                  onTap: () async {
                    await SpotifyPlatinumService.switchProfile(profile.id);
                    setState(() {});
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup', style: TextStyle(color: platinumLime)),
            ),
          ],
        );
      },
    );
  }

  void _showAudioFidelitySheet(BuildContext context, MusicPlayerProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF222222),
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
                const Row(
                  children: [
                    Icon(Icons.graphic_eq_rounded, color: platinumLime),
                    SizedBox(width: 8),
                    Text(
                      'Kualitas Audio Streaming',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildFidelityOption(
                  title: 'Platinum Lossless (24-bit / 44,1 kHz)',
                  subtitle: 'Studio Master resolusi tertinggi via FLAC uncompressed (~1411-2304 kbps)',
                  tier: AudioFidelityTier.platinumLossless24Bit,
                  isCurrent: SpotifyPlatinumService.fidelity == AudioFidelityTier.platinumLossless24Bit,
                  ctx: ctx,
                  provider: provider,
                ),
                _buildFidelityOption(
                  title: 'Sangat Tinggi (Very High 320 kbps)',
                  subtitle: 'Format AAC berkualitas tinggi dengan kompresi efisien',
                  tier: AudioFidelityTier.veryHigh320k,
                  isCurrent: SpotifyPlatinumService.fidelity == AudioFidelityTier.veryHigh320k,
                  ctx: ctx,
                  provider: provider,
                ),
                _buildFidelityOption(
                  title: 'Standar (High 160 kbps)',
                  subtitle: 'Penggunaan kuota hemat dengan kualitas seimbang',
                  tier: AudioFidelityTier.standard160k,
                  isCurrent: SpotifyPlatinumService.fidelity == AudioFidelityTier.standard160k,
                  ctx: ctx,
                  provider: provider,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFidelityOption({
    required String title,
    required String subtitle,
    required AudioFidelityTier tier,
    required bool isCurrent,
    required BuildContext ctx,
    required MusicPlayerProvider provider,
  }) {
    return InkWell(
      onTap: () async {
        await SpotifyPlatinumService.setAudioFidelity(tier);
        provider.notifyAll();
        setState(() {});
        if (ctx.mounted) Navigator.pop(ctx);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isCurrent ? platinumLime.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isCurrent ? platinumLime : Colors.white12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isCurrent ? platinumLime : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (isCurrent) const Icon(Icons.check_circle_rounded, color: platinumLime),
          ],
        ),
      ),
    );
  }

  void _showDjMixerDialog(BuildContext context, MusicPlayerProvider provider) {
    int currentCrossfade = SpotifyPlatinumService.crossfadeSeconds;
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF242424),
              title: const Row(
                children: [
                  Icon(Icons.tune_rounded, color: platinumLime),
                  SizedBox(width: 8),
                  Text('DJ Mixer & Automix', style: TextStyle(color: Colors.white, fontSize: 18)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Crossfade Transisi: ${currentCrossfade}s',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  Slider(
                    value: currentCrossfade.toDouble(),
                    min: 0,
                    max: 12,
                    divisions: 12,
                    activeColor: platinumLime,
                    inactiveColor: Colors.white24,
                    onChanged: (val) {
                      setDlgState(() {
                        currentCrossfade = val.toInt();
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.link_rounded, color: platinumLime, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Pioneer DJ / Virtual DJ Link Ready (MIDI Stream Bridge)',
                            style: TextStyle(color: Colors.white70, fontSize: 11.5),
                          ),
                        ),
                      ],
                    ),
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
                    backgroundColor: platinumLime,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () async {
                    await SpotifyPlatinumService.setCrossfadeSeconds(currentCrossfade);
                    setState(() {});
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
