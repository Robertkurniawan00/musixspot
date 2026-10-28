import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import 'title_normalizer.dart';
import 'music_api_service.dart';

/// DynamicCatalogService manages dynamic, live-updating music catalogs and playlists
/// sourced asynchronously from Deezer, iTunes, and verified streaming databases.
///
/// Features:
/// 1. Asynchronous live fetching without UI freezes.
/// 2. Persistent caching via SharedPreferences for instantaneous offline availability.
/// 3. Resilient fallback seeds if internet is absent or slow.
/// 4. Auto-curation of trending K-Drama OSTs, Anime OSTs, Indo Pop/Indie, and Global Charts.
class DynamicCatalogService {
  static final DynamicCatalogService _instance = DynamicCatalogService._internal();
  factory DynamicCatalogService() => _instance;
  DynamicCatalogService._internal();

  static const String _baseUrl = 'https://api.deezer.com';
  static const String _prefKeyPopular = 'dynamic_catalog_popular_releases_v2';
  static const String _prefKeyKdrama = 'dynamic_catalog_kdrama_v2';
  static const String _prefKeyAnime = 'dynamic_catalog_anime_v2';
  static const String _prefKeyIndo = 'dynamic_catalog_indo_v2';
  static const String _prefKeyGlobalPop = 'dynamic_catalog_global_pop_v2';
  static const String _prefKeyLastUpdated = 'dynamic_catalog_last_updated_v2';

  bool _isRefreshing = false;
  DateTime? _lastRefreshed;

  List<Playlist> _popularReleases = [];
  List<Playlist> _kdramaPlaylists = [];
  List<Playlist> _animePlaylists = [];
  List<Playlist> _indonesianPlaylists = [];
  List<Playlist> _globalPopPlaylists = [];

  bool get isRefreshing => _isRefreshing;
  DateTime? get lastRefreshed => _lastRefreshed;

  List<Playlist> get popularReleases => List.unmodifiable(_popularReleases);
  List<Playlist> get kdramaPlaylists => List.unmodifiable(_kdramaPlaylists);
  List<Playlist> get animePlaylists => List.unmodifiable(_animePlaylists);
  List<Playlist> get indonesianPlaylists => List.unmodifiable(_indonesianPlaylists);
  List<Playlist> get globalPopPlaylists => List.unmodifiable(_globalPopPlaylists);

  /// Initializes the catalog from local cache first, then triggers a background refresh
  /// if data is missing or stale (> 4 hours).
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _loadFromCache(prefs);

      // If cache was completely empty, populate with pristine offline baseline seeds
      if (_popularReleases.isEmpty) {
        _popularReleases = MusicApiService.getPopularReleases();
      }
      if (_kdramaPlaylists.isEmpty) {
        _kdramaPlaylists = _buildBaselineKdramaPlaylists();
      }
      if (_animePlaylists.isEmpty) {
        _animePlaylists = _buildBaselineAnimePlaylists();
      }
      if (_indonesianPlaylists.isEmpty) {
        _indonesianPlaylists = _buildBaselineIndoPlaylists();
      }
      if (_globalPopPlaylists.isEmpty) {
        _globalPopPlaylists = _buildBaselineGlobalPopPlaylists();
      }

      final lastMs = prefs.getInt(_prefKeyLastUpdated);
      if (lastMs != null) {
        _lastRefreshed = DateTime.fromMillisecondsSinceEpoch(lastMs);
      }

      // Check staleness (refresh if > 4 hours or never refreshed)
      final bool isStale = _lastRefreshed == null ||
          DateTime.now().difference(_lastRefreshed!).inHours >= 4;

