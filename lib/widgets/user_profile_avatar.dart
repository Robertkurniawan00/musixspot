import 'package:flutter/material.dart';
import '../services/spotify_platinum_service.dart';
import 'theme_picker_sheet.dart';

/// Spotify authentic profile avatar button
/// Standard 36×36 circular gradient with active profile initial
class UserProfileAvatar extends StatelessWidget {
  final double size;
  final VoidCallback? onProfileUpdated;

  const UserProfileAvatar({
    super.key,
    this.size = 36,
    this.onProfileUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final letter = SpotifyPlatinumService.activeProfile.avatarLetter;

    return GestureDetector(
      onTap: () async {
        ThemePickerSheet.show(context);
        onProfileUpdated?.call();
      },
      child: Container(
        width: size,
        height: size,
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
            letter,
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.44,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
