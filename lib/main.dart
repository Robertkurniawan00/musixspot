import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:audio_service/audio_service.dart';
import 'providers/music_player_provider.dart';
import 'theme/spotify_theme.dart';
import 'screens/splash_screen.dart';
import 'services/language_service.dart';
import 'services/user_behavior_service.dart';
import 'services/background_audio_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LanguageService.init();
  await UserBehaviorService.init();

  try {
    await AudioService.init(
      builder: () => MusixspotAudioHandler.instance,
      config: AudioServiceConfig(
        androidNotificationChannelId: 'com.spotifyclone.musicplayer.channel.audio',
        androidNotificationChannelName: 'musixspot Playback',
        androidNotificationOngoing: true,
        androidNotificationIcon: 'drawable/ic_stat_music',
        androidStopForegroundOnPause: false,
      ),
    );
  } catch (e) {
    debugPrint('AudioService init error: $e');
  }

  // Dark navigation bar and status bar to match Spotify's immersive UI
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const MusixspotApp());
}

class MusixspotApp extends StatelessWidget {
  const MusixspotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: LanguageService.instance),
        ChangeNotifierProvider(create: (_) => MusicPlayerProvider()),
      ],
      child: Consumer2<MusicPlayerProvider, LanguageService>(
        builder: (context, musicProvider, languageService, _) {
          return MaterialApp(
            title: 'musixspot',
            debugShowCheckedModeBanner: false,
            theme: SpotifyTheme.getThemeData(musicProvider.themeMode),
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