      if (isStale) {
        // Run refresh in background without awaiting, keeping app boot instant
        unawaited(refreshCatalog(force: false));
      }
    } catch (e) {
      debugPrint('DynamicCatalogService.init error: $e');
    }
  }

  void _loadFromCache(SharedPreferences prefs) {
    try {
      final popStr = prefs.getString(_prefKeyPopular);
      if (popStr != null && popStr.isNotEmpty) {
        final List list = json.decode(popStr);
        _popularReleases = list.map((item) => Playlist.fromJson(item)).toList();
      }

      final kdramaStr = prefs.getString(_prefKeyKdrama);
      if (kdramaStr != null && kdramaStr.isNotEmpty) {
        final List list = json.decode(kdramaStr);
        _kdramaPlaylists = list.map((item) => Playlist.fromJson(item)).toList();
      }

      final animeStr = prefs.getString(_prefKeyAnime);
      if (animeStr != null && animeStr.isNotEmpty) {
        final List list = json.decode(animeStr);
        _animePlaylists = list.map((item) => Playlist.fromJson(item)).toList();
      }

      final indoStr = prefs.getString(_prefKeyIndo);
      if (indoStr != null && indoStr.isNotEmpty) {
        final List list = json.decode(indoStr);
        _indonesianPlaylists = list.map((item) => Playlist.fromJson(item)).toList();
      }

      final globalStr = prefs.getString(_prefKeyGlobalPop);
      if (globalStr != null && globalStr.isNotEmpty) {
        final List list = json.decode(globalStr);
        _globalPopPlaylists = list.map((item) => Playlist.fromJson(item)).toList();
      }
    } catch (e) {
      debugPrint('DynamicCatalogService._loadFromCache parse error: $e');
    }
  }

  /// Pulls fresh chart albums, OSTs, and trending playlists from live APIs
  Future<bool> refreshCatalog({bool force = true}) async {
    if (_isRefreshing) return false;
    _isRefreshing = true;

    try {
      // Run section fetches concurrently with timeouts
      final results = await Future.wait([
        _fetchLiveChartReleases(),
        _fetchLiveKdramaOSTs(),
        _fetchLiveAnimeOSTs(),
        _fetchLiveIndonesianReleases(),
        _fetchLiveGlobalPopReleases(),
      ]).timeout(const Duration(seconds: 15));

      final livePop = results[0];
      final liveKdrama = results[1];
      final liveAnime = results[2];
      final liveIndo = results[3];
      final liveGlobal = results[4];

      if (livePop.isNotEmpty) _popularReleases = livePop;
      if (liveKdrama.isNotEmpty) _kdramaPlaylists = liveKdrama;
      if (liveAnime.isNotEmpty) _animePlaylists = liveAnime;
      if (liveIndo.isNotEmpty) _indonesianPlaylists = liveIndo;
      if (liveGlobal.isNotEmpty) _globalPopPlaylists = liveGlobal;

      _lastRefreshed = DateTime.now();

      // Persist to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefKeyPopular,
        json.encode(_popularReleases.map((p) => p.toJson()).toList()),
      );
      await prefs.setString(
        _prefKeyKdrama,
        json.encode(_kdramaPlaylists.map((p) => p.toJson()).toList()),
      );
      await prefs.setString(
        _prefKeyAnime,
        json.encode(_animePlaylists.map((p) => p.toJson()).toList()),
      );
      await prefs.setString(
        _prefKeyIndo,
        json.encode(_indonesianPlaylists.map((p) => p.toJson()).toList()),
      );
      await prefs.setString(
        _prefKeyGlobalPop,
        json.encode(_globalPopPlaylists.map((p) => p.toJson()).toList()),
      );
      await prefs.setInt(_prefKeyLastUpdated, _lastRefreshed!.millisecondsSinceEpoch);

      debugPrint('DynamicCatalogService: catalog refreshed successfully.');
      return true;
    } catch (e) {
      debugPrint('DynamicCatalogService.refreshCatalog error: $e');
      return false;
    } finally {
      _isRefreshing = false;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // LIVE NETWORK FETCHER IMPLEMENTATIONS
  // ──────────────────────────────────────────────────────────────────────────

  /// Fetches live global chart albums and synthesizes high-res release playlists
  Future<List<Playlist>> _fetchLiveChartReleases() async {
    final List<Playlist> releases = [];
    try {
      final uri = Uri.parse('$_baseUrl/chart/0/albums?limit=10');
      final resp = await http.get(uri).timeout(const Duration(seconds: 7));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final items = (data['data'] as List?) ?? [];

        for (final item in items) {
          final albumId = (item['id'] ?? '').toString();
          final rawTitle = (item['title'] ?? 'Trending Album').toString();
          final title = TitleNormalizer.cleanTitle(rawTitle);
          final rawArtist = (item['artist']?['name'] ?? 'Popular Artist').toString();
          final artist = TitleNormalizer.cleanArtist(rawArtist);
          final coverUrl = (item['cover_xl'] ??
                  item['cover_big'] ??
                  item['cover_medium'] ??
                  '')
              .toString();

          if (albumId.isEmpty || coverUrl.isEmpty) continue;

          // Fetch tracks for this chart release
          final tracks = await _fetchAlbumTracks(albumId, title, artist, coverUrl);
          if (tracks.isNotEmpty) {
            releases.add(
              Playlist(
                id: 'dyn_rel_$albumId',
                title: title,
                subtitle: 'Album • $artist',
                coverUrl: coverUrl,
                songs: tracks,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('DynamicCatalogService._fetchLiveChartReleases error: $e');
    }

    // Blend with baseline popular releases if empty or to ensure essential staples
    if (releases.isEmpty) {
      return MusicApiService.getPopularReleases();
    }
    // Include baseline essentials (like Bruno Mars 24K Magic, Lesung Pipi, Kisah Klasik)
    final baseline = MusicApiService.getPopularReleases();
    for (final base in baseline) {
      if (!releases.any((r) => r.title.toLowerCase() == base.title.toLowerCase())) {
        releases.add(base);
      }
    }
    return releases;
  }

  /// Fetches live K-Drama OST playlists (Queen of Tears, Lovely Runner, King the Land, etc.)
  Future<List<Playlist>> _fetchLiveKdramaOSTs() async {
    final List<Playlist> list = [];
    final kdramaQueries = [
      {
        'name': 'Crash Landing on You OST',
        'drama': 'Crash Landing on You',
        'sub': 'IU, Baek Yerin, 10cm, Yoon Mi-rae & Crush',
        'cover': 'https://cdn-images.dzcdn.net/images/cover/73cf2b46ff8aa6c8a94c6a9adcc17325/1000x1000-000000-80-0-0.jpg',
      },
      {
        'name': 'Queen of Tears OST',
        'drama': 'Queen of Tears',
        'sub': 'BSS, 10CM, Kim Soo Hyun, Crush & Isaac Hong',
        'cover': 'https://cdn-images.dzcdn.net/images/cover/02d1405b9b32121e98eb04e415e58963/1000x1000-000000-80-0-0.jpg',
      },
      {
        'name': 'Lovely Runner OST',
        'drama': 'Lovely Runner',
        'sub': 'ECLIPSE, 10CM, Minnie (G)I-DLE & N.Flying',
        'cover': 'https://cdn-images.dzcdn.net/images/cover/740e1a4f5605c801a3a520719d475a9f/1000x1000-000000-80-0-0.jpg',
      },
      {
        'name': 'King the Land OST',
        'drama': 'King the Land',
        'sub': 'Lim Kim, Jung Seung Hwan & Minseo',
        'cover': 'https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/b4/0b/40/b40b40eb-3023-e283-0570-e4df73eb36a8/196922579174_cover.jpg/1000x1000bb.jpg',
      },
      {
        'name': 'Goblin OST Chanyeol Punch Crush',
        'drama': 'Goblin (Guardian)',
        'sub': 'Chanyeol, Punch, Crush, Ailee & Lasse Lindh',
        'cover': 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/bf/25/f8/bf25f824-cce8-cf8c-dfa3-fc8c03565f12/8809516262849.jpg/1000x1000bb.jpg',
      },
      {
        'name': 'Descendants of the Sun OST',
        'drama': 'Descendants of the Sun',
        'sub': 'Gummy, Davichi, Yoon Mi-rae, Chen & Punch',
        'cover': 'https://cdn-images.dzcdn.net/images/cover/37577e577b9938377eeca28def556250/1000x1000-000000-80-0-0.jpg',
      },
    ];

    for (final q in kdramaQueries) {
      try {
        final dramaName = q['drama']!;
        final tracks = await _searchTracksOnDeezer('${q['name']}', limit: 14);
        if (tracks.isNotEmpty) {
          final coverUrl = q['cover'] ?? tracks.first.albumArtUrl;
          list.add(
            Playlist(
              id: 'dyn_kdrama_${dramaName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
              title: '$dramaName Original Soundtrack',
              subtitle: q['sub']!,
              coverUrl: coverUrl,
              songs: tracks,
            ),
          );
        }
      } catch (e) {
        debugPrint('DynamicCatalogService._fetchLiveKdramaOSTs query error: $e');
      }
    }

    if (list.isEmpty) {
      return _buildBaselineKdramaPlaylists();
    }
    return list;
  }

  /// Fetches live Anime OST playlists (Demon Slayer, Jujutsu Kaisen, Attack on Titan, RADWIMPS)
  Future<List<Playlist>> _fetchLiveAnimeOSTs() async {
    final List<Playlist> list = [];
    final animeQueries = [
      {
        'query': 'Demon Slayer Kimetsu no Yaiba',
        'title': 'Demon Slayer (Kimetsu no Yaiba) Complete OST',
        'sub': 'LiSA, Aimer, MAN WITH A MISSION x milet & MY FIRST STORY',
        'cover': 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/44/28/7f/44287ff2-ceb9-0c84-904c-d1c998f5a606/VVCL01659B00Z_1000.jpg/1000x1000bb.jpg',
      },
      {
        'query': 'Jujutsu Kaisen OST King Gnu Eve',
        'title': 'Jujutsu Kaisen Best Soundtrack & Openings',
        'sub': 'Eve, King Gnu, Tatsuya Kitani & Soshi Sakiyama',
        'cover': 'https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/ce/68/70/ce687059-d830-4e32-2fa5-8276f571e2ef/BVCL01358B00Z_1000.jpg/1000x1000bb.jpg',
      },
      {
        'query': 'Attack on Titan Linked Horizon',
        'title': 'Attack on Titan (Shingeki no Kyojin) Masterpieces',
        'sub': 'Linked Horizon, Hiroyuki Sawano, SiM & Ai Higuchi',
        'cover': 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/f1/b7/c1/f1b7c125-9988-cb9b-449e-e67c858df342/PCCA_03836.jpg/1000x1000bb.jpg',
      },
      {
        'query': 'RADWIMPS Suzume Your Name',
        'title': 'RADWIMPS Makoto Shinkai Film Soundtracks',
        'sub': 'Your Name, Weathering With You & Suzume',
        'cover': 'https://is1-ssl.mzstatic.com/image/thumb/Music112/v4/b4/d9/b0/b4d9b0ca-2bb5-b541-b0db-b8d4f4e2bf7e/22UMGIM98246.rgb.jpg/1000x1000bb.jpg',
      },
      {
        'query': 'FLOW Naruto Sign Silhouette',
        'title': 'Naruto Shippuden Legendary Openings',
        'sub': 'FLOW, SHUN, Kana-Boon, Ikimonogakari & ASIAN KUNG-FU GENERATION',
        'cover': 'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/08/94/a4/0894a42b-5ee7-6aa6-4929-1660d5bfa53e/KSCL02551B00Z_1000.jpg/1000x1000bb.jpg',
      },
    ];

    for (final item in animeQueries) {
      try {
        final query = item['query']!;
        final tracks = await _searchTracksOnDeezer(query, limit: 12);
        if (tracks.isNotEmpty) {
          final coverUrl = tracks.first.albumArtUrl.isNotEmpty
              ? tracks.first.albumArtUrl
              : item['cover']!;
          list.add(
            Playlist(
              id: 'dyn_anime_${item['title']!.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
              title: item['title']!,
              subtitle: item['sub']!,
              coverUrl: coverUrl,
              songs: tracks,
            ),
          );
        }
      } catch (e) {
        debugPrint('DynamicCatalogService._fetchLiveAnimeOSTs error: $e');
      }
    }

    if (list.isEmpty) {
      return _buildBaselineAnimePlaylists();
    }
    return list;
  }

  /// Fetches live Indonesian trending releases (Mahalini, Tiara Andini, Pamungkas, Hindia, .Feast)
  Future<List<Playlist>> _fetchLiveIndonesianReleases() async {
    final List<Playlist> list = [];
    final artists = [
      {'name': 'Mahalini', 'album': 'Fabula', 'sub': 'Album • Mahalini (Sial, Sisa Rasa, Kisah Sempurna)'},
      {'name': 'Tiara Andini', 'album': 'Tiara Andini', 'sub': 'Album • Tiara Andini (Kupu-Kupu, Janji Setia, Merasa Indah)'},
      {'name': 'Pamungkas', 'album': 'Flying Solo', 'sub': 'Album • Pamungkas (To the Bone, One Only, Flying Solo)'},
      {'name': 'Hindia', 'album': 'Menari Dengan Bayangan', 'sub': 'Album • Hindia (Evaluasi, Secukupnya, Rumah Ke Rumah)'},
      {'name': '.Feast', 'album': 'Membangun & Menghancurkan', 'sub': 'Album • .Feast (Peradaban, Tarian Penghancur Raya)'},
    ];

    for (final a in artists) {
      try {
        final tracks = await _searchTracksOnDeezer('artist:"${a['name']}"', limit: 12);
        if (tracks.isNotEmpty) {
          list.add(
            Playlist(
              id: 'dyn_indo_${a['name']!.toLowerCase().replaceAll(' ', '_')}',
              title: '${a['album']}',
              subtitle: a['sub']!,
              coverUrl: tracks.first.albumArtUrl,
              songs: tracks,
            ),
          );
        }
      } catch (e) {
        debugPrint('DynamicCatalogService._fetchLiveIndonesianReleases error: $e');
      }
    }

    if (list.isEmpty) {
      return _buildBaselineIndoPlaylists();
    }
    return list;
  }

  /// Fetches live Global Pop releases (Adele, Coldplay, Ed Sheeran, Bruno Mars, Ariana Grande)
  Future<List<Playlist>> _fetchLiveGlobalPopReleases() async {
    final List<Playlist> list = [];
    final icons = [
      {'name': 'Bruno Mars', 'title': '24K Magic', 'sub': 'Album • Bruno Mars', 'cover': 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/10/7c/49/107c49b6-455b-43d9-6c3e-075679904119/075679904119.jpg/1000x1000bb.jpg'},
      {'name': 'Adele', 'title': '30 & Greatest Hits', 'sub': 'Album • Adele', 'cover': 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/7b/72/7f/7b727f71-6784-1875-104c-35c8e3bfd0e8/886449666492.jpg/1000x1000bb.jpg'},
      {'name': 'Coldplay', 'title': 'Music of the Spheres & Classics', 'sub': 'Album • Coldplay', 'cover': 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/cb/ad/07/cbad0711-c1e1-e176-805c-df8a14b53fa4/190296608348.jpg/1000x1000bb.jpg'},
      {'name': 'Ed Sheeran', 'title': '= (Equals) & Best Hits', 'sub': 'Album • Ed Sheeran', 'cover': 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/e0/75/a3/e075a34e-eeeb-2f04-850c-e2f7b8979ca6/190296614486.jpg/1000x1000bb.jpg'},
      {'name': 'Ariana Grande', 'title': 'eternal sunshine', 'sub': 'Album • Ariana Grande', 'cover': 'https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/e5/22/07/e52207b2-13cf-ff48-e8cb-dfd206f4eeef/24UMGIM08434.rgb.jpg/1000x1000bb.jpg'},
    ];

    for (final icon in icons) {
      try {
        final tracks = await _searchTracksOnDeezer('artist:"${icon['name']}"', limit: 12);
        if (tracks.isNotEmpty) {
          list.add(
            Playlist(
              id: 'dyn_global_${icon['name']!.toLowerCase().replaceAll(' ', '_')}',
              title: icon['title']!,
              subtitle: icon['sub']!,
              coverUrl: icon['cover'] ?? tracks.first.albumArtUrl,
              songs: tracks,
            ),
          );
        }
      } catch (e) {
        debugPrint('DynamicCatalogService._fetchLiveGlobalPopReleases error: $e');
      }
    }

    if (list.isEmpty) {
      return _buildBaselineGlobalPopPlaylists();
    }
    return list;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // HELPER METHODS
  // ──────────────────────────────────────────────────────────────────────────

  Future<List<Song>> _fetchAlbumTracks(
    String albumId,
    String albumTitle,
    String artistName,
    String coverUrl,
  ) async {
    try {
      final uri = Uri.parse('$_baseUrl/album/$albumId/tracks?limit=15');
      final resp = await http.get(uri).timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final items = (data['data'] as List?) ?? [];
        final List<Song> list = [];

        for (final item in items) {
          final trackId = (item['id'] ?? '').toString();
          final rawTitle = (item['title'] ?? item['title_short'] ?? 'Unknown').toString();
          final title = TitleNormalizer.cleanTitle(rawTitle);
          final rawTrackArtist = (item['artist']?['name'] ?? artistName).toString();
          final trackArtist = TitleNormalizer.cleanArtist(rawTrackArtist);
          final durationSec = (item['duration'] as int?) ?? 210;

          list.add(
            Song(
              id: 'dyn_track_$trackId',
              title: title,
              artist: trackArtist,
              album: albumTitle,
              albumArtUrl: coverUrl,
              audioUrl: 'youtube:$trackArtist $title',
              duration: Duration(seconds: durationSec),
              lyrics: null,
            ),
          );
        }
        return list;
      }
    } catch (_) {}
    return [];
  }

  Future<List<Song>> _searchTracksOnDeezer(String query, {int limit = 12}) async {
    try {
      final uri = Uri.parse('$_baseUrl/search?q=${Uri.encodeComponent(query)}&limit=$limit');
      final resp = await http.get(uri).timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final items = (data['data'] as List?) ?? [];
        final List<Song> list = [];
        final seen = <String>{};

        for (final item in items) {
          final trackId = (item['id'] ?? '').toString();
          final rawTitle = (item['title'] ?? item['title_short'] ?? '').toString();
          final title = TitleNormalizer.cleanTitle(rawTitle);
          final rawArtist = (item['artist']?['name'] ?? '').toString();
          final artist = TitleNormalizer.cleanArtist(rawArtist);
          final key = TitleNormalizer.dedupKey(artist, title);

          if (seen.contains(key)) continue;
          seen.add(key);

          final albumObj = item['album'] as Map<String, dynamic>?;
          final albumTitle = (albumObj?['title'] ?? '').toString();

          // Strict blacklist for known misattributed or spam tracks (e.g. The Hat Girl / Birds of Prey)
          final lowerArtist = rawArtist.toLowerCase();
          final lowerTitle = rawTitle.toLowerCase();
          final lowerAlbum = albumTitle.toLowerCase();
          if (lowerArtist.contains('hat girl') ||
              lowerTitle.contains('the hat girl') ||
              lowerAlbum.contains('birds of prey')) {
            continue;
          }

          final coverUrl = (albumObj?['cover_xl'] ??
                  albumObj?['cover_big'] ??
                  albumObj?['cover_medium'] ??
                  '')
              .toString();
          final durationSec = (item['duration'] as int?) ?? 210;

          if (title.isNotEmpty && artist.isNotEmpty && coverUrl.isNotEmpty) {
            list.add(
              Song(
                id: 'dyn_dz_$trackId',
                title: title,
                artist: artist,
                album: albumTitle,
                albumArtUrl: coverUrl,
                audioUrl: 'youtube:$artist $title',
                duration: Duration(seconds: durationSec),
                lyrics: null,
              ),
            );
          }
        }
        return list;
      }
    } catch (_) {}
    return [];
  }

  // ──────────────────────────────────────────────────────────────────────────
  // PRISTINE OFFLINE BASELINES (Guaranteed 100% playable even without internet)
  // ──────────────────────────────────────────────────────────────────────────

  List<Playlist> _buildBaselineKdramaPlaylists() {
    return MusicApiService.getKoreanDramaPlaylists();
  }

  List<Playlist> _buildBaselineAnimePlaylists() {
    final jpopPlaylists = MusicApiService.getJPopPlaylists();
    if (jpopPlaylists.isNotEmpty) {
      return jpopPlaylists;
    }
    return [
      Playlist(
        id: 'pl_anime_demon_slayer_base',
        title: 'Demon Slayer (Kimetsu no Yaiba) Best OST',
        subtitle: 'LiSA, Aimer, MAN WITH A MISSION x milet',
        coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/44/28/7f/44287ff2-ceb9-0c84-904c-d1c998f5a606/VVCL01659B00Z_1000.jpg/1000x1000bb.jpg',
        songs: MusicApiService.getJPopTracks(),
      ),
    ];
  }

  List<Playlist> _buildBaselineIndoPlaylists() {
    return MusicApiService.getMusikIndonesiaPlaylists();
  }

  List<Playlist> _buildBaselineGlobalPopPlaylists() {
    return MusicApiService.getPopularReleases();
  }
}
