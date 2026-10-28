import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage {
  indonesian,
  english,
}

class LanguageService extends ChangeNotifier {
  static final LanguageService instance = LanguageService._();
  LanguageService._();

  static const String _prefKey = 'spotivibes_language_code';
  static AppLanguage _currentLanguage = AppLanguage.indonesian;

  static AppLanguage get currentLanguage => _currentLanguage;
  static bool get isIndonesian => _currentLanguage == AppLanguage.indonesian;

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_prefKey) ?? 'id';
      _currentLanguage = code == 'en' ? AppLanguage.english : AppLanguage.indonesian;
      instance.notifyListeners();
    } catch (_) {
      _currentLanguage = AppLanguage.indonesian;
    }
  }

  static Future<void> setLanguage(AppLanguage language) async {
    _currentLanguage = language;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, language == AppLanguage.english ? 'en' : 'id');
    } catch (_) {}
    instance.notifyListeners();
  }

  /// Translation strings map
  static final Map<String, Map<AppLanguage, String>> _strings = {
    // Navigation
    'nav_home': {
      AppLanguage.indonesian: 'Home',
      AppLanguage.english: 'Home',
    },
    'nav_search': {
      AppLanguage.indonesian: 'Cari',
      AppLanguage.english: 'Search',
    },
    'nav_library': {
      AppLanguage.indonesian: 'Koleksi Kamu',
      AppLanguage.english: 'Your Library',
    },

    // Search Screen
    'search_title': {
      AppLanguage.indonesian: 'Cari',
      AppLanguage.english: 'Search',
    },
    'search_hint': {
      AppLanguage.indonesian: 'Apa yang ingin kamu dengarkan?',
      AppLanguage.english: 'What do you want to listen to?',
    },
    'search_play_what_you_love': {
      AppLanguage.indonesian: 'Putar yang kamu suka',
      AppLanguage.english: 'Play what you love',
    },
    'search_subtitle': {
      AppLanguage.indonesian: 'Cari artis, lagu, album, dan lainnya.',
      AppLanguage.english: 'Search for artists, songs, albums, and more.',
    },
    'search_browse_all': {
      AppLanguage.indonesian: 'Jelajahi semua',
      AppLanguage.english: 'Browse all',
    },
    'search_no_results': {
      AppLanguage.indonesian: 'Lagu tidak ditemukan',
      AppLanguage.english: 'No songs found',
    },

    // Categories
    'cat_live': {
      AppLanguage.indonesian: 'Acara Live',
      AppLanguage.english: 'Live Events',
    },
    'cat_made_for_you': {
      AppLanguage.indonesian: 'Dibuat Untuk Kamu',
      AppLanguage.english: 'Made For You',
    },
    'cat_new_releases': {
      AppLanguage.indonesian: 'Rilis Baru',
      AppLanguage.english: 'New Releases',
    },
    'cat_indo_music': {
      AppLanguage.indonesian: 'Musik Indonesia',
      AppLanguage.english: 'Indonesian Music',
    },
    'cat_sleep': {
      AppLanguage.indonesian: 'Tidur',
      AppLanguage.english: 'Sleep',
    },
    'cat_at_home': {
      AppLanguage.indonesian: 'Di Rumah',
      AppLanguage.english: 'At Home',
    },
    'cat_chill': {
      AppLanguage.indonesian: 'Chill',
      AppLanguage.english: 'Chill',
    },

    // Home Screen Sections
    'home_good_morning': {
      AppLanguage.indonesian: 'Selamat Pagi',
      AppLanguage.english: 'Good Morning',
    },
    'home_good_afternoon': {
      AppLanguage.indonesian: 'Selamat Siang',
      AppLanguage.english: 'Good Afternoon',
    },
    'home_good_evening': {
      AppLanguage.indonesian: 'Selamat Malam',
      AppLanguage.english: 'Good Evening',
    },
    'home_recently_played': {
      AppLanguage.indonesian: 'Baru saja diputar',
      AppLanguage.english: 'Recently Played',
    },
    'home_trending_region': {
      AppLanguage.indonesian: 'Tangga Lagu Populer Regional',
      AppLanguage.english: 'Regional Trending Hits',
    },
    'home_favorite_artists_picks': {
      AppLanguage.indonesian: 'Berdasarkan Artis Pilihanmu',
      AppLanguage.english: 'Based on Your Favorite Artists',
    },
    'home_nostalgia': {
      AppLanguage.indonesian: 'Kembali Ke Masa Lalu',
      AppLanguage.english: 'Time Capsule Nostalgia',
    },
    'cat_ost_drakor': {
      AppLanguage.indonesian: 'OST Drama Korea',
      AppLanguage.english: 'K-Drama OST',
    },
    'home_kdrama_ost': {
      AppLanguage.indonesian: 'OST Drama Korea Terbaik',
      AppLanguage.english: 'Top K-Drama OSTs',
    },
    'home_anime_ost': {
      AppLanguage.indonesian: 'Soundtrack Anime & J-Pop Legendaris',
      AppLanguage.english: 'Legendary Anime & J-Pop OSTs',
    },

    // Regions
    'region_all': {
      AppLanguage.indonesian: 'Global 🌍',
      AppLanguage.english: 'Global 🌍',
    },
    'region_id': {
      AppLanguage.indonesian: 'Indonesia 🇮🇩',
      AppLanguage.english: 'Indonesia 🇮🇩',
    },
    'region_ph': {
      AppLanguage.indonesian: 'Filipina 🇵🇭',
      AppLanguage.english: 'Philippines 🇵🇭',
    },
    'region_th': {
      AppLanguage.indonesian: 'Thailand 🇹🇭',
      AppLanguage.english: 'Thailand 🇹🇭',
    },
    'region_my': {
      AppLanguage.indonesian: 'Malaysia 🇲🇾',
      AppLanguage.english: 'Malaysia 🇲🇾',
    },

    // Connect & Devices
    'connect_title': {
      AppLanguage.indonesian: 'Connect',
      AppLanguage.english: 'Connect',
    },
    'connect_this_phone': {
      AppLanguage.indonesian: 'Ponsel ini',
      AppLanguage.english: 'This phone',
    },
    'connect_normal_badge': {
      AppLanguage.indonesian: 'Normal',
      AppLanguage.english: 'Normal',
    },
    'connect_other_devices': {
      AppLanguage.indonesian: 'Pilih perangkat lain',
      AppLanguage.english: 'Select another device',
    },
    'connect_find_bluetooth': {
      AppLanguage.indonesian: 'Temukan perangkat Bluetooth',
      AppLanguage.english: 'Find Bluetooth devices',
    },
    'connect_searching': {
      AppLanguage.indonesian: 'Mencari perangkat...',
      AppLanguage.english: 'Searching for devices...',
    },

    // Player & Lyrics
    'lyrics_title': {
      AppLanguage.indonesian: 'LIRIK',
      AppLanguage.english: 'LYRICS',
    },
    'queue_title': {
      AppLanguage.indonesian: 'Antrean Saat Ini',
      AppLanguage.english: 'Now Playing Queue',
    },
    'share_song': {
      AppLanguage.indonesian: 'Bagikan Lagu',
      AppLanguage.english: 'Share Song',
    },
    'share_copied': {
      AppLanguage.indonesian: 'Tautan lagu disalin ke papan klip!',
      AppLanguage.english: 'Song link copied to clipboard!',
    },

    // Onboarding
    'onboard_title': {
      AppLanguage.indonesian: 'Pilih minimal 6 artis favoritmu',
      AppLanguage.english: 'Select at least 6 favorite artists',
    },
    'onboard_subtitle': {
      AppLanguage.indonesian: 'Kami akan menyesuaikan musik di beranda berdasarkan seleramu.',
      AppLanguage.english: 'We will personalize your home feed based on your taste.',
    },
    'onboard_search_hint': {
      AppLanguage.indonesian: 'Cari artis favorit...',
      AppLanguage.english: 'Search favorite artists...',
    },
    'onboard_done': {
      AppLanguage.indonesian: 'Selesai',
      AppLanguage.english: 'Done',
    },
    'onboard_select_more': {
      AppLanguage.indonesian: 'Pilih {n} artis lagi',
      AppLanguage.english: 'Select {n} more artists',
    },

    // Settings Sidebar
    'settings_title': {
      AppLanguage.indonesian: 'Pengaturan & Profil',
      AppLanguage.english: 'Settings & Profile',
    },
    'settings_language': {
      AppLanguage.indonesian: 'Bahasa Aplikasi',
      AppLanguage.english: 'App Language',
    },
    'settings_choose_artists': {
      AppLanguage.indonesian: 'Pilih Ulang Artis Favorit',
      AppLanguage.english: 'Choose Favorite Artists',
    },
    'settings_about': {
      AppLanguage.indonesian: 'Tentang musixspot',
      AppLanguage.english: 'About musixspot',
    },
    'settings_about_app': {
      AppLanguage.indonesian: 'Tentang musixspot',
      AppLanguage.english: 'About musixspot',
    },
  };

  static String tr(String key) {
    final entry = _strings[key];
    if (entry == null) return key;
    return entry[_currentLanguage] ?? entry[AppLanguage.indonesian] ?? key;
  }
}
