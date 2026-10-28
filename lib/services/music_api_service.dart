import 'dart:io';
import 'package:flutter/material.dart';
import '../models/song.dart';
import '../models/playlist.dart';
import '../models/category.dart';
import '../models/artist.dart';
import 'multi_source_search_service.dart';
import 'youtube_api_service.dart';
import 'deezer_api_service.dart';
import 'title_normalizer.dart';
import 'user_behavior_service.dart';

class MusicApiService {
  // ─────────────────────────────────────────────────────────────────────────
  // LIVE SEARCH — YouTube API v3 + JioSaavn + iTunes (parallel, deduplicated)
  // ─────────────────────────────────────────────────────────────────────────
  static Future<List<Song>> searchTracks(String query) async {
    if (query.trim().isEmpty) return [];

    final q = query.trim().toLowerCase();
    final List<Song> results = [];
    final seenKeys = <String>{};

    void addSong(Song s) {
      final clean = TitleNormalizer.normalizeSong(s);
      final cleanTitleLower = clean.title.toLowerCase().trim();
      // Filter out songs titled literally just "OST" or "Kpop" or fake titles
      if (cleanTitleLower == 'ost' ||
          cleanTitleLower == 'kpop' ||
          cleanTitleLower == 'k-pop' ||
          cleanTitleLower == 'ost part' ||
          cleanTitleLower == 'soundtrack') {
        return;
      }
      final k = TitleNormalizer.dedupKey(clean.artist, clean.title);
      if (!seenKeys.contains(k)) {
        seenKeys.add(k);
        results.add(clean);
      }
    }

    final isOstSearch = q == 'ost' ||
        q == 'drakor' ||
        q == 'drama' ||
        q.startsWith('ost ') ||
        q.endsWith(' ost') ||
        q.contains('soundtrack');

    final isKpopSearch = q == 'kpop' ||
        q == 'k-pop' ||
        q.startsWith('kpop ') ||
        q.endsWith(' kpop') ||
        q.contains('k-pop');

    // 0. Korean Drama & Anime Official OST catalog match (genuine soundtracks)
    if (isOstSearch ||
        q.contains('secret garden') ||
        q.contains('goblin') ||
        q.contains('crash landing') ||
        q.contains('descendants') ||
        q.contains('itaewon') ||
        q.contains('hotel del luna') ||
        q.contains('reply') ||
        q.contains('baek ji') ||
        q.contains('hyun bin') ||
        q.contains('gummy') ||
        q.contains('dmeanor') ||
        q.contains('why do we') ||
        q.contains('stay there') ||
        q.contains('are you human') ||
        q.contains('wendy') ||
        q.contains('wendi') ||
        q.contains('손승완') ||
        q.contains('punch') ||
        q.contains('crush') ||
        q.contains('ailee')) {
      for (final song in getKoreanDramaTracks()) {
        if (isOstSearch ||
            song.title.toLowerCase().contains(q) ||
            song.artist.toLowerCase().contains(q) ||
            song.album.toLowerCase().contains(q)) {
          addSong(song);
        }
      }
      for (final song in getNarutoOstTracks()) {
        if (isOstSearch ||
            song.title.toLowerCase().contains(q) ||
            song.artist.toLowerCase().contains(q) ||
            song.album.toLowerCase().contains(q)) {
          addSong(song);
        }
      }
    }

    // 0b. K-Pop Catalog match (genuine songs by K-Pop artists, not songs titled "kpop")
    if (isKpopSearch) {
      for (final song in getKPopTracks()) {
        addSong(song);
      }
      for (final artist in getComprehensiveArtists()) {
        if (artist.genres.any((g) => g.toLowerCase().contains('k-pop') || g.toLowerCase().contains('k-drama')) ||
            artist.country.toLowerCase() == 'korea selatan') {
          for (final song in artist.topTracks) {
            addSong(song);
          }
        }
      }
    }

    // 0c. Naruto & Anime Official OST catalog match
    if (!isOstSearch && (q.contains('naruto') ||
        q.contains('shippuden') ||
        q.contains('anime') ||
        q.contains('shun') ||
        q.contains('never change') ||
        q.contains('unlimits') ||
        q.contains('cascade') ||
        q.contains('flow') ||
        q.contains('silhouette') ||
        q.contains('haruka kanata') ||
        q.contains('blue bird') ||
        q.contains('sambomaster') ||
        q.contains('seishun') ||
        q.contains('diver') ||
        q.contains('guren') ||
        q.contains('akeboshi') ||
        q.contains('wind') ||
        q.contains('hero\'s come back') ||
        q.contains('sayonara memory'))) {
      for (final song in getNarutoOstTracks()) {
        if (q.contains('naruto') ||
            q.contains('shippuden') ||
            q.contains('anime') ||
            song.title.toLowerCase().contains(q) ||
            song.artist.toLowerCase().contains(q) ||
            song.album.toLowerCase().contains(q)) {
          addSong(song);
        }
      }
    }

    // 1. Curated catalog — instant, offline
    for (final song in getFeaturedTracks()) {
      if (song.title.toLowerCase().contains(q) ||
          song.artist.toLowerCase().contains(q) ||
          song.album.toLowerCase().contains(q)) {
        addSong(song);
      }
    }

    // 2. Artist top tracks — instant, offline
    for (final artist in getComprehensiveArtists()) {
      if (artist.name.toLowerCase().contains(q) || q.contains(artist.name.toLowerCase())) {
        for (final song in artist.topTracks) {
          addSong(song);
        }
      }
    }

    // For broad genre queries (OST, K-Pop), return the authentic catalog immediately without polluting results with videos titled "OST" or "kpop"
    if ((isOstSearch || isKpopSearch) && results.length >= 8) {
      return results;
    }

    // 3. Multi-source: YouTube API v3 (primary) + JioSaavn + iTunes (parallel)
    try {
      final multiSongs = await MultiSourceSearchService.search(query, limit: 30);
      for (final song in multiSongs) {
        addSong(song);
      }
    } catch (e) {
      debugPrint('Multi-source search error: $e');
    }

    // 4. YouTube API v3 direct fallback (if still few results)
    if (results.length < 8) {
      try {
        final ytSongs = await YouTubeApiService.search(query, limit: 15);
        for (final song in ytSongs) {
          addSong(song);
        }
      } catch (e) {
        debugPrint('YouTube API v3 fallback error: $e');
      }
    }

    return results;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BROWSE CATEGORIES
  // ─────────────────────────────────────────────────────────────────────────
  static List<BrowseCategory> getBrowseCategories() {
    return [
      BrowseCategory(id: 'musik', title: 'Musik', backgroundColor: const Color(0xFFDC148C),
          imageUrl: 'https://images.unsplash.com/photo-1539185441755-769473a23570?w=500&q=80'),
      BrowseCategory(id: 'podcast', title: 'Podcast', backgroundColor: const Color(0xFF006450),
          imageUrl: 'https://images.unsplash.com/photo-1590602847861-f357a9332bbc?w=500&q=80'),
      BrowseCategory(id: 'live', title: 'Acara Live', backgroundColor: const Color(0xFF7358FF),
          imageUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500&q=80'),
      BrowseCategory(id: 'made_for_you', title: 'Dibuat Untuk Kamu', backgroundColor: const Color(0xFF1E3264),
          imageUrl: 'https://images.unsplash.com/photo-1518770660439-4636190af475?w=500&q=80'),
      BrowseCategory(id: 'new_releases', title: 'Rilis Baru', backgroundColor: const Color(0xFFE91429),
          imageUrl: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=500&q=80'),
      BrowseCategory(id: 'musik_indonesia', title: 'Musik Indonesia', backgroundColor: const Color(0xFFDC148C),
          imageUrl: 'https://images.unsplash.com/photo-1510915361894-db8b60106cb1?w=500&q=80'),
      BrowseCategory(id: 'pop', title: 'Pop', backgroundColor: const Color(0xFF148A08),
          imageUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&q=80'),
      BrowseCategory(id: 'kpop', title: 'K-Pop', backgroundColor: const Color(0xFF148A08),
          imageUrl: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=500&q=80'),
      BrowseCategory(id: 'ost_drakor', title: 'OST Drama Korea', backgroundColor: const Color(0xFF5B3256),
          imageUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/6b/64/00/6b64006c-843c-3ca5-2601-38290f6b45a6/cover.jpg/600x600bb.jpg'),
      BrowseCategory(id: 'di_rumah', title: 'Di Rumah', backgroundColor: const Color(0xFF503750),
          imageUrl: 'https://images.unsplash.com/photo-1513694203232-719a280e022f?w=500&q=80'),
      BrowseCategory(id: 'hip_hop', title: 'Hip-Hop', backgroundColor: const Color(0xFFBA5D07),
          imageUrl: 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=500&q=80'),
      BrowseCategory(id: 'dance_electronic', title: 'Musik Dansa/Elektronik', backgroundColor: const Color(0xFFD84000),
          imageUrl: 'https://images.unsplash.com/photo-1516873240891-4bf014598ab4?w=500&q=80'),
      BrowseCategory(id: 'rock', title: 'Rock', backgroundColor: const Color(0xFFE91429),
          imageUrl: 'https://images.unsplash.com/photo-1498038432885-c6f3f1b912ee?w=500&q=80'),
      BrowseCategory(id: 'chill', title: 'Chill', backgroundColor: const Color(0xFF27856A),
          imageUrl: 'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?w=500&q=80'),
      BrowseCategory(id: 'tidur', title: 'Tidur', backgroundColor: const Color(0xFF1E3264),
          imageUrl: 'https://images.unsplash.com/photo-1507499739999-097706ad8914?w=500&q=80'),
      BrowseCategory(id: 'jpop', title: 'Anime & Lagu Jepang', backgroundColor: const Color(0xFFBC5900),
          imageUrl: 'https://images.unsplash.com/photo-1503899036084-c55cdd92da26?w=500&q=80'),
      BrowseCategory(id: 'jazz', title: 'Jazz', backgroundColor: const Color(0xFF7D4B32),
          imageUrl: 'https://images.unsplash.com/photo-1511192336575-5a79af67a629?w=500&q=80'),
      BrowseCategory(id: 'cinta', title: 'Romansa', backgroundColor: const Color(0xFFE61E32),
          imageUrl: 'https://images.unsplash.com/photo-1518199266791-5375a83190b7?w=500&q=80'),
      BrowseCategory(id: 'workout', title: 'Olahraga', backgroundColor: const Color(0xFF477D95),
          imageUrl: 'https://images.unsplash.com/photo-1483721074573-586540da5703?w=500&q=80'),
      BrowseCategory(id: 'pesta', title: 'Pesta', backgroundColor: const Color(0xFF537AA1),
          imageUrl: 'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?w=500&q=80'),
      BrowseCategory(id: 'indie', title: 'Indie', backgroundColor: const Color(0xFF8D67AB),
          imageUrl: 'https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=500&q=80'),
    ];
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CATEGORY DETAILS — Dedicated Spotify 1:1 Page Data (Screenshots 2 & 4)
  // ─────────────────────────────────────────────────────────────────────────
  static CategoryData getCategoryDetails(BrowseCategory category) {
    final feat = getFeaturedTracks();
    final nos = getNostalgiaTracks();
    final releases = getPopularReleases();
    final artists = getArtists();
    final raimTracks = artists.isNotEmpty ? artists.first.topTracks : <Song>[];
    final kpopTracks = getKPopTracks();
    final jpopTracks = getJPopTracks();
    final indieTracks = getIndieTracks();
    final sleepTracks = getSleepTracks();
    final kDramaTracks = getKoreanDramaTracks();
    final kDramaPlaylists = getKoreanDramaPlaylists();

    switch (category.id) {
      case 'made_for_you':
        final homePlaylists = getHomePlaylists();
        final defaultPl = homePlaylists.isNotEmpty
            ? homePlaylists.first
            : Playlist(id: 'pl_fallback', title: 'Daily Mix', subtitle: 'Pilihan musik', coverUrl: '', songs: []);
        final dailyMix1 = homePlaylists.firstWhere((p) => p.id == 'pl_daily_mix_1', orElse: () => defaultPl);
        final dailyMix2 = homePlaylists.firstWhere((p) => p.id == 'pl_daily_mix_2', orElse: () => defaultPl);
        final dailyMix3 = homePlaylists.firstWhere((p) => p.id == 'pl_daily_mix_3', orElse: () => defaultPl);
        final dailyMix4 = homePlaylists.firstWhere((p) => p.id == 'pl_daily_mix_4', orElse: () => defaultPl);
        final discWeekly = homePlaylists.firstWhere((p) => p.id == 'pl_discover_weekly', orElse: () => defaultPl);
        final relRadar = homePlaylists.firstWhere((p) => p.id == 'pl_release_radar', orElse: () => defaultPl);
        return CategoryData(
          category: category,
          heroPlaylist: dailyMix1,
          sections: [
            CategorySection(
              title: 'Mix Harianmu (12 Lagu Tiap Mix)',
              playlists: [dailyMix1, dailyMix2, dailyMix3, dailyMix4],
            ),
            CategorySection(
              title: 'Pilihan Khusus Untukmu',
              playlists: [discWeekly, relRadar],
            ),
          ],
        );

      case 'new_releases':
        final freshPopSongs = [
          feat[1], feat[11], feat[15], feat[19], feat[7], feat[16],
          feat[3], feat[2], nos[0], nos[1], raimTracks[0], raimTracks[1],
        ];
        final globalNewSongs = [
          feat[0], feat[5], feat[10], feat[14], feat[4], feat[8],
          feat[9], feat[12], feat[13], feat[17], nos[8], nos[9],
        ];
        final hero = Playlist(
          id: 'pl_hero_nmf_id',
          title: 'NEW MUSIC FRIDAY INDONESIA',
          subtitle: 'Rilis baru pilihan editor. Cover: Donne Maula',
          coverUrl: 'https://cdn-images.dzcdn.net/images/cover/f5809041de170abd4c84dcdede0d202a/1000x1000-000000-80-0-0.jpg',
          songs: freshPopSongs,
        );
        return CategoryData(
          category: category,
          heroPlaylist: hero,
          sections: [
            CategorySection(
              title: 'Rilis baru teratas',
              playlists: releases,
            ),
            CategorySection(
              title: 'Rilis Baru Pilihan Editor',
              playlists: [
                Playlist(
                  id: 'rel_fresh_pop',
                  title: 'Fresh Pop Indonesia',
                  subtitle: 'Kumpulan rilisan pop lokal terbaru minggu ini',
                  coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/6f/18/10/6f1810e0-2d6a-a456-1362-de607c70408a/cover.jpg/600x600bb.jpg',
                  songs: freshPopSongs,
                ),
                Playlist(
                  id: 'rel_global_hits',
                  title: 'Global New Music',
                  subtitle: 'Rilis internasional terhangat pilihan dunia',
                  coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/2b/b9/fe/2bb9fef5-d7f3-8345-25a9-db0e79fde4e4/20UMGIM11048.rgb.jpg/600x600bb.jpg',
                  songs: globalNewSongs,
                ),
                Playlist(
                  id: 'rel_indie_radar',
                  title: 'Radar Indie Terbaru',
                  subtitle: 'Eksplorasi musisi indie pendatang baru',
                  coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/f4/42/c7/f442c726-f2a1-c045-829e-45f33f2fe1d0/3615939061533.png/600x600bb.jpg',
                  songs: indieTracks.take(12).toList(),
                ),
              ],
            ),
          ],
        );

      case 'kpop':
        final kpopOnSongs = [
          kpopTracks[6], kpopTracks[7], kpopTracks[0], kpopTracks[1],
          kpopTracks[3], kpopTracks[4], kpopTracks[8], kpopTracks[9],
          kpopTracks[12], kpopTracks[13], kpopTracks[14], kpopTracks[16],
        ];
        final kClubPartySongs = [
          kpopTracks[1], kpopTracks[3], kpopTracks[4], kpopTracks[5],
          kpopTracks[14], kpopTracks[15], kpopTracks[16], kpopTracks[0],
          kpopTracks[7], kpopTracks[12], kpopTracks[13], kpopTracks[2],
        ];
        final thisIsBtsSongs = [
          kpopTracks[0], kpopTracks[1], kpopTracks[2], feat[10],
          kpopTracks[3], kpopTracks[6], kpopTracks[7], kpopTracks[10],
          kpopTracks[11], kpopTracks[16], kpopTracks[17], kpopTracks[4],
        ];
        final btsArmySongs = [
          kpopTracks[1], kpopTracks[0], kpopTracks[2], kpopTracks[10],
          kpopTracks[11], kpopTracks[6], kpopTracks[7], kpopTracks[8],
          kpopTracks[9], kpopTracks[3], kpopTracks[4], kpopTracks[17],
        ];
        final kRockSongs = [
          kpopTracks[10], kpopTracks[11], kpopTracks[0], kpopTracks[1],
          kpopTracks[4], kpopTracks[15], kpopTracks[16], kpopTracks[2],
          kpopTracks[6], kpopTracks[7], kpopTracks[12], kpopTracks[13],
        ];
        final kRnbSongs = [
          kpopTracks[6], kpopTracks[7], kpopTracks[8], kpopTracks[9],
          kpopTracks[17], kpopTracks[10], kpopTracks[11], kpopTracks[2],
          kpopTracks[1], kpopTracks[0], kpopTracks[14], kpopTracks[13],
        ];

        final heroKpop = Playlist(
          id: 'kpop_on',
          title: 'K-Pop ON! (온)',
          subtitle: 'Lagu K-Pop paling hits saat ini. Cover: NewJeans',
          coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/b1/83/88/b183884d-2e11-cfcf-089c-5e9218d6e902/196922485121_Cover.jpg/600x600bb.jpg',
          songs: kpopOnSongs,
        );

        return CategoryData(
          category: category,
          heroPlaylist: heroKpop,
          sections: [
            CategorySection(
              title: 'K-Essentials (12 Lagu Tiap Playlist)',
              playlists: [
                heroKpop,
                Playlist(
                  id: 'kpop_party',
                  title: 'K-Club Party',
                  subtitle: 'Semangat tinggi beat dansa K-Pop penuh energi',
                  coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/b4/d2/54/b4d2542a-a92c-6ca7-8db1-1d54eb53ef1d/20UMGIM78945.rgb.jpg/600x600bb.jpg',
                  songs: kClubPartySongs,
                ),
                Playlist(
                  id: 'kpop_rock',
                  title: 'K-Rock',
                  subtitle: 'Sisi rock Korea terbaik: DAY6, FTISLAND, Xdinary Heroes',
                  coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music128/v4/28/6e/b7/286eb792-74d4-9d5f-dcf8-07f7c46f6c99/Cover_DAY6.jpg/600x600bb.jpg',
                  songs: kRockSongs,
                ),
                Playlist(
                  id: 'kpop_rnb',
                  title: 'K-R&B Chill',
                  subtitle: 'Suasana santai dan halus dari R&B Korea terkini',
                  coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music112/v4/55/7c/49/557c493c-cf80-e835-f483-3eb41a5fe7aa/196922067341_Cover.jpg/600x600bb.jpg',
                  songs: kRnbSongs,
                ),
              ],
            ),
            CategorySection(
              title: 'Playlist BTS & ARMY',
              playlists: [
                Playlist(
                  id: 'kpop_this_is_bts',
                  title: 'This Is BTS',
                  subtitle: 'Esensi karya terbaik dari ikon global BTS',
                  coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/c3/8e/3c/c38e3cb9-40ea-920f-a496-5b91cf84ee71/195497495574.jpg/600x600bb.jpg',
                  songs: thisIsBtsSongs,
                ),
                Playlist(
                  id: 'kpop_bts_army',
                  title: 'BTS & ARMY',
                  subtitle: 'Lagu favorit sepanjang masa persembahan fans dan member',
                  coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/58/04/b1/5804b123-640c-3962-d278-831631ae7421/196006456071.jpg/600x600bb.jpg',
                  songs: btsArmySongs,
                ),
              ],
            ),
            CategorySection(
              title: 'Acara & Festival Musik Korea',
              playlists: [
                Playlist(
                  id: 'kpop_ost_terbaik',
                  title: 'OST Drama Korea Terbaik',
                  subtitle: 'Baek Ji Young, Hyun Bin, Crush, Ailee & Chanyeol',
                  coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/6b/64/00/6b64006c-843c-3ca5-2601-38290f6b45a6/cover.jpg/1000x1000bb.jpg',
                  songs: kDramaTracks.take(12).toList(),
                ),
              ],
            ),
          ],
        );

      case 'jpop':
        final jpopTopHits = [
          jpopTracks[0], jpopTracks[1], jpopTracks[2], jpopTracks[3],
          jpopTracks[4], jpopTracks[5], jpopTracks[6], jpopTracks[7],
          jpopTracks[8], jpopTracks[9], jpopTracks[10], jpopTracks[12],
        ];
        final jpopAnimeSongs = [
          jpopTracks[0], jpopTracks[2], jpopTracks[4], jpopTracks[5],
          jpopTracks[6], jpopTracks[8], jpopTracks[9], jpopTracks[11],
          jpopTracks[13], jpopTracks[1], jpopTracks[7], jpopTracks[14],
        ];
        final jpopRockSongs = [
          jpopTracks[2], jpopTracks[4], jpopTracks[6], jpopTracks[7],
          jpopTracks[13], jpopTracks[14], jpopTracks[5], jpopTracks[0],
          jpopTracks[10], jpopTracks[11], jpopTracks[9], jpopTracks[1],
        ];
        final jpopChillSongs = [
          jpopTracks[12], jpopTracks[3], jpopTracks[9], jpopTracks[15],
          jpopTracks[1], jpopTracks[10], jpopTracks[14], jpopTracks[7],
          jpopTracks[0], jpopTracks[11], jpopTracks[5], jpopTracks[8],
        ];

        final heroJpop = Playlist(
          id: 'pl_jpop_top_hits',
          title: 'J-Pop Top Hits (12 Lagu)',
          subtitle: 'YOASOBI, Kenshi Yonezu, LiSA, Ado, Radwimps dan hits terpanas Jepang',
          coverUrl: 'https://cdn-images.dzcdn.net/images/cover/c028acc15f911c6ca3ff821abbb64aa3/1000x1000-000000-80-0-0.jpg',
          songs: jpopTopHits,
        );

        return CategoryData(
          category: category,
          heroPlaylist: heroJpop,
          sections: [
            CategorySection(
              title: 'J-Pop & Anime Terpopuler (12 Lagu Tiap Playlist)',
              playlists: [
                heroJpop,
                Playlist(
                  id: 'pl_jpop_anime_essentials',
                  title: 'Anime Openings & OST Ikonik',
                  subtitle: 'Demon Slayer, Chainsaw Man, Jujutsu Kaisen, Your Name, Spy x Family',
                  coverUrl: 'https://cdn-images.dzcdn.net/images/cover/219b98615e49c9df44727bc3d9d57c8e/1000x1000-000000-80-0-0.jpg',
                  songs: jpopAnimeSongs,
                ),
              ],
            ),
            CategorySection(
              title: 'Energi Rock & Tokyo City Vibes',
              playlists: [
                Playlist(
                  id: 'pl_jpop_rock_energy',
                  title: 'J-Rock & Band Penuh Energi',
                  subtitle: 'King Gnu, Official HIGE DANDISM, Vaundy, Eve & LiSA',
                  coverUrl: 'https://cdn-images.dzcdn.net/images/cover/b51d07c77bfda2e5f1bc965e5e9ab36f/1000x1000-000000-80-0-0.jpg',
                  songs: jpopRockSongs,
                ),
                Playlist(
                  id: 'pl_jpop_chill_tokyo',
                  title: 'Japanese Chill & City Pop',
                  subtitle: 'Fujii Kaze, Aimyon, RADWIMPS dan alunan melodi santai malam Tokyo',
                  coverUrl: 'https://cdn-images.dzcdn.net/images/cover/8ac32b2df291eb60249da046aae17df3/1000x1000-000000-80-0-0.jpg',
                  songs: jpopChillSongs,
                ),
              ],
            ),
          ],
        );

      case 'indie':
        final indiePilihanSongs = [
          indieTracks[0], indieTracks[1], indieTracks[2], indieTracks[3],
          indieTracks[4], indieTracks[5], indieTracks[6], indieTracks[7],
          indieTracks[8], indieTracks[9], indieTracks[10], indieTracks[11],
        ];
        final indieSenjaSongs = [
          indieTracks[2], indieTracks[3], indieTracks[4], indieTracks[5],
          indieTracks[7], indieTracks[8], indieTracks[10], indieTracks[11],
          indieTracks[15], indieTracks[0], indieTracks[1], indieTracks[6],
        ];
        final indieRockSongs = [
          indieTracks[12], indieTracks[13], indieTracks[14], indieTracks[0],
          indieTracks[6], indieTracks[8], indieTracks[9], indieTracks[1],
          indieTracks[2], indieTracks[4], indieTracks[7], indieTracks[15],
        ];
        final indieBedroomSongs = [
          indieTracks[9], indieTracks[10], indieTracks[11], indieTracks[15],
          indieTracks[3], indieTracks[5], indieTracks[7], indieTracks[8],
          indieTracks[0], indieTracks[1], indieTracks[2], indieTracks[4],
        ];

        final heroIndie = Playlist(
          id: 'pl_indie_pilihan',
          title: 'Indienesia Pilihan (12 Lagu)',
          subtitle: 'Hindia, Sal Priadi, Nadin Amizah, Pamungkas, Reality Club, Danilla',
          coverUrl: indieTracks[2].albumArtUrl,
          songs: indiePilihanSongs,
        );

        return CategoryData(
          category: category,
          heroPlaylist: heroIndie,
          sections: [
            CategorySection(
              title: 'Indie Indonesia Terdepan (12 Lagu Tiap Playlist)',
              playlists: [
                heroIndie,
                Playlist(
                  id: 'pl_indie_senja_kopi',
                  title: 'Indie Senja & Kopi Santai',
                  subtitle: 'Petikan akustik damai menemani secangkir kopi sore hari',
                  coverUrl: indieTracks[4].albumArtUrl,
                  songs: indieSenjaSongs,
                ),
              ],
            ),
            CategorySection(
              title: 'Alternatif, Rock & Bedroom Pop',
              playlists: [
                Playlist(
                  id: 'pl_indie_rock_alternatif',
                  title: 'Indie Rock Alternatif',
                  subtitle: '.Feast, Barasuara, Efek Rumah Kaca & Reality Club',
                  coverUrl: indieTracks[12].albumArtUrl,
                  songs: indieRockSongs,
                ),
                Playlist(
                  id: 'pl_indie_bedroom_pop',
                  title: 'Bedroom Pop & Lo-Fi Chill',
                  subtitle: 'Karya independen manis untuk teman rebahan santai',
                  coverUrl: indieTracks[9].albumArtUrl,
                  songs: indieBedroomSongs,
                ),
              ],
            ),
          ],
        );

      case 'ost_drakor':
        final heroKdrama = kDramaPlaylists.first;
        final qotSongs = [
          kDramaTracks[16], kDramaTracks[8], kDramaTracks[17], kDramaTracks[18],
          kDramaTracks[19], kDramaTracks[0], kDramaTracks[1], kDramaTracks[2],
          kDramaTracks[3], kDramaTracks[4], kDramaTracks[5], kDramaTracks[6],
        ];
        final hdlSongs = [
          kDramaTracks[13], kDramaTracks[5], kDramaTracks[20], kDramaTracks[21],
          kDramaTracks[8], kDramaTracks[9], kDramaTracks[10], kDramaTracks[2],
          kDramaTracks[3], kDramaTracks[0], kDramaTracks[1], kDramaTracks[16],
        ];

        return CategoryData(
          category: category,
          heroPlaylist: heroKdrama,
          sections: [
            CategorySection(
              title: 'OST Drakor Paling Ikonik & Populer (12 Lagu)',
              playlists: [
                kDramaPlaylists[0],
                kDramaPlaylists[1],
                kDramaPlaylists[2],
                kDramaPlaylists[3],
              ],
            ),
            CategorySection(
              title: 'Soundtrack Emosional & Nostalgia (12 Lagu)',
              playlists: [
                kDramaPlaylists[4],
                kDramaPlaylists[5],
                Playlist(
                  id: 'pl_kost_queen_of_tears',
                  title: 'Queen of Tears Official OST',
                  subtitle: 'Crush, Paul Kim, Heize & Isaac Hong',
                  coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music122/v4/c3/99/33/c3993309-8db2-2f3c-5353-d142d76579a3/198704093952.jpg/1000x1000bb.jpg',
                  songs: qotSongs,
                ),
                Playlist(
                  id: 'pl_kost_hotel_del_luna',
                  title: 'Hotel Del Luna Complete Soundtrack',
                  subtitle: 'Taeyeon, Gummy, Punch & Heize',
                  coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music113/v4/7c/fe/eb/7cfeeb79-4b36-7ca6-4d0c-f376f9db1627/8809658314175.jpg/1000x1000bb.jpg',
                  songs: hdlSongs,
                ),
              ],
            ),
          ],
        );

      case 'tidur':
        final sleepDeepSongs = List<Song>.from(sleepTracks);
        final sleepRainSongs = [
          sleepTracks[0], sleepTracks[9], sleepTracks[3], sleepTracks[4],
          sleepTracks[10], sleepTracks[1], sleepTracks[2], sleepTracks[5],
          sleepTracks[6], sleepTracks[7], sleepTracks[8], sleepTracks[11],
        ];
        final sleepWhiteNoiseSongs = [
          sleepTracks[3], sleepTracks[1], sleepTracks[6], sleepTracks[0],
          sleepTracks[9], sleepTracks[4], sleepTracks[5], sleepTracks[7],
          sleepTracks[8], sleepTracks[2], sleepTracks[10], sleepTracks[11],
        ];
        final sleepPianoSongs = [
          sleepTracks[2], sleepTracks[11], sleepTracks[8], sleepTracks[1],
          sleepTracks[6], sleepTracks[0], sleepTracks[3], sleepTracks[4],
          sleepTracks[5], sleepTracks[7], sleepTracks[9], sleepTracks[10],
        ];
        final sleepAcousticSongs = [
          sleepTracks[8], sleepTracks[2], sleepTracks[11], sleepTracks[4],
          sleepTracks[5], sleepTracks[0], sleepTracks[1], sleepTracks[3],
          sleepTracks[6], sleepTracks[7], sleepTracks[9], sleepTracks[10],
        ];
        final sleepAmbientSongs = [
          sleepTracks[6], sleepTracks[1], sleepTracks[7], sleepTracks[3],
          sleepTracks[0], sleepTracks[2], sleepTracks[4], sleepTracks[5],
          sleepTracks[8], sleepTracks[9], sleepTracks[10], sleepTracks[11],
        ];

        final heroTidur = Playlist(
          id: 'pl_sleep_deep',
          title: 'Deep Sleep & Gelombang Delta (12 Lagu)',
          subtitle: 'Frekuensi relaksasi untuk tidur lelap pulas tanpa terbangun',
          coverUrl: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=600',
          songs: sleepDeepSongs,
        );

        return CategoryData(
          category: category,
          heroPlaylist: heroTidur,
          sections: [
            CategorySection(
              title: 'Tidur Nyenyak (12 Lagu Tiap Playlist)',
              playlists: [
                heroTidur,
                Playlist(
                  id: 'pl_sleep_rain',
                  title: 'Suara Hujan & Badai Tenang',
                  subtitle: 'Gemercik hujan meredakan ketegangan tubuh dan pikiran',
                  coverUrl: 'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?w=600',
                  songs: sleepRainSongs,
                ),
                Playlist(
                  id: 'pl_sleep_white_noise',
                  title: 'White Noise Tidur Nyenyak',
                  subtitle: 'Derau putih isolasi suara malam hari',
                  coverUrl: 'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?w=600',
                  songs: sleepWhiteNoiseSongs,
                ),
              ],
            ),
            CategorySection(
              title: 'Instrumen & Frekuensi Relaksasi (12 Lagu)',
              playlists: [
                Playlist(
                  id: 'pl_sleep_piano',
                  title: 'Piano Pengantar Tidur',
                  subtitle: 'Sentuhan tuts piano akustik yang teduh dan menenangkan',
                  coverUrl: 'https://images.unsplash.com/photo-1478737270239-2f02b77fc618?w=600',
                  songs: sleepPianoSongs,
                ),
                Playlist(
                  id: 'pl_sleep_acoustic',
                  title: 'Gitar Akustik Malam Hari',
                  subtitle: 'Petikan dawai lembut pereda lelah sebelum terpejam',
                  coverUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600',
                  songs: sleepAcousticSongs,
                ),
                Playlist(
                  id: 'pl_sleep_ambient',
                  title: 'Ambient Meditasi Malam',
                  subtitle: 'Ketukan halus merelaksasi jiwa dan raga',
                  coverUrl: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=600',
                  songs: sleepAmbientSongs,
                ),
              ],
            ),
          ],
        );

      case 'musik_indonesia':
        final indoTopHitsSongs = [
          feat[1], feat[11], feat[15], feat[16], feat[19], feat[7],
          feat[3], feat[2], nos[0], nos[1], raimTracks[0], raimTracks[1],
        ];
        final indoPuncakSongs = [
          feat[11], feat[1], feat[15], feat[16], feat[18], feat[19],
          feat[7], feat[3], nos[1], nos[0], nos[2], nos[3],
        ];
        final indoPopSongs = [
          raimTracks[0], raimTracks[1], raimTracks[2], raimTracks[3],
          feat[1], feat[11], feat[15], feat[19], feat[7], nos[0],
          nos[1], nos[3],
        ];
        final indoAkustikSongs = [
          feat[3], feat[1], feat[7], raimTracks[0], raimTracks[3],
          feat[11], feat[15], nos[0], nos[3], nos[4], nos[5], nos[6],
        ];
        final indoSheilaSongs = [
          nos[1], nos[0], feat[2], feat[7], nos[2], nos[3],
          nos[4], nos[5], feat[1], feat[3], feat[11], feat[15],
        ];

        final heroIndo = Playlist(
          id: 'pl_indo_top_hits',
          title: 'Top Hits Indonesia (12 Lagu)',
          subtitle: 'Lagu Indonesia paling banyak didengarkan saat ini',
          coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/6f/18/10/6f1810e0-2d6a-a456-1362-de607c70408a/cover.jpg/600x600bb.jpg',
          songs: indoTopHitsSongs,
        );

        return CategoryData(
          category: category,
          heroPlaylist: heroIndo,
          sections: [
            CategorySection(
              title: 'Populer di Indonesia (12 Lagu Tiap Playlist)',
              playlists: [
                heroIndo,
                Playlist(
                  id: 'pl_indo_puncak',
                  title: 'Puncak Klasemen Indonesia',
                  subtitle: 'Tangga lagu terpanas minggu ini tanah air',
                  coverUrl: 'https://cdn-images.dzcdn.net/images/cover/f5809041de170abd4c84dcdede0d202a/1000x1000-000000-80-0-0.jpg',
                  songs: indoPuncakSongs,
                ),
                Playlist(
                  id: 'pl_indo_pop',
                  title: 'Pop Indo Terpopuler',
                  subtitle: 'Kompilasi lagu pop Indonesia terfavorit',
                  coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/3b/26/cb/3b26cbe3-8140-6f42-7b56-036a4e192ba5/2947485.jpg/1000x1000bb.jpg',
                  songs: indoPopSongs,
                ),
              ],
            ),
            CategorySection(
              title: 'Akustik & Chill Indo',
              playlists: [
                Playlist(
                  id: 'pl_indo_akustik_santai',
                  title: 'Akustik Santai Sore Hari',
                  subtitle: 'Petikan akustik kopi senja musisi lokal',
                  coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/f4/42/c7/f442c726-f2a1-c045-829e-45f33f2fe1d0/3615939061533.png/600x600bb.jpg',
                  songs: indoAkustikSongs,
                ),
                Playlist(
                  id: 'pl_indo_indie',
                  title: 'Indienesia Pilihan',
                  subtitle: 'Karya segar musisi independen tanah air',
                  coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/5a/69/54/5a695472-ccc4-3922-bd5f-939feff54b05/199800024511.jpg/600x600bb.jpg',
                  songs: indieTracks.take(12).toList(),
                ),
              ],
            ),
            CategorySection(
              title: 'Hits Nostalgia Indonesia',
              playlists: [
                Playlist(
                  id: 'pl_indo_sheila',
                  title: 'Kisah Klasik Sheila On 7',
                  subtitle: 'Deretan hits legendaris Sheila On 7',
                  coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music/v4/99/71/5e/99715e79-687c-d3d2-232f-186050577e45/886444671422.jpg/600x600bb.jpg',
                  songs: indoSheilaSongs,
                ),
                Playlist(
                  id: 'pl_indo_retro_2000',
                  title: 'Pop Retro 2000-an',
                  subtitle: 'Lagu kenangan masa sekolah yang membekas di hati',
                  coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music/90/01/6d/mzi.ywjxtlbq.jpg/600x600bb.jpg',
                  songs: nos,
                ),
              ],
            ),
          ],
        );

      default:
        final topDefaultSongs = [
          feat[0], feat[1], feat[2], feat[3], feat[4], feat[5],
          feat[6], feat[7], feat[8], feat[9], feat[10], feat[11],
        ];
        final chillDefaultSongs = [
          feat[3], feat[6], feat[8], feat[9], feat[13], feat[14],
          feat[15], feat[1], feat[4], nos[0], nos[1], nos[3],
        ];
        final essDefaultSongs = [
          feat[10], feat[12], feat[14], feat[16], feat[17], feat[18],
          feat[19], feat[0], feat[1], nos[8], nos[9], nos[10],
        ];

        return CategoryData(
          category: category,
          sections: [
            CategorySection(
              title: 'Unggulan ${category.title} (12 Lagu Tiap Playlist)',
              playlists: [
                Playlist(
                  id: 'pl_cat_${category.id}_top',
                  title: 'Top Hits ${category.title}',
                  subtitle: 'Pilihan lagu terbaik kategori ${category.title}',
                  coverUrl: category.imageUrl,
                  songs: topDefaultSongs,
                ),
                Playlist(
                  id: 'pl_cat_${category.id}_chill',
                  title: '${category.title} Santai',
                  subtitle: 'Melodi santai penghibur waktu luang',
                  coverUrl: feat[3].albumArtUrl,
                  songs: chillDefaultSongs,
                ),
                Playlist(
                  id: 'pl_cat_${category.id}_essentials',
                  title: '${category.title} Essentials',
                  subtitle: 'Kompilasi wajib dengar',
                  coverUrl: feat[10].albumArtUrl,
                  songs: essDefaultSongs,
                ),
              ],
            ),
            CategorySection(
              title: 'Populer Saat Ini',
              playlists: releases.take(3).toList(),
            ),
          ],
        );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FEATURED TRACKS — All verified real YouTube IDs & working iTunes CDN art
  // ─────────────────────────────────────────────────────────────────────────
  static List<Song> getFeaturedTracks() {
    return [
      // 1. The Weeknd - Blinding Lights
      Song(
        id: 'feat_weeknd_blinding',
        title: 'Blinding Lights',
        artist: 'The Weeknd',
        album: 'After Hours',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/2b/b9/fe/2bb9fef5-d7f3-8345-25a9-db0e79fde4e4/20UMGIM11048.rgb.jpg/600x600bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=4NRXx6U8ABQ',
        duration: const Duration(minutes: 3, seconds: 20),
        lyrics: Song.generateSampleLyrics('Blinding Lights'),
      ),

      // 2. Tulus - Hati-Hati di Jalan
      Song(
        id: 'feat_tulus_hatihati',
        title: 'Hati-Hati di Jalan',
        artist: 'Tulus',
        album: 'Manusia',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/6f/18/10/6f1810e0-2d6a-a456-1362-de607c70408a/cover.jpg/600x600bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=_N6vSc_mT6I',
        duration: const Duration(minutes: 4, seconds: 2),
        lyrics: Song.generateSampleLyrics('Hati-Hati di Jalan'),
      ),

      // 3. Sheila On 7 - Dan...
      Song(
        id: 'feat_so7_dan',
        title: 'Dan...',
        artist: 'Sheila On 7',
        album: 'Sheila On 7',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music/90/01/6d/mzi.ywjxtlbq.jpg/600x600bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=IWvo2fld3s4',
        duration: const Duration(minutes: 4, seconds: 48),
        lyrics: Song.generateSampleLyrics('Dan...'),
      ),

      // 4. Pamungkas - To the Bone
      Song(
        id: 'feat_pamungkas_tothebone',
        title: 'To the Bone',
        artist: 'Pamungkas',
        album: 'Flying Solo',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/f4/42/c7/f442c726-f2a1-c045-829e-45f33f2fe1d0/3615939061533.png/600x600bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=oIYWenB637c',
        duration: const Duration(minutes: 5, seconds: 44),
        lyrics: Song.generateSampleLyrics('To the Bone'),
      ),

      // 5. Daft Punk - Get Lucky
      Song(
        id: 'feat_daft_getlucky',
        title: 'Get Lucky',
        artist: 'Daft Punk',
        album: 'Random Access Memories',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/e8/43/5f/e8435ffa-b6b9-b171-40ab-4ff3959ab661/886443919266.jpg/600x600bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=5NV6Rdv1a3I',
        duration: const Duration(minutes: 4, seconds: 8),
        lyrics: Song.generateSampleLyrics('Get Lucky'),
      ),

      // 6. The Weeknd - Starboy
      Song(
        id: 'feat_weeknd_starboy',
        title: 'Starboy',
        artist: 'The Weeknd',
        album: 'Starboy',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/b5/92/bb/b592bb72-52e3-e756-9b26-9f56d08f47ab/16UMGIM67864.rgb.jpg/600x600bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=Rif-RTvmmss',
        duration: const Duration(minutes: 3, seconds: 50),
        lyrics: Song.generateSampleLyrics('Starboy'),
      ),

      // 7. Tulus - Monokrom
      Song(
        id: 'feat_tulus_monokrom',
        title: 'Monokrom',
        artist: 'Tulus',
        album: 'Monokrom',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music18/v4/d1/8f/41/d18f41cf-45e4-39f4-4d10-0a0af01f7eb7/cover.jpg/600x600bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=QqJ-Vp8mvbk',
        duration: const Duration(minutes: 3, seconds: 35),
        lyrics: Song.generateSampleLyrics('Monokrom'),
      ),

      // 8. Sheila On 7 - Film Favorit
      Song(
        id: 'feat_so7_filmfavorit',
        title: 'Film Favorit',
        artist: 'Sheila On 7',
        album: 'Film Favorit - Single',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/5a/69/54/5a695472-ccc4-3922-bd5f-939feff54b05/199800024511.jpg/600x600bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=cHKZ7eWiZjM',
        duration: const Duration(minutes: 3, seconds: 54),
        lyrics: Song.generateSampleLyrics('Film Favorit'),
      ),

      // 9. Coldplay - Yellow
      Song(
        id: 'feat_coldplay_yellow',
        title: 'Yellow',
        artist: 'Coldplay',
        album: 'Parachutes',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/f5/93/8c/f5938c49-964c-31d1-4b33-78b634f71fb7/190295978075.jpg/600x600bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=yKNxeF4KMsY',
        duration: const Duration(minutes: 4, seconds: 29),
        lyrics: Song.generateSampleLyrics('Yellow'),
      ),

      // 10. Coldplay - Fix You
      Song(
        id: 'feat_coldplay_fixyou',
        title: 'Fix You',
        artist: 'Coldplay',
        album: 'X&Y',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/0c/82/48/0c8248a8-4a5b-d30d-8056-f32d650d2fc9/190295978068.jpg/600x600bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=k4V3Mo61fJM',
        duration: const Duration(minutes: 4, seconds: 55),
        lyrics: Song.generateSampleLyrics('Fix You'),
      ),

      // 11. Lady Gaga & Bruno Mars - Die With A Smile
      Song(
        id: 'feat_brunomars_diewithasmile',
        title: 'Die With A Smile',
        artist: 'Lady Gaga & Bruno Mars',
        album: 'Die With A Smile - Single',
        albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/4bd5903f4ce8f2601916bfadb44efe8a/1000x1000-000000-80-0-0.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=kPa7bsKwL-c',
        duration: const Duration(minutes: 4, seconds: 11),
        lyrics: Song.generateSampleLyrics('Die With A Smile'),
      ),

      // 12. Bernadya - Satu Bulan
      Song(
        id: 'feat_bernadya_satubulan',
        title: 'Satu Bulan',
        artist: 'Bernadya',
        album: 'Sialnya, Hidup Harus Tetap Berjalan',
        albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/f5809041de170abd4c84dcdede0d202a/1000x1000-000000-80-0-0.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=yjnSX_iUFVo',
        duration: const Duration(minutes: 3, seconds: 12),
        lyrics: Song.generateSampleLyrics('Satu Bulan'),
      ),

      // 13. Taylor Swift - Cruel Summer
      Song(
        id: 'feat_taylor_cruelsummer',
        title: 'Cruel Summer',
        artist: 'Taylor Swift',
        album: 'Lover',
        albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/6111c5ab9729c8eac47883e4e50e9cf8/1000x1000-000000-80-0-0.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=JLJcHbYSlB8',
        duration: const Duration(minutes: 2, seconds: 58),
        lyrics: Song.generateSampleLyrics('Cruel Summer'),
      ),

      // 14. Billie Eilish - BIRDS OF A FEATHER
      Song(
        id: 'feat_billie_birdsofafeather',
        title: 'BIRDS OF A FEATHER',
        artist: 'Billie Eilish',
        album: 'HIT ME HARD AND SOFT',
        albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/5d284b31cb9ddeb1a0c79aede5a94e1c/1000x1000-000000-80-0-0.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=V9PVRfjEBTI',
        duration: const Duration(minutes: 3, seconds: 30),
        lyrics: Song.generateSampleLyrics('BIRDS OF A FEATHER'),
      ),

      // 15. Hindia - Evaluasi
      Song(
        id: 'feat_hindia_evaluasi',
        title: 'Evaluasi',
        artist: 'Hindia',
        album: 'Menari Dengan Bayangan',
        albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/23cc662ac90d414741c26754e0105d9d/1000x1000-000000-80-0-0.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=cWrSjCZ5AeE',
        duration: const Duration(minutes: 3, seconds: 24),
        lyrics: Song.generateSampleLyrics('Evaluasi'),
      ),

      // 16. NIKI - High School in Jakarta
      Song(
        id: 'feat_niki_highschool',
        title: 'High School in Jakarta',
        artist: 'NIKI',
        album: 'Nicole',
        albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/3f61783ca024dfd8f5cffdf92c55cf19/1000x1000-000000-80-0-0.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=d4CF4km1rUQ',
        duration: const Duration(minutes: 3, seconds: 39),
        lyrics: Song.generateSampleLyrics('High School in Jakarta'),
      ),

      // 17. Mahalini - Sial
      Song(
        id: 'feat_mahalini_sial',
        title: 'Sial',
        artist: 'Mahalini',
        album: 'Fabula',
        albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/ea2ee495e17ab155bdcdac0fe75cf513/1000x1000-000000-80-0-0.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=QSWYyoF79oE',
        duration: const Duration(minutes: 4, seconds: 3),
        lyrics: Song.generateSampleLyrics('Sial'),
      ),

      // 18. Sabrina Carpenter - Espresso
      Song(
        id: 'feat_sabrina_espresso',
        title: 'Espresso',
        artist: 'Sabrina Carpenter',
        album: 'Short n\' Sweet',
        albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/e3221287a77eb262944e6528766eeba4/1000x1000-000000-80-0-0.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=eVli-tstM5E',
        duration: const Duration(minutes: 2, seconds: 55),
        lyrics: Song.generateSampleLyrics('Espresso'),
      ),

      // 19. Sheila On 7 - Sephia
      Song(
        id: 'feat_so7_sephia',
        title: 'Sephia',
        artist: 'Sheila On 7',
        album: 'Kisah Klasik Untuk Masa Depan',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music/v4/99/71/5e/99715e79-687c-d3d2-232f-186050577e45/886444671422.jpg/600x600bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=dSR5dyHPUxA',
        duration: const Duration(minutes: 4, seconds: 40),
        lyrics: Song.generateSampleLyrics('Sephia'),
      ),

      // 20. Tulus - Diri
      Song(
        id: 'feat_tulus_diri',
        title: 'Diri',
        artist: 'Tulus',
        album: 'Manusia',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/6f/18/10/6f1810e0-2d6a-a456-1362-de607c70408a/cover.jpg/600x600bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=fsGcUWiylW8',
        duration: const Duration(minutes: 3, seconds: 32),
        lyrics: Song.generateSampleLyrics('Diri'),
      ),
    ];
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ARTISTS — Verified profiles, artwork, and full top tracks
  // ─────────────────────────────────────────────────────────────────────────
  static List<Artist> getArtists() {
    return [
      Artist(
        id: 'artist_raim_laode',
        name: 'Raim Laode',
        imageUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/3b/26/cb/3b26cbe3-8140-6f42-7b56-036a4e192ba5/2947485.jpg/1000x1000bb.jpg',
        headerImageUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/3b/26/cb/3b26cbe3-8140-6f42-7b56-036a4e192ba5/2947485.jpg/1000x1000bb.jpg',
        monthlyListeners: '4.850.320 pendengar bulanan',
        bio: 'Penyanyi, penulis lagu, dan komika asal Wakatobi, Sulawesi Tenggara. Pelantun hits mega-viral "Komang" yang menduduki peringkat #1 MusicXSpot Indonesia.',
        isVerified: true,
        topTracks: [
          Song(
            id: 'raim_1',
            title: 'Komang',
            artist: 'Raim Laode',
            album: 'Komang - Single',
            albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/6c/ce/b6/6cceb619-db30-d4d9-028b-b8fea5607994/6179.jpg/1000x1000bb.jpg',
            audioUrl: 'https://www.youtube.com/watch?v=d_k8wBvH130',
            duration: const Duration(minutes: 3, seconds: 42),
            lyrics: Song.generateSampleLyrics('Komang'),
          ),
          Song(
            id: 'raim_2',
            title: 'Dunia Yang Nanti',
            artist: 'Raim Laode',
            album: 'Dunia Yang Nanti - Single',
            albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/3b/26/cb/3b26cbe3-8140-6f42-7b56-036a4e192ba5/2947485.jpg/1000x1000bb.jpg',
            audioUrl: 'https://www.youtube.com/watch?v=28l2Yg5vAqk',
            duration: const Duration(minutes: 4, seconds: 10),
            lyrics: Song.generateSampleLyrics('Dunia Yang Nanti'),
          ),
          Song(
            id: 'raim_3',
            title: 'Lesung Pipi',
            artist: 'Raim Laode',
            album: 'Lesung Pipi - Single',
            albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/d6/9e/a3/d69ea311-9c75-0109-1938-1a6f00ba0cc4/5019.jpg/1000x1000bb.jpg',
            audioUrl: 'https://www.youtube.com/watch?v=mJE0ROBWPvY',
            duration: const Duration(minutes: 3, seconds: 32),
            lyrics: Song.generateSampleLyrics('Lesung Pipi'),
          ),
          Song(
            id: 'raim_4',
            title: 'Bersenja Gurau',
            artist: 'Raim Laode',
            album: 'Bersenja Gurau - Single',
            albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/b1/ff/b8/b1ffb889-72db-8a72-7697-610db5df704f/5050.jpg/1000x1000bb.jpg',
            audioUrl: 'https://www.youtube.com/watch?v=vVjV45Pz0jE',
            duration: const Duration(minutes: 3, seconds: 55),
            lyrics: Song.generateSampleLyrics('Bersenja Gurau'),
          ),
          Song(
            id: 'raim_5',
            title: 'iqro\'',
            artist: 'Raim Laode',
            album: 'iqro\' - Single',
            albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/99/3a/ca/993aca2e-32b9-0304-4446-a23da44a13d7/326772.jpg/1000x1000bb.jpg',
            audioUrl: 'https://www.youtube.com/watch?v=uK1zP2YvN8Y',
            duration: const Duration(minutes: 3, seconds: 28),
            lyrics: Song.generateSampleLyrics('iqro\''),
          ),
          Song(
            id: 'raim_6',
            title: 'Menari-nari',
            artist: 'Raim Laode',
            album: 'Menari-nari - Single',
            albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/3b/26/cb/3b26cbe3-8140-6f42-7b56-036a4e192ba5/2947485.jpg/1000x1000bb.jpg',
            audioUrl: 'https://www.youtube.com/watch?v=P2d8n7c4gLo',
            duration: const Duration(minutes: 3, seconds: 38),
            lyrics: Song.generateSampleLyrics('Menari-nari'),
          ),
        ],
        albums: const [
          ArtistAlbum(
            id: 'dz_alb_dunia_nanti',
            title: 'Dunia Yang Nanti',
            coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/3b/26/cb/3b26cbe3-8140-6f42-7b56-036a4e192ba5/2947485.jpg/1000x1000bb.jpg',
            releaseYear: '2024',
            type: 'Single',
          ),
          ArtistAlbum(
            id: 'dz_alb_komang',
            title: 'Komang',
            coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/6c/ce/b6/6cceb619-db30-d4d9-028b-b8fea5607994/6179.jpg/1000x1000bb.jpg',
            releaseYear: '2022',
            type: 'Single',
          ),
          ArtistAlbum(
            id: 'dz_alb_lesung_pipi',
            title: 'Lesung Pipi',
            coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/d6/9e/a3/d69ea311-9c75-0109-1938-1a6f00ba0cc4/5019.jpg/1000x1000bb.jpg',
            releaseYear: '2023',
            type: 'Single',
          ),
          ArtistAlbum(
            id: 'dz_alb_bersenja_gurau',
            title: 'Bersenja Gurau',
            coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/b1/ff/b8/b1ffb889-72db-8a72-7697-610db5df704f/5050.jpg/1000x1000bb.jpg',
            releaseYear: '2021',
            type: 'Single',
          ),
          ArtistAlbum(
            id: 'dz_alb_iqro',
            title: 'iqro\'',
            coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/99/3a/ca/993aca2e-32b9-0304-4446-a23da44a13d7/326772.jpg/1000x1000bb.jpg',
            releaseYear: '2023',
            type: 'Single',
          ),
        ],
      ),
      Artist(
        id: 'artist_tulus',
        name: 'Tulus',
        imageUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/6f/18/10/6f1810e0-2d6a-a456-1362-de607c70408a/cover.jpg/600x600bb.jpg',
        headerImageUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/6f/18/10/6f1810e0-2d6a-a456-1362-de607c70408a/cover.jpg/600x600bb.jpg',
        monthlyListeners: '14.285.910 pendengar bulanan',
        bio: 'Penyanyi dan penulis lagu asal Bukittinggi, Indonesia. Karya-karyanya selalu menduduki puncak tangga lagu MusicXSpot Indonesia dengan lirik puitis dan harmoni yang hangat.',
        topTracks: [
          Song(id: 'tulus_1', title: 'Hati-Hati di Jalan', artist: 'Tulus', album: 'Manusia',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/6f/18/10/6f1810e0-2d6a-a456-1362-de607c70408a/cover.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=_N6vSc_mT6I',
              duration: const Duration(minutes: 4, seconds: 2),
              lyrics: Song.generateSampleLyrics('Hati-Hati di Jalan')),
          Song(id: 'tulus_2', title: 'Monokrom', artist: 'Tulus', album: 'Monokrom',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music18/v4/d1/8f/41/d18f41cf-45e4-39f4-4d10-0a0af01f7eb7/cover.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=QqJ-Vp8mvbk',
              duration: const Duration(minutes: 3, seconds: 35),
              lyrics: Song.generateSampleLyrics('Monokrom')),
          Song(id: 'tulus_3', title: 'Diri', artist: 'Tulus', album: 'Manusia',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/6f/18/10/6f1810e0-2d6a-a456-1362-de607c70408a/cover.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=fsGcUWiylW8',
              duration: const Duration(minutes: 3, seconds: 32),
              lyrics: Song.generateSampleLyrics('Diri')),
          Song(id: 'tulus_4', title: 'Interaksi', artist: 'Tulus', album: 'Manusia',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/6f/18/10/6f1810e0-2d6a-a456-1362-de607c70408a/cover.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=GIy9ZbH0sHo',
              duration: const Duration(minutes: 2, seconds: 50),
              lyrics: Song.generateSampleLyrics('Interaksi')),
          Song(id: 'tulus_5', title: 'Sepatu', artist: 'Tulus', album: 'Gajah',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music124/v4/18/ef/7b/18ef7b5d-80e8-e4c7-838a-3110ebf94e52/cover.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=Q4kQZmPlUSo',
              duration: const Duration(minutes: 3, seconds: 40),
              lyrics: Song.generateSampleLyrics('Sepatu')),
        ],
        albums: const [
          ArtistAlbum(
            id: 'alb_tulus_manusia',
            title: 'Manusia',
            coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/6f/18/10/6f1810e0-2d6a-a456-1362-de607c70408a/cover.jpg/600x600bb.jpg',
            releaseYear: '2022',
            type: 'Album',
          ),
          ArtistAlbum(
            id: 'alb_tulus_monokrom',
            title: 'Monokrom',
            coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music18/v4/d1/8f/41/d18f41cf-45e4-39f4-4d10-0a0af01f7eb7/cover.jpg/600x600bb.jpg',
            releaseYear: '2016',
            type: 'Album',
          ),
          ArtistAlbum(
            id: 'alb_tulus_gajah',
            title: 'Gajah',
            coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music124/v4/18/ef/7b/18ef7b5d-80e8-e4c7-838a-3110ebf94e52/cover.jpg/600x600bb.jpg',
            releaseYear: '2014',
            type: 'Album',
          ),
        ],
      ),

      Artist(
        id: 'artist_the_weeknd',
        name: 'The Weeknd',
        imageUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/2b/b9/fe/2bb9fef5-d7f3-8345-25a9-db0e79fde4e4/20UMGIM11048.rgb.jpg/600x600bb.jpg',
        headerImageUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/2b/b9/fe/2bb9fef5-d7f3-8345-25a9-db0e79fde4e4/20UMGIM11048.rgb.jpg/600x600bb.jpg',
        monthlyListeners: '107.540.230 pendengar bulanan',
        bio: 'Abel Makkonen Tesfaye, secara profesional dikenal sebagai The Weeknd. Artis nomor 1 di dunia di MusicXSpot dengan ratusan juta pendengar setiap bulannya.',
        topTracks: [
          Song(id: 'weeknd_1', title: 'Blinding Lights', artist: 'The Weeknd', album: 'After Hours',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/2b/b9/fe/2bb9fef5-d7f3-8345-25a9-db0e79fde4e4/20UMGIM11048.rgb.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=4NRXx6U8ABQ',
              duration: const Duration(minutes: 3, seconds: 20),
              lyrics: Song.generateSampleLyrics('Blinding Lights')),
          Song(id: 'weeknd_2', title: 'Starboy', artist: 'The Weeknd', album: 'Starboy',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/b5/92/bb/b592bb72-52e3-e756-9b26-9f56d08f47ab/16UMGIM67864.rgb.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=Rif-RTvmmss',
              duration: const Duration(minutes: 3, seconds: 50),
              lyrics: Song.generateSampleLyrics('Starboy')),
          Song(id: 'weeknd_3', title: 'Save Your Tears', artist: 'The Weeknd', album: 'After Hours',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music124/v4/83/3a/f7/833af71b-2e0c-3303-24f5-8f5c546c073b/20UMGIM21167.rgb.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=u6lihZAcy4s',
              duration: const Duration(minutes: 3, seconds: 35),
              lyrics: Song.generateSampleLyrics('Save Your Tears')),
        ],
      ),

      Artist(
        id: 'artist_so7',
        name: 'Sheila On 7',
        imageUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music/90/01/6d/mzi.ywjxtlbq.jpg/600x600bb.jpg',
        headerImageUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music/90/01/6d/mzi.ywjxtlbq.jpg/600x600bb.jpg',
        monthlyListeners: '7.892.400 pendengar bulanan',
        bio: 'Grup musik pop rock legendaris asal Yogyakarta yang didirikan pada tahun 1996. Salah satu band paling dicintai di Indonesia dengan hits abadi melintasi generasi.',
        topTracks: [
          Song(id: 'so7_1', title: 'Dan...', artist: 'Sheila On 7', album: 'Sheila On 7',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music/90/01/6d/mzi.ywjxtlbq.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=IWvo2fld3s4',
              duration: const Duration(minutes: 4, seconds: 48),
              lyrics: Song.generateSampleLyrics('Dan...')),
          Song(id: 'so7_2', title: 'Film Favorit', artist: 'Sheila On 7', album: 'Film Favorit - Single',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/5a/69/54/5a695472-ccc4-3922-bd5f-939feff54b05/199800024511.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=cHKZ7eWiZjM',
              duration: const Duration(minutes: 3, seconds: 54),
              lyrics: Song.generateSampleLyrics('Film Favorit')),
          Song(id: 'so7_3', title: 'Sephia', artist: 'Sheila On 7', album: 'Kisah Klasik Untuk Masa Depan',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music/v4/99/71/5e/99715e79-687c-d3d2-232f-186050577e45/886444671422.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=dSR5dyHPUxA',
              duration: const Duration(minutes: 4, seconds: 40),
              lyrics: Song.generateSampleLyrics('Sephia')),
        ],
      ),

      Artist(
        id: 'artist_daft_punk',
        name: 'Daft Punk',
        imageUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/e8/43/5f/e8435ffa-b6b9-b171-40ab-4ff3959ab661/886443919266.jpg/600x600bb.jpg',
        headerImageUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/e8/43/5f/e8435ffa-b6b9-b171-40ab-4ff3959ab661/886443919266.jpg/600x600bb.jpg',
        monthlyListeners: '23.415.600 pendengar bulanan',
        bio: 'Duo musik elektronik ikonik asal Paris, Prancis, yang memelopori gelombang musik synth dan french house di seluruh dunia.',
        topTracks: [
          Song(id: 'daft_1', title: 'Get Lucky', artist: 'Daft Punk', album: 'Random Access Memories',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/e8/43/5f/e8435ffa-b6b9-b171-40ab-4ff3959ab661/886443919266.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=5NV6Rdv1a3I',
              duration: const Duration(minutes: 4, seconds: 8),
              lyrics: Song.generateSampleLyrics('Get Lucky')),
          Song(id: 'daft_2', title: 'One More Time', artist: 'Daft Punk', album: 'Discovery',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/fd/4a/77/fd4a77db-0ebc-d043-41a2-f32fa1bb0fb4/dj.qrikkdwj.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=A2VpR8HahKc',
              duration: const Duration(minutes: 5, seconds: 20),
              lyrics: Song.generateSampleLyrics('One More Time')),
        ],
      ),

      Artist(
        id: 'artist_coldplay',
        name: 'Coldplay',
        imageUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/f5/93/8c/f5938c49-964c-31d1-4b33-78b634f71fb7/190295978075.jpg/600x600bb.jpg',
        headerImageUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/0c/82/48/0c8248a8-4a5b-d30d-8056-f32d650d2fc9/190295978068.jpg/600x600bb.jpg',
        monthlyListeners: '68.120.400 pendengar bulanan',
        bio: 'Band rock alternatif asal London, Inggris, yang terdiri dari Chris Martin, Jonny Buckland, Guy Berryman, dan Will Champion. Salah satu band paling sukses di dunia.',
        topTracks: [
          Song(id: 'coldplay_1', title: 'Yellow', artist: 'Coldplay', album: 'Parachutes',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/f5/93/8c/f5938c49-964c-31d1-4b33-78b634f71fb7/190295978075.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=yKNxeF4KMsY',
              duration: const Duration(minutes: 4, seconds: 29),
              lyrics: Song.generateSampleLyrics('Yellow')),
          Song(id: 'coldplay_2', title: 'Fix You', artist: 'Coldplay', album: 'X&Y',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/0c/82/48/0c8248a8-4a5b-d30d-8056-f32d650d2fc9/190295978068.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=k4V3Mo61fJM',
              duration: const Duration(minutes: 4, seconds: 55),
              lyrics: Song.generateSampleLyrics('Fix You')),
          Song(id: 'coldplay_3', title: 'The Scientist', artist: 'Coldplay', album: 'A Rush of Blood to the Head',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/b9/b4/2a/b9b42ad1-1e25-5096-da43-497a247e69a3/190295978051.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=RB-RcX5DS5A',
              duration: const Duration(minutes: 5, seconds: 9),
              lyrics: Song.generateSampleLyrics('The Scientist')),
          Song(id: 'coldplay_4', title: 'Viva La Vida', artist: 'Coldplay', album: 'Viva La Vida',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/52/aa/85/52aa851f-15b7-6322-f91f-df84b15b7b19/190295978044.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=dvgZkm1xWPE',
              duration: const Duration(minutes: 4, seconds: 2),
              lyrics: Song.generateSampleLyrics('Viva La Vida')),
        ],
      ),

      Artist(
        id: 'artist_bernadya',
        name: 'Bernadya',
        imageUrl: 'https://cdn-images.dzcdn.net/images/artist/5bd274a72993ee8b8e72a7a8aedc12b5/1000x1000-000000-80-0-0.jpg',
        headerImageUrl: 'https://cdn-images.dzcdn.net/images/artist/5bd274a72993ee8b8e72a7a8aedc12b5/1000x1000-000000-80-0-0.jpg',
        monthlyListeners: '13.910.420 pendengar bulanan',
        bio: 'Penyanyi dan penulis lagu asal Surabaya. Album perdananya "Sialnya, Hidup Harus Tetap Berjalan" memecahkan rekor streaming MusicXSpot di Indonesia.',
        topTracks: [
          Song(id: 'bernadya_1', title: 'Satu Bulan', artist: 'Bernadya', album: 'Sialnya, Hidup Harus Tetap Berjalan',
              albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/f5809041de170abd4c84dcdede0d202a/1000x1000-000000-80-0-0.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=yjnSX_iUFVo',
              duration: const Duration(minutes: 3, seconds: 12),
              lyrics: Song.generateSampleLyrics('Satu Bulan')),
          Song(id: 'bernadya_2', title: 'Kata Mereka Ini Berlebihan', artist: 'Bernadya', album: 'Sialnya, Hidup Harus Tetap Berjalan',
              albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/f5809041de170abd4c84dcdede0d202a/1000x1000-000000-80-0-0.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=C7D-gq02i9Q',
              duration: const Duration(minutes: 3, seconds: 6),
              lyrics: Song.generateSampleLyrics('Kata Mereka Ini Berlebihan')),
          Song(id: 'bernadya_3', title: 'Kini Mereka Tahu', artist: 'Bernadya', album: 'Sialnya, Hidup Harus Tetap Berjalan',
              albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/f5809041de170abd4c84dcdede0d202a/1000x1000-000000-80-0-0.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=Xh0YqJg06yU',
              duration: const Duration(minutes: 3, seconds: 40),
              lyrics: Song.generateSampleLyrics('Kini Mereka Tahu')),
        ],
        albums: const [
          ArtistAlbum(
            id: '602528092',
            title: 'Sialnya, Hidup Harus Tetap Berjalan',
            coverUrl: 'https://cdn-images.dzcdn.net/images/cover/870667b82b372984ba65f023eb74f4a6/1000x1000-000000-80-0-0.jpg',
            releaseYear: '2024',
            type: 'Album',
          ),
          ArtistAlbum(
            id: '453886595',
            title: 'Terlintas',
            coverUrl: 'https://cdn-images.dzcdn.net/images/cover/f5809041de170abd4c84dcdede0d202a/1000x1000-000000-80-0-0.jpg',
            releaseYear: '2023',
            type: 'EP',
          ),
        ],
      ),

      Artist(
        id: 'artist_bruno_mars',
        name: 'Bruno Mars',
        country: 'Amerika Serikat',
        genres: const ['Pop', 'R&B', 'Funk', 'Soul'],
        imageUrl: 'https://cdn-images.dzcdn.net/images/artist/90f0b5b11df4f87ee878f38569b5995b/1000x1000-000000-80-0-0.jpg',
        headerImageUrl: 'https://cdn-images.dzcdn.net/images/artist/90f0b5b11df4f87ee878f38569b5995b/1000x1000-000000-80-0-0.jpg',
        monthlyListeners: '120.450.800 pendengar bulanan',
        bio: 'Pemenang belasan Grammy Awards dan salah satu penyanyi serta produser musik paling berpengaruh di dunia pelantun "24K Magic", "That\'s What I Like", dan "Versace on the Floor".',
        isVerified: true,
        topTracks: [
          Song(
            id: 'bruno_24k_magic',
            title: '24K Magic',
            artist: 'Bruno Mars',
            album: '24K Magic',
            albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/e3/47/a0/e347a0cc-87ce-5d05-d560-176c7d48f66e/075679904119.jpg/1000x1000bb.jpg',
            audioUrl: 'https://www.youtube.com/watch?v=UqyT8IEBkvY',
            duration: const Duration(minutes: 3, seconds: 46),
            lyrics: Song.generateSampleLyrics('24K Magic'),
          ),
          Song(
            id: 'bruno_thats_what_i_like',
            title: 'That\'s What I Like',
            artist: 'Bruno Mars',
            album: '24K Magic',
            albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/e3/47/a0/e347a0cc-87ce-5d05-d560-176c7d48f66e/075679904119.jpg/1000x1000bb.jpg',
            audioUrl: 'https://www.youtube.com/watch?v=PMivT7MJ41M',
            duration: const Duration(minutes: 3, seconds: 26),
            lyrics: Song.generateSampleLyrics('That\'s What I Like'),
          ),
          Song(
            id: 'bruno_versace_on_the_floor',
            title: 'Versace on the Floor',
            artist: 'Bruno Mars',
            album: '24K Magic',
            albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/e3/47/a0/e347a0cc-87ce-5d05-d560-176c7d48f66e/075679904119.jpg/1000x1000bb.jpg',
            audioUrl: 'https://www.youtube.com/watch?v=-FyjE33PhF4',
            duration: const Duration(minutes: 4, seconds: 21),
            lyrics: Song.generateSampleLyrics('Versace on the Floor'),
          ),
          Song(
            id: 'bruno_1',
            title: 'Die With A Smile',
            artist: 'Lady Gaga & Bruno Mars',
            album: 'Die With A Smile - Single',
            albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/4bd5903f4ce8f2601916bfadb44efe8a/1000x1000-000000-80-0-0.jpg',
            audioUrl: 'https://www.youtube.com/watch?v=kPa7bsKwL-c',
            duration: const Duration(minutes: 4, seconds: 11),
            lyrics: Song.generateSampleLyrics('Die With A Smile'),
          ),
          Song(
            id: 'bruno_locked_out_of_heaven',
            title: 'Locked Out of Heaven',
            artist: 'Bruno Mars',
            album: 'Unorthodox Jukebox',
            albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/3d/bf/52/3dbf52eb-aee5-c944-d621-e789ee9cfc4f/075679958044.jpg/1000x1000bb.jpg',
            audioUrl: 'https://www.youtube.com/watch?v=e-fA-gBCkj0',
            duration: const Duration(minutes: 3, seconds: 53),
            lyrics: Song.generateSampleLyrics('Locked Out of Heaven'),
          ),
          Song(
            id: 'bruno_when_i_was_your_man',
            title: 'When I Was Your Man',
            artist: 'Bruno Mars',
            album: 'Unorthodox Jukebox',
            albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/3d/bf/52/3dbf52eb-aee5-c944-d621-e789ee9cfc4f/075679958044.jpg/1000x1000bb.jpg',
            audioUrl: 'https://www.youtube.com/watch?v=ekzHIWGv83s',
            duration: const Duration(minutes: 3, seconds: 33),
            lyrics: Song.generateSampleLyrics('When I Was Your Man'),
          ),
        ],
        albums: [
          ArtistAlbum(
            id: 'alb_bruno_24k_magic',
            title: '24K Magic',
            coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/e3/47/a0/e347a0cc-87ce-5d05-d560-176c7d48f66e/075679904119.jpg/1000x1000bb.jpg',
            releaseYear: '2016',
            type: 'Album',
            songs: [
              Song(
                id: 'bruno_24k_1',
                title: '24K Magic',
                artist: 'Bruno Mars',
                album: '24K Magic',
                albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/e3/47/a0/e347a0cc-87ce-5d05-d560-176c7d48f66e/075679904119.jpg/1000x1000bb.jpg',
                audioUrl: 'https://www.youtube.com/watch?v=UqyT8IEBkvY',
                duration: const Duration(minutes: 3, seconds: 46),
                lyrics: Song.generateSampleLyrics('24K Magic'),
              ),
              Song(
                id: 'bruno_24k_2',
                title: 'Chunky',
                artist: 'Bruno Mars',
                album: '24K Magic',
                albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/e3/47/a0/e347a0cc-87ce-5d05-d560-176c7d48f66e/075679904119.jpg/1000x1000bb.jpg',
                audioUrl: 'https://www.youtube.com/watch?v=pX9_z3cOQeY',
                duration: const Duration(minutes: 3, seconds: 6),
                lyrics: Song.generateSampleLyrics('Chunky'),
              ),
              Song(
                id: 'bruno_24k_3',
                title: 'Perm',
                artist: 'Bruno Mars',
                album: '24K Magic',
                albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/e3/47/a0/e347a0cc-87ce-5d05-d560-176c7d48f66e/075679904119.jpg/1000x1000bb.jpg',
                audioUrl: 'https://www.youtube.com/watch?v=kXm38m5j5fU',
                duration: const Duration(minutes: 3, seconds: 30),
                lyrics: Song.generateSampleLyrics('Perm'),
              ),
              Song(
                id: 'bruno_24k_4',
                title: 'That\'s What I Like',
                artist: 'Bruno Mars',
                album: '24K Magic',
                albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/e3/47/a0/e347a0cc-87ce-5d05-d560-176c7d48f66e/075679904119.jpg/1000x1000bb.jpg',
                audioUrl: 'https://www.youtube.com/watch?v=PMivT7MJ41M',
                duration: const Duration(minutes: 3, seconds: 26),
                lyrics: Song.generateSampleLyrics('That\'s What I Like'),
              ),
              Song(
                id: 'bruno_24k_5',
                title: 'Versace on the Floor',
                artist: 'Bruno Mars',
                album: '24K Magic',
                albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/e3/47/a0/e347a0cc-87ce-5d05-d560-176c7d48f66e/075679904119.jpg/1000x1000bb.jpg',
                audioUrl: 'https://www.youtube.com/watch?v=-FyjE33PhF4',
                duration: const Duration(minutes: 4, seconds: 21),
                lyrics: Song.generateSampleLyrics('Versace on the Floor'),
              ),
              Song(
                id: 'bruno_24k_6',
                title: 'Straight Up & Down',
                artist: 'Bruno Mars',
                album: '24K Magic',
                albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/e3/47/a0/e347a0cc-87ce-5d05-d560-176c7d48f66e/075679904119.jpg/1000x1000bb.jpg',
                audioUrl: 'https://www.youtube.com/watch?v=vE-QWp_V1kY',
                duration: const Duration(minutes: 3, seconds: 18),
                lyrics: Song.generateSampleLyrics('Straight Up & Down'),
              ),
              Song(
                id: 'bruno_24k_7',
                title: 'Calling All My Lovelies',
                artist: 'Bruno Mars',
                album: '24K Magic',
                albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/e3/47/a0/e347a0cc-87ce-5d05-d560-176c7d48f66e/075679904119.jpg/1000x1000bb.jpg',
                audioUrl: 'https://www.youtube.com/watch?v=4g6V-Zg_Xoc',
                duration: const Duration(minutes: 4, seconds: 10),
                lyrics: Song.generateSampleLyrics('Calling All My Lovelies'),
              ),
              Song(
                id: 'bruno_24k_8',
                title: 'Finesse',
                artist: 'Bruno Mars',
                album: '24K Magic',
                albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/e3/47/a0/e347a0cc-87ce-5d05-d560-176c7d48f66e/075679904119.jpg/1000x1000bb.jpg',
                audioUrl: 'https://www.youtube.com/watch?v=LsoLEjrDogU',
                duration: const Duration(minutes: 3, seconds: 10),
                lyrics: Song.generateSampleLyrics('Finesse'),
              ),
              Song(
                id: 'bruno_24k_9',
                title: 'Too Good to Say Goodbye',
                artist: 'Bruno Mars',
                album: '24K Magic',
                albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/e3/47/a0/e347a0cc-87ce-5d05-d560-176c7d48f66e/075679904119.jpg/1000x1000bb.jpg',
                audioUrl: 'https://www.youtube.com/watch?v=k3uK1Z92R6c',
                duration: const Duration(minutes: 4, seconds: 41),
                lyrics: Song.generateSampleLyrics('Too Good to Say Goodbye'),
              ),
            ],
          ),
          const ArtistAlbum(
            id: 'alb_bruno_unorthodox',
            title: 'Unorthodox Jukebox',
            coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/3d/bf/52/3dbf52eb-aee5-c944-d621-e789ee9cfc4f/075679958044.jpg/1000x1000bb.jpg',
            releaseYear: '2012',
            type: 'Album',
          ),
          const ArtistAlbum(
            id: 'alb_bruno_doowops',
            title: 'Doo-Wops & Hooligans',
            coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/21/d9/ca/21d9ca96-8051-7f41-b842-1e9d19a27b87/075679954008.jpg/1000x1000bb.jpg',
            releaseYear: '2010',
            type: 'Album',
          ),
        ],
      ),

      Artist(
        id: 'artist_taylor_swift',
        name: 'Taylor Swift',
        imageUrl: 'https://cdn-images.dzcdn.net/images/artist/cc2495870fe1a792ad0cdb05501ad5ec/1000x1000-000000-80-0-0.jpg',
        headerImageUrl: 'https://cdn-images.dzcdn.net/images/artist/cc2495870fe1a792ad0cdb05501ad5ec/1000x1000-000000-80-0-0.jpg',
        monthlyListeners: '105.820.100 pendengar bulanan',
        bio: 'Penyanyi dan penulis lagu global dengan pengaruh budaya terbesar di era modern.',
        topTracks: [
          Song(id: 'taylor_1', title: 'Cruel Summer', artist: 'Taylor Swift', album: 'Lover',
              albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/6111c5ab9729c8eac47883e4e50e9cf8/1000x1000-000000-80-0-0.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=JLJcHbYSlB8',
              duration: const Duration(minutes: 2, seconds: 58),
              lyrics: Song.generateSampleLyrics('Cruel Summer')),
        ],
      ),

      Artist(
        id: 'artist_hindia',
        name: 'Hindia',
        imageUrl: 'https://cdn-images.dzcdn.net/images/artist/b33a022fb4490dce3b6e12d1c19c0123/1000x1000-000000-80-0-0.jpg',
        headerImageUrl: 'https://cdn-images.dzcdn.net/images/artist/b33a022fb4490dce3b6e12d1c19c0123/1000x1000-000000-80-0-0.jpg',
        monthlyListeners: '8.450.200 pendengar bulanan',
        bio: 'Baskara Putra, musisi dan penulis lirik asal Jakarta yang karyanya menangkap keresahan generasi muda.',
        topTracks: [
          Song(id: 'hindia_1', title: 'Evaluasi', artist: 'Hindia', album: 'Menari Dengan Bayangan',
              albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/23cc662ac90d414741c26754e0105d9d/1000x1000-000000-80-0-0.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=cWrSjCZ5AeE',
              duration: const Duration(minutes: 3, seconds: 24),
              lyrics: Song.generateSampleLyrics('Evaluasi')),
        ],
      ),

      Artist(
        id: 'artist_niki',
        name: 'NIKI',
        imageUrl: 'https://cdn-images.dzcdn.net/images/artist/324c50c04a5a944117cd3daa0963fc63/1000x1000-000000-80-0-0.jpg',
        headerImageUrl: 'https://cdn-images.dzcdn.net/images/artist/324c50c04a5a944117cd3daa0963fc63/1000x1000-000000-80-0-0.jpg',
        monthlyListeners: '11.230.900 pendengar bulanan',
        bio: 'Nicole Zefanya, musisi R&B dan indie-pop asal Jakarta di bawah naungan 88rising yang mendunia.',
        topTracks: [
          Song(id: 'niki_1', title: 'High School in Jakarta', artist: 'NIKI', album: 'Nicole',
              albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/3f61783ca024dfd8f5cffdf92c55cf19/1000x1000-000000-80-0-0.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=d4CF4km1rUQ',
              duration: const Duration(minutes: 3, seconds: 39),
              lyrics: Song.generateSampleLyrics('High School in Jakarta')),
        ],
      ),

      Artist(
        id: 'artist_billie_eilish',
        name: 'Billie Eilish',
        imageUrl: 'https://cdn-images.dzcdn.net/images/artist/8eab1a9a644889aabaca1e193e05f984/1000x1000-000000-80-0-0.jpg',
        headerImageUrl: 'https://cdn-images.dzcdn.net/images/artist/8eab1a9a644889aabaca1e193e05f984/1000x1000-000000-80-0-0.jpg',
        monthlyListeners: '98.340.500 pendengar bulanan',
        bio: 'Pelopor genre alt-pop modern pemenang Oscar dan Grammy termuda.',
        topTracks: [
          Song(id: 'billie_1', title: 'BIRDS OF A FEATHER', artist: 'Billie Eilish', album: 'HIT ME HARD AND SOFT',
              albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/5d284b31cb9ddeb1a0c79aede5a94e1c/1000x1000-000000-80-0-0.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=V9PVRfjEBTI',
              duration: const Duration(minutes: 3, seconds: 30),
              lyrics: Song.generateSampleLyrics('BIRDS OF A FEATHER')),
        ],
      ),

      Artist(
        id: 'artist_mahalini',
        name: 'Mahalini',
        imageUrl: 'https://cdn-images.dzcdn.net/images/artist/bbb3c9932bf14c2ca059e24a041baf91/1000x1000-000000-80-0-0.jpg',
        headerImageUrl: 'https://cdn-images.dzcdn.net/images/artist/bbb3c9932bf14c2ca059e24a041baf91/1000x1000-000000-80-0-0.jpg',
        monthlyListeners: '9.120.800 pendengar bulanan',
        bio: 'Penyanyi pop berdarah Bali dengan vokal khas penuh penghayatan emosional pelantun hits "Sial", "Sisa Rasa", dan "Mati-Matian".',
        isVerified: true,
        country: 'Indonesia',
        genres: const ['Pop', 'Indonesian Pop', 'Ballad'],
        topTracks: [
          Song(id: 'mahalini_1', title: 'Sial', artist: 'Mahalini', album: 'Fábula',
              albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/ea2ee495e17ab155bdcdac0fe75cf513/1000x1000-000000-80-0-0.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=QSWYyoF79oE',
              duration: const Duration(minutes: 4, seconds: 3),
              lyrics: Song.generateSampleLyrics('Sial')),
          Song(id: 'mahalini_2', title: 'Sisa Rasa', artist: 'Mahalini', album: 'Fábula',
              albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/ea2ee495e17ab155bdcdac0fe75cf513/1000x1000-000000-80-0-0.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=kYJzX9eP69Y',
              duration: const Duration(minutes: 4, seconds: 14)),
          Song(id: 'mahalini_3', title: 'Mati-Matian', artist: 'Mahalini', album: 'Mati-Matian',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/4a/01/a2/4a01a2d5-94f3-6bf2-72bf-08e1694f272a/198704204488.jpg/1000x1000bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=b4bU7J7f3p8',
              duration: const Duration(minutes: 4, seconds: 8)),
          Song(id: 'mahalini_4', title: 'Kisah Sempurna', artist: 'Mahalini', album: 'Fábula',
              albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/ea2ee495e17ab155bdcdac0fe75cf513/1000x1000-000000-80-0-0.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=1d9p-c3m_78',
              duration: const Duration(minutes: 4, seconds: 36)),
          Song(id: 'mahalini_5', title: 'Bermuara', artist: 'Rizky Febian & Mahalini', album: 'Bermuara',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/ce/22/0c/ce220c38-895c-a5b8-53e7-3f3ae99a0951/198704381288.jpg/1000x1000bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=bZ7Jk9uH7j0',
              duration: const Duration(minutes: 3, seconds: 58)),
          Song(id: 'mahalini_6', title: 'Sampai Menutup Mata', artist: 'Mahalini', album: 'Sampai Menutup Mata',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/21/df/b4/21dfb471-a477-94d7-ea76-b94fca240cb1/198704781491.jpg/1000x1000bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=MhL7_sM8kO0',
              duration: const Duration(minutes: 4, seconds: 20)),
          Song(id: 'mahalini_7', title: 'Melawan Restu', artist: 'Mahalini', album: 'Fábula',
              albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/ea2ee495e17ab155bdcdac0fe75cf513/1000x1000-000000-80-0-0.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=P_J3P4aM9k0',
              duration: const Duration(minutes: 3, seconds: 40)),
          Song(id: 'mahalini_8', title: 'Bohongi Hati', artist: 'Mahalini', album: 'Fábula',
              albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/ea2ee495e17ab155bdcdac0fe75cf513/1000x1000-000000-80-0-0.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=B8_H_7j8mK0',
              duration: const Duration(minutes: 4, seconds: 23)),
          Song(id: 'mahalini_9', title: 'Ini Laguku', artist: 'Mahalini', album: 'Fábula',
              albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/ea2ee495e17ab155bdcdac0fe75cf513/1000x1000-000000-80-0-0.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=I8_L_9j7kM0',
              duration: const Duration(minutes: 3, seconds: 35)),
        ],
        albums: [
          ArtistAlbum(
            id: 'alb_mahalini_fabula',
            title: 'Fábula',
            coverUrl: 'https://cdn-images.dzcdn.net/images/cover/ea2ee495e17ab155bdcdac0fe75cf513/1000x1000-000000-80-0-0.jpg',
            releaseYear: '2023',
            type: 'Album',
            songs: [
              Song(id: 'fab_1', title: 'Ini Laguku', artist: 'Mahalini', album: 'Fábula', albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/ea2ee495e17ab155bdcdac0fe75cf513/1000x1000-000000-80-0-0.jpg', audioUrl: 'youtube:Mahalini Ini Laguku', duration: const Duration(minutes: 3, seconds: 35)),
              Song(id: 'fab_2', title: 'Burung Camar', artist: 'Mahalini', album: 'Fábula', albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/ea2ee495e17ab155bdcdac0fe75cf513/1000x1000-000000-80-0-0.jpg', audioUrl: 'youtube:Mahalini Burung Camar', duration: const Duration(minutes: 3, seconds: 20)),
              Song(id: 'fab_3', title: 'Satu-Satu', artist: 'Mahalini', album: 'Fábula', albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/ea2ee495e17ab155bdcdac0fe75cf513/1000x1000-000000-80-0-0.jpg', audioUrl: 'youtube:Mahalini Satu-Satu', duration: const Duration(minutes: 4, seconds: 0)),
              Song(id: 'fab_4', title: 'Bohongi Hati', artist: 'Mahalini', album: 'Fábula', albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/ea2ee495e17ab155bdcdac0fe75cf513/1000x1000-000000-80-0-0.jpg', audioUrl: 'youtube:Mahalini Bohongi Hati', duration: const Duration(minutes: 4, seconds: 23)),
              Song(id: 'fab_5', title: 'Sial', artist: 'Mahalini', album: 'Fábula', albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/ea2ee495e17ab155bdcdac0fe75cf513/1000x1000-000000-80-0-0.jpg', audioUrl: 'https://www.youtube.com/watch?v=QSWYyoF79oE', duration: const Duration(minutes: 4, seconds: 3)),
              Song(id: 'fab_6', title: 'Kisah Sempurna', artist: 'Mahalini', album: 'Fábula', albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/ea2ee495e17ab155bdcdac0fe75cf513/1000x1000-000000-80-0-0.jpg', audioUrl: 'https://www.youtube.com/watch?v=1d9p-c3m_78', duration: const Duration(minutes: 4, seconds: 36)),
              Song(id: 'fab_7', title: 'Putar Waktu', artist: 'Mahalini', album: 'Fábula', albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/ea2ee495e17ab155bdcdac0fe75cf513/1000x1000-000000-80-0-0.jpg', audioUrl: 'youtube:Mahalini Putar Waktu', duration: const Duration(minutes: 3, seconds: 50)),
              Song(id: 'fab_8', title: 'Melawan Restu', artist: 'Mahalini', album: 'Fábula', albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/ea2ee495e17ab155bdcdac0fe75cf513/1000x1000-000000-80-0-0.jpg', audioUrl: 'https://www.youtube.com/watch?v=P_J3P4aM9k0', duration: const Duration(minutes: 3, seconds: 40)),
              Song(id: 'fab_9', title: 'Sisa Rasa', artist: 'Mahalini', album: 'Fábula', albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/ea2ee495e17ab155bdcdac0fe75cf513/1000x1000-000000-80-0-0.jpg', audioUrl: 'https://www.youtube.com/watch?v=kYJzX9eP69Y', duration: const Duration(minutes: 4, seconds: 14)),
            ],
          ),
          ArtistAlbum(
            id: 'alb_mahalini_mati_matian',
            title: 'Mati-Matian',
            coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/4a/01/a2/4a01a2d5-94f3-6bf2-72bf-08e1694f272a/198704204488.jpg/1000x1000bb.jpg',
            releaseYear: '2024',
            type: 'Single',
            songs: [
              Song(id: 'mat_1', title: 'Mati-Matian', artist: 'Mahalini', album: 'Mati-Matian', albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/4a/01/a2/4a01a2d5-94f3-6bf2-72bf-08e1694f272a/198704204488.jpg/1000x1000bb.jpg', audioUrl: 'https://www.youtube.com/watch?v=b4bU7J7f3p8', duration: const Duration(minutes: 4, seconds: 8)),
            ],
          ),
          ArtistAlbum(
            id: 'alb_mahalini_sampai_menutup_mata',
            title: 'Sampai Menutup Mata',
            coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/21/df/b4/21dfb471-a477-94d7-ea76-b94fca240cb1/198704781491.jpg/1000x1000bb.jpg',
            releaseYear: '2024',
            type: 'Single',
            songs: [
              Song(id: 'smm_1', title: 'Sampai Menutup Mata', artist: 'Mahalini', album: 'Sampai Menutup Mata', albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/21/df/b4/21dfb471-a477-94d7-ea76-b94fca240cb1/198704781491.jpg/1000x1000bb.jpg', audioUrl: 'https://www.youtube.com/watch?v=MhL7_sM8kO0', duration: const Duration(minutes: 4, seconds: 20)),
            ],
          ),
          ArtistAlbum(
            id: 'alb_mahalini_bermuara',
            title: 'Bermuara (feat. Rizky Febian)',
            coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/ce/22/0c/ce220c38-895c-a5b8-53e7-3f3ae99a0951/198704381288.jpg/1000x1000bb.jpg',
            releaseYear: '2024',
            type: 'Single',
            songs: [
              Song(id: 'ber_1', title: 'Bermuara', artist: 'Rizky Febian & Mahalini', album: 'Bermuara', albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/ce/22/0c/ce220c38-895c-a5b8-53e7-3f3ae99a0951/198704381288.jpg/1000x1000bb.jpg', audioUrl: 'https://www.youtube.com/watch?v=bZ7Jk9uH7j0', duration: const Duration(minutes: 3, seconds: 58)),
            ],
          ),
          ArtistAlbum(
            id: 'alb_mahalini_sisa_rasa',
            title: 'Sisa Rasa',
            coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/f4/bf/2a/f4bf2ab7-5311-db75-c9cb-fa5bbbf6cb7c/196292523203_cover.jpg/1000x1000bb.jpg',
            releaseYear: '2021',
            type: 'Single',
            songs: [
              Song(id: 'sr_1', title: 'Sisa Rasa', artist: 'Mahalini', album: 'Sisa Rasa', albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/f4/bf/2a/f4bf2ab7-5311-db75-c9cb-fa5bbbf6cb7c/196292523203_cover.jpg/1000x1000bb.jpg', audioUrl: 'https://www.youtube.com/watch?v=kYJzX9eP69Y', duration: const Duration(minutes: 4, seconds: 14)),
            ],
          ),
          ArtistAlbum(
            id: 'alb_mahalini_melawan_restu',
            title: 'Melawan Restu',
            coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/a4/bc/ef/a4bcefbe-e74f-69d1-dcf3-b9be9bca5b2a/196006478959_cover.jpg/1000x1000bb.jpg',
            releaseYear: '2021',
            type: 'Single',
            songs: [
              Song(id: 'mr_1', title: 'Melawan Restu', artist: 'Mahalini', album: 'Melawan Restu', albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/a4/bc/ef/a4bcefbe-e74f-69d1-dcf3-b9be9bca5b2a/196006478959_cover.jpg/1000x1000bb.jpg', audioUrl: 'https://www.youtube.com/watch?v=P_J3P4aM9k0', duration: const Duration(minutes: 3, seconds: 40)),
            ],
          ),
          ArtistAlbum(
            id: 'alb_mahalini_kisah_sempurna',
            title: 'Kisah Sempurna',
            coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/7e/bc/0a/7ebc0a6b-c73e-ce89-94b2-c045b46d0a7a/196626495374_cover.jpg/1000x1000bb.jpg',
            releaseYear: '2022',
            type: 'Single',
            songs: [
              Song(id: 'ks_1', title: 'Kisah Sempurna', artist: 'Mahalini', album: 'Kisah Sempurna', albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/7e/bc/0a/7ebc0a6b-c73e-ce89-94b2-c045b46d0a7a/196626495374_cover.jpg/1000x1000bb.jpg', audioUrl: 'https://www.youtube.com/watch?v=1d9p-c3m_78', duration: const Duration(minutes: 4, seconds: 36)),
            ],
          ),
        ],
      ),
    ];
  }

  static Artist? getArtistByName(String name) {
    try {
      final clean = TitleNormalizer.cleanArtist(name).toLowerCase();
      return getComprehensiveArtists().firstWhere(
        (a) => a.name.toLowerCase() == clean || a.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Search artist across curated catalog and Deezer global music catalog
  static Future<Artist?> searchArtist(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return null;
    final cleanQ = TitleNormalizer.cleanArtist(q).toLowerCase();

    // 0. Franchise & Anime search match (e.g. "naruto", "naruto shippuden")
    if (q.contains('naruto') || q.contains('shippuden')) {
      final narutoTracks = getNarutoOstTracks();
      return Artist(
        id: 'artist_naruto_ost',
        name: 'Naruto Shippuden (Official OST)',
        country: 'Jepang',
        genres: const ['Anime OST', 'J-Rock', 'J-Pop'],
        imageUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music124/v4/6c/1d/e6/6c1de681-d7fa-a93b-f347-643340afd588/jacket_KSXX00341B00Z_550.jpg/1000x1000bb.jpg',
        headerImageUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music124/v4/6c/1d/e6/6c1de681-d7fa-a93b-f347-643340afd588/jacket_KSXX00341B00Z_550.jpg/1000x1000bb.jpg',
        monthlyListeners: '14.850.000 pendengar bulanan',
        bio: 'Koleksi resmi lagu tema pembuka dan penutup serial anime Naruto dan Naruto Shippuden oleh SHUN, UNLIMITS, FLOW, KANA-BOON, AKFG, dan Ikimono Gakari.',
        isVerified: true,
        topTracks: narutoTracks,
        albums: const [
          ArtistAlbum(
            id: 'alb_naruto_best_hit',
            title: 'Naruto Best Hit Collection',
            coverUrl: 'https://cdn-images.dzcdn.net/images/cover/9079a40733dca07fb02a14b304c475ee/1000x1000-000000-80-0-0.jpg',
            releaseYear: '2010',
            type: 'Album',
          ),
          ArtistAlbum(
            id: 'alb_naruto_shippuden_themes',
            title: 'Naruto Shippuden Theme Songs',
            coverUrl: 'https://cdn-images.dzcdn.net/images/cover/3b7fa1f21eb2ee3fa5c9ebdf35316be3/1000x1000-000000-80-0-0.jpg',
            releaseYear: '2016',
            type: 'Album',
          ),
        ],
      );
    }

    // 1. Curated match across comprehensive regional and global catalog
    for (final artist in getComprehensiveArtists()) {
      final nameLower = artist.name.toLowerCase();
      if (nameLower == q || nameLower == cleanQ || nameLower.contains(cleanQ) || cleanQ.contains(nameLower)) {
        return artist;
      }
      final parts = nameLower.split(' ');
      if (parts.any((p) => p.length >= 3 && cleanQ.contains(p))) {
        return artist;
      }
    }

    // 2. Deezer global artist catalog lookup (Korean, Japanese, Global artists)
    try {
      final deezerArtist = await DeezerApiService.searchArtist(query);
      if (deezerArtist != null) return deezerArtist;
    } catch (e) {
      debugPrint('MusicApiService.searchArtist error: $e');
    }

    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // COMPREHENSIVE REGIONAL & GLOBAL ARTISTS (ID, PH, TH, MY, GLOBAL)
  // ─────────────────────────────────────────────────────────────────────────
  static List<Artist> getComprehensiveArtists() {
    final baseArtists = getArtists();

    final additionalArtists = [
      // ── INDONESIA (TAMBAHAN) ──
      Artist(
        id: 'artist_sal_priadi',
        name: 'Sal Priadi',
        country: 'Indonesia',
        genres: const ['Indie Pop', 'Folk', 'Pop'],
        imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/1/1f/Sal_Priadi_in_2020.png',
        headerImageUrl: 'https://upload.wikimedia.org/wikipedia/commons/1/1f/Sal_Priadi_in_2020.png',
        monthlyListeners: '9.420.100 pendengar bulanan',
        bio: 'Penyanyi dan penulis lagu puitis asal Malang dengan hits "Gala Bunga Matahari" dan "Dari Planet Lain".',
        topTracks: [
          Song(id: 'sal_1', title: 'Gala Bunga Matahari', artist: 'Sal Priadi', album: 'MARKERS AND SUCH PENS FLASHDISKS',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/fa/a8/4c/faa84c4f-0f09-3730-6460-8c53e9dc159d/cover.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=0zKkJqJ1g1Y',
              duration: const Duration(minutes: 3, seconds: 50),
              lyrics: Song.generateSampleLyrics('Gala Bunga Matahari')),
          Song(id: 'sal_2', title: 'Dari Planet Lain', artist: 'Sal Priadi', album: 'MARKERS AND SUCH PENS FLASHDISKS',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/fa/a8/4c/faa84c4f-0f09-3730-6460-8c53e9dc159d/cover.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=kYv_8Rsm36A',
              duration: const Duration(minutes: 3, seconds: 4),
              lyrics: Song.generateSampleLyrics('Dari Planet Lain')),
        ],
      ),
      Artist(
        id: 'artist_nadin_amizah',
        name: 'Nadin Amizah',
        country: 'Indonesia',
        genres: const ['Folk', 'Indie Pop', 'Acoustic'],
        imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/4/4f/WikipediaNadin.jpg',
        headerImageUrl: 'https://upload.wikimedia.org/wikipedia/commons/4/4f/WikipediaNadin.jpg',
        monthlyListeners: '7.850.400 pendengar bulanan',
        bio: 'Musisi folk-pop asal Bandung dengan gaya penceritaan lirik mendalam dan teatrikal.',
        topTracks: [
          Song(id: 'nadin_1', title: 'Rayuan Perempuan Gila', artist: 'Nadin Amizah', album: 'Untuk Dunia, Cinta, dan Kotornya',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music124/v4/1d/10/9b/1d109b17-1bbf-1894-e774-4d9ad6baa7b3/cover.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=k4T0hU7Wf94',
              duration: const Duration(minutes: 4, seconds: 50),
              lyrics: Song.generateSampleLyrics('Rayuan Perempuan Gila')),
          Song(id: 'nadin_2', title: 'Bertaut', artist: 'Nadin Amizah', album: 'Selamat Ulang Tahun',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music124/v4/1d/10/9b/1d109b17-1bbf-1894-e774-4d9ad6baa7b3/cover.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=0k5L1y_z41c',
              duration: const Duration(minutes: 5, seconds: 15),
              lyrics: Song.generateSampleLyrics('Bertaut')),
        ],
      ),
      Artist(
        id: 'artist_pamungkas',
        name: 'Pamungkas',
        country: 'Indonesia',
        genres: const ['Indie Pop', 'R&B', 'Soul'],
        imageUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/7b/db/55/7bdb5527-c006-4941-208d-6927948745a6/3617224176939.jpg/600x600bb.jpg',
        headerImageUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/7b/db/55/7bdb5527-c006-4941-208d-6927948745a6/3617224176939.jpg/600x600bb.jpg',
        monthlyListeners: '6.920.000 pendengar bulanan',
        bio: 'Solois dan multi-instrumentalis pelantun mega-hits "To the Bone".',
        topTracks: [
          Song(id: 'pam_1', title: 'To the Bone', artist: 'Pamungkas', album: 'Flying Solo',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/7b/db/55/7bdb5527-c006-4941-208d-6927948745a6/3617224176939.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=2v8v2f9246Y',
              duration: const Duration(minutes: 5, seconds: 44),
              lyrics: Song.generateSampleLyrics('To the Bone')),
        ],
      ),
      Artist(
        id: 'artist_tiara_andini',
        name: 'Tiara Andini',
        country: 'Indonesia',
        genres: const ['Pop', 'Ballad', 'R&B'],
        imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/2/2a/Tiara_Andini_photo_by_Winston_Gomez_%282021%29.jpg',
        headerImageUrl: 'https://upload.wikimedia.org/wikipedia/commons/2/2a/Tiara_Andini_photo_by_Winston_Gomez_%282021%29.jpg',
        monthlyListeners: '8.120.300 pendengar bulanan',
        bio: 'Penyanyi pop jebolan Indonesian Idol dengan vokal powerful dan hits beragam genre.',
        topTracks: [
          Song(id: 'tiara_1', title: 'Kupu-Kupu', artist: 'Tiara Andini', album: 'Kupu-Kupu',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music122/v4/a8/b6/b3/a8b6b39f-2794-6920-374d-9e0efe8f3f30/22UM1IM06786.rgb.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=0hW9L2hKz5Y',
              duration: const Duration(minutes: 3, seconds: 25),
              lyrics: Song.generateSampleLyrics('Kupu-Kupu')),
        ],
      ),
      Artist(
        id: 'artist_denny_caknan',
        name: 'Denny Caknan',
        country: 'Indonesia',
        genres: const ['Pop Jawa', 'Dangdut', 'Koplo'],
        imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/0/09/Denny_Caknan_Boshe_Jogja.png',
        headerImageUrl: 'https://upload.wikimedia.org/wikipedia/commons/0/09/Denny_Caknan_Boshe_Jogja.png',
        monthlyListeners: '7.340.500 pendengar bulanan',
        bio: 'Ikon musik pop Jawa modern asal Ngawi dengan lagu-lagu ambyar dicintai jutaan penggemar.',
        topTracks: [
          Song(id: 'denny_1', title: 'Kartonyono Medot Janji', artist: 'Denny Caknan', album: 'Kartonyono Medot Janji',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/98/4f/67/984f678a-215c-daf0-0172-fa74fd4d7cb5/cover.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=Zf_iG7N3X6c',
              duration: const Duration(minutes: 5, seconds: 12),
              lyrics: Song.generateSampleLyrics('Kartonyono Medot Janji')),
        ],
      ),
      Artist(
        id: 'artist_juicy_luicy',
        name: 'Juicy Luicy',
        country: 'Indonesia',
        genres: const ['Pop', 'Indie Pop', 'Jazz-Pop'],
        imageUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music114/v4/50/d8/9c/50d89c7d-3083-cbfa-6b4b-f783c9556d7d/192641578595_Cover.jpg/600x600bb.jpg',
        headerImageUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music114/v4/50/d8/9c/50d89c7d-3083-cbfa-6b4b-f783c9556d7d/192641578595_Cover.jpg/600x600bb.jpg',
        monthlyListeners: '10.500.200 pendengar bulanan',
        bio: 'Band pop asal Bandung yang dikenal lewat lagu-lagu patah hati santai seperti "Lantas" dan "Tampar".',
        topTracks: [
          Song(id: 'jl_1', title: 'Lantas', artist: 'Juicy Luicy', album: 'Sentimental',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music114/v4/50/d8/9c/50d89c7d-3083-cbfa-6b4b-f783c9556d7d/192641578595_Cover.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=3rU6Y3iX03Y',
              duration: const Duration(minutes: 3, seconds: 50),
              lyrics: Song.generateSampleLyrics('Lantas')),
        ],
      ),
      Artist(
        id: 'artist_donne_maula',
        name: 'Donne Maula',
        country: 'Indonesia',
        genres: const ['Indie Pop', 'Acoustic', 'Folk'],
        imageUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/46/4f/d8/464fd833-247d-96d8-3039-91ca20caf62d/cover.jpg/600x600bb.jpg',
        headerImageUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/46/4f/d8/464fd833-247d-96d8-3039-91ca20caf62d/cover.jpg/600x600bb.jpg',
        monthlyListeners: '6.450.000 pendengar bulanan',
        bio: 'Penyanyi dan pencipta lagu hits nasional "Bercinta Lewat Kata" soundtrack film Jatuh Cinta Seperti di Dongeng-Dongeng.',
        topTracks: [
          Song(id: 'donne_1', title: 'Bercinta Lewat Kata', artist: 'Donne Maula', album: 'Bercinta Lewat Kata',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/46/4f/d8/464fd833-247d-96d8-3039-91ca20caf62d/cover.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=x8lG_zU5V8o',
              duration: const Duration(minutes: 3, seconds: 55),
              lyrics: Song.generateSampleLyrics('Bercinta Lewat Kata')),
        ],
      ),

      // ── FILIPINA (PH) ──
      Artist(
        id: 'artist_zack_tabudlo',
        name: 'Zack Tabudlo',
        country: 'Filipina',
        genres: const ['OPM', 'Pop', 'R&B'],
        imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/d/d2/Zack_Tabudlo.png',
        headerImageUrl: 'https://upload.wikimedia.org/wikipedia/commons/d/d2/Zack_Tabudlo.png',
        monthlyListeners: '8.920.000 pendengar bulanan',
        bio: 'Penyanyi, pencipta lagu, dan produser asal Filipina dengan hits internasional "Binibini" dan "Pano".',
        topTracks: [
          Song(id: 'zack_1', title: 'Binibini', artist: 'Zack Tabudlo', album: 'Episode',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/f8/fe/aa/f8feaae7-f0ec-ab22-c06f-1ca45232ea14/21UM1IM13834.rgb.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=iE3B0v6p9eI',
              duration: const Duration(minutes: 3, seconds: 42),
              lyrics: Song.generateSampleLyrics('Binibini')),
          Song(id: 'zack_2', title: 'Pano', artist: 'Zack Tabudlo', album: 'Episode',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/f8/fe/aa/f8feaae7-f0ec-ab22-c06f-1ca45232ea14/21UM1IM13834.rgb.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=69V__aTa_00',
              duration: const Duration(minutes: 4, seconds: 14),
              lyrics: Song.generateSampleLyrics('Pano')),
        ],
      ),
      Artist(
        id: 'artist_sb19',
        name: 'SB19',
        country: 'Filipina',
        genres: const ['P-Pop', 'Pop', 'Dance'],
        imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/4/43/SB19_at_Binibining_Pilipinas_2022_%28cropped%29.jpg',
        headerImageUrl: 'https://upload.wikimedia.org/wikipedia/commons/4/43/SB19_at_Binibining_Pilipinas_2022_%28cropped%29.jpg',
        monthlyListeners: '4.780.000 pendengar bulanan',
        bio: 'Boyband terkemuka pelopor P-Pop asal Filipina pelantun lagu viral dunia "GENTO".',
        topTracks: [
          Song(id: 'sb19_1', title: 'GENTO', artist: 'SB19', album: 'PAGTATAG!',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/4e/10/49/4e10493c-1b00-2a1c-b8ce-0342b20f76f9/196871202343.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=VJvw_i1gGtc',
              duration: const Duration(minutes: 3, seconds: 52),
              lyrics: Song.generateSampleLyrics('GENTO')),
        ],
      ),
      Artist(
        id: 'artist_benandben',
        name: 'Ben&Ben',
        country: 'Filipina',
        genres: const ['Folk Pop', 'Indie Folk', 'OPM'],
        imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/a/ab/Ben%26Ben_in_2018_2.png',
        headerImageUrl: 'https://upload.wikimedia.org/wikipedia/commons/a/ab/Ben%26Ben_in_2018_2.png',
        monthlyListeners: '5.620.000 pendengar bulanan',
        bio: 'Grup musik indie folk-pop 9 personel asal Manila terkenal dengan harmoni akustik manis.',
        topTracks: [
          Song(id: 'ben_1', title: 'Leaves', artist: 'Ben&Ben', album: 'Leaves',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/35/72/19/35721962-2902-809f-e24c-73a8bdf7dfcb/886449312276.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=Q3K0TOhx1-A',
              duration: const Duration(minutes: 5, seconds: 12),
              lyrics: Song.generateSampleLyrics('Leaves')),
        ],
      ),
      Artist(
        id: 'artist_moira',
        name: 'Moira Dela Torre',
        country: 'Filipina',
        genres: const ['OPM', 'Acoustic', 'Ballad'],
        imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/2/27/Moira_performing_in_2019.jpg',
        headerImageUrl: 'https://upload.wikimedia.org/wikipedia/commons/2/27/Moira_performing_in_2019.jpg',
        monthlyListeners: '4.890.000 pendengar bulanan',
        bio: 'Ratu lagu ballad OPM Filipina dengan vokal emosional dan lembut.',
        topTracks: [
          Song(id: 'moira_1', title: 'Paubaya', artist: 'Moira Dela Torre', album: 'Patawad',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/64/33/30/64333008-9520-0fcb-b596-38b4b8dede41/3616404485618.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=z8fKqL13Wrs',
              duration: const Duration(minutes: 4, seconds: 35),
              lyrics: Song.generateSampleLyrics('Paubaya')),
        ],
      ),
      Artist(
        id: 'artist_arthur_nery',
        name: 'Arthur Nery',
        country: 'Filipina',
        genres: const ['R&B', 'Soul', 'OPM'],
        imageUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/23/b7/24/23b72461-4b92-230a-a1c1-041fb75acbaf/cover.jpg/600x600bb.jpg',
        headerImageUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/23/b7/24/23b72461-4b92-230a-a1c1-041fb75acbaf/cover.jpg/600x600bb.jpg',
        monthlyListeners: '3.950.000 pendengar bulanan',
        bio: 'Penyanyi R&B kontemporer asal Cagayan de Oro pelantun hits "Pagsamo".',
        topTracks: [
          Song(id: 'nery_1', title: 'Pagsamo', artist: 'Arthur Nery', album: 'Pagsamo',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/23/b7/24/23b72461-4b92-230a-a1c1-041fb75acbaf/cover.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=Yh_k_R8Zc4c',
              duration: const Duration(minutes: 4, seconds: 57),
              lyrics: Song.generateSampleLyrics('Pagsamo')),
        ],
      ),

      // ── THAILAND (TH) ──
      Artist(
        id: 'artist_jeff_satur',
        name: 'Jeff Satur',
        country: 'Thailand',
        genres: const ['T-Pop', 'R&B', 'Pop'],
        imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/d/d9/Jeff_Satur_at_GDH_LINEUP_2025_LOOK_FORWARD%2C_July_17%2C_2024_01.png',
        headerImageUrl: 'https://upload.wikimedia.org/wikipedia/commons/d/d9/Jeff_Satur_at_GDH_LINEUP_2025_LOOK_FORWARD%2C_July_17%2C_2024_01.png',
        monthlyListeners: '4.210.000 pendengar bulanan',
        bio: 'Penyanyi, aktor, dan produser musik visioner Thailand dengan gaya vokal dan visual memikat.',
        topTracks: [
          Song(id: 'jeff_1', title: 'Dum Dum', artist: 'Jeff Satur', album: 'Space Shuttle No.8',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/2b/bd/d5/2bbdd57c-56cb-71b5-48fc-f3022b7b15f1/5054197976865.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=E9p2L6rR9-g',
              duration: const Duration(minutes: 3, seconds: 28),
              lyrics: Song.generateSampleLyrics('Dum Dum')),
          Song(id: 'jeff_2', title: 'Fade', artist: 'Jeff Satur', album: 'Space Shuttle No.8',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/2b/bd/d5/2bbdd57c-56cb-71b5-48fc-f3022b7b15f1/5054197976865.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=kSgN9y941t4',
              duration: const Duration(minutes: 3, seconds: 48),
              lyrics: Song.generateSampleLyrics('Fade')),
        ],
      ),
      Artist(
        id: 'artist_nont_tanont',
        name: 'NONT TANONT',
        country: 'Thailand',
        genres: const ['T-Pop', 'Pop', 'R&B'],
        imageUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/5d/70/fe/5d70fe6e-f3e4-c874-a2de-e4ecd186bf80/cover.jpg/600x600bb.jpg',
        headerImageUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/5d/70/fe/5d70fe6e-f3e4-c874-a2de-e4ecd186bf80/cover.jpg/600x600bb.jpg',
        monthlyListeners: '3.870.000 pendengar bulanan',
        bio: 'Penyanyi pop nomor satu Thailand dengan suara renyah dan deretan hits teratas.',
        topTracks: [
          Song(id: 'nont_1', title: 'Melt', artist: 'NONT TANONT', album: 'Melt',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/5d/70/fe/5d70fe6e-f3e4-c874-a2de-e4ecd186bf80/cover.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=qH_aJ9lC9j0',
              duration: const Duration(minutes: 3, seconds: 35),
              lyrics: Song.generateSampleLyrics('Melt')),
        ],
      ),
      Artist(
        id: 'artist_billkin',
        name: 'Billkin',
        country: 'Thailand',
        genres: const ['T-Pop', 'Pop Ballad', 'Soul'],
        imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/5/59/Billkin_%40_LAHNMAH_%28cropped%29.png',
        headerImageUrl: 'https://upload.wikimedia.org/wikipedia/commons/5/59/Billkin_%40_LAHNMAH_%28cropped%29.png',
        monthlyListeners: '3.120.000 pendengar bulanan',
        bio: 'Bintang pop dan aktor ternama Thailand pelantun "Mr. Everything".',
        topTracks: [
          Song(id: 'bk_1', title: 'Mr. Everything', artist: 'Billkin', album: 'Mr. Everything',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Video211/v4/40/16/18/40161860-45af-a15a-4d02-ccda1ec95b44/26UMGIM14309.crop.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=Jd7pBqjG4vU',
              duration: const Duration(minutes: 3, seconds: 40),
              lyrics: Song.generateSampleLyrics('Mr. Everything')),
        ],
      ),
      Artist(
        id: 'artist_bowkylion',
        name: 'BOWKYLION',
        country: 'Thailand',
        genres: const ['Indie Pop', 'Synthpop', 'T-Pop'],
        imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/5/59/Bowkylion_in_October_2022.png',
        headerImageUrl: 'https://upload.wikimedia.org/wikipedia/commons/5/59/Bowkylion_in_October_2022.png',
        monthlyListeners: '2.940.000 pendengar bulanan',
        bio: 'Penyanyi dan produser wanita indie pop terpopuler Thailand dengan nuansa retro synth modern.',
        topTracks: [
          Song(id: 'bowky_1', title: 'Untold', artist: 'BOWKYLION', album: 'Lionheart',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/36/51/da/3651dae6-a3ed-858e-169a-f5c42f0f97ff/25UMGIM82515.rgb.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=gA5d8z7w9jM',
              duration: const Duration(minutes: 4, seconds: 2),
              lyrics: Song.generateSampleLyrics('Untold')),
        ],
      ),
      Artist(
        id: 'artist_three_man_down',
        name: 'Three Man Down',
        country: 'Thailand',
        genres: const ['Pop Rock', 'Alternative Rock'],
        imageUrl: 'https://cdn-images.dzcdn.net/images/artist/14155fab9d68ad7795910acbea84bb41/1000x1000-000000-80-0-0.jpg',
        headerImageUrl: 'https://cdn-images.dzcdn.net/images/artist/14155fab9d68ad7795910acbea84bb41/1000x1000-000000-80-0-0.jpg',
        monthlyListeners: '3.420.000 pendengar bulanan',
        bio: 'Band pop rock papan atas Thailand yang merajai tangga musik konser dan festival.',
        topTracks: [
          Song(id: 'tmd_1', title: 'City Lights', artist: 'Three Man Down', album: 'This City Won\'t Be Lonely Anymore',
              albumArtUrl: 'https://cdn-images.dzcdn.net/images/artist/14155fab9d68ad7795910acbea84bb41/1000x1000-000000-80-0-0.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=0s8pL9fH_44',
              duration: const Duration(minutes: 4, seconds: 11),
              lyrics: Song.generateSampleLyrics('City Lights')),
        ],
      ),

      // ── MALAYSIA (MY) ──
      Artist(
        id: 'artist_masdo',
        name: 'Masdo',
        country: 'Malaysia',
        genres: const ['Pop 60-an', 'Retro Pop', 'Rock n Roll'],
        imageUrl: 'https://cdn-images.dzcdn.net/images/artist/90091123a5fb1001da2a6ec787d71f71/1000x1000-000000-80-0-0.jpg',
        headerImageUrl: 'https://cdn-images.dzcdn.net/images/artist/90091123a5fb1001da2a6ec787d71f71/1000x1000-000000-80-0-0.jpg',
        monthlyListeners: '3.650.000 pendengar bulanan',
        bio: 'Kugiran retro pop 60-an asal Malaysia pencetus fenomena lagu viral serantau "Dinda".',
        topTracks: [
          Song(id: 'masdo_1', title: 'Dinda', artist: 'Masdo', album: 'Selamat Tinggal Pujaan',
              albumArtUrl: 'https://cdn-images.dzcdn.net/images/artist/90091123a5fb1001da2a6ec787d71f71/1000x1000-000000-80-0-0.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=1rY2Q4J_wEw',
              duration: const Duration(minutes: 3, seconds: 20),
              lyrics: Song.generateSampleLyrics('Dinda')),
        ],
      ),
      Artist(
        id: 'artist_insomniacks',
        name: 'Insomniacks',
        country: 'Malaysia',
        genres: const ['Alternative Rock', 'Pop Rock'],
        imageUrl: 'https://cdn-images.dzcdn.net/images/artist/620ae6cf26c8f3f0b6cb892e49ff5d2d/1000x1000-000000-80-0-0.jpg',
        headerImageUrl: 'https://cdn-images.dzcdn.net/images/artist/620ae6cf26c8f3f0b6cb892e49ff5d2d/1000x1000-000000-80-0-0.jpg',
        monthlyListeners: '2.840.000 pendengar bulanan',
        bio: 'Band pop rock muda Malaysia terkenal dengan single hit melankolis "Pulang" dan "Sempurna".',
        topTracks: [
          Song(id: 'insom_1', title: 'Pulang', artist: 'Insomniacks', album: 'Pulang',
              albumArtUrl: 'https://cdn-images.dzcdn.net/images/artist/620ae6cf26c8f3f0b6cb892e49ff5d2d/1000x1000-000000-80-0-0.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=_w8L3qA9p2w',
              duration: const Duration(minutes: 4, seconds: 18),
              lyrics: Song.generateSampleLyrics('Pulang')),
        ],
      ),
      Artist(
        id: 'artist_faizal_tahir',
        name: 'Faizal Tahir',
        country: 'Malaysia',
        genres: const ['Pop Rock', 'Pop'],
        imageUrl: 'https://cdn-images.dzcdn.net/images/artist/29752a15b6f5f98f95eab9c47393d280/1000x1000-000000-80-0-0.jpg',
        headerImageUrl: 'https://cdn-images.dzcdn.net/images/artist/29752a15b6f5f98f95eab9c47393d280/1000x1000-000000-80-0-0.jpg',
        monthlyListeners: '2.520.000 pendengar bulanan',
        bio: 'Penyanyi dan komposer veteran berkarisma Malaysia pelantun "Santai" dan "Ragaman".',
        topTracks: [
          Song(id: 'faizal_1', title: 'Santai', artist: 'Faizal Tahir', album: 'Rojak',
              albumArtUrl: 'https://cdn-images.dzcdn.net/images/artist/29752a15b6f5f98f95eab9c47393d280/1000x1000-000000-80-0-0.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=uK8w2xY7vP0',
              duration: const Duration(minutes: 3, seconds: 34),
              lyrics: Song.generateSampleLyrics('Santai')),
        ],
      ),
      Artist(
        id: 'artist_siti_nurhaliza',
        name: 'Siti Nurhaliza',
        country: 'Malaysia',
        genres: const ['Pop Tradisional', 'Pop Melayu', 'Ballad'],
        imageUrl: 'https://cdn-images.dzcdn.net/images/artist/e9f3d5decfd2ea1795b1659773257529/1000x1000-000000-80-0-0.jpg',
        headerImageUrl: 'https://cdn-images.dzcdn.net/images/artist/e9f3d5decfd2ea1795b1659773257529/1000x1000-000000-80-0-0.jpg',
        monthlyListeners: '2.780.000 pendengar bulanan',
        bio: 'Biduanita negara dan diva musik teragung Malaysia dengan reputasi tak tertandingi di Asia Tenggara.',
        topTracks: [
          Song(id: 'siti_1', title: 'Bukan Cinta Biasa', artist: 'Siti Nurhaliza', album: 'E.M.A.S',
              albumArtUrl: 'https://cdn-images.dzcdn.net/images/artist/e9f3d5decfd2ea1795b1659773257529/1000x1000-000000-80-0-0.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=f8uK2_jL8vE',
              duration: const Duration(minutes: 4, seconds: 58),
              lyrics: Song.generateSampleLyrics('Bukan Cinta Biasa')),
        ],
      ),

      // ── SCREENSHOT ARTISTS (Icona Pop, Urban Cone, Tove Styrke, Rhys, Zara Larsson, Tove Lo, Juliander, Alan Walker, Seeb) ──
      Artist(
        id: 'artist_icona_pop',
        name: 'Icona Pop',
        country: 'Swedia',
        genres: const ['Electropop', 'Dance-Pop'],
        imageUrl: 'https://cdn-images.dzcdn.net/images/artist/02652234486bae9c3e80fd9cedf07d73/1000x1000-000000-80-0-0.jpg',
        headerImageUrl: 'https://cdn-images.dzcdn.net/images/artist/02652234486bae9c3e80fd9cedf07d73/1000x1000-000000-80-0-0.jpg',
        monthlyListeners: '9.800.000 pendengar bulanan',
        bio: 'Duo electropop Swedia Caroline Hjelt dan Aino Jawo dengan hits anthemic global "I Love It".',
        topTracks: [
          Song(id: 'icona_1', title: 'I Love It', artist: 'Icona Pop', album: 'This Is... Icona Pop',
              albumArtUrl: 'https://cdn-images.dzcdn.net/images/artist/02652234486bae9c3e80fd9cedf07d73/1000x1000-000000-80-0-0.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=UxxajLWwzqY',
              duration: const Duration(minutes: 2, seconds: 35),
              lyrics: Song.generateSampleLyrics('I Love It')),
        ],
      ),
      Artist(
        id: 'artist_urban_cone',
        name: 'Urban Cone',
        country: 'Swedia',
        genres: const ['Indie Pop', 'Electronic'],
        imageUrl: 'https://cdn-images.dzcdn.net/images/artist/3b48232fb9934b5c0d02a4aa964e33aa/1000x1000-000000-80-0-0.jpg',
        headerImageUrl: 'https://cdn-images.dzcdn.net/images/artist/3b48232fb9934b5c0d02a4aa964e33aa/1000x1000-000000-80-0-0.jpg',
        monthlyListeners: '1.450.000 pendengar bulanan',
        bio: 'Grup indie pop asal Stockholm, Swedia, dengan melodi synth yang ceria dan segar.',
        topTracks: [
          Song(id: 'urban_1', title: 'Sadness Disease', artist: 'Urban Cone', album: 'Polaroid Memories',
              albumArtUrl: 'https://cdn-images.dzcdn.net/images/artist/3b48232fb9934b5c0d02a4aa964e33aa/1000x1000-000000-80-0-0.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=H6UoXfW173c',
              duration: const Duration(minutes: 3, seconds: 20),
              lyrics: Song.generateSampleLyrics('Sadness Disease')),
        ],
      ),
      Artist(
        id: 'artist_tove_styrke',
        name: 'Tove Styrke',
        country: 'Swedia',
        genres: const ['Electropop', 'Scandi-Pop'],
        imageUrl: 'https://cdn-images.dzcdn.net/images/artist/f1e616531d239a741ccf8467b0a9c0f6/1000x1000-000000-80-0-0.jpg',
        headerImageUrl: 'https://cdn-images.dzcdn.net/images/artist/f1e616531d239a741ccf8467b0a9c0f6/1000x1000-000000-80-0-0.jpg',
        monthlyListeners: '2.890.000 pendengar bulanan',
        bio: 'Penyanyi electropop Swedia yang dipuji kritikus musik atas gaya pop minimalis dan ritmisnya.',
        topTracks: [
          Song(id: 'tove_st_1', title: 'Say My Name', artist: 'Tove Styrke', album: 'Sway',
              albumArtUrl: 'https://cdn-images.dzcdn.net/images/artist/f1e616531d239a741ccf8467b0a9c0f6/1000x1000-000000-80-0-0.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=LqI-1n3g9X8',
              duration: const Duration(minutes: 3, seconds: 24),
              lyrics: Song.generateSampleLyrics('Say My Name')),
        ],
      ),
      Artist(
        id: 'artist_rhys',
        name: 'Rhys',
        country: 'Swedia',
        genres: const ['Pop', 'Singer-Songwriter'],
        imageUrl: 'https://cdn-images.dzcdn.net/images/artist/ccc7574447e62561efa9d1cbb63a6ead/1000x1000-000000-80-0-0.jpg',
        headerImageUrl: 'https://cdn-images.dzcdn.net/images/artist/ccc7574447e62561efa9d1cbb63a6ead/1000x1000-000000-80-0-0.jpg',
        monthlyListeners: '980.000 pendengar bulanan',
        bio: 'Penyanyi berdarah Swedia-Amerika dengan suara lembut dan lirik relatable.',
        topTracks: [
          Song(id: 'rhys_1', title: 'Too Much', artist: 'Rhys', album: 'Stages',
              albumArtUrl: 'https://cdn-images.dzcdn.net/images/artist/ccc7574447e62561efa9d1cbb63a6ead/1000x1000-000000-80-0-0.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=R_Q9V3h2_8A',
              duration: const Duration(minutes: 3, seconds: 15),
              lyrics: Song.generateSampleLyrics('Too Much')),
        ],
      ),
      Artist(
        id: 'artist_zara_larsson',
        name: 'Zara Larsson',
        country: 'Swedia',
        genres: const ['Pop', 'Dance-Pop'],
        imageUrl: 'https://cdn-images.dzcdn.net/images/artist/26e260152661dea1897a6eea198f9981/1000x1000-000000-80-0-0.jpg',
        headerImageUrl: 'https://cdn-images.dzcdn.net/images/artist/26e260152661dea1897a6eea198f9981/1000x1000-000000-80-0-0.jpg',
        monthlyListeners: '35.400.000 pendengar bulanan',
        bio: 'Pop superstar global asal Swedia dengan deretan hits platinum internasional seperti "Lush Life" dan "Symphony".',
        topTracks: [
          Song(id: 'zara_1', title: 'Lush Life', artist: 'Zara Larsson', album: 'So Good',
              albumArtUrl: 'https://cdn-images.dzcdn.net/images/artist/26e260152661dea1897a6eea198f9981/1000x1000-000000-80-0-0.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=tD4HCZe-tew',
              duration: const Duration(minutes: 3, seconds: 21),
              lyrics: Song.generateSampleLyrics('Lush Life')),
        ],
      ),
      Artist(
        id: 'artist_tove_lo',
        name: 'Tove Lo',
        country: 'Swedia',
        genres: const ['Electropop', 'Alt-Pop'],
        imageUrl: 'https://cdn-images.dzcdn.net/images/artist/0e5945bfdd3a0c8a66a2bb758571b225/1000x1000-000000-80-0-0.jpg',
        headerImageUrl: 'https://cdn-images.dzcdn.net/images/artist/0e5945bfdd3a0c8a66a2bb758571b225/1000x1000-000000-80-0-0.jpg',
        monthlyListeners: '22.300.000 pendengar bulanan',
        bio: 'Penyanyi dan penulis lagu alt-pop Swedia dikenal lewat lagu "Habits (Stay High)" dan kolaborasi lintas genre.',
        topTracks: [
          Song(id: 'tove_lo_1', title: 'Habits (Stay High)', artist: 'Tove Lo', album: 'Queen of the Clouds',
              albumArtUrl: 'https://cdn-images.dzcdn.net/images/artist/0e5945bfdd3a0c8a66a2bb758571b225/1000x1000-000000-80-0-0.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=SYM-RJwSGQ8',
              duration: const Duration(minutes: 3, seconds: 28),
              lyrics: Song.generateSampleLyrics('Habits (Stay High)')),
        ],
      ),
      Artist(
        id: 'artist_juliander',
        name: 'Juliander',
        country: 'Swedia',
        genres: const ['Pop', 'Indie Pop'],
        imageUrl: 'https://cdn-images.dzcdn.net/images/artist/ad23adb889320c741fe5333a506ec38c/1000x1000-000000-80-0-0.jpg',
        headerImageUrl: 'https://cdn-images.dzcdn.net/images/artist/ad23adb889320c741fe5333a506ec38c/1000x1000-000000-80-0-0.jpg',
        monthlyListeners: '850.000 pendengar bulanan',
        bio: 'Musisi pop berbakat asal Swedia yang pernah berkolaborasi dalam tur bersama Alan Walker.',
        topTracks: [
          Song(id: 'jul_1', title: 'Same Moon', artist: 'Juliander', album: 'Same Moon',
              albumArtUrl: 'https://cdn-images.dzcdn.net/images/artist/ad23adb889320c741fe5333a506ec38c/1000x1000-000000-80-0-0.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=o04_rN1q2sU',
              duration: const Duration(minutes: 3, seconds: 15),
              lyrics: Song.generateSampleLyrics('Same Moon')),
        ],
      ),
      Artist(
        id: 'artist_alan_walker',
        name: 'Alan Walker',
        country: 'Norwegia',
        genres: const ['EDM', 'Electro House', 'Dance'],
        imageUrl: 'https://cdn-images.dzcdn.net/images/artist/79d384488d390e65a6c27a95c431627e/1000x1000-000000-80-0-0.jpg',
        headerImageUrl: 'https://cdn-images.dzcdn.net/images/artist/79d384488d390e65a6c27a95c431627e/1000x1000-000000-80-0-0.jpg',
        monthlyListeners: '38.900.000 pendengar bulanan',
        bio: 'Produser musik dan DJ Norwegia berstatus ikon global pelantun "Faded" dengan miliaran stream.',
        topTracks: [
          Song(id: 'alan_1', title: 'Faded', artist: 'Alan Walker', album: 'Different World',
              albumArtUrl: 'https://cdn-images.dzcdn.net/images/artist/79d384488d390e65a6c27a95c431627e/1000x1000-000000-80-0-0.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=60ItHLz5WEA',
              duration: const Duration(minutes: 3, seconds: 32),
              lyrics: Song.generateSampleLyrics('Faded')),
        ],
      ),
      Artist(
        id: 'artist_seeb',
        name: 'Seeb',
        country: 'Norwegia',
        genres: const ['Tropical House', 'EDM'],
        imageUrl: 'https://cdn-images.dzcdn.net/images/artist/a5d389f235e5ec65ce6bcb1bb0bbc63e/1000x1000-000000-80-0-0.jpg',
        headerImageUrl: 'https://cdn-images.dzcdn.net/images/artist/a5d389f235e5ec65ce6bcb1bb0bbc63e/1000x1000-000000-80-0-0.jpg',
        monthlyListeners: '7.820.000 pendengar bulanan',
        bio: 'Duo produser EDM Norwegia terkenal atas remix legendaris Mike Posner "I Took a Pill in Ibiza".',
        topTracks: [
          Song(id: 'seeb_1', title: 'Grip', artist: 'Seeb & Bastille', album: 'Sad in Scandinavia',
              albumArtUrl: 'https://cdn-images.dzcdn.net/images/artist/a5d389f235e5ec65ce6bcb1bb0bbc63e/1000x1000-000000-80-0-0.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=uK8f-T72V90',
              duration: const Duration(minutes: 3, seconds: 18),
              lyrics: Song.generateSampleLyrics('Grip')),
        ],
      ),

      // ── GLOBAL HITS (Sabrina Carpenter, BTS, NewJeans, BLACKPINK) ──
      Artist(
        id: 'artist_sabrina_carpenter',
        name: 'Sabrina Carpenter',
        country: 'Amerika Serikat',
        genres: const ['Pop', 'Dance-Pop'],
        imageUrl: 'https://cdn-images.dzcdn.net/images/artist/4a9cdc7737e2a0e59b4917b47884b859/1000x1000-000000-80-0-0.jpg',
        headerImageUrl: 'https://cdn-images.dzcdn.net/images/artist/4a9cdc7737e2a0e59b4917b47884b859/1000x1000-000000-80-0-0.jpg',
        monthlyListeners: '82.400.000 pendengar bulanan',
        bio: 'Sensasi pop global pelantun hits musim panas "Espresso" dan album "Short n\' Sweet".',
        topTracks: [
          Song(id: 'sabrina_1', title: 'Espresso', artist: 'Sabrina Carpenter', album: 'Short n\' Sweet',
              albumArtUrl: 'https://cdn-images.dzcdn.net/images/artist/4a9cdc7737e2a0e59b4917b47884b859/1000x1000-000000-80-0-0.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=eVli-tstM5E',
              duration: const Duration(minutes: 2, seconds: 55),
              lyrics: Song.generateSampleLyrics('Espresso')),
        ],
      ),
      Artist(
        id: 'artist_bts',
        name: 'BTS',
        country: 'Korea Selatan',
        genres: const ['K-Pop', 'Pop', 'Hip-Hop'],
        imageUrl: 'https://cdn-images.dzcdn.net/images/artist/b5c64fa8216ca158e52b4d88bd9388ff/1000x1000-000000-80-0-0.jpg',
        headerImageUrl: 'https://cdn-images.dzcdn.net/images/artist/b5c64fa8216ca158e52b4d88bd9388ff/1000x1000-000000-80-0-0.jpg',
        monthlyListeners: '31.200.000 pendengar bulanan',
        bio: 'Ikon pop global abad ke-21 asal Korea Selatan dengan jutaan penggemar ARMY di seluruh dunia.',
        topTracks: [
          Song(id: 'bts_1', title: 'Dynamite', artist: 'BTS', album: 'BE',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/c3/8e/3c/c38e3cb9-40ea-920f-a496-5b91cf84ee71/195497495574.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=gdZLi9oWNZg',
              duration: const Duration(minutes: 3, seconds: 19),
              lyrics: Song.generateSampleLyrics('Dynamite')),
        ],
      ),
      Artist(
        id: 'artist_newjeans',
        name: 'NewJeans',
        country: 'Korea Selatan',
        genres: const ['K-Pop', 'R&B', 'Dance'],
        imageUrl: 'https://cdn-images.dzcdn.net/images/artist/0866c2c1d7d00879f5db46ddc1250db8/1000x1000-000000-80-0-0.jpg',
        headerImageUrl: 'https://cdn-images.dzcdn.net/images/artist/0866c2c1d7d00879f5db46ddc1250db8/1000x1000-000000-80-0-0.jpg',
        monthlyListeners: '17.800.000 pendengar bulanan',
        bio: 'Grup K-Pop pelopor gelombang Y2K R&B pop yang mendobrak tangga lagu internasional.',
        topTracks: [
          Song(id: 'nj_1', title: 'Super Shy', artist: 'NewJeans', album: 'Get Up',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/b1/83/88/b183884d-2e11-cfcf-089c-5e9218d6e902/196922485121_Cover.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=ArmDp-zijuc',
              duration: const Duration(minutes: 2, seconds: 34),
              lyrics: Song.generateSampleLyrics('Super Shy')),
        ],
      ),
      Artist(
        id: 'artist_blackpink',
        name: 'BLACKPINK',
        country: 'Korea Selatan',
        genres: const ['K-Pop', 'Pop', 'Dance', 'EDM'],
        imageUrl: 'https://cdn-images.dzcdn.net/images/artist/89675729453893a91be35bde691050ff/1000x1000-000000-80-0-0.jpg',
        headerImageUrl: 'https://cdn-images.dzcdn.net/images/artist/89675729453893a91be35bde691050ff/1000x1000-000000-80-0-0.jpg',
        monthlyListeners: '21.500.000 pendengar bulanan',
        bio: 'Girl group paling berpengaruh di dunia: Jisoo, Jennie, Rosé, Lisa.',
        topTracks: [
          Song(id: 'bp_1', title: 'How You Like That', artist: 'BLACKPINK', album: 'THE ALBUM',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/b4/d2/54/b4d2542a-a92c-6ca7-8db1-1d54eb53ef1d/20UMGIM78945.rgb.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=ioNng23DkIM',
              duration: const Duration(minutes: 3, seconds: 1),
              lyrics: Song.generateSampleLyrics('How You Like That')),
        ],
      ),

      // ── K-DRAMA OST & ASIAN MAESTROS ──
      Artist(
        id: 'artist_baek_ji_young',
        name: 'Baek Ji Young',
        country: 'Korea Selatan',
        genres: const ['K-Drama OST', 'Ballad', 'K-Pop'],
        imageUrl: 'https://cdn-images.dzcdn.net/images/artist/cd2f3a15df0a19d839937fda15680e01/1000x1000-000000-80-0-0.jpg',
        headerImageUrl: 'https://cdn-images.dzcdn.net/images/artist/cd2f3a15df0a19d839937fda15680e01/1000x1000-000000-80-0-0.jpg',
        monthlyListeners: '4.850.000 pendengar bulanan',
        bio: 'Ratu Soundtrack Drama Korea (Queen of K-Drama OST) pelantun karya legendaris "That Woman", "That Man", "Like Being Hit by a Bullet", dan "Ordinary".',
        isVerified: true,
        topTracks: [
          Song(id: 'bjy_1', title: 'That Woman', artist: 'Baek Ji Young', album: 'Secret Garden OST Special Edition',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/6b/64/00/6b64006c-843c-3ca5-2601-38290f6b45a6/cover.jpg/1000x1000bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=1F7rK6w-KqE',
              duration: const Duration(minutes: 4, seconds: 32),
              lyrics: Song.generateSampleLyrics('That Woman')),
          Song(id: 'bjy_2', title: 'That Man', artist: 'Baek Ji Young', album: 'Secret Garden OST Special Edition',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/6b/64/00/6b64006c-843c-3ca5-2601-38290f6b45a6/cover.jpg/1000x1000bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=0h5csmD4r2Y',
              duration: const Duration(minutes: 4, seconds: 31),
              lyrics: Song.generateSampleLyrics('That Man')),
          Song(id: 'bjy_3', title: 'Like Being Hit by a Bullet', artist: 'Baek Ji Young', album: 'Sensibility',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/6b/64/00/6b64006c-843c-3ca5-2601-38290f6b45a6/cover.jpg/1000x1000bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=nFj4J2F4_uE',
              duration: const Duration(minutes: 3, seconds: 58),
              lyrics: Song.generateSampleLyrics('Like Being Hit by a Bullet')),
          Song(id: 'bjy_4', title: 'Ordinary', artist: 'Baek Ji Young', album: 'Ordinary',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/6b/64/00/6b64006c-843c-3ca5-2601-38290f6b45a6/cover.jpg/1000x1000bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=7uK2_F9f9k',
              duration: const Duration(minutes: 3, seconds: 52),
              lyrics: Song.generateSampleLyrics('Ordinary')),
          Song(id: 'bjy_5', title: 'Voice', artist: 'Baek Ji Young', album: 'Voice',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/6b/64/00/6b64006c-843c-3ca5-2601-38290f6b45a6/cover.jpg/1000x1000bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=3g8K2_F9f9k',
              duration: const Duration(minutes: 3, seconds: 45),
              lyrics: Song.generateSampleLyrics('Voice')),
          Song(id: 'bjy_6', title: 'Garosugil at Dawn', artist: 'Baek Ji Young', album: 'Reminiscence',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/6b/64/00/6b64006c-843c-3ca5-2601-38290f6b45a6/cover.jpg/1000x1000bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=1d8R2_F9f9k',
              duration: const Duration(minutes: 4, seconds: 2),
              lyrics: Song.generateSampleLyrics('Garosugil at Dawn')),
          Song(id: 'bjy_7', title: 'Don\'t Forget', artist: 'Baek Ji Young', album: 'IRIS OST Part 1',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/6b/64/00/6b64006c-843c-3ca5-2601-38290f6b45a6/cover.jpg/1000x1000bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=0h5csmD4r2Y',
              duration: const Duration(minutes: 4, seconds: 5),
              lyrics: Song.generateSampleLyrics('Don\'t Forget')),
          Song(id: 'bjy_8', title: 'I Won\'t Love', artist: 'Baek Ji Young', album: 'Smile Again',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/6b/64/00/6b64006c-843c-3ca5-2601-38290f6b45a6/cover.jpg/1000x1000bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=0h5csmD4r2Y',
              duration: const Duration(minutes: 4, seconds: 12),
              lyrics: Song.generateSampleLyrics('I Won\'t Love')),
        ],
        albums: const [
          ArtistAlbum(
            id: 'alb_bjy_secret_garden',
            title: 'Secret Garden OST Special Edition',
            coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/6b/64/00/6b64006c-843c-3ca5-2601-38290f6b45a6/cover.jpg/1000x1000bb.jpg',
            releaseYear: '2011',
            type: 'Album',
          ),
          ArtistAlbum(
            id: 'alb_bjy_sensibility',
            title: 'Sensibility',
            coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/6b/64/00/6b64006c-843c-3ca5-2601-38290f6b45a6/cover.jpg/1000x1000bb.jpg',
            releaseYear: '2008',
            type: 'Album',
          ),
          ArtistAlbum(
            id: 'alb_bjy_reminiscence',
            title: 'Reminiscence',
            coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/6b/64/00/6b64006c-843c-3ca5-2601-38290f6b45a6/cover.jpg/1000x1000bb.jpg',
            releaseYear: '2019',
            type: 'Album',
          ),
          ArtistAlbum(
            id: 'alb_bjy_ordinary',
            title: 'Ordinary',
            coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/6b/64/00/6b64006c-843c-3ca5-2601-38290f6b45a6/cover.jpg/1000x1000bb.jpg',
            releaseYear: '2011',
            type: 'Single',
          ),
          ArtistAlbum(
            id: 'alb_bjy_voice',
            title: 'Voice',
            coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/6b/64/00/6b64006c-843c-3ca5-2601-38290f6b45a6/cover.jpg/1000x1000bb.jpg',
            releaseYear: '2012',
            type: 'EP',
          ),
        ],
      ),

      Artist(
        id: 'artist_hyun_bin',
        name: 'Hyun Bin',
        country: 'Korea Selatan',
        genres: const ['K-Drama OST', 'Ballad', 'Soundtrack'],
        imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/6/60/Hyun_Bin_at_the_2024_Toronto_International_Film_Festival_2_%28cropped%29.jpg',
        headerImageUrl: 'https://upload.wikimedia.org/wikipedia/commons/6/60/Hyun_Bin_at_the_2024_Toronto_International_Film_Festival_2_%28cropped%29.jpg',
        monthlyListeners: '2.410.000 pendengar bulanan',
        bio: 'Aktor papan atas Korea Selatan bintang drama "Secret Garden" dan "Crash Landing on You" yang menyanyikan single hit #1 tangga lagu "That Man" (그 남자) dan "Can\'t Have You".',
        isVerified: true,
        topTracks: [
          Song(id: 'hb_1', title: 'That Man', artist: 'Hyun Bin', album: 'Secret Garden OST Part 5',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music114/v4/2c/a7/36/2ca73629-463d-8bf6-1adc-1baa51e6e377/1.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=0h5csmD4r2Y',
              duration: const Duration(minutes: 4, seconds: 31),
              lyrics: getHyunBinThatManLyrics()),
          Song(id: 'hb_2', title: 'Can\'t Have You', artist: 'Hyun Bin', album: 'Friend, Our Legend OST',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music114/v4/2c/a7/36/2ca73629-463d-8bf6-1adc-1baa51e6e377/1.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=5w9bK8x2Q2w',
              duration: const Duration(minutes: 4, seconds: 12),
              lyrics: Song.generateSampleLyrics('Can\'t Have You')),
          Song(id: 'hb_that_man_inst', title: 'That Man (Inst.)', artist: 'Hyun Bin', album: 'Secret Garden OST Part 5',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music114/v4/2c/a7/36/2ca73629-463d-8bf6-1adc-1baa51e6e377/1.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=0h5csmD4r2Y',
              duration: const Duration(minutes: 4, seconds: 31),
              lyrics: Song.generateSampleLyrics('Instrumental')),
          Song(id: 'hb_cant_have_you_inst', title: 'Can\'t Have You (Inst.)', artist: 'Hyun Bin', album: 'Friend, Our Legend OST',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music114/v4/2c/a7/36/2ca73629-463d-8bf6-1adc-1baa51e6e377/1.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=5w9bK8x2Q2w',
              duration: const Duration(minutes: 4, seconds: 12),
              lyrics: Song.generateSampleLyrics('Instrumental')),
          Song(id: 'hb_dream_in_my_heart', title: 'Dream in My Heart (내 마음의 보석상자)', artist: 'Hyun Bin', album: 'Friend, Our Legend OST',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music114/v4/2c/a7/36/2ca73629-463d-8bf6-1adc-1baa51e6e377/1.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=5w9bK8x2Q2w',
              duration: const Duration(minutes: 3, seconds: 48),
              lyrics: Song.generateSampleLyrics('Dream in My Heart')),
        ],
        albums: const [
          ArtistAlbum(
            id: 'alb_hb_secret_garden',
            title: 'Secret Garden OST Part 5',
            coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music114/v4/2c/a7/36/2ca73629-463d-8bf6-1adc-1baa51e6e377/1.jpg/600x600bb.jpg',
            releaseYear: '2011',
            type: 'Single',
          ),
          ArtistAlbum(
            id: 'alb_hb_friend',
            title: 'Friend, Our Legend OST',
            coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music114/v4/2c/a7/36/2ca73629-463d-8bf6-1adc-1baa51e6e377/1.jpg/600x600bb.jpg',
            releaseYear: '2009',
            type: 'Album',
          ),
        ],
      ),

      Artist(
        id: 'artist_wendy',
        name: 'Wendy',
        country: 'Korea Selatan',
        genres: const ['K-Pop', 'Ballad', 'R&B', 'K-Drama OST'],
        imageUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/0d/1e/8a/0d1e8ad4-b463-2c1b-26b2-65922eb43fef/cover.jpg/1000x1000bb.jpg',
        headerImageUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/0d/1e/8a/0d1e8ad4-b463-2c1b-26b2-65922eb43fef/cover.jpg/1000x1000bb.jpg',
        monthlyListeners: '3.450.000 pendengar bulanan',
        bio: 'Wendy (손승완) adalah vokalis utama Red Velvet dan solois berbakat asal Korea Selatan di bawah SM Entertainment. Terkenal dengan teknik vokal emosional memukau, melantunkan hits Spotify "Like Water", "When This Rain Stops", "Wish You Hell", duet global "Written In The Stars" bersama John Legend, serta deretan OST drama populer.',
        isVerified: true,
        topTracks: [
          Song(
            id: 'wendy_like_water',
            title: 'Like Water',
            artist: 'Wendy',
            album: 'Like Water - The 1st Mini Album',
            albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music114/v4/06/66/3a/06663a8a-e95e-149f-b989-1065166a5996/Wendy_LikeWater.jpg/1000x1000bb.jpg',
            audioUrl: 'https://www.youtube.com/watch?v=-Ih5UcXl_4g',
            duration: const Duration(minutes: 4, seconds: 21),
            lyrics: Song.generateSampleLyrics('Like Water'),
          ),
          Song(
            id: 'wendy_when_this_rain_stops',
            title: 'When This Rain Stops',
            artist: 'Wendy',
            album: 'Like Water - The 1st Mini Album',
            albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music114/v4/06/66/3a/06663a8a-e95e-149f-b989-1065166a5996/Wendy_LikeWater.jpg/1000x1000bb.jpg',
            audioUrl: 'https://www.youtube.com/watch?v=0_fI6-6oZf0',
            duration: const Duration(minutes: 3, seconds: 56),
            lyrics: Song.generateSampleLyrics('When This Rain Stops'),
          ),
          Song(
            id: 'wendy_wish_you_hell',
            title: 'Wish You Hell',
            artist: 'Wendy',
            album: 'Wish You Hell - The 2nd Mini Album',
            albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/0d/1e/8a/0d1e8ad4-b463-2c1b-26b2-65922eb43fef/cover.jpg/1000x1000bb.jpg',
            audioUrl: 'https://www.youtube.com/watch?v=kYJvE-ZpTcA',
            duration: const Duration(minutes: 2, seconds: 51),
            lyrics: Song.generateSampleLyrics('Wish You Hell'),
          ),
          Song(
            id: 'wendy_written_in_the_stars',
            title: 'Written In The Stars',
            artist: 'Wendy x John Legend',
            album: 'Written In The Stars - SM STATION',
            albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music118/v4/f2/61/89/f2618991-e0c1-5272-fb53-84724b0aa8e1/Wendy_JohnLegend.jpg/1000x1000bb.jpg',
            audioUrl: 'https://www.youtube.com/watch?v=uT3PW_jW_t8',
            duration: const Duration(minutes: 3, seconds: 51),
            lyrics: Song.generateSampleLyrics('Written In The Stars'),
          ),
          Song(
            id: 'wendy_what_if_love',
            title: 'What If Love',
            artist: 'Wendy',
            album: 'Touch Your Heart OST Part 3',
            albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music114/v4/8e/3c/64/8e3c64d8-c89b-73b0-6425-4c07a0bbba86/TYH_OST.jpg/1000x1000bb.jpg',
            audioUrl: 'https://www.youtube.com/watch?v=Gk74y6w7M7s',
            duration: const Duration(minutes: 3, seconds: 41),
            lyrics: Song.generateSampleLyrics('What If Love'),
          ),
          Song(
            id: 'wendy_goodbye',
            title: 'Goodbye',
            artist: 'Wendy',
            album: 'The Beauty Inside OST Part 6',
            albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music114/v4/2c/a7/36/2ca73629-463d-8bf6-1adc-1baa51e6e377/1.jpg/600x600bb.jpg',
            audioUrl: 'https://www.youtube.com/watch?v=1F9wW7wU4cQ',
            duration: const Duration(minutes: 3, seconds: 15),
            lyrics: Song.generateSampleLyrics('Goodbye'),
          ),
        ],
        albums: const [
          ArtistAlbum(
            id: 'alb_wendy_wish_you_hell',
            title: 'Wish You Hell - The 2nd Mini Album',
            coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/0d/1e/8a/0d1e8ad4-b463-2c1b-26b2-65922eb43fef/cover.jpg/1000x1000bb.jpg',
            releaseYear: '2024',
            type: 'Album',
          ),
          ArtistAlbum(
            id: 'alb_wendy_like_water',
            title: 'Like Water - The 1st Mini Album',
            coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music114/v4/06/66/3a/06663a8a-e95e-149f-b989-1065166a5996/Wendy_LikeWater.jpg/1000x1000bb.jpg',
            releaseYear: '2021',
            type: 'Album',
          ),
          ArtistAlbum(
            id: 'alb_wendy_written_in_the_stars',
            title: 'Written In The Stars',
            coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music118/v4/f2/61/89/f2618991-e0c1-5272-fb53-84724b0aa8e1/Wendy_JohnLegend.jpg/1000x1000bb.jpg',
            releaseYear: '2018',
            type: 'Single',
          ),
          ArtistAlbum(
            id: 'alb_wendy_touch_your_heart',
            title: 'Touch Your Heart OST Part 3',
            coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music114/v4/8e/3c/64/8e3c64d8-c89b-73b0-6425-4c07a0bbba86/TYH_OST.jpg/1000x1000bb.jpg',
            releaseYear: '2019',
            type: 'Single',
          ),
        ],
      ),

      Artist(
        id: 'artist_gummy',
        name: 'Gummy',
        country: 'Korea Selatan',
        genres: const ['K-Drama OST', 'Ballad', 'R&B'],
        imageUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music124/v4/55/63/1a/55631ad4-90ff-a30c-a31f-97b6d46212e3/8806197904723.jpg/1000x1000bb.jpg',
        headerImageUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music124/v4/55/63/1a/55631ad4-90ff-a30c-a31f-97b6d46212e3/8806197904723.jpg/1000x1000bb.jpg',
        monthlyListeners: '5.230.000 pendengar bulanan',
        bio: 'Vokalis legendaris Korea Selatan pelantun hits OST "You Are My Everything" (Descendants of the Sun) dan "Remember Me" (Hotel Del Luna).',
        isVerified: true,
        topTracks: [
          Song(id: 'gum_1', title: 'You Are My Everything', artist: 'Gummy', album: 'Descendants of the Sun OST Part 4',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music118/v4/64/92/ff/6492ff1c-e722-e3e8-5a02-23c31a787268/8809484114750.jpg/1000x1000bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=To_4e_1K-3Q',
              duration: const Duration(minutes: 4, seconds: 0),
              lyrics: Song.generateSampleLyrics('You Are My Everything')),
          Song(id: 'gum_2', title: 'Remember Me', artist: 'Gummy', album: 'Hotel Del Luna OST Part 6',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music113/v4/7c/fe/eb/7cfeeb79-4b36-7ca6-4d0c-f376f9db1627/8809658314175.jpg/1000x1000bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=9_d8_F9f9k',
              duration: const Duration(minutes: 3, seconds: 48),
              lyrics: Song.generateSampleLyrics('Remember Me')),
        ],
        albums: const [
          ArtistAlbum(
            id: 'alb_gum_dots',
            title: 'Descendants of the Sun OST Part 4',
            coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music118/v4/64/92/ff/6492ff1c-e722-e3e8-5a02-23c31a787268/8809484114750.jpg/1000x1000bb.jpg',
            releaseYear: '2016',
            type: 'Single',
          ),
          ArtistAlbum(
            id: 'alb_gum_hdl',
            title: 'Hotel Del Luna OST Part 6',
            coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music113/v4/7c/fe/eb/7cfeeb79-4b36-7ca6-4d0c-f376f9db1627/8809658314175.jpg/1000x1000bb.jpg',
            releaseYear: '2019',
            type: 'Single',
          ),
        ],
      ),

      // ── DMEANOR (KOREA SELATAN / R&B & K-DRAMA OST) ──
      Artist(
        id: 'artist_dmeanor',
        name: 'DMEANOR',
        country: 'Korea Selatan',
        genres: const ['R&B/Soul', 'K-Drama OST', 'K-Pop'],
        imageUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/29/b6/fa/29b6fa09-cd0c-fcf8-a8f6-fb9f34dbf200/8809933240376.jpg/1000x1000bb.jpg',
        headerImageUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/29/b6/fa/29b6fa09-cd0c-fcf8-a8f6-fb9f34dbf200/8809933240376.jpg/1000x1000bb.jpg',
        monthlyListeners: '2.140.000 pendengar bulanan',
        bio: 'Penyanyi dan pencipta lagu R&B/Soul asal Korea Selatan pelantun hits OST legendaris "Why Do We" (너도 인간이니? / Are You Human?) dalam versi Korea dan Inggris, serta "Stay There" (Voice 2 OST), "Right Here", dan "Don\'t Hold Me".',
        isVerified: true,
        topTracks: [
          Song(
            id: 'dmeanor_stay_there',
            title: 'Stay There',
            artist: 'DMEANOR',
            album: 'Voice 2 OST Part 4',
            albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/4a/60/0b/4a600b74-3236-a67b-11f8-08571cf31ae9/8809623750017.jpg/1000x1000bb.jpg',
            audioUrl: 'https://www.youtube.com/watch?v=1Tgt0-0HIxQ',
            duration: const Duration(minutes: 3, seconds: 53),
            lyrics: Song.generateSampleLyrics('Stay There'),
          ),
          Song(
            id: 'dmeanor_why_do_we_korean',
            title: 'Why Do We (Korean Ver.)',
            artist: 'DMEANOR',
            album: 'Are You Human? OST Part 8',
            albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/93/fc/3f/93fc3fd2-c05e-c461-a197-d06aaf709a96/191953013459.jpg/1000x1000bb.jpg',
            audioUrl: 'https://www.youtube.com/watch?v=IffYFYj-aO4',
            duration: const Duration(minutes: 4, seconds: 14),
            lyrics: Song.generateSampleLyrics('Why Do We (Korean Ver.)'),
          ),
          Song(
            id: 'dmeanor_why_do_we_english',
            title: 'Why Do We (English Ver.)',
            artist: 'DMEANOR',
            album: 'Are You Human? OST Part 8',
            albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/93/fc/3f/93fc3fd2-c05e-c461-a197-d06aaf709a96/191953013459.jpg/1000x1000bb.jpg',
            audioUrl: 'https://www.youtube.com/watch?v=5wExaQidIU8',
            duration: const Duration(minutes: 4, seconds: 14),
            lyrics: Song.generateSampleLyrics('Why Do We (English Ver.)'),
          ),
          Song(
            id: 'dmeanor_stay_there_inst',
            title: 'Stay There (Inst.)',
            artist: 'DMEANOR',
            album: 'Voice 2 OST Part 4',
            albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/4a/60/0b/4a600b74-3236-a67b-11f8-08571cf31ae9/8809623750017.jpg/1000x1000bb.jpg',
            audioUrl: 'https://www.youtube.com/watch?v=oauwnaiXHb8',
            duration: const Duration(minutes: 3, seconds: 53),
            lyrics: Song.generateSampleLyrics('Instrumental'),
          ),
          Song(
            id: 'dmeanor_right_here',
            title: 'Right Here',
            artist: 'DMEANOR',
            album: 'Right Here - Single',
            albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/29/b6/fa/29b6fa09-cd0c-fcf8-a8f6-fb9f34dbf200/8809933240376.jpg/1000x1000bb.jpg',
            audioUrl: 'https://www.youtube.com/watch?v=1F9wW7wU4cQ',
            duration: const Duration(minutes: 3, seconds: 28),
            lyrics: Song.generateSampleLyrics('Right Here'),
          ),
          Song(
            id: 'dmeanor_dont_hold_me',
            title: 'Don\'t Hold Me',
            artist: 'DMEANOR',
            album: 'Don\'t Hold Me - Single',
            albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/50/c6/e7/50c6e7f5-b568-c0b7-2c3e-1f7c9e43bfa3/8809933240383.jpg/1000x1000bb.jpg',
            audioUrl: 'https://www.youtube.com/watch?v=1F9wW7wU4cQ',
            duration: const Duration(minutes: 3, seconds: 19),
            lyrics: Song.generateSampleLyrics('Don\'t Hold Me'),
          ),
          Song(
            id: 'dmeanor_fool_for_loving',
            title: 'Fool For Loving',
            artist: 'DMEANOR',
            album: 'Fool For Loving - Single',
            albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/50/c6/e7/50c6e7f5-b568-c0b7-2c3e-1f7c9e43bfa3/8809933240383.jpg/1000x1000bb.jpg',
            audioUrl: 'https://www.youtube.com/watch?v=1F9wW7wU4cQ',
            duration: const Duration(minutes: 3, seconds: 35),
            lyrics: Song.generateSampleLyrics('Fool For Loving'),
          ),
        ],
        albums: [
          ArtistAlbum(
            id: 'alb_dmeanor_voice2',
            title: 'Voice 2 OST Part 4',
            coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/4a/60/0b/4a600b74-3236-a67b-11f8-08571cf31ae9/8809623750017.jpg/1000x1000bb.jpg',
            releaseYear: '2018',
            type: 'Single',
            songs: [
              Song(
                id: 'dmeanor_stay_there',
                title: 'Stay There',
                artist: 'DMEANOR',
                album: 'Voice 2 OST Part 4',
                albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/4a/60/0b/4a600b74-3236-a67b-11f8-08571cf31ae9/8809623750017.jpg/1000x1000bb.jpg',
                audioUrl: 'https://www.youtube.com/watch?v=1Tgt0-0HIxQ',
                duration: const Duration(minutes: 3, seconds: 53),
                lyrics: Song.generateSampleLyrics('Stay There'),
              ),
              Song(
                id: 'dmeanor_stay_there_inst',
                title: 'Stay There (Inst.)',
                artist: 'DMEANOR',
                album: 'Voice 2 OST Part 4',
                albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/4a/60/0b/4a600b74-3236-a67b-11f8-08571cf31ae9/8809623750017.jpg/1000x1000bb.jpg',
                audioUrl: 'https://www.youtube.com/watch?v=oauwnaiXHb8',
                duration: const Duration(minutes: 3, seconds: 53),
                lyrics: Song.generateSampleLyrics('Instrumental'),
              ),
            ],
          ),
          ArtistAlbum(
            id: 'alb_dmeanor_are_you_human',
            title: 'Are You Human? OST Part 8',
            coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/93/fc/3f/93fc3fd2-c05e-c461-a197-d06aaf709a96/191953013459.jpg/1000x1000bb.jpg',
            releaseYear: '2018',
            type: 'Single',
            songs: [
              Song(
                id: 'dmeanor_why_do_we_korean',
                title: 'Why Do We (Korean Ver.)',
                artist: 'DMEANOR',
                album: 'Are You Human? OST Part 8',
                albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/93/fc/3f/93fc3fd2-c05e-c461-a197-d06aaf709a96/191953013459.jpg/1000x1000bb.jpg',
                audioUrl: 'https://www.youtube.com/watch?v=IffYFYj-aO4',
                duration: const Duration(minutes: 4, seconds: 14),
                lyrics: Song.generateSampleLyrics('Why Do We (Korean Ver.)'),
              ),
              Song(
                id: 'dmeanor_why_do_we_english',
                title: 'Why Do We (English Ver.)',
                artist: 'DMEANOR',
                album: 'Are You Human? OST Part 8',
                albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/93/fc/3f/93fc3fd2-c05e-c461-a197-d06aaf709a96/191953013459.jpg/1000x1000bb.jpg',
                audioUrl: 'https://www.youtube.com/watch?v=5wExaQidIU8',
                duration: const Duration(minutes: 4, seconds: 14),
                lyrics: Song.generateSampleLyrics('Why Do We (English Ver.)'),
              ),
              Song(
                id: 'dmeanor_why_do_we_inst',
                title: 'Why Do We (Inst.)',
                artist: 'DMEANOR',
                album: 'Are You Human? OST Part 8',
                albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/93/fc/3f/93fc3fd2-c05e-c461-a197-d06aaf709a96/191953013459.jpg/1000x1000bb.jpg',
                audioUrl: 'https://www.youtube.com/watch?v=q6j7q2cclzU',
                duration: const Duration(minutes: 4, seconds: 14),
                lyrics: Song.generateSampleLyrics('Instrumental'),
              ),
            ],
          ),
          const ArtistAlbum(
            id: 'alb_dmeanor_right_here',
            title: 'Right Here',
            coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/29/b6/fa/29b6fa09-cd0c-fcf8-a8f6-fb9f34dbf200/8809933240376.jpg/1000x1000bb.jpg',
            releaseYear: '2017',
            type: 'Single',
          ),
          const ArtistAlbum(
            id: 'alb_dmeanor_dont_hold_me',
            title: 'Don\'t Hold Me',
            coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/50/c6/e7/50c6e7f5-b568-c0b7-2c3e-1f7c9e43bfa3/8809933240383.jpg/1000x1000bb.jpg',
            releaseYear: '2017',
            type: 'Single',
          ),
        ],
      ),

      Artist(
        id: 'artist_jay_chou',
        name: 'Jay Chou',
        country: 'Taiwan',
        genres: const ['Mandopop', 'R&B', 'Pop'],
        imageUrl: 'https://cdn-images.dzcdn.net/images/artist/4b60277efe2dff28823aac761d390406/1000x1000-000000-80-0-0.jpg',
        headerImageUrl: 'https://cdn-images.dzcdn.net/images/artist/4b60277efe2dff28823aac761d390406/1000x1000-000000-80-0-0.jpg',
        monthlyListeners: '14.200.000 pendengar bulanan',
        bio: 'King of Mandopop dengan karya legendaris selama 2 dekade lebih (2000-2017). Pelantun hits "Common Jasmine Orange", "Sunny Day", "Silence", dan "Confession Balloon".',
        isVerified: true,
        topTracks: [
          Song(id: 'jc_1', title: 'Common Jasmine Orange', artist: 'Jay Chou', album: 'Jay Chou Best Hits 2000-2017',
              albumArtUrl: 'https://cdn-images.dzcdn.net/images/artist/4b60277efe2dff28823aac761d390406/1000x1000-000000-80-0-0.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=Bbp9ZaJD_eA',
              duration: const Duration(minutes: 4, seconds: 35),
              lyrics: Song.generateSampleLyrics('Common Jasmine Orange')),
          Song(id: 'jc_2', title: 'Sunny Day', artist: 'Jay Chou', album: 'Jay Chou Best Hits 2000-2017',
              albumArtUrl: 'https://cdn-images.dzcdn.net/images/artist/4b60277efe2dff28823aac761d390406/1000x1000-000000-80-0-0.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=DYptgVvkVLQ',
              duration: const Duration(minutes: 4, seconds: 29),
              lyrics: Song.generateSampleLyrics('Sunny Day')),
          Song(id: 'jc_3', title: 'Silence', artist: 'Jay Chou', album: 'Jay Chou Best Hits 2000-2017',
              albumArtUrl: 'https://cdn-images.dzcdn.net/images/artist/4b60277efe2dff28823aac761d390406/1000x1000-000000-80-0-0.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=1hI-7vj2FzU',
              duration: const Duration(minutes: 4, seconds: 34),
              lyrics: Song.generateSampleLyrics('Silence')),
          Song(id: 'jc_4', title: 'Confession Balloon', artist: 'Jay Chou', album: 'Jay Chou Best Hits 2000-2017',
              albumArtUrl: 'https://cdn-images.dzcdn.net/images/artist/4b60277efe2dff28823aac761d390406/1000x1000-000000-80-0-0.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=bu7nU9Mhpyo',
              duration: const Duration(minutes: 3, seconds: 35),
              lyrics: Song.generateSampleLyrics('Confession Balloon')),
        ],
        albums: const [
          ArtistAlbum(
            id: 'alb_jc_best_hits',
            title: 'Jay Chou Best Hits 2000-2017',
            coverUrl: 'https://cdn-images.dzcdn.net/images/artist/4b60277efe2dff28823aac761d390406/1000x1000-000000-80-0-0.jpg',
            releaseYear: '2017',
            type: 'Album',
          ),
          ArtistAlbum(
            id: 'alb_jc_qilixiang',
            title: 'Common Jasmine Orange',
            coverUrl: 'https://cdn-images.dzcdn.net/images/artist/4b60277efe2dff28823aac761d390406/1000x1000-000000-80-0-0.jpg',
            releaseYear: '2004',
            type: 'Album',
          ),
        ],
      ),

      // ── KENSHI YONEZU (JEPANG) ──
      Artist(
        id: 'artist_kenshi_yonezu',
        name: 'Kenshi Yonezu',
        country: 'Jepang',
        genres: const ['J-Pop', 'Anime', 'Rock'],
        imageUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/86/b0/9d/86b09d63-367a-563a-1e24-d5d62c220ac8/jacket_SRCL09749B00Z_550.jpg/600x600bb.jpg',
        headerImageUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/86/b0/9d/86b09d63-367a-563a-1e24-d5d62c220ac8/jacket_SRCL09749B00Z_550.jpg/600x600bb.jpg',
        monthlyListeners: '14.280.000 pendengar bulanan',
        bio: 'Penyanyi, penulis lagu, dan produser visioner asal Jepang pencipta lagu legendaris "Lemon", "KICK BACK" (Chainsaw Man), "Peace Sign" (My Hero Academia), dan "Chikyugi" (The Boy and the Heron).',
        isVerified: true,
        topTracks: [
          Song(id: 'kenshi_1', title: 'IRIS OUT', artist: 'Kenshi Yonezu', album: 'LOST CORNER',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music122/v4/4e/a8/75/4ea875d1-bdb6-9b83-185a-646391cbffbd/4547366589849.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=M_F6uVp45Yk',
              duration: const Duration(minutes: 3, seconds: 28)),
          Song(id: 'kenshi_2', title: 'KICK BACK', artist: 'Kenshi Yonezu', album: 'KICK BACK (Chainsaw Man OP)',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music122/v4/4e/a8/75/4ea875d1-bdb6-9b83-185a-646391cbffbd/4547366589849.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=M2cckDmNLMI',
              duration: const Duration(minutes: 3, seconds: 13)),
          Song(id: 'kenshi_3', title: 'Peace Sign', artist: 'Kenshi Yonezu', album: 'BOOTLEG (My Hero Academia OP)',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music114/v4/a2/60/65/a260650f-8967-2697-ff52-ef65589ab38f/jacket_SRCL09458B00Z_550.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=9aJVYmnMrUQ',
              duration: const Duration(minutes: 3, seconds: 58)),
          Song(id: 'kenshi_4', title: 'Lemon', artist: 'Kenshi Yonezu', album: 'Lemon (Unnatural OST)',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/86/b0/9d/86b09d63-367a-563a-1e24-d5d62c220ac8/jacket_SRCL09749B00Z_550.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=SX_ViT4Ra7k',
              duration: const Duration(minutes: 4, seconds: 15)),
          Song(id: 'kenshi_5', title: 'Chikyugi - Spinning Globe', artist: 'Kenshi Yonezu', album: 'LOST CORNER (The Boy and the Heron)',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music122/v4/4e/a8/75/4ea875d1-bdb6-9b83-185a-646391cbffbd/4547366589849.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=VGBn8b_fSls',
              duration: const Duration(minutes: 4, seconds: 33)),
        ],
        albums: const [
          ArtistAlbum(id: 'alb_kenshi_lostcorner', title: 'LOST CORNER',
              coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music122/v4/4e/a8/75/4ea875d1-bdb6-9b83-185a-646391cbffbd/4547366589849.jpg/600x600bb.jpg',
              releaseYear: '2024', type: 'Album'),
          ArtistAlbum(id: 'alb_kenshi_bootleg', title: 'BOOTLEG',
              coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music114/v4/a2/60/65/a260650f-8967-2697-ff52-ef65589ab38f/jacket_SRCL09458B00Z_550.jpg/600x600bb.jpg',
              releaseYear: '2017', type: 'Album'),
          ArtistAlbum(id: 'alb_kenshi_stray_sheep', title: 'STRAY SHEEP',
              coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/86/b0/9d/86b09d63-367a-563a-1e24-d5d62c220ac8/jacket_SRCL09749B00Z_550.jpg/600x600bb.jpg',
              releaseYear: '2020', type: 'Album'),
        ],
      ),

      // ── UTADA HIKARU (JEPANG) ──
      Artist(
        id: 'artist_utada_hikaru',
        name: 'Utada Hikaru',
        country: 'Jepang',
        genres: const ['J-Pop', 'R&B', 'Electronic'],
        imageUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music128/v4/d1/a6/81/d1a681b9-aa68-6148-5a50-69fd4c95cc37/00602567241966.rgb.jpg/600x600bb.jpg',
        headerImageUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music128/v4/d1/a6/81/d1a681b9-aa68-6148-5a50-69fd4c95cc37/00602567241966.rgb.jpg/600x600bb.jpg',
        monthlyListeners: '8.950.000 pendengar bulanan',
        bio: 'Diva legendaris J-Pop dan R&B pemegang rekor penjualan album sepanjang masa di Jepang. Dikenal secara global lewat "First Love", "One Last Kiss" (Evangelion), dan lagu tema Kingdom Hearts.',
        isVerified: true,
        topTracks: [
          Song(id: 'utada_1', title: 'One Last Kiss', artist: 'Utada Hikaru', album: 'BAD MODE (Evangelion 3.0+1.0)',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/0a/e9/a2/0ae9a2d9-3276-825b-cc16-ca494011531c/24UMGIM13711.rgb.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=0Uhh62MUEic',
              duration: const Duration(minutes: 4, seconds: 12)),
          Song(id: 'utada_2', title: 'First Love', artist: 'Utada Hikaru', album: 'First Love',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music128/v4/d1/a6/81/d1a681b9-aa68-6148-5a50-69fd4c95cc37/00602567241966.rgb.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=o1sUaVJUeB0',
              duration: const Duration(minutes: 4, seconds: 17)),
          Song(id: 'utada_3', title: 'Simple And Clean', artist: 'Utada Hikaru', album: 'Kingdom Hearts OST',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music128/v4/d1/a6/81/d1a681b9-aa68-6148-5a50-69fd4c95cc37/00602567241966.rgb.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=kOSNIIxBdUp',
              duration: const Duration(minutes: 5, seconds: 3)),
          Song(id: 'utada_4', title: 'Automatic', artist: 'Utada Hikaru', album: 'First Love',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music128/v4/d1/a6/81/d1a681b9-aa68-6148-5a50-69fd4c95cc37/00602567241966.rgb.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=-9Dxp3qmxBk',
              duration: const Duration(minutes: 5, seconds: 28)),
          Song(id: 'utada_5', title: 'Michi', artist: 'Utada Hikaru', album: 'Fantôme',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/0a/e9/a2/0ae9a2d9-3276-825b-cc16-ca494011531c/24UMGIM13711.rgb.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=BA682HnZ1eY',
              duration: const Duration(minutes: 3, seconds: 36)),
        ],
        albums: const [
          ArtistAlbum(id: 'alb_utada_badmode', title: 'BAD MODE',
              coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/0a/e9/a2/0ae9a2d9-3276-825b-cc16-ca494011531c/24UMGIM13711.rgb.jpg/600x600bb.jpg',
              releaseYear: '2022', type: 'Album'),
          ArtistAlbum(id: 'alb_utada_firstlove', title: 'First Love',
              coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music128/v4/d1/a6/81/d1a681b9-aa68-6148-5a50-69fd4c95cc37/00602567241966.rgb.jpg/600x600bb.jpg',
              releaseYear: '1999', type: 'Album'),
        ],
      ),

      // ── YOASOBI (JEPANG) ──
      Artist(
        id: 'artist_yoasobi',
        name: 'YOASOBI',
        country: 'Jepang',
        genres: const ['J-Pop', 'Anisong', 'Electropop'],
        imageUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/3a/17/eb/3a17eb30-eacb-82eb-51df-d1321dbb55bc/197188492205.jpg/600x600bb.jpg',
        headerImageUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/3a/17/eb/3a17eb30-eacb-82eb-51df-d1321dbb55bc/197188492205.jpg/600x600bb.jpg',
        monthlyListeners: '16.700.000 pendengar bulanan',
        bio: 'Super-duo fenomena global Jepang Ayase dan ikura yang mengubah novel menjadi musik hits dunia seperti "Idol", "Yoru ni Kakeru", dan "Kaibutsu".',
        isVerified: true,
        topTracks: [
          Song(id: 'yoasobi_1', title: 'Idol', artist: 'YOASOBI', album: 'THE BOOK 3 (Oshi no Ko OP)',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/3a/17/eb/3a17eb30-eacb-82eb-51df-d1321dbb55bc/197188492205.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=ZRtdQ81jPUQ',
              duration: const Duration(minutes: 3, seconds: 33)),
          Song(id: 'yoasobi_2', title: 'Yoru ni Kakeru', artist: 'YOASOBI', album: 'THE BOOK',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/7f/8c/90/7f8c90dd-e11f-30d5-271d-4b72eee970bd/195497666737.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=by4SYYWl728',
              duration: const Duration(minutes: 4, seconds: 21)),
          Song(id: 'yoasobi_3', title: 'Kaibutsu', artist: 'YOASOBI', album: 'THE BOOK 2 (BEASTARS OP)',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/3a/17/eb/3a17eb30-eacb-82eb-51df-d1321dbb55bc/197188492205.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=dy90tA3TT1c',
              duration: const Duration(minutes: 3, seconds: 26)),
          Song(id: 'yoasobi_4', title: 'Yuusha', artist: 'YOASOBI', album: 'THE BOOK 3 (Sousou no Frieren OP)',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/3a/17/eb/3a17eb30-eacb-82eb-51df-d1321dbb55bc/197188492205.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=OIBODIPC_8Y',
              duration: const Duration(minutes: 3, seconds: 14)),
          Song(id: 'yoasobi_5', title: 'Gunjou', artist: 'YOASOBI', album: 'THE BOOK',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/7f/8c/90/7f8c90dd-e11f-30d5-271d-4b72eee970bd/195497666737.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=vELh3Q6EBjI',
              duration: const Duration(minutes: 4, seconds: 8)),
        ],
        albums: const [
          ArtistAlbum(id: 'alb_yoasobi_book3', title: 'THE BOOK 3',
              coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/3a/17/eb/3a17eb30-eacb-82eb-51df-d1321dbb55bc/197188492205.jpg/600x600bb.jpg',
              releaseYear: '2023', type: 'Album'),
          ArtistAlbum(id: 'alb_yoasobi_book1', title: 'THE BOOK',
              coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/7f/8c/90/7f8c90dd-e11f-30d5-271d-4b72eee970bd/195497666737.jpg/600x600bb.jpg',
              releaseYear: '2021', type: 'Album'),
        ],
      ),

      // ── YUURI (JEPANG) ──
      Artist(
        id: 'artist_yuuri',
        name: 'Yuuri',
        country: 'Jepang',
        genres: const ['J-Pop', 'Rock', 'Acoustic'],
        imageUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/f1/d5/61/f1d561dc-7fab-68fa-39ac-4440d7a27940/4547366533842.jpg/600x600bb.jpg',
        headerImageUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/f1/d5/61/f1d561dc-7fab-68fa-39ac-4440d7a27940/4547366533842.jpg/600x600bb.jpg',
        monthlyListeners: '6.540.000 pendengar bulanan',
        bio: 'Penyanyi-penulis lagu asal Jepang dengan vokal serak bertenaga dan emosional, terkenal lewat mega-hits "Dried Flower" dan "Betelgeuse".',
        isVerified: true,
        topTracks: [
          Song(id: 'yuuri_1', title: 'Betelgeuse', artist: 'Yuuri', album: 'Ichi',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/f1/d5/61/f1d561dc-7fab-68fa-39ac-4440d7a27940/4547366533842.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=cbqvxDTLM84',
              duration: const Duration(minutes: 4, seconds: 12)),
          Song(id: 'yuuri_2', title: 'Dried Flower', artist: 'Yuuri', album: 'Ichi',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/d2/23/07/d2230757-3f9c-fccd-3cc8-333f7be09716/4547366478655.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=kzZ6KXDM1RI',
              duration: const Duration(minutes: 4, seconds: 46)),
          Song(id: 'yuuri_3', title: 'Curtain Call', artist: 'Yuuri', album: 'Curtain Call (My Hero Academia OP)',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/f1/d5/61/f1d561dc-7fab-68fa-39ac-4440d7a27940/4547366533842.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=6_3H-i07R4Q',
              duration: const Duration(minutes: 3, seconds: 25)),
          Song(id: 'yuuri_4', title: 'Leo', artist: 'Yuuri', album: 'Ichi',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/d2/23/07/d2230757-3f9c-fccd-3cc8-333f7be09716/4547366478655.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=uxYLn_hCSjA',
              duration: const Duration(minutes: 4, seconds: 7)),
          Song(id: 'yuuri_5', title: 'Peter Pan', artist: 'Yuuri', album: 'Ichi',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/d2/23/07/d2230757-3f9c-fccd-3cc8-333f7be09716/4547366478655.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=c18pA384rO4',
              duration: const Duration(minutes: 4, seconds: 0)),
        ],
        albums: const [
          ArtistAlbum(id: 'alb_yuuri_ichi', title: 'Ichi',
              coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/d2/23/07/d2230757-3f9c-fccd-3cc8-333f7be09716/4547366478655.jpg/600x600bb.jpg',
              releaseYear: '2022', type: 'Album'),
        ],
      ),

      // ── SHUN (NARUTO OST / JEPANG) ──
      Artist(
        id: 'artist_shun',
        name: 'SHUN',
        country: 'Jepang',
        genres: const ['J-HipHop', 'Anime', 'Pop'],
        imageUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music124/v4/2e/eb/9a/2eeb9ac0-558c-7094-75b9-a4978ed82e9a/jacket_SECL01543B00Z_550.jpg/1000x1000bb.jpg',
        headerImageUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music124/v4/2e/eb/9a/2eeb9ac0-558c-7094-75b9-a4978ed82e9a/jacket_SECL01543B00Z_550.jpg/1000x1000bb.jpg',
        monthlyListeners: '3.120.000 pendengar bulanan',
        bio: 'Rapper dan musisi Jepang pelantun lagu tema penutup resmi Naruto Shippuden "Never Change".',
        isVerified: true,
        topTracks: [
          Song(id: 'naruto_shun_never_change', title: 'Never Change', artist: 'SHUN', album: 'Naruto Shippuden Ending Theme Single',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music124/v4/2e/eb/9a/2eeb9ac0-558c-7094-75b9-a4978ed82e9a/jacket_SECL01543B00Z_550.jpg/1000x1000bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=kYJvO3z3i7Y',
              duration: const Duration(minutes: 4, seconds: 12)),
        ],
        albums: const [
          ArtistAlbum(id: 'alb_shun_never_change', title: 'NEVER CHANGE',
              coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music124/v4/2e/eb/9a/2eeb9ac0-558c-7094-75b9-a4978ed82e9a/jacket_SECL01543B00Z_550.jpg/1000x1000bb.jpg',
              releaseYear: '2013', type: 'Single'),
        ],
      ),

      // ── UNLIMITS (NARUTO OST / JEPANG) ──
      Artist(
        id: 'artist_unlimits',
        name: 'UNLIMITS',
        country: 'Jepang',
        genres: const ['J-Rock', 'Alternative Rock', 'Anime'],
        imageUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music114/v4/50/0e/3d/500e3dc1-8b44-5d3c-e1d8-2d333386643d/jacket_SRCL07949B00Z_550.jpg/1000x1000bb.jpg',
        headerImageUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music114/v4/50/0e/3d/500e3dc1-8b44-5d3c-e1d8-2d333386643d/jacket_SRCL07949B00Z_550.jpg/1000x1000bb.jpg',
        monthlyListeners: '2.840.000 pendengar bulanan',
        bio: 'Band rock asal Jepang yang membawakan lagu tema penutup ke-21 Naruto Shippuden "Cascade".',
        isVerified: true,
        topTracks: [
          Song(id: 'naruto_unlimits_cascade', title: 'Cascade', artist: 'UNLIMITS', album: 'Cascade - EP (Naruto Shippuden ED 21)',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music114/v4/50/0e/3d/500e3dc1-8b44-5d3c-e1d8-2d333386643d/jacket_SRCL07949B00Z_550.jpg/1000x1000bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=0F7xPZk_QjU',
              duration: const Duration(minutes: 3, seconds: 48)),
        ],
        albums: const [
          ArtistAlbum(id: 'alb_unlimits_cascade', title: 'Cascade',
              coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music114/v4/50/0e/3d/500e3dc1-8b44-5d3c-e1d8-2d333386643d/jacket_SRCL07949B00Z_550.jpg/1000x1000bb.jpg',
              releaseYear: '2012', type: 'Single'),
        ],
      ),

      // ── FLOW (NARUTO OST / JEPANG) ──
      Artist(
        id: 'artist_flow',
        name: 'FLOW',
        country: 'Jepang',
        genres: const ['J-Rock', 'Anime Rock', 'Pop Rock'],
        imageUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music124/v4/6c/1d/e6/6c1de681-d7fa-a93b-f347-643340afd588/jacket_KSXX00341B00Z_550.jpg/1000x1000bb.jpg',
        headerImageUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music124/v4/6c/1d/e6/6c1de681-d7fa-a93b-f347-643340afd588/jacket_KSXX00341B00Z_550.jpg/1000x1000bb.jpg',
        monthlyListeners: '5.620.000 pendengar bulanan',
        bio: 'Band rock legendaris Jepang pengisi lagu pembuka ikonik Naruto "GO!!!" dan Naruto Shippuden "Sign".',
        isVerified: true,
        topTracks: [
          Song(id: 'naruto_flow_sign', title: 'Sign', artist: 'FLOW', album: 'Sign (Naruto Shippuden OP 6)',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music124/v4/6c/1d/e6/6c1de681-d7fa-a93b-f347-643340afd588/jacket_KSXX00341B00Z_550.jpg/1000x1000bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=q9e_9p-hC34',
              duration: const Duration(minutes: 3, seconds: 57)),
        ],
        albums: const [
          ArtistAlbum(id: 'alb_flow_sign', title: 'Sign',
              coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music124/v4/6c/1d/e6/6c1de681-d7fa-a93b-f347-643340afd588/jacket_KSXX00341B00Z_550.jpg/1000x1000bb.jpg',
              releaseYear: '2010', type: 'Single'),
        ],
      ),

      // ── OASIS (GLOBAL / INGGRIS) ──
      Artist(
        id: 'artist_oasis',
        name: 'Oasis',
        country: 'Inggris',
        genres: const ['Britpop', 'Rock', 'Alternative Rock'],
        imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/c/c0/Oasis_-_Principality_Stadium%2C_Cardiff_-_Friday_4th_July_2025_member_collage.jpg',
        headerImageUrl: 'https://upload.wikimedia.org/wikipedia/commons/c/c0/Oasis_-_Principality_Stadium%2C_Cardiff_-_Friday_4th_July_2025_member_collage.jpg',
        monthlyListeners: '28.300.000 pendengar bulanan',
        bio: 'Band rock legendaris asal Manchester, Inggris yang dipimpin Liam dan Noel Gallagher, pencipta anthem legendaris dunia "Wonderwall" dan "Don\'t Look Back in Anger".',
        isVerified: true,
        topTracks: [
          Song(id: 'oasis_1', title: 'Wonderwall', artist: 'Oasis', album: "(What's the Story) Morning Glory?",
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music113/v4/04/92/e0/0492e08b-cbcc-9969-9ad6-8f5a0888068c/5051961007107.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=bx1Bh8ZvH84',
              duration: const Duration(minutes: 4, seconds: 18),
              lyrics: Song.generateSampleLyrics('Wonderwall')),
          Song(id: 'oasis_2', title: "Don't Look Back in Anger", artist: 'Oasis', album: "(What's the Story) Morning Glory?",
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music113/v4/04/92/e0/0492e08b-cbcc-9969-9ad6-8f5a0888068c/5051961007107.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=r8OipmKFDeM',
              duration: const Duration(minutes: 4, seconds: 48),
              lyrics: Song.generateSampleLyrics("Don't Look Back in Anger")),
          Song(id: 'oasis_3', title: 'Champagne Supernova', artist: 'Oasis', album: "(What's the Story) Morning Glory?",
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music113/v4/04/92/e0/0492e08b-cbcc-9969-9ad6-8f5a0888068c/5051961007107.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=tI-5uv4wryI',
              duration: const Duration(minutes: 7, seconds: 28),
              lyrics: Song.generateSampleLyrics('Champagne Supernova')),
          Song(id: 'oasis_4', title: 'Stand by Me', artist: 'Oasis', album: 'Be Here Now',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music123/v4/fa/7a/57/fa7a57c6-fbf7-61b4-4f19-fd341f1ad7d8/5051961008104.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=maTP315XZCQ',
              duration: const Duration(minutes: 5, seconds: 56),
              lyrics: Song.generateSampleLyrics('Stand by Me')),
          Song(id: 'oasis_5', title: 'Live Forever', artist: 'Oasis', album: 'Definitely Maybe',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music124/v4/00/af/e3/00afe365-35f8-04cb-379a-e12abead71cd/5051961070132.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=i_2mWhfOhGU',
              duration: const Duration(minutes: 4, seconds: 36),
              lyrics: Song.generateSampleLyrics('Live Forever')),
        ],
        albums: const [
          ArtistAlbum(id: 'alb_oasis_morningglory', title: "(What's the Story) Morning Glory?",
              coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music113/v4/04/92/e0/0492e08b-cbcc-9969-9ad6-8f5a0888068c/5051961007107.jpg/600x600bb.jpg',
              releaseYear: '1995', type: 'Album'),
          ArtistAlbum(id: 'alb_oasis_definitely_maybe', title: 'Definitely Maybe',
              coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music124/v4/00/af/e3/00afe365-35f8-04cb-379a-e12abead71cd/5051961070132.jpg/600x600bb.jpg',
              releaseYear: '1994', type: 'Album'),
          ArtistAlbum(id: 'alb_oasis_be_here_now', title: 'Be Here Now',
              coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music123/v4/fa/7a/57/fa7a57c6-fbf7-61b4-4f19-fd341f1ad7d8/5051961008104.jpg/600x600bb.jpg',
              releaseYear: '1997', type: 'Album'),
        ],
      ),

      // ── BACKSTREET BOYS (GLOBAL / AS) ──
      Artist(
        id: 'artist_backstreet_boys',
        name: 'Backstreet Boys',
        country: 'Amerika Serikat',
        genres: const ['Boy Band', 'Pop', 'Dance-Pop'],
        imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/9/9a/Backstreet_Boys_2019_by_Glenn_Francis.jpg',
        headerImageUrl: 'https://upload.wikimedia.org/wikipedia/commons/9/9a/Backstreet_Boys_2019_by_Glenn_Francis.jpg',
        monthlyListeners: '21.450.000 pendengar bulanan',
        bio: 'Boy band terlaris sepanjang masa dalam sejarah musik dunia dengan hits legendaris "I Want It That Way", "Everybody (Backstreet\'s Back)", dan "As Long as You Love Me".',
        isVerified: true,
        topTracks: [
          Song(id: 'bsb_1', title: 'I Want It That Way', artist: 'Backstreet Boys', album: 'Millennium',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/1e/74/29/1e74299f-697d-e334-1456-8bf680e7f888/196872361513.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=4fndeDfaWCg',
              duration: const Duration(minutes: 3, seconds: 33),
              lyrics: Song.generateSampleLyrics('I Want It That Way')),
          Song(id: 'bsb_2', title: "Everybody (Backstreet's Back)", artist: 'Backstreet Boys', album: "Backstreet's Back",
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music114/v4/6b/e5/ee/6be5eeee-ba48-3686-2d31-ef9866ba94ab/012414177926.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=6M6samPEMpM',
              duration: const Duration(minutes: 3, seconds: 44),
              lyrics: Song.generateSampleLyrics("Everybody (Backstreet's Back)")),
          Song(id: 'bsb_3', title: 'As Long as You Love Me', artist: 'Backstreet Boys', album: "Backstreet's Back",
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music114/v4/6b/e5/ee/6be5eeee-ba48-3686-2d31-ef9866ba94ab/012414177926.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=0Gl2QnHNpkA',
              duration: const Duration(minutes: 3, seconds: 32),
              lyrics: Song.generateSampleLyrics('As Long as You Love Me')),
          Song(id: 'bsb_4', title: 'Shape of My Heart', artist: 'Backstreet Boys', album: 'Black & Blue',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/d1/04/3f/d1043ff2-73b8-e7c5-3ed8-ae9b768bb24f/012414174321.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=OT5msu-dap8',
              duration: const Duration(minutes: 3, seconds: 50),
              lyrics: Song.generateSampleLyrics('Shape of My Heart')),
          Song(id: 'bsb_5', title: 'Show Me the Meaning of Being Lonely', artist: 'Backstreet Boys', album: 'Millennium',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/1e/74/29/1e74299f-697d-e334-1456-8bf680e7f888/196872361513.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=aBt8fN7mJNg',
              duration: const Duration(minutes: 3, seconds: 54),
              lyrics: Song.generateSampleLyrics('Show Me the Meaning of Being Lonely')),
        ],
        albums: const [
          ArtistAlbum(id: 'alb_bsb_millennium', title: 'Millennium',
              coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/1e/74/29/1e74299f-697d-e334-1456-8bf680e7f888/196872361513.jpg/600x600bb.jpg',
              releaseYear: '1999', type: 'Album'),
          ArtistAlbum(id: 'alb_bsb_backstreetsback', title: "Backstreet's Back",
              coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music114/v4/6b/e5/ee/6be5eeee-ba48-3686-2d31-ef9866ba94ab/012414177926.jpg/600x600bb.jpg',
              releaseYear: '1997', type: 'Album'),
          ArtistAlbum(id: 'alb_bsb_black_and_blue', title: 'Black & Blue',
              coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/d1/04/3f/d1043ff2-73b8-e7c5-3ed8-ae9b768bb24f/012414174321.jpg/600x600bb.jpg',
              releaseYear: '2000', type: 'Album'),
        ],
      ),

      // ── WESTLIFE (GLOBAL / IRLANDIA) ──
      Artist(
        id: 'artist_westlife',
        name: 'Westlife',
        country: 'Irlandia',
        genres: const ['Boy Band', 'Pop', 'Ballad'],
        imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/a/aa/Westlife_2021_Warner_Music_New_Zealand.png',
        headerImageUrl: 'https://upload.wikimedia.org/wikipedia/commons/a/aa/Westlife_2021_Warner_Music_New_Zealand.png',
        monthlyListeners: '11.890.000 pendengar bulanan',
        bio: 'Grup vokal pop legendaris asal Irlandia dengan 14 single #1 di tangga lagu UK dan dicintai di seluruh dunia lewat hits "My Love", "You Raise Me Up", dan "Beautiful in White".',
        isVerified: true,
        topTracks: [
          Song(id: 'wl_1', title: 'My Love', artist: 'Westlife', album: 'Coast to Coast',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/1d/48/7d/1d487da2-ed7a-3e31-74d6-49cf93b40aeb/mzi.kpnsbult.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=ulOb9gIGGd0',
              duration: const Duration(minutes: 3, seconds: 52),
              lyrics: Song.generateSampleLyrics('My Love')),
          Song(id: 'wl_2', title: 'You Raise Me Up', artist: 'Westlife', album: 'Face to Face',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music122/v4/6b/38/ab/6b38abc7-23a1-a5b1-9fc7-b96740df42e7/888880790033.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=9bxc9hCw45M',
              duration: const Duration(minutes: 4, seconds: 0),
              lyrics: Song.generateSampleLyrics('You Raise Me Up')),
          Song(id: 'wl_3', title: 'Uptown Girl', artist: 'Westlife', album: 'World of Our Own',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/d8/cc/20/d8cc20ec-7ae3-5008-2b79-5448108c74ce/886446674254.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=0fcRa5Z6LmU',
              duration: const Duration(minutes: 3, seconds: 6),
              lyrics: Song.generateSampleLyrics('Uptown Girl')),
          Song(id: 'wl_4', title: 'Fool Again', artist: 'Westlife', album: 'Westlife',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/c7/8a/f6/c78af6d0-3436-dfce-1000-b85e6c7834d7/886443166707.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=H4BB9eGUEaE',
              duration: const Duration(minutes: 3, seconds: 54),
              lyrics: Song.generateSampleLyrics('Fool Again')),
          Song(id: 'wl_5', title: 'If I Let You Go', artist: 'Westlife', album: 'Westlife',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/c7/8a/f6/c78af6d0-3436-dfce-1000-b85e6c7834d7/886443166707.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=7NrQei36fJg',
              duration: const Duration(minutes: 3, seconds: 40),
              lyrics: Song.generateSampleLyrics('If I Let You Go')),
        ],
        albums: const [
          ArtistAlbum(id: 'alb_wl_coasttocoast', title: 'Coast to Coast',
              coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/1d/48/7d/1d487da2-ed7a-3e31-74d6-49cf93b40aeb/mzi.kpnsbult.jpg/600x600bb.jpg',
              releaseYear: '2000', type: 'Album'),
          ArtistAlbum(id: 'alb_wl_facetoface', title: 'Face to Face',
              coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music122/v4/6b/38/ab/6b38abc7-23a1-a5b1-9fc7-b96740df42e7/888880790033.jpg/600x600bb.jpg',
              releaseYear: '2005', type: 'Album'),
          ArtistAlbum(id: 'alb_wl_worldofourown', title: 'World of Our Own',
              coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/d8/cc/20/d8cc20ec-7ae3-5008-2b79-5448108c74ce/886446674254.jpg/600x600bb.jpg',
              releaseYear: '2001', type: 'Album'),
          ArtistAlbum(id: 'alb_wl_westlife', title: 'Westlife',
              coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/c7/8a/f6/c78af6d0-3436-dfce-1000-b85e6c7834d7/886443166707.jpg/600x600bb.jpg',
              releaseYear: '1999', type: 'Album'),
        ],
      ),

      // ── AFGAN (INDONESIA) ──
      Artist(
        id: 'artist_afgan',
        name: 'Afgan',
        country: 'Indonesia',
        genres: const ['Pop', 'R&B', 'Soul'],
        imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/b/b9/Afgan_In_2025.png',
        headerImageUrl: 'https://upload.wikimedia.org/wikipedia/commons/b/b9/Afgan_In_2025.png',
        monthlyListeners: '5.920.000 pendengar bulanan',
        bio: 'Penyanyi pria papan atas Indonesia dengan karakter vokal khas, lesung pipit ikonik, dan sederet karya hits seperti "Jodoh Pasti Bertemu", "Panah Asmara", dan "Heaven".',
        isVerified: true,
        topTracks: [
          Song(id: 'afgan_1', title: 'Jodoh Pasti Bertemu', artist: 'Afgan', album: 'L1ve to Love, Love to L1ve',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/b3/9e/f3/b39ef370-fc50-4c2a-9754-ad29ee4b0d4f/25UMGIM88557.rgb.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=Q2o3-d73_vE',
              duration: const Duration(minutes: 4, seconds: 12),
              lyrics: Song.generateSampleLyrics('Jodoh Pasti Bertemu')),
          Song(id: 'afgan_2', title: 'Heaven', artist: 'Afgan, Isyana Sarasvati, Rendy Pandugo', album: 'Dekade',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/48/1e/cf/481ecf00-7e53-518e-18c3-9d115e25334e/886446965628.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=z_WqHoxRj6E',
              duration: const Duration(minutes: 3, seconds: 40),
              lyrics: Song.generateSampleLyrics('Heaven')),
          Song(id: 'afgan_3', title: 'Panah Asmara', artist: 'Afgan', album: 'The One',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/60/16/16/60161622-d252-8fc4-9c9f-36c34fdc6299/0.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=i6h_a7f6P-w',
              duration: const Duration(minutes: 4, seconds: 32),
              lyrics: Song.generateSampleLyrics('Panah Asmara')),
          Song(id: 'afgan_4', title: 'Sabar', artist: 'Afgan', album: 'L1ve to Love, Love to L1ve',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/b3/9e/f3/b39ef370-fc50-4c2a-9754-ad29ee4b0d4f/25UMGIM88557.rgb.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=GhyLzR2T_H4',
              duration: const Duration(minutes: 4, seconds: 45),
              lyrics: Song.generateSampleLyrics('Sabar')),
          Song(id: 'afgan_5', title: 'Terima Kasih Cinta', artist: 'Afgan', album: 'Confession No.1',
              albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/be/f2/12/bef2125b-0f9d-b965-abff-96cefc508f1d/0.jpg/600x600bb.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=Kj69V1T9k5g',
              duration: const Duration(minutes: 4, seconds: 11),
              lyrics: Song.generateSampleLyrics('Terima Kasih Cinta')),
        ],
        albums: const [
          ArtistAlbum(id: 'alb_afgan_dekade', title: 'Dekade',
              coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/48/1e/cf/481ecf00-7e53-518e-18c3-9d115e25334e/886446965628.jpg/600x600bb.jpg',
              releaseYear: '2018', type: 'Album'),
          ArtistAlbum(id: 'alb_afgan_l1ve', title: 'L1ve to Love, Love to L1ve',
              coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/b3/9e/f3/b39ef370-fc50-4c2a-9754-ad29ee4b0d4f/25UMGIM88557.rgb.jpg/600x600bb.jpg',
              releaseYear: '2013', type: 'Album'),
          ArtistAlbum(id: 'alb_afgan_confession', title: 'Confession No.1',
              coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/be/f2/12/bef2125b-0f9d-b965-abff-96cefc508f1d/0.jpg/600x600bb.jpg',
              releaseYear: '2008', type: 'Album'),
          ArtistAlbum(id: 'alb_afgan_the_one', title: 'The One',
              coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/60/16/16/60161622-d252-8fc4-9c9f-36c34fdc6299/0.jpg/600x600bb.jpg',
              releaseYear: '2010', type: 'Album'),
          ArtistAlbum(id: 'alb_afgan_sides', title: 'Sides',
              coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music113/v4/d3/ff/ac/d3ffacdc-d81c-879b-a9c2-5c601d8cca6d/9781549194757.jpg/600x600bb.jpg',
              releaseYear: '2016', type: 'Album'),
          ArtistAlbum(id: 'alb_afgan_wallflower', title: 'Wallflower',
              coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music114/v4/c2/00/11/c20011ed-99f1-af81-adbe-273c0acd3ba4/194690464010_cover.jpg/600x600bb.jpg',
              releaseYear: '2021', type: 'Album'),
        ],
      ),

      // ── AUDIEN (SCREENSHOTS REFERENCE) ──
      Artist(
        id: 'artist_audien',
        name: 'Audien',
        country: 'Amerika Serikat',
        genres: const ['EDM', 'Progressive House', 'Elektronik'],
        imageUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/18/07/77/1807772b-0e36-0e51-e4ac-f01caadc4b3e/00602547530592.rgb.jpg/1000x1000bb.jpg',
        headerImageUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/18/07/77/1807772b-0e36-0e51-e4ac-f01caadc4b3e/00602547530592.rgb.jpg/1000x1000bb.jpg',
        monthlyListeners: '3.420.000 pendengar bulanan',
        bio: 'Produser musik dan DJ nominasi Grammy asal Amerika Serikat, pelopor melodic progressive house anthemic dunia.',
        isVerified: true,
        topTracks: [
          Song(id: 'audien_1', title: 'Future Fires', artist: 'MEDZ, TRØVES, Audien', album: 'Future Fires',
              albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/786a51241f8c474d2836d55734898115/1000x1000-000000-80-0-0.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=qj8vW295g1U',
              duration: const Duration(minutes: 3, seconds: 18),
              lyrics: Song.generateSampleLyrics('Future Fires')),
          Song(id: 'audien_2', title: 'thinkin bout u', artist: 'Falling North, H4RRIS, Lexi Scatena', album: 'thinkin bout u',
              albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/855b4122d16452292f96cfb4822bc26d/1000x1000-000000-80-0-0.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=7i1ZJ2W8NfQ',
              duration: const Duration(minutes: 3, seconds: 5),
              lyrics: Song.generateSampleLyrics('thinkin bout u')),
          Song(id: 'audien_3', title: 'Something Better', artist: 'Audien ft. Lady A', album: 'Daydreams',
              albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/855b4122d16452292f96cfb4822bc26d/1000x1000-000000-80-0-0.jpg',
              audioUrl: 'https://www.youtube.com/watch?v=7i1ZJ2W8NfQ',
              duration: const Duration(minutes: 3, seconds: 32),
              lyrics: Song.generateSampleLyrics('Something Better')),
        ],
        albums: const [
          ArtistAlbum(id: 'alb_audien_daydreams', title: 'Daydreams',
              coverUrl: 'https://cdn-images.dzcdn.net/images/cover/855b4122d16452292f96cfb4822bc26d/1000x1000-000000-80-0-0.jpg',
              releaseYear: '2015', type: 'EP'),
        ],
      ),
    ];

    return [...baseArtists, ...additionalArtists];
  }

  /// ─────────────────────────────────────────────────────────────────────────
  /// REGIONAL TRENDING HIT TRACKS (GLOBAL, INDONESIA, FILIPINA, THAILAND, MALAYSIA)
  /// ─────────────────────────────────────────────────────────────────────────
  static List<Song> getTrendingByRegion(String regionCode) {
    final allArtists = getComprehensiveArtists();
    Song? findTrack(String artistName, String songTitle) {
      for (final a in allArtists) {
        if (a.name.toLowerCase() == artistName.toLowerCase()) {
          for (final t in a.topTracks) {
            if (t.title.toLowerCase().contains(songTitle.toLowerCase())) return t;
          }
        }
      }
      return null;
    }

    switch (regionCode.toLowerCase()) {
      case 'id':
        return [
          findTrack('Bernadya', 'Satu Bulan') ?? getFeaturedTracks()[11],
          findTrack('Raim Laode', 'Komang') ?? getArtists().first.topTracks.first,
          findTrack('Donne Maula', 'Bercinta Lewat Kata') ?? getFeaturedTracks()[11],
          findTrack('Sal Priadi', 'Gala Bunga Matahari') ?? getFeaturedTracks()[1],
          findTrack('Tulus', 'Hati-Hati di Jalan') ?? getFeaturedTracks()[1],
          findTrack('Sheila On 7', 'Dan...') ?? getFeaturedTracks()[2],
          findTrack('Mahalini', 'Sial') ?? getFeaturedTracks()[18],
          findTrack('Hindia', 'Evaluasi') ?? getFeaturedTracks()[14],
        ];

      case 'ph':
        final list = <Song>[];
        final zack = findTrack('Zack Tabudlo', 'Binibini');
        if (zack != null) list.add(zack);
        final pano = findTrack('Zack Tabudlo', 'Pano');
        if (pano != null) list.add(pano);
        final sb = findTrack('SB19', 'GENTO');
        if (sb != null) list.add(sb);
        final ben = findTrack('Ben&Ben', 'Leaves');
        if (ben != null) list.add(ben);
        final moira = findTrack('Moira Dela Torre', 'Paubaya');
        if (moira != null) list.add(moira);
        final nery = findTrack('Arthur Nery', 'Pagsamo');
        if (nery != null) list.add(nery);
        return list.isNotEmpty ? list : getFeaturedTracks().take(6).toList();

      case 'th':
        final list = <Song>[];
        final jeffDum = findTrack('Jeff Satur', 'Dum Dum');
        if (jeffDum != null) list.add(jeffDum);
        final jeffFade = findTrack('Jeff Satur', 'Fade');
        if (jeffFade != null) list.add(jeffFade);
        final nont = findTrack('NONT TANONT', 'Melt');
        if (nont != null) list.add(nont);
        final bk = findTrack('Billkin', 'Mr. Everything');
        if (bk != null) list.add(bk);
        final bowky = findTrack('BOWKYLION', 'Untold');
        if (bowky != null) list.add(bowky);
        final tmd = findTrack('Three Man Down', 'City Lights');
        if (tmd != null) list.add(tmd);
        return list.isNotEmpty ? list : getFeaturedTracks().take(6).toList();

      case 'my':
        final list = <Song>[];
        final masdo = findTrack('Masdo', 'Dinda');
        if (masdo != null) list.add(masdo);
        final insom = findTrack('Insomniacks', 'Pulang');
        if (insom != null) list.add(insom);
        final faizal = findTrack('Faizal Tahir', 'Santai');
        if (faizal != null) list.add(faizal);
        final siti = findTrack('Siti Nurhaliza', 'Bukan Cinta Biasa');
        if (siti != null) list.add(siti);
        return list.isNotEmpty ? list : getFeaturedTracks().take(4).toList();

      case 'all':
      default:
        return [
          getFeaturedTracks()[0],  // The Weeknd - Blinding Lights
          getFeaturedTracks()[10], // Bruno Mars & Lady Gaga - Die With A Smile
          getFeaturedTracks()[13], // Billie Eilish - BIRDS OF A FEATHER
          findTrack('Sabrina Carpenter', 'Espresso') ?? getFeaturedTracks()[17],
          findTrack('Taylor Swift', 'Cruel Summer') ?? getFeaturedTracks()[12],
          findTrack('Alan Walker', 'Faded') ?? getFeaturedTracks()[4],
          findTrack('Zara Larsson', 'Lush Life') ?? getFeaturedTracks()[8],
          getFeaturedTracks()[4],  // Coldplay - Yellow
        ];
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // KOREAN DRAMA SOUNDTRACKS & PLAYLISTS (Iconic Ballads, CLOY, Goblin, Secret Garden)
  // ─────────────────────────────────────────────────────────────────────────
  static List<Song> getKoreanDramaTracks() {
    return [
      Song(
        id: 'kost_that_woman_bjy',
        title: 'That Woman',
        artist: 'Baek Ji Young',
        album: 'Secret Garden OST Special Edition',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/6b/64/00/6b64006c-843c-3ca5-2601-38290f6b45a6/cover.jpg/1000x1000bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=1F7rK6w-KqE',
        duration: const Duration(minutes: 4, seconds: 32),
        lyrics: Song.generateSampleLyrics('That Woman'),
      ),
      Song(
        id: 'kost_that_man_hb',
        title: 'That Man',
        artist: 'Hyun Bin',
        album: 'Secret Garden OST Special Edition',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/6b/64/00/6b64006c-843c-3ca5-2601-38290f6b45a6/cover.jpg/1000x1000bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=0h5csmD4r2Y',
        duration: const Duration(minutes: 4, seconds: 31),
        lyrics: getHyunBinThatManLyrics(),
      ),
      Song(
        id: 'kost_stay_with_me',
        title: 'Stay With Me',
        artist: 'Chanyeol & Punch',
        album: 'Goblin (Guardian) OST Part 1',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/ce/2d/a2/ce2da283-bc2e-ce71-d610-d029517178c1/191018042456.jpg/1000x1000bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=HF_qE6o-5d8',
        duration: const Duration(minutes: 3, seconds: 12),
        lyrics: Song.generateSampleLyrics('Stay With Me'),
      ),
      Song(
        id: 'kost_beautiful_crush',
        title: 'Beautiful',
        artist: 'Crush',
        album: 'Goblin (Guardian) OST Part 4',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/ce/2d/a2/ce2da283-bc2e-ce71-d610-d029517178c1/191018042456.jpg/1000x1000bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=Wz3gM1k2b9M',
        duration: const Duration(minutes: 3, seconds: 48),
        lyrics: Song.generateSampleLyrics('Beautiful'),
      ),
      Song(
        id: 'kost_first_snow_ailee',
        title: 'I Will Go to You Like the First Snow',
        artist: 'Ailee',
        album: 'Goblin (Guardian) OST Part 9',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/ce/2d/a2/ce2da283-bc2e-ce71-d610-d029517178c1/191018042456.jpg/1000x1000bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=6rS7MDgU0sE',
        duration: const Duration(minutes: 3, seconds: 50),
        lyrics: Song.generateSampleLyrics('I Will Go to You Like the First Snow'),
      ),
      Song(
        id: 'kost_you_are_my_everything_gummy',
        title: 'You Are My Everything',
        artist: 'Gummy',
        album: 'Descendants of the Sun OST Part 4',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music118/v4/64/92/ff/6492ff1c-e722-e3e8-5a02-23c31a787268/8809484114750.jpg/1000x1000bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=To_4e_1K-3Q',
        duration: const Duration(minutes: 4, seconds: 0),
        lyrics: Song.generateSampleLyrics('You Are My Everything'),
      ),
      Song(
        id: 'kost_this_love_davichi',
        title: 'This Love',
        artist: 'Davichi',
        album: 'Descendants of the Sun OST Part 3',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music118/v4/64/92/ff/6492ff1c-e722-e3e8-5a02-23c31a787268/8809484114750.jpg/1000x1000bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=XyzaMpAVtvM',
        duration: const Duration(minutes: 3, seconds: 46),
        lyrics: Song.generateSampleLyrics('This Love'),
      ),
      Song(
        id: 'kost_always_yoonmirae',
        title: 'Always',
        artist: 'Yoon Mi-rae',
        album: 'Descendants of the Sun OST Part 1',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music118/v4/64/92/ff/6492ff1c-e722-e3e8-5a02-23c31a787268/8809484114750.jpg/1000x1000bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=aE0eV2yrr7g',
        duration: const Duration(minutes: 3, seconds: 25),
        lyrics: Song.generateSampleLyrics('Always'),
      ),
      Song(
        id: 'kost_give_you_my_heart_iu',
        title: 'Give You My Heart',
        artist: 'IU',
        album: 'Crash Landing on You OST Part 11',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music124/v4/6c/fb/83/6cfb83d1-447a-7bf3-f725-d162a033da26/195081079366.jpg/1000x1000bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=2f_e_7QkKfs',
        duration: const Duration(minutes: 4, seconds: 41),
        lyrics: Song.generateSampleLyrics('Give You My Heart'),
      ),
      Song(
        id: 'kost_here_i_am_again_yerin',
        title: 'Here I Am Again',
        artist: 'Baek Yerin',
        album: 'Crash Landing on You OST Part 4',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music124/v4/6c/fb/83/6cfb83d1-447a-7bf3-f725-d162a033da26/195081079366.jpg/1000x1000bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=eG_W_46y3d4',
        duration: const Duration(minutes: 3, seconds: 55),
        lyrics: Song.generateSampleLyrics('Here I Am Again'),
      ),
      Song(
        id: 'kost_sunset_10cm',
        title: 'Sunset',
        artist: '10cm',
        album: 'Crash Landing on You OST Part 3',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music124/v4/6c/fb/83/6cfb83d1-447a-7bf3-f725-d162a033da26/195081079366.jpg/1000x1000bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=d_ZtY8u8GvM',
        duration: const Duration(minutes: 3, seconds: 37),
        lyrics: Song.generateSampleLyrics('Sunset'),
      ),
      Song(
        id: 'kost_start_over_gaho',
        title: 'Start Over',
        artist: 'Gaho',
        album: 'Itaewon Class OST Part 2',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music114/v4/f1/b7/fc/f1b7fcbc-a106-96b6-a579-2776c5f49d8c/8809704414590.jpg/1000x1000bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=O0StKlRHVeE',
        duration: const Duration(minutes: 3, seconds: 22),
        lyrics: Song.generateSampleLyrics('Start Over'),
      ),
      Song(
        id: 'kost_sweet_night_v',
        title: 'Sweet Night',
        artist: 'V',
        album: 'Itaewon Class OST Part 12',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music114/v4/f1/b7/fc/f1b7fcbc-a106-96b6-a579-2776c5f49d8c/8809704414590.jpg/1000x1000bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=N5ShoQimivM',
        duration: const Duration(minutes: 3, seconds: 34),
        lyrics: Song.generateSampleLyrics('Sweet Night'),
      ),
      Song(
        id: 'kost_a_poem_titled_you_taeyeon',
        title: 'A Poem Titled You',
        artist: 'Taeyeon',
        album: 'Hotel Del Luna OST Part 3',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music113/v4/7c/fe/eb/7cfeeb79-4b36-7ca6-4d0c-f376f9db1627/8809658314175.jpg/1000x1000bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=wXhXbXmO8zQ',
        duration: const Duration(minutes: 3, seconds: 30),
        lyrics: Song.generateSampleLyrics('A Poem Titled You'),
      ),
      Song(
        id: 'kost_dont_worry_leejuck',
        title: 'Don\'t Worry',
        artist: 'Lee Juck',
        album: 'Reply 1988 OST Part 2',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music114/v4/dc/4d/91/dc4d9136-1e66-db26-f831-7e89e3a39e94/8809484112428.jpg/1000x1000bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=Dic27CXdV60',
        duration: const Duration(minutes: 3, seconds: 51),
        lyrics: Song.generateSampleLyrics('Don\'t Worry'),
      ),
      Song(
        id: 'kost_a_little_girl_hyukoh',
        title: 'A Little Girl',
        artist: 'Hyukoh',
        album: 'Reply 1988 OST Part 3',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music114/v4/dc/4d/91/dc4d9136-1e66-db26-f831-7e89e3a39e94/8809484112428.jpg/1000x1000bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=1dMvF98Zg9s',
        duration: const Duration(minutes: 3, seconds: 50),
        lyrics: Song.generateSampleLyrics('A Little Girl'),
      ),
      Song(
        id: 'kost_love_you_with_all_crush',
        title: 'Love You With All My Heart',
        artist: 'Crush',
        album: 'Queen of Tears OST Part 4',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music122/v4/c3/99/33/c3993309-8db2-2f3c-5353-d142d76579a3/198704093952.jpg/1000x1000bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=J8yR2lG_4oA',
        duration: const Duration(minutes: 4, seconds: 4),
        lyrics: Song.generateSampleLyrics('Love You With All My Heart'),
      ),
      Song(
        id: 'kost_fallin_isaac',
        title: 'Fallin\'',
        artist: 'Isaac Hong',
        album: 'Queen of Tears OST Part 2',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music122/v4/c3/99/33/c3993309-8db2-2f3c-5353-d142d76579a3/198704093952.jpg/1000x1000bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=0h5csmD4r2Y',
        duration: const Duration(minutes: 4, seconds: 5),
        lyrics: Song.generateSampleLyrics('Fallin\''),
      ),
      Song(
        id: 'kost_cant_get_over_paul',
        title: 'Can\'t Get Over You',
        artist: 'Paul Kim',
        album: 'Queen of Tears OST Part 3',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music122/v4/c3/99/33/c3993309-8db2-2f3c-5353-d142d76579a3/198704093952.jpg/1000x1000bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=sO7z8V5-r7M',
        duration: const Duration(minutes: 3, seconds: 48),
        lyrics: Song.generateSampleLyrics('Can\'t Get Over You'),
      ),
      Song(
        id: 'kost_hold_me_back_heize',
        title: 'Hold Me Back',
        artist: 'Heize',
        album: 'Queen of Tears OST Part 1',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music122/v4/c3/99/33/c3993309-8db2-2f3c-5353-d142d76579a3/198704093952.jpg/1000x1000bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=jW2_vF-nO6E',
        duration: const Duration(minutes: 3, seconds: 52),
        lyrics: Song.generateSampleLyrics('Hold Me Back'),
      ),
      Song(
        id: 'kost_done_for_me_punch',
        title: 'Done For Me',
        artist: 'Punch',
        album: 'Hotel Del Luna OST Part 12',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music113/v4/7c/fe/eb/7cfeeb79-4b36-7ca6-4d0c-f376f9db1627/8809658314175.jpg/1000x1000bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=5U0xJkOqC_E',
        duration: const Duration(minutes: 3, seconds: 42),
        lyrics: Song.generateSampleLyrics('Done For Me'),
      ),
      Song(
        id: 'kost_lean_on_me_10cm',
        title: 'Lean On Me',
        artist: '10cm',
        album: 'Hotel Del Luna OST Part 2',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music113/v4/7c/fe/eb/7cfeeb79-4b36-7ca6-4d0c-f376f9db1627/8809658314175.jpg/1000x1000bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=kYv_8Rsm36A',
        duration: const Duration(minutes: 3, seconds: 38),
        lyrics: Song.generateSampleLyrics('Lean On Me'),
      ),
      Song(
        id: 'kost_everytime_chen_punch',
        title: 'Everytime',
        artist: 'Chen & Punch',
        album: 'Descendants of the Sun OST Part 2',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music118/v4/64/92/ff/6492ff1c-e722-e3e8-5a02-23c31a787268/8809484114750.jpg/1000x1000bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=fTc5tuET6_U',
        duration: const Duration(minutes: 3, seconds: 8),
        lyrics: Song.generateSampleLyrics('Everytime'),
      ),
      Song(
        id: 'kost_youth_kimfeel',
        title: 'Youth',
        artist: 'Kim Feel',
        album: 'Reply 1988 OST Part 1',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music114/v4/dc/4d/91/dc4d9136-1e66-db26-f831-7e89e3a39e94/8809484112428.jpg/1000x1000bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=0hW9L2hKz5Y',
        duration: const Duration(minutes: 4, seconds: 28),
        lyrics: Song.generateSampleLyrics('Youth'),
      ),
      Song(
        id: 'kost_why_do_we_korean',
        title: 'Why Do We (Korean Ver.)',
        artist: 'DMEANOR',
        album: 'Are You Human? OST Part 8',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/93/fc/3f/93fc3fd2-c05e-c461-a197-d06aaf709a96/191953013459.jpg/1000x1000bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=IffYFYj-aO4',
        duration: const Duration(minutes: 4, seconds: 14),
        lyrics: Song.generateSampleLyrics('Why Do We (Korean Ver.)'),
      ),
      Song(
        id: 'kost_why_do_we_english',
        title: 'Why Do We (English Ver.)',
        artist: 'DMEANOR',
        album: 'Are You Human? OST Part 8',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/93/fc/3f/93fc3fd2-c05e-c461-a197-d06aaf709a96/191953013459.jpg/1000x1000bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=5wExaQidIU8',
        duration: const Duration(minutes: 4, seconds: 14),
        lyrics: Song.generateSampleLyrics('Why Do We (English Ver.)'),
      ),
      Song(
        id: 'kost_dmeanor_stay_there',
        title: 'Stay There',
        artist: 'DMEANOR',
        album: 'Voice 2 OST Part 4',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/4a/60/0b/4a600b74-3236-a67b-11f8-08571cf31ae9/8809623750017.jpg/1000x1000bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=1Tgt0-0HIxQ',
        duration: const Duration(minutes: 3, seconds: 53),
        lyrics: Song.generateSampleLyrics('Stay There'),
      ),
      Song(
        id: 'kost_dmeanor_stay_there_inst',
        title: 'Stay There (Inst.)',
        artist: 'DMEANOR',
        album: 'Voice 2 OST Part 4',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/4a/60/0b/4a600b74-3236-a67b-11f8-08571cf31ae9/8809623750017.jpg/1000x1000bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=oauwnaiXHb8',
        duration: const Duration(minutes: 3, seconds: 53),
        lyrics: Song.generateSampleLyrics('Instrumental'),
      ),
    ];
  }

  static List<Playlist> getKoreanDramaPlaylists() {
    final kTracks = getKoreanDramaTracks();
    return [
      Playlist(
        id: 'pl_kost_secret_garden',
        title: 'Secret Garden OST Special Edition',
        subtitle: 'Baek Ji Young, Hyun Bin, 4MEN & Shin Yong Jae',
        coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/6b/64/00/6b64006c-843c-3ca5-2601-38290f6b45a6/cover.jpg/1000x1000bb.jpg',
        songs: [kTracks[0], kTracks[1], kTracks[17], kTracks[18], kTracks[2], kTracks[3], kTracks[4], kTracks[5], kTracks[8], kTracks[9], kTracks[13], kTracks[16]],
      ),
      Playlist(
        id: 'pl_kost_goblin',
        title: 'Goblin (Guardian) Complete OST',
        subtitle: 'Chanyeol, Punch, Crush, Ailee & Lasse Lindh',
        coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/ce/2d/a2/ce2da283-bc2e-ce71-d610-d029517178c1/191018042456.jpg/1000x1000bb.jpg',
        songs: [kTracks[2], kTracks[3], kTracks[4], kTracks[19], kTracks[0], kTracks[1], kTracks[5], kTracks[6], kTracks[8], kTracks[9], kTracks[13], kTracks[16]],
      ),
      Playlist(
        id: 'pl_kost_descendants',
        title: 'Descendants of the Sun Full OST',
        subtitle: 'Gummy, Davichi, Yoon Mi-rae, Chen & Punch',
        coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music118/v4/64/92/ff/6492ff1c-e722-e3e8-5a02-23c31a787268/8809484114750.jpg/1000x1000bb.jpg',
        songs: [kTracks[5], kTracks[6], kTracks[7], kTracks[22], kTracks[2], kTracks[3], kTracks[8], kTracks[9], kTracks[0], kTracks[1], kTracks[11], kTracks[12]],
      ),
      Playlist(
        id: 'pl_kost_cloy',
        title: 'Crash Landing on You Full OST',
        subtitle: 'IU, Baek Yerin, 10cm, Yoon Mi-rae & Crush',
        coverUrl: 'https://cdn-images.dzcdn.net/images/cover/73cf2b46ff8aa6c8a94c6a9adcc17325/1000x1000-000000-80-0-0.jpg',
        songs: [kTracks[8], kTracks[9], kTracks[10], kTracks[16], kTracks[0], kTracks[1], kTracks[2], kTracks[5], kTracks[13], kTracks[19], kTracks[3], kTracks[4]],
      ),
      Playlist(
        id: 'pl_kost_itaewon',
        title: 'Itaewon Class Official Soundtrack',
        subtitle: 'Gaho, BTS V, Ha Hyun Woo & Sondia',
        coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music114/v4/f1/b7/fc/f1b7fcbc-a106-96b6-a579-2776c5f49d8c/8809704414590.jpg/1000x1000bb.jpg',
        songs: [kTracks[11], kTracks[12], kTracks[2], kTracks[3], kTracks[5], kTracks[8], kTracks[0], kTracks[1], kTracks[14], kTracks[15], kTracks[16], kTracks[22]],
      ),
      Playlist(
        id: 'pl_kost_reply1988',
        title: 'Reply 1988 Nostalgia OST',
        subtitle: 'Lee Juck, Hyukoh, Kim Feel & Park Bo Gum',
        coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music114/v4/dc/4d/91/dc4d9136-1e66-db26-f831-7e89e3a39e94/8809484112428.jpg/1000x1000bb.jpg',
        songs: [kTracks[14], kTracks[15], kTracks[23], kTracks[0], kTracks[1], kTracks[2], kTracks[3], kTracks[4], kTracks[8], kTracks[9], kTracks[11], kTracks[13]],
      ),
    ];
  }

  static List<Playlist> getJPopPlaylists() {
    final cat = getBrowseCategories().firstWhere(
      (c) => c.id == 'jpop',
      orElse: () => getBrowseCategories().first,
    );
    final data = getCategoryDetails(cat);
    final list = <Playlist>[];
    if (data.heroPlaylist != null) list.add(data.heroPlaylist!);
    for (final sec in data.sections) {
      list.addAll(sec.playlists);
    }
    return list;
  }

  static List<Playlist> getMusikIndonesiaPlaylists() {
    final cat = getBrowseCategories().firstWhere(
      (c) => c.id == 'musik_indonesia',
      orElse: () => getBrowseCategories().first,
    );
    final data = getCategoryDetails(cat);
    final list = <Playlist>[];
    if (data.heroPlaylist != null) list.add(data.heroPlaylist!);
    for (final sec in data.sections) {
      list.addAll(sec.playlists);
    }
    return list;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // K-POP TRACKS (18 Lagu Lengkap)
  // ─────────────────────────────────────────────────────────────────────────
  static List<Song> getKPopTracks() {
    return [
      Song(
        id: 'kpop_bts_dynamite',
        title: 'Dynamite',
        artist: 'BTS',
        album: 'BE',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/c3/8e/3c/c38e3cb9-40ea-920f-a496-5b91cf84ee71/195497495574.jpg/600x600bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=gdZLi9oWNZg',
        duration: const Duration(minutes: 3, seconds: 19),
        lyrics: Song.generateSampleLyrics('Dynamite'),
      ),
      Song(
        id: 'kpop_bts_butter',
        title: 'Butter',
        artist: 'BTS',
        album: 'Butter - Single',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/58/04/b1/5804b123-640c-3962-d278-831631ae7421/196006456071.jpg/600x600bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=WMweEpGlu_U',
        duration: const Duration(minutes: 2, seconds: 44),
        lyrics: Song.generateSampleLyrics('Butter'),
      ),
      Song(
        id: 'kpop_bts_boywithluv',
        title: 'Boy With Luv',
        artist: 'BTS & Halsey',
        album: 'Map of the Soul: Persona',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/58/04/b1/5804b123-640c-3962-d278-831631ae7421/196006456071.jpg/600x600bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=XsX3ATc3FbA',
        duration: const Duration(minutes: 3, seconds: 49),
        lyrics: Song.generateSampleLyrics('Boy With Luv'),
      ),
      Song(
        id: 'kpop_bp_howyoulike',
        title: 'How You Like That',
        artist: 'BLACKPINK',
        album: 'THE ALBUM',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/b4/d2/54/b4d2542a-a92c-6ca7-8db1-1d54eb53ef1d/20UMGIM78945.rgb.jpg/600x600bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=ioNng23DkIM',
        duration: const Duration(minutes: 3, seconds: 1),
        lyrics: Song.generateSampleLyrics('How You Like That'),
      ),
      Song(
        id: 'kpop_bp_pinkvenom',
        title: 'Pink Venom',
        artist: 'BLACKPINK',
        album: 'BORN PINK',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/b4/d2/54/b4d2542a-a92c-6ca7-8db1-1d54eb53ef1d/20UMGIM78945.rgb.jpg/600x600bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=gQlMMD8auMs',
        duration: const Duration(minutes: 3, seconds: 6),
        lyrics: Song.generateSampleLyrics('Pink Venom'),
      ),
      Song(
        id: 'kpop_bp_ddu',
        title: 'DDU-DU DDU-DU',
        artist: 'BLACKPINK',
        album: 'SQUARE UP',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/b4/d2/54/b4d2542a-a92c-6ca7-8db1-1d54eb53ef1d/20UMGIM78945.rgb.jpg/600x600bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=IHNzOHi8sPQ',
        duration: const Duration(minutes: 3, seconds: 29),
        lyrics: Song.generateSampleLyrics('DDU-DU DDU-DU'),
      ),
      Song(
        id: 'kpop_nj_hypeboy',
        title: 'Hype Boy',
        artist: 'NewJeans',
        album: 'New Jeans 1st EP',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music112/v4/55/7c/49/557c493c-cf80-e835-f483-3eb41a5fe7aa/196922067341_Cover.jpg/600x600bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=11cta61Wi0g',
        duration: const Duration(minutes: 2, seconds: 59),
        lyrics: Song.generateSampleLyrics('Hype Boy'),
      ),
      Song(
        id: 'kpop_nj_supershy',
        title: 'Super Shy',
        artist: 'NewJeans',
        album: 'Get Up - EP',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/b1/83/88/b183884d-2e11-cfcf-089c-5e9218d6e902/196922485121_Cover.jpg/600x600bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=ArmDp-zijuc',
        duration: const Duration(minutes: 2, seconds: 34),
        lyrics: Song.generateSampleLyrics('Super Shy'),
      ),
      Song(
        id: 'kpop_nj_ditto',
        title: 'Ditto',
        artist: 'NewJeans',
        album: 'OMG - Single',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/b1/83/88/b183884d-2e11-cfcf-089c-5e9218d6e902/196922485121_Cover.jpg/600x600bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=pSUydWEqKwE',
        duration: const Duration(minutes: 3, seconds: 5),
        lyrics: Song.generateSampleLyrics('Ditto'),
      ),
      Song(
        id: 'kpop_nj_omg',
        title: 'OMG',
        artist: 'NewJeans',
        album: 'OMG - Single',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music112/v4/55/7c/49/557c493c-cf80-e835-f483-3eb41a5fe7aa/196922067341_Cover.jpg/600x600bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=sVTy_wmn5SU',
        duration: const Duration(minutes: 3, seconds: 32),
        lyrics: Song.generateSampleLyrics('OMG'),
      ),
      Song(
        id: 'kpop_day6_youwere',
        title: 'You Were Beautiful',
        artist: 'DAY6',
        album: 'Sunrise',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music128/v4/28/6e/b7/286eb792-74d4-9d5f-dcf8-07f7c46f6c99/Cover_DAY6.jpg/600x600bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=BS7tz2rAfdI',
        duration: const Duration(minutes: 4, seconds: 43),
        lyrics: Song.generateSampleLyrics('You Were Beautiful'),
      ),
      Song(
        id: 'kpop_day6_timeofourlife',
        title: 'Time of Our Life',
        artist: 'DAY6',
        album: 'The Book of Us: Gravity',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music128/v4/28/6e/b7/286eb792-74d4-9d5f-dcf8-07f7c46f6c99/Cover_DAY6.jpg/600x600bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=vnS_6zGdeCw',
        duration: const Duration(minutes: 3, seconds: 18),
        lyrics: Song.generateSampleLyrics('Time of Our Life'),
      ),
      Song(
        id: 'kpop_twice_whatislove',
        title: 'What is Love?',
        artist: 'TWICE',
        album: 'What is Love?',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/58/04/b1/5804b123-640c-3962-d278-831631ae7421/196006456071.jpg/600x600bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=i0p1bmr0EmE',
        duration: const Duration(minutes: 3, seconds: 28),
        lyrics: Song.generateSampleLyrics('What is Love?'),
      ),
      Song(
        id: 'kpop_ive_iam',
        title: 'I AM',
        artist: 'IVE',
        album: 'I\'ve IVE',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/b1/83/88/b183884d-2e11-cfcf-089c-5e9218d6e902/196922485121_Cover.jpg/600x600bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=6ZUIwj3FgUY',
        duration: const Duration(minutes: 3, seconds: 3),
        lyrics: Song.generateSampleLyrics('I AM'),
      ),
      Song(
        id: 'kpop_lesserafim_perfectnight',
        title: 'Perfect Night',
        artist: 'LE SSERAFIM',
        album: 'Perfect Night - Single',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music112/v4/55/7c/49/557c493c-cf80-e835-f483-3eb41a5fe7aa/196922067341_Cover.jpg/600x600bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=hLvWy2b857I',
        duration: const Duration(minutes: 2, seconds: 39),
        lyrics: Song.generateSampleLyrics('Perfect Night'),
      ),
      Song(
        id: 'kpop_skz_godsmenu',
        title: 'God\'s Menu',
        artist: 'Stray Kids',
        album: 'GO LIVE',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music128/v4/28/6e/b7/286eb792-74d4-9d5f-dcf8-07f7c46f6c99/Cover_DAY6.jpg/600x600bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=TQTlCHxyuu8',
        duration: const Duration(minutes: 2, seconds: 48),
        lyrics: Song.generateSampleLyrics('God\'s Menu'),
      ),
      Song(
        id: 'kpop_aespa_supernova',
        title: 'Supernova',
        artist: 'aespa',
        album: 'Armageddon',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/b1/83/88/b183884d-2e11-cfcf-089c-5e9218d6e902/196922485121_Cover.jpg/600x600bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=phuiiNCxRMg',
        duration: const Duration(minutes: 2, seconds: 58),
        lyrics: Song.generateSampleLyrics('Supernova'),
      ),
      Song(
        id: 'kpop_iu_celebrity',
        title: 'Celebrity',
        artist: 'IU',
        album: 'LILAC',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music124/v4/6c/fb/83/6cfb83d1-447a-7bf3-f725-d162a033da26/195081079366.jpg/1000x1000bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=0-q1K8530JF',
        duration: const Duration(minutes: 3, seconds: 15),
        lyrics: Song.generateSampleLyrics('Celebrity'),
      ),
    ];
  }

  // ─────────────────────────────────────────────────────────────────────────
  // JAPANESE & ANIME TRACKS (16 Lagu Lengkap)
  // ─────────────────────────────────────────────────────────────────────────
  static List<Song> getJPopTracks() {
    return [
      Song(
        id: 'jpop_yoasobi_idol',
        title: 'Idol',
        artist: 'YOASOBI',
        album: 'Idol - Single (Oshi no Ko)',
        albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/c028acc15f911c6ca3ff821abbb64aa3/1000x1000-000000-80-0-0.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=ZRtdQ81jPUQ',
        duration: const Duration(minutes: 3, seconds: 33),
        lyrics: null,
      ),
      Song(
        id: 'jpop_yoasobi_yorunikakeru',
        title: 'Yoru ni Kakeru',
        artist: 'YOASOBI',
        album: 'THE BOOK',
        albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/c028acc15f911c6ca3ff821abbb64aa3/1000x1000-000000-80-0-0.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=by4SYYWl728',
        duration: const Duration(minutes: 4, seconds: 21),
        lyrics: null,
      ),
      Song(
        id: 'jpop_kenshi_kickback',
        title: 'KICK BACK',
        artist: 'Kenshi Yonezu',
        album: 'Chainsaw Man OP Single',
        albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/219b98615e49c9df44727bc3d9d57c8e/1000x1000-000000-80-0-0.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=M2cckDmNLMI',
        duration: const Duration(minutes: 3, seconds: 13),
        lyrics: null,
      ),
      Song(
        id: 'jpop_kenshi_lemon',
        title: 'Lemon',
        artist: 'Kenshi Yonezu',
        album: 'Lemon - Single',
        albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/bfa6c8d10b91e7790b05b4b1a77484df/1000x1000-000000-80-0-0.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=SX_ViT4Ra7k',
        duration: const Duration(minutes: 4, seconds: 15),
        lyrics: Song.generateSampleLyrics('Lemon'),
      ),
      Song(
        id: 'jpop_kenshi_peacesign',
        title: 'Peace Sign',
        artist: 'Kenshi Yonezu',
        album: 'BOOTLEG (My Hero Academia OP)',
        albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/2fffa92823652199fa7e366feff98418/1000x1000-000000-80-0-0.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=9aJVYmnMrUQ',
        duration: const Duration(minutes: 3, seconds: 58),
        lyrics: Song.generateSampleLyrics('Peace Sign'),
      ),
      Song(
        id: 'jpop_utada_onelastkiss',
        title: 'One Last Kiss',
        artist: 'Utada Hikaru',
        album: 'BAD MODE (Evangelion 3.0+1.0)',
        albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/edeece1b61c16ce66ce8d74ca9a16fef/1000x1000-000000-80-0-0.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=0Uhh62MUEic',
        duration: const Duration(minutes: 4, seconds: 12),
        lyrics: Song.generateSampleLyrics('One Last Kiss'),
      ),
      Song(
        id: 'jpop_utada_firstlove',
        title: 'First Love',
        artist: 'Utada Hikaru',
        album: 'First Love',
        albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/e00b84c8a58ecadfc97f54c9657f2022/1000x1000-000000-80-0-0.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=o1sUaVJUeB0',
        duration: const Duration(minutes: 4, seconds: 17),
        lyrics: Song.generateSampleLyrics('First Love'),
      ),
      Song(
        id: 'jpop_yuuri_betelgeuse',
        title: 'Betelgeuse',
        artist: 'Yuuri',
        album: 'Ichi',
        albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/6e2df894a73756b185cf83d25d487295/1000x1000-000000-80-0-0.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=cbqvxDTLM84',
        duration: const Duration(minutes: 4, seconds: 12),
        lyrics: Song.generateSampleLyrics('Betelgeuse'),
      ),
      Song(
        id: 'jpop_yuuri_driedflower',
        title: 'Dried Flower',
        artist: 'Yuuri',
        album: 'Ichi',
        albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/6e2df894a73756b185cf83d25d487295/1000x1000-000000-80-0-0.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=kzZ6KXDM1RI',
        duration: const Duration(minutes: 4, seconds: 46),
        lyrics: Song.generateSampleLyrics('Dried Flower'),
      ),
      Song(
        id: 'jpop_yuuri_curtaincall',
        title: 'Curtain Call',
        artist: 'Yuuri',
        album: 'Curtain Call (My Hero Academia OP)',
        albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/3547285a86d27fc69124be3bf8357f86/1000x1000-000000-80-0-0.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=6_3H-i07R4Q',
        duration: const Duration(minutes: 3, seconds: 25),
        lyrics: Song.generateSampleLyrics('Curtain Call'),
      ),
      Song(
        id: 'jpop_lisa_gurenge',
        title: 'Gurenge',
        artist: 'LiSA',
        album: 'Demon Slayer OP Single',
        albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/b7b2505ea5bfdfd1e39fc7347904fc49/1000x1000-000000-80-0-0.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=CwkzK-F0Y00',
        duration: const Duration(minutes: 3, seconds: 58),
        lyrics: Song.generateSampleLyrics('Gurenge'),
      ),
      Song(
        id: 'jpop_lisa_homura',
        title: 'Homura',
        artist: 'LiSA',
        album: 'Demon Slayer Mugen Train OST',
        albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/99fa774e1e8da61bc02f23ea73587002/1000x1000-000000-80-0-0.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=4DxL6IKmNx4',
        duration: const Duration(minutes: 4, seconds: 35),
        lyrics: Song.generateSampleLyrics('Homura'),
      ),
      Song(
        id: 'jpop_eve_kaikaikitan',
        title: 'Kaikai Kitan',
        artist: 'Eve',
        album: 'Kaikai Kitan / Jujutsu Kaisen OP',
        albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/6c026d36e2f42a6c8b9db77b318bf973/1000x1000-000000-80-0-0.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=1tk1pqWROys',
        duration: const Duration(minutes: 3, seconds: 40),
        lyrics: Song.generateSampleLyrics('Kaikai Kitan'),
      ),
      Song(
        id: 'jpop_ado_usseewa',
        title: 'Usseewa',
        artist: 'Ado',
        album: 'Kyougen',
        albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/8627b0b8c66e288d45129c5421516e88/1000x1000-000000-80-0-0.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=Qp3b-RXtz4w',
        duration: const Duration(minutes: 3, seconds: 24),
        lyrics: Song.generateSampleLyrics('Usseewa'),
      ),
      Song(
        id: 'jpop_ado_newgenesis',
        title: 'New Genesis',
        artist: 'Ado',
        album: 'Uta no Uta: ONE PIECE FILM RED',
        albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/a8564dc1e8783d21c3b1e95fc88f6155/1000x1000-000000-80-0-0.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=1FliVTcX8bQ',
        duration: const Duration(minutes: 3, seconds: 46),
        lyrics: Song.generateSampleLyrics('New Genesis'),
      ),
      Song(
        id: 'jpop_radwimps_sparkle',
        title: 'Sparkle',
        artist: 'RADWIMPS',
        album: 'Your Name. (Kimi no Na wa)',
        albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/78627c2f689fcf2908f51a4f00fe325c/1000x1000-000000-80-0-0.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=e3Ze62AL9r0',
        duration: const Duration(minutes: 6, seconds: 50),
        lyrics: Song.generateSampleLyrics('Sparkle'),
      ),
      Song(
        id: 'jpop_higedan_pretender',
        title: 'Pretender',
        artist: 'Official HIGE DANDISM',
        album: 'Traveler',
        albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/3bfd12eefc7f2178ff0b80f156cb8b3f/1000x1000-000000-80-0-0.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=TQ8WlA2GXbk',
        duration: const Duration(minutes: 5, seconds: 27),
        lyrics: Song.generateSampleLyrics('Pretender'),
      ),
      Song(
        id: 'jpop_higedan_mixednuts',
        title: 'Mixed Nuts',
        artist: 'Official HIGE DANDISM',
        album: 'Spy x Family OP Single',
        albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/c9f37c3525cb48df13f73967858c14a2/1000x1000-000000-80-0-0.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=CbH2F0kXgTY',
        duration: const Duration(minutes: 3, seconds: 33),
        lyrics: Song.generateSampleLyrics('Mixed Nuts'),
      ),
      Song(
        id: 'jpop_fujii_shinunoga',
        title: 'Shinunoga E-Wa',
        artist: 'Fujii Kaze',
        album: 'HELP EVER HURT NEVER',
        albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/d1c322b7a9f997cb0f19e4ffc18aa002/1000x1000-000000-80-0-0.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=dusrGkPrcwQ',
        duration: const Duration(minutes: 3, seconds: 5),
        lyrics: Song.generateSampleLyrics('Shinunoga E-Wa'),
      ),
      Song(
        id: 'jpop_kinggnu_specialz',
        title: 'SPECIALZ',
        artist: 'King Gnu',
        album: 'THE GREATEST UNKNOWN (Jujutsu Kaisen OP)',
        albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/bfdf1d619aeefafb265dbb43f1190db0/1000x1000-000000-80-0-0.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=fhzKLBZJC3w',
        duration: const Duration(minutes: 3, seconds: 57),
        lyrics: Song.generateSampleLyrics('SPECIALZ'),
      ),
      Song(
        id: 'jpop_vaundy_kaiju',
        title: 'Kaiju no Hanauta',
        artist: 'Vaundy',
        album: 'strobo',
        albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/a69c0d9a6ae49c95ff4c3bbf5bf37eb7/1000x1000-000000-80-0-0.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=7HgJIAUtICU',
        duration: const Duration(minutes: 3, seconds: 43),
        lyrics: Song.generateSampleLyrics('Kaiju no Hanauta'),
      ),
      Song(
        id: 'jpop_aimyon_marigold',
        title: 'Marigold',
        artist: 'Aimyon',
        album: 'Momoiro no Hoho',
        albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/11cf6ebc7f9996b7975f7ecfc367f0f6/1000x1000-000000-80-0-0.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=0xSiBpUdW4E',
        duration: const Duration(minutes: 5, seconds: 6),
        lyrics: Song.generateSampleLyrics('Marigold'),
      ),
    ];
  }

  // ─────────────────────────────────────────────────────────────────────────
  // INDIE TRACKS (16 Lagu Lengkap)
  // ─────────────────────────────────────────────────────────────────────────
  static List<Song> getIndieTracks() {
    return [
      Song(
        id: 'indie_hindia_evaluasi',
        title: 'Evaluasi',
        artist: 'Hindia',
        album: 'Menari Dengan Bayangan',
        albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/23cc662ac90d414741c26754e0105d9d/1000x1000-000000-80-0-0.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=cWrSjCZ5AeE',
        duration: const Duration(minutes: 3, seconds: 24),
        lyrics: Song.generateSampleLyrics('Evaluasi'),
      ),
      Song(
        id: 'indie_hindia_rumah',
        title: 'Rumah Ke Rumah',
        artist: 'Hindia',
        album: 'Menari Dengan Bayangan',
        albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/23cc662ac90d414741c26754e0105d9d/1000x1000-000000-80-0-0.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=680wT4b3WwE',
        duration: const Duration(minutes: 4, seconds: 37),
        lyrics: Song.generateSampleLyrics('Rumah Ke Rumah'),
      ),
      Song(
        id: 'indie_sal_gala',
        title: 'Gala Bunga Matahari',
        artist: 'Sal Priadi',
        album: 'MARKERS AND SUCH PENS FLASHDISKS',
        albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/4333671752b04c86ecf1f33f6756e43f/1000x1000-000000-80-0-0.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=0zKkJqJ1g1Y',
        duration: const Duration(minutes: 3, seconds: 50),
        lyrics: Song.generateSampleLyrics('Gala Bunga Matahari'),
      ),
      Song(
        id: 'indie_sal_planet',
        title: 'Dari Planet Lain',
        artist: 'Sal Priadi',
        album: 'MARKERS AND SUCH PENS FLASHDISKS',
        albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/4333671752b04c86ecf1f33f6756e43f/1000x1000-000000-80-0-0.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=kYv_8Rsm36A',
        duration: const Duration(minutes: 3, seconds: 4),
        lyrics: Song.generateSampleLyrics('Dari Planet Lain'),
      ),
      Song(
        id: 'indie_nadin_rayuan',
        title: 'Rayuan Perempuan Gila',
        artist: 'Nadin Amizah',
        album: 'Untuk Dunia, Cinta, dan Kotornya',
        albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/b3f6ebcbf6ecce1d1162fa9c908c6b75/1000x1000-000000-80-0-0.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=k4T0hU7Wf94',
        duration: const Duration(minutes: 4, seconds: 50),
        lyrics: Song.generateSampleLyrics('Rayuan Perempuan Gila'),
      ),
      Song(
        id: 'indie_nadin_bertaut',
        title: 'Bertaut',
        artist: 'Nadin Amizah',
        album: 'Selamat Ulang Tahun',
        albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/77b8cfd84d09fc088fa23dc234c0e64c/1000x1000-000000-80-0-0.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=0k5L1y_z41c',
        duration: const Duration(minutes: 5, seconds: 15),
        lyrics: Song.generateSampleLyrics('Bertaut'),
      ),
      Song(
        id: 'indie_pam_tothebone',
        title: 'To the Bone',
        artist: 'Pamungkas',
        album: 'Flying Solo',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/f4/42/c7/f442c726-f2a1-c045-829e-45f33f2fe1d0/3615939061533.png/600x600bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=oIYWenB637c',
        duration: const Duration(minutes: 5, seconds: 44),
        lyrics: Song.generateSampleLyrics('To the Bone'),
      ),
      Song(
        id: 'indie_pam_kenangan',
        title: 'Kenangan Manis',
        artist: 'Pamungkas',
        album: 'Flying Solo',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/f4/42/c7/f442c726-f2a1-c045-829e-45f33f2fe1d0/3615939061533.png/600x600bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=sI9W1218Z5U',
        duration: const Duration(minutes: 3, seconds: 27),
        lyrics: Song.generateSampleLyrics('Kenangan Manis'),
      ),
      Song(
        id: 'indie_fourtwnty_zonanyaman',
        title: 'Zona Nyaman',
        artist: 'Fourtwnty',
        album: 'Ego & Fungsi Otak',
        albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/23cc662ac90d414741c26754e0105d9d/1000x1000-000000-80-0-0.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=wsGVwT1P3b8',
        duration: const Duration(minutes: 4, seconds: 17),
        lyrics: Song.generateSampleLyrics('Zona Nyaman'),
      ),
      Song(
        id: 'indie_realityclub_anything',
        title: 'Anything You Want',
        artist: 'Reality Club',
        album: 'Reality Club Presents...',
        albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/ea2ee495e17ab155bdcdac0fe75cf513/1000x1000-000000-80-0-0.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=3-M9X3Uv4aA',
        duration: const Duration(minutes: 3, seconds: 48),
        lyrics: Song.generateSampleLyrics('Anything You Want'),
      ),
      Song(
        id: 'indie_danilla_adadisana',
        title: 'Ada Di Sana',
        artist: 'Danilla',
        album: 'Telisik',
        albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/b3f6ebcbf6ecce1d1162fa9c908c6b75/1000x1000-000000-80-0-0.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=f9vT8q_y8h0',
        duration: const Duration(minutes: 3, seconds: 35),
        lyrics: Song.generateSampleLyrics('Ada Di Sana'),
      ),
      Song(
        id: 'indie_donne_bercinta',
        title: 'Bercinta Lewat Kata',
        artist: 'Donne Maula',
        album: 'Bercinta Lewat Kata',
        albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/d1f885f81015c7e11bbdc9e20a4422bb/1000x1000-000000-80-0-0.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=x8lG_zU5V8o',
        duration: const Duration(minutes: 3, seconds: 55),
        lyrics: Song.generateSampleLyrics('Bercinta Lewat Kata'),
      ),
      Song(
        id: 'indie_feast_peradaban',
        title: 'Peradaban',
        artist: '.Feast',
        album: 'Beberapa Orang Memaafkan',
        albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/23cc662ac90d414741c26754e0105d9d/1000x1000-000000-80-0-0.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=QeM_346xN3Y',
        duration: const Duration(minutes: 5, seconds: 40),
        lyrics: Song.generateSampleLyrics('Peradaban'),
      ),
      Song(
        id: 'indie_barasuara_sendu',
        title: 'Sendu Melagu',
        artist: 'Barasuara',
        album: 'Taifun',
        albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/4333671752b04c86ecf1f33f6756e43f/1000x1000-000000-80-0-0.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=Kz4M0v9Q3mU',
        duration: const Duration(minutes: 4, seconds: 20),
        lyrics: Song.generateSampleLyrics('Sendu Melagu'),
      ),
      Song(
        id: 'indie_erk_sebelahmata',
        title: 'Sebelah Mata',
        artist: 'Efek Rumah Kaca',
        album: 'Efek Rumah Kaca',
        albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/77b8cfd84d09fc088fa23dc234c0e64c/1000x1000-000000-80-0-0.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=3-M9X3Uv4aA',
        duration: const Duration(minutes: 4, seconds: 30),
        lyrics: Song.generateSampleLyrics('Sebelah Mata'),
      ),
      Song(
        id: 'indie_fiersa_celengan',
        title: 'Celengan Rindu',
        artist: 'Fiersa Besari',
        album: 'Tempat Aku Pulang',
        albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/ea2ee495e17ab155bdcdac0fe75cf513/1000x1000-000000-80-0-0.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=GqK9J2b_7h0',
        duration: const Duration(minutes: 3, seconds: 45),
        lyrics: Song.generateSampleLyrics('Celengan Rindu'),
      ),
    ];
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SLEEP & RELAXATION TRACKS (12 Lagu Lengkap)
  // ─────────────────────────────────────────────────────────────────────────
  static List<Song> getSleepTracks() {
    return [
      Song(
        id: 'sleep_rain_gentle',
        title: 'Hujan Lembut Pengantar Lelap',
        artist: 'Suara Alam Damai',
        album: 'Relaksasi Tidur Nyenyak',
        albumArtUrl: 'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?w=600',
        audioUrl: 'https://www.youtube.com/watch?v=mPZkdNFkNps',
        duration: const Duration(minutes: 5, seconds: 30),
        lyrics: Song.generateSampleLyrics('Hujan Lembut Pengantar Lelap'),
      ),
      Song(
        id: 'sleep_delta_waves',
        title: 'Gelombang Delta Tidur Dalam',
        artist: 'Frekuensi Otak',
        album: 'Deep Delta Rest',
        albumArtUrl: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=600',
        audioUrl: 'https://www.youtube.com/watch?v=1ZYbU88VzII',
        duration: const Duration(minutes: 6, seconds: 15),
        lyrics: Song.generateSampleLyrics('Gelombang Delta Tidur Dalam'),
      ),
      Song(
        id: 'sleep_piano_lullaby',
        title: 'Piano Malam Bintang-Bintang',
        artist: 'Melodi Malam',
        album: 'Piano Tidur Nyenyak',
        albumArtUrl: 'https://images.unsplash.com/photo-1478737270239-2f02b77fc618?w=600',
        audioUrl: 'https://www.youtube.com/watch?v=4xDzrJKXOOY',
        duration: const Duration(minutes: 4, seconds: 40),
        lyrics: Song.generateSampleLyrics('Piano Malam Bintang-Bintang'),
      ),
      Song(
        id: 'sleep_ambient_white_noise',
        title: 'White Noise Ruang Tidur',
        artist: 'Derau Tenang',
        album: 'White Noise Relaksasi',
        albumArtUrl: 'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?w=600',
        audioUrl: 'https://www.youtube.com/watch?v=nMfPqeZjc2c',
        duration: const Duration(minutes: 5, seconds: 0),
        lyrics: Song.generateSampleLyrics('White Noise Ruang Tidur'),
      ),
      Song(
        id: 'sleep_forest_stream',
        title: 'Gemericik Air Sungai Hutan',
        artist: 'Suara Alam Damai',
        album: 'Hutan Tenang',
        albumArtUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600',
        audioUrl: 'https://www.youtube.com/watch?v=IvjMgVS6kng',
        duration: const Duration(minutes: 5, seconds: 12),
        lyrics: Song.generateSampleLyrics('Gemericik Air Sungai Hutan'),
      ),
      Song(
        id: 'sleep_night_wind',
        title: 'Angin Malam Musim Gugur',
        artist: 'Suara Alam Damai',
        album: 'Angin Senja',
        albumArtUrl: 'https://images.unsplash.com/photo-1478737270239-2f02b77fc618?w=600',
        audioUrl: 'https://www.youtube.com/watch?v=n8X9_MgEdCg',
        duration: const Duration(minutes: 4, seconds: 45),
        lyrics: Song.generateSampleLyrics('Angin Malam Musim Gugur'),
      ),
      Song(
        id: 'sleep_432hz_meditation',
        title: 'Meditasi Frekuensi 432Hz',
        artist: 'Frekuensi Otak',
        album: 'Frekuensi Harmoni Alam',
        albumArtUrl: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=600',
        audioUrl: 'https://www.youtube.com/watch?v=1ZYbU88VzII',
        duration: const Duration(minutes: 6, seconds: 0),
        lyrics: Song.generateSampleLyrics('Meditasi Frekuensi 432Hz'),
      ),
      Song(
        id: 'sleep_ocean_waves',
        title: 'Ombak Pantai Menenangkan',
        artist: 'Suara Alam Damai',
        album: 'Pesisir Malam',
        albumArtUrl: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=600',
        audioUrl: 'https://www.youtube.com/watch?v=bn9F19Hi1Lk',
        duration: const Duration(minutes: 5, seconds: 20),
        lyrics: Song.generateSampleLyrics('Ombak Pantai Menenangkan'),
      ),
      Song(
        id: 'sleep_acoustic_lullaby',
        title: 'Akustik Lullaby Tengah Malam',
        artist: 'Melodi Malam',
        album: 'Gitar Tidur',
        albumArtUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600',
        audioUrl: 'https://www.youtube.com/watch?v=4xDzrJKXOOY',
        duration: const Duration(minutes: 4, seconds: 15),
        lyrics: Song.generateSampleLyrics('Akustik Lullaby Tengah Malam'),
      ),
      Song(
        id: 'sleep_rain_roof',
        title: 'Derau Hujan di Atap Kaca',
        artist: 'Suara Alam Damai',
        album: 'Hujan Kamar Tidur',
        albumArtUrl: 'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?w=600',
        audioUrl: 'https://www.youtube.com/watch?v=mPZkdNFkNps',
        duration: const Duration(minutes: 5, seconds: 50),
        lyrics: Song.generateSampleLyrics('Derau Hujan di Atap Kaca'),
      ),
      Song(
        id: 'sleep_tropical_jungle',
        title: 'Suasana Hutan Hujan Tropis',
        artist: 'Suara Alam Damai',
        album: 'Tropis Malam Hari',
        albumArtUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600',
        audioUrl: 'https://www.youtube.com/watch?v=IvjMgVS6kng',
        duration: const Duration(minutes: 4, seconds: 55),
        lyrics: Song.generateSampleLyrics('Suasana Hutan Hujan Tropis'),
      ),
      Song(
        id: 'sleep_soft_piano_close_eyes',
        title: 'Piano Teduh Pejam Mata',
        artist: 'Melodi Malam',
        album: 'Lullaby Instrumental',
        albumArtUrl: 'https://images.unsplash.com/photo-1478737270239-2f02b77fc618?w=600',
        audioUrl: 'https://www.youtube.com/watch?v=4xDzrJKXOOY',
        duration: const Duration(minutes: 5, seconds: 10),
        lyrics: Song.generateSampleLyrics('Piano Teduh Pejam Mata'),
      ),
    ];
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ─────────────────────────────────────────────────────────────────────────
  // DYNAMIC RELEASE RADAR FRIDAY UPDATE HELPER
  // ─────────────────────────────────────────────────────────────────────────
  static String getReleaseRadarSubtitle({bool refreshed = false}) {
    final now = DateTime.now();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    if (refreshed) {
      final dateStr = '${now.day} ${months[now.month - 1]}';
      return 'Diperbarui baru saja • $dateStr • 30 lagu baru';
    }
    final daysSinceFriday = (now.weekday - DateTime.friday + 7) % 7;
    final lastFriday = now.subtract(Duration(days: daysSinceFriday));
    final dateStr = '${lastFriday.day} ${months[lastFriday.month - 1]}';
    return 'Diperbarui setiap Jumat • $dateStr • 30 lagu baru';
  }

  /// Generates a deduplicated list of 50 Top Indonesia tracks
  static List<Song> getTop50IndonesiaTracks() {
    final result = <Song>[];
    final seen = <String>{};

    void addList(List<Song> list) {
      for (final s in list) {
        if (!seen.contains(s.id)) {
          seen.add(s.id);
          result.add(s);
        }
      }
    }

    // Curated Indonesian tracks
    addList(getIndieTracks());
    addList(getFeaturedTracks().where((s) => !s.id.contains('coldplay') && !s.id.contains('weeknd') && !s.id.contains('daft')).toList());
    addList(getNostalgiaTracks().where((s) => !s.id.contains('westlife') && !s.id.contains('oasis') && !s.id.contains('queen')).toList());
    for (final a in getComprehensiveArtists()) {
      if (a.country.toLowerCase() == 'indonesia') {
        addList(a.topTracks);
      }
    }
    // Fallback fill to ensure exactly 50
    addList(getFeaturedTracks());
    addList(getNostalgiaTracks());
    return result.take(50).toList();
  }

  /// Generates a deduplicated list of 50 Top Global tracks
  static List<Song> getTop50GlobalTracks() {
    final result = <Song>[];
    final seen = <String>{};

    void addList(List<Song> list) {
      for (final s in list) {
        if (!seen.contains(s.id)) {
          seen.add(s.id);
          result.add(s);
        }
      }
    }

    // Global / International tracks
    addList(getFeaturedTracks().where((s) => s.id.contains('coldplay') || s.id.contains('weeknd') || s.id.contains('daft') || s.id.contains('taylor') || s.id.contains('sabrina') || s.id.contains('billie') || s.id.contains('bruno') || s.id.contains('dua')).toList());
    addList(getNostalgiaTracks().where((s) => s.id.contains('westlife') || s.id.contains('oasis') || s.id.contains('queen')).toList());
    addList(getJPopTracks());
    addList(getKPopTracks());
    for (final a in getComprehensiveArtists()) {
      if (a.country.toLowerCase() != 'indonesia') {
        addList(a.topTracks);
      }
    }
    // Fallback fill to guarantee exactly 50
    addList(getKoreanDramaTracks());
    addList(getFeaturedTracks());
    return result.take(50).toList();
  }

  /// Generates a deduplicated list of 50 Viral Indonesia tracks
  static List<Song> getViral50IndonesiaTracks() {
    final topIndo = getTop50IndonesiaTracks();
    final reversed = List<Song>.from(topIndo.reversed);
    return reversed.take(50).toList();
  }

  /// Generates a deduplicated list of 50 Viral Global tracks
  static List<Song> getViral50GlobalTracks() {
    final topGlobal = getTop50GlobalTracks();
    final reversed = List<Song>.from(topGlobal.reversed);
    return reversed.take(50).toList();
  }

  static bool _forcePhilippineLocaleForTesting = false;
  static set forcePhilippineLocaleForTesting(bool val) => _forcePhilippineLocaleForTesting = val;

  /// Detects if app is running on a Philippine device / locale
  static bool get isPhilippineLocale {
    if (_forcePhilippineLocaleForTesting) return true;
    try {
      final loc = Platform.localeName.toUpperCase();
      if (loc.contains('_PH') || loc.contains('-PH') || loc.startsWith('FIL') || loc.startsWith('TL')) {
        return true;
      }
      final dispatcherLoc = WidgetsBinding.instance.platformDispatcher.locale.countryCode?.toUpperCase();
      if (dispatcherLoc == 'PH') {
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Generates a deduplicated list of 50 Top Philippines tracks (OPM + Top PH Hits)
  static List<Song> getTop50PhilippinesTracks() {
    final result = <Song>[];
    final seen = <String>{};

    void addSong(Song s) {
      if (!seen.contains(s.id)) {
        seen.add(s.id);
        result.add(s);
      }
    }

    void addList(List<Song> list) {
      for (final s in list) {
        addSong(s);
      }
    }

    // 1. All curated Philippine OPM artists
    for (final a in getComprehensiveArtists()) {
      if (a.country.toLowerCase() == 'filipina' || a.country.toLowerCase() == 'philippines') {
        addList(a.topTracks);
      }
    }

    // 2. Additional iconic OPM hits
    final opmHits = [
      Song(
        id: 'ph_dilaw_uhaw',
        title: 'Uhaw (Tayong Lahat)',
        artist: 'Dilaw',
        album: 'Uhaw',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/4a/1c/fc/4a1cfcca-eb7d-66ef-2784-07d0f9829f79/886449339327.jpg/600x600bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=k5q6e6gN5J8',
        duration: const Duration(minutes: 4, seconds: 1),
        lyrics: Song.generateSampleLyrics('Uhaw (Tayong Lahat)'),
      ),
      Song(
        id: 'ph_sunkissed_pasilyo',
        title: 'Pasilyo',
        artist: 'SunKissed Lola',
        album: 'Pasilyo',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music122/v4/bf/f9/ba/bff9ba9a-2e38-4e89-1382-f5e6a92ec219/196871202343.jpg/600x600bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=b8yq9V8yq3Y',
        duration: const Duration(minutes: 4, seconds: 30),
        lyrics: Song.generateSampleLyrics('Pasilyo'),
      ),
      Song(
        id: 'ph_adie_tahanan',
        title: 'Tahanan',
        artist: 'Adie',
        album: 'Tahanan',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/1e/e7/bb/1ee7bb03-aa99-2826-6f8d-db4ea110ecba/21UM1IM34341.rgb.jpg/600x600bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=kR2g3c_9eZ8',
        duration: const Duration(minutes: 4, seconds: 53),
        lyrics: Song.generateSampleLyrics('Tahanan'),
      ),
      Song(
        id: 'ph_cup_of_joe_tingin',
        title: 'Tingin',
        artist: 'Cup of Joe ft. Janine Teñoso',
        album: 'Patutunguhan',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/8e/3c/64/8e3c64d8-c89b-73b0-6425-4c07a0bbba86/23UM1IM41846.rgb.jpg/600x600bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=2n5n9E3Jc1k',
        duration: const Duration(minutes: 4, seconds: 0),
        lyrics: Song.generateSampleLyrics('Tingin'),
      ),
      Song(
        id: 'ph_maki_dilaw',
        title: 'Dilaw',
        artist: 'Maki',
        album: 'Dilaw',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/2b/97/8d/2b978ddb-2ecf-cb8d-ee06-19f6a7d75b33/198588049615.jpg/600x600bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=5U0q2N0Ksmg',
        duration: const Duration(minutes: 3, seconds: 12),
        lyrics: Song.generateSampleLyrics('Dilaw'),
      ),
    ];
    addList(opmHits);

    // 3. Global top hits dominating PH Spotify Charts
    addList(getTop50GlobalTracks());
    addList(getFeaturedTracks());

    return result.take(50).toList();
  }

  /// Generates a deduplicated list of 50 Viral Philippines tracks
  static List<Song> getViral50PhilippinesTracks() {
    final topPH = getTop50PhilippinesTracks();
    final reversed = List<Song>.from(topPH.reversed);
    return reversed.take(50).toList();
  }

  /// Generates 30 fresh tracks for Release Radar personalized by listened artists & genres
  static List<Song> getReleaseRadarTracks({bool refresh = false}) {
    final result = <Song>[];
    final seen = <String>{};

    void addSong(Song s) {
      if (!seen.contains(s.id)) {
        seen.add(s.id);
        result.add(s);
      }
    }

    final topArtistNames = UserBehaviorService.getTopArtists(limit: 8).map((a) => a.toLowerCase()).toSet();
    final targetArtists = <String>{...topArtistNames};
    final allArtists = List<Artist>.from(getComprehensiveArtists());
    if (refresh) {
      allArtists.shuffle();
    }
    final preferredGenres = allArtists
        .where((a) => targetArtists.contains(a.name.toLowerCase()))
        .expand((a) => a.genres)
        .map((g) => g.toLowerCase())
        .toSet();

    // 1. First priority: New releases / top tracks from artists the user actually listens to / follows
    for (final a in allArtists) {
      if (targetArtists.contains(a.name.toLowerCase())) {
        final tracks = List<Song>.from(a.topTracks);
        if (refresh) tracks.shuffle();
        for (final t in tracks.take(2)) {
          addSong(t);
        }
      }
    }

    // 2. Second priority: New releases / tracks matching the user's preferred genres
    if (preferredGenres.isNotEmpty) {
      for (final a in allArtists) {
        final matchesGenre = a.genres.any((g) => preferredGenres.contains(g.toLowerCase()));
        if (matchesGenre && a.topTracks.isNotEmpty) {
          final tracks = List<Song>.from(a.topTracks);
          if (refresh) tracks.shuffle();
          addSong(tracks.first);
        }
      }
    }

    // 3. Third priority: Fresh catalog tracks from remaining comprehensive artists
    for (final a in allArtists) {
      if (a.topTracks.isNotEmpty) {
        final tracks = List<Song>.from(a.topTracks);
        if (refresh) tracks.shuffle();
        addSong(tracks.first);
      }
      if (result.length >= 30) break;
    }

    // Fallback fills
    final featured = List<Song>.from(getFeaturedTracks());
    if (refresh) featured.shuffle();
    for (final s in featured) {
      addSong(s);
      if (result.length >= 30) break;
    }
    final indie = List<Song>.from(getIndieTracks());
    if (refresh) indie.shuffle();
    for (final s in indie) {
      addSong(s);
      if (result.length >= 30) break;
    }

    return result.take(30).toList();
  }

  /// Generates 24 coherent tracks for each of Daily Mix 1 to 6
  static List<Song> getDailyMixTracks(int mixNumber) {
    final result = <Song>[];
    final seen = <String>{};

    void addList(List<Song> list) {
      for (final s in list) {
        if (!seen.contains(s.id)) {
          seen.add(s.id);
          result.add(s);
        }
      }
    }

    switch (mixNumber) {
      case 1:
        // Pop Indonesia & Sentimental
        addList(getFeaturedTracks().where((s) => s.artist == 'Tulus' || s.artist == 'Sheila On 7' || s.artist == 'Bernadya' || s.artist == 'Raim Laode').toList());
        addList(getNostalgiaTracks().where((s) => !s.id.contains('westlife') && !s.id.contains('oasis')).toList());
        for (final a in getComprehensiveArtists()) {
          if (a.name == 'Afgan' || a.name == 'Raim Laode' || a.name == 'Tulus' || a.name == 'Pamungkas') {
            addList(a.topTracks);
          }
        }
        addList(getIndieTracks());
        break;

      case 2:
        // Global Pop, Dance & Funk
        addList(getFeaturedTracks().where((s) => s.artist == 'The Weeknd' || s.artist == 'Daft Punk' || s.artist == 'Bruno Mars' || s.artist == 'Dua Lipa' || s.artist == 'Coldplay').toList());
        for (final a in getComprehensiveArtists()) {
          if (a.name == 'Audien' || a.name == 'Icona Pop' || a.name == 'Urban Cone' || a.name == 'Alan Walker' || a.name == 'Zara Larsson' || a.name == 'Seeb') {
            addList(a.topTracks);
          }
        }
        addList(getNostalgiaTracks().where((s) => s.id.contains('westlife') || s.id.contains('oasis')).toList());
        break;

      case 3:
        // Indie & Folk Akustik Indonesia
        addList(getIndieTracks());
        for (final a in getComprehensiveArtists()) {
          if (a.name == 'Nadin Amizah' || a.name == 'Sal Priadi' || a.name == 'Pamungkas' || a.name == 'Hindia') {
            addList(a.topTracks);
          }
        }
        addList(getFeaturedTracks().where((s) => s.artist == 'Bernadya' || s.artist == 'Nadin Amizah' || s.artist == 'Pamungkas').toList());
        break;

      case 4:
        // Pop Divas & Global Mega Hits
        addList(getFeaturedTracks().where((s) => s.artist == 'Taylor Swift' || s.artist == 'Sabrina Carpenter' || s.artist == 'Billie Eilish' || s.artist == 'Olivia Rodrigo' || s.artist == 'Dua Lipa').toList());
        for (final a in getComprehensiveArtists()) {
          if (a.name == 'Tove Lo' || a.name == 'Tove Styrke' || a.name == 'Rhys' || a.name == 'Zara Larsson' || a.name == 'Utada Hikaru') {
            addList(a.topTracks);
          }
        }
        addList(getNostalgiaTracks().where((s) => s.id.contains('backstreet') || s.id.contains('westlife')).toList());
        break;

      case 5:
        // J-Pop & Anime Essentials
        addList(getJPopTracks());
        for (final a in getComprehensiveArtists()) {
          if (a.name == 'Kenshi Yonezu' || a.name == 'Utada Hikaru' || a.name == 'YOASOBI' || a.name == 'Yuuri') {
            addList(a.topTracks);
          }
        }
        break;

      case 6:
        // K-Pop & Iconic Korean Drama OST
        addList(getKPopTracks());
        addList(getKoreanDramaTracks());
        for (final a in getComprehensiveArtists()) {
          if (a.name == 'Kyuhyun' || a.name == 'IU' || a.name == 'Taeyeon') {
            addList(a.topTracks);
          }
        }
        break;

      default:
        addList(getFeaturedTracks());
    }

    // Ensure at least 24 tracks by padding from general pool if needed
    if (result.length < 24) {
      addList(getFeaturedTracks());
      addList(getIndieTracks());
    }
    return result.take(24).toList();
  }

  static List<Playlist> getHomePlaylists() {
    final topIndoSongs = getTop50IndonesiaTracks();
    final topGlobalSongs = getTop50GlobalTracks();
    final viralSongs = getViral50IndonesiaTracks();
    final releaseRadarSongs = getReleaseRadarTracks();

    final dailyMix1Songs = getDailyMixTracks(1);
    final dailyMix2Songs = getDailyMixTracks(2);
    final dailyMix3Songs = getDailyMixTracks(3);
    final dailyMix4Songs = getDailyMixTracks(4);
    final dailyMix5Songs = getDailyMixTracks(5);
    final dailyMix6Songs = getDailyMixTracks(6);

    const topGlobalCover = 'https://charts-images.scdn.co/assets/locale_en/regional/daily/region_global_default.jpg';

    return [
      Playlist(
        id: 'pl_release_radar',
        title: 'Release Radar',
        subtitle: getReleaseRadarSubtitle(),
        coverUrl: releaseRadarSongs.first.albumArtUrl,
        songs: releaseRadarSongs,
        isReleaseRadar: true,
      ),
      Playlist(
        id: 'pl_discover_weekly',
        title: 'Discover Weekly',
        subtitle: 'Lagu-lagu yang mungkin kamu suka • 30 lagu',
        coverUrl: 'assets/images/discover_weekly.png',
        songs: topGlobalSongs.take(30).toList(),
        isDiscoverWeekly: true,
      ),
      Playlist(
        id: 'pl_daily_mix_1',
        title: 'Daily Mix 1',
        subtitle: 'Tulus, Sheila On 7, Afgan, Raim Laode • 24 lagu',
        coverUrl: _buildDailyMixCoverUrl(dailyMix1Songs),
        songs: dailyMix1Songs,
        isDailyMix: true,
        dailyMixNumber: 1,
      ),
      Playlist(
        id: 'pl_daily_mix_2',
        title: 'Daily Mix 2',
        subtitle: 'The Weeknd, Daft Punk, Audien, Dua Lipa • 24 lagu',
        coverUrl: _buildDailyMixCoverUrl(dailyMix2Songs),
        songs: dailyMix2Songs,
        isDailyMix: true,
        dailyMixNumber: 2,
      ),
      Playlist(
        id: 'pl_daily_mix_3',
        title: 'Daily Mix 3',
        subtitle: 'Bernadya, Hindia, Nadin Amizah, Sal Priadi • 24 lagu',
        coverUrl: _buildDailyMixCoverUrl(dailyMix3Songs),
        songs: dailyMix3Songs,
        isDailyMix: true,
        dailyMixNumber: 3,
      ),
      Playlist(
        id: 'pl_daily_mix_4',
        title: 'Daily Mix 4',
        subtitle: 'Taylor Swift, Sabrina Carpenter, Billie Eilish • 24 lagu',
        coverUrl: _buildDailyMixCoverUrl(dailyMix4Songs),
        songs: dailyMix4Songs,
        isDailyMix: true,
        dailyMixNumber: 4,
      ),
      Playlist(
        id: 'pl_daily_mix_5',
        title: 'Daily Mix 5',
        subtitle: 'YOASOBI, Kenshi Yonezu, Utada Hikaru, Yuuri • 24 lagu',
        coverUrl: _buildDailyMixCoverUrl(dailyMix5Songs),
        songs: dailyMix5Songs,
        isDailyMix: true,
        dailyMixNumber: 5,
      ),
      Playlist(
        id: 'pl_daily_mix_6',
        title: 'Daily Mix 6',
        subtitle: 'BTS, NewJeans, IU, Taeyeon, Drama OST • 24 lagu',
        coverUrl: _buildDailyMixCoverUrl(dailyMix6Songs),
        songs: dailyMix6Songs,
        isDailyMix: true,
        dailyMixNumber: 6,
      ),
      if (isPhilippineLocale) ...[
        Playlist(
          id: 'pl_top_50_indo',
          title: 'Top 50 - Philippines',
          subtitle: 'The most played tracks in the Philippines today • 50 tracks',
          coverUrl: 'assets/images/top50_philippines.jpg',
          songs: getTop50PhilippinesTracks(),
        ),
        Playlist(
          id: 'pl_top_50_global',
          title: 'Top 50 - Global',
          subtitle: 'Lagu paling populer di seluruh dunia minggu ini • 50 lagu',
          coverUrl: topGlobalCover,
          songs: topGlobalSongs,
        ),
        Playlist(
          id: 'pl_viral_hits',
          title: 'Viral 50 - Philippines',
          subtitle: 'Trending songs across the Philippines • 50 tracks',
          coverUrl: 'assets/images/viral50_philippines.jpg',
          songs: getViral50PhilippinesTracks(),
        ),
      ] else ...[
        Playlist(
          id: 'pl_top_50_indo',
          title: 'Top 50 - Indonesia',
          subtitle: 'Lagu paling banyak diputar di Indonesia saat ini • 50 lagu',
          coverUrl: 'assets/images/top50_indonesia.jpg',
          songs: topIndoSongs,
        ),
        Playlist(
          id: 'pl_top_50_global',
          title: 'Top 50 - Global',
          subtitle: 'Lagu paling populer di seluruh dunia minggu ini • 50 lagu',
          coverUrl: topGlobalCover,
          songs: topGlobalSongs,
        ),
        Playlist(
          id: 'pl_viral_hits',
          title: 'Viral Hits Indonesia',
          subtitle: 'Lagu yang sedang tren di media sosial • 50 lagu',
          coverUrl: 'assets/images/viral50_indonesia.jpg',
          songs: viralSongs,
        ),
      ],
    ];
  }

  static List<Playlist> getTopChartsPlaylists() {
    final isPH = isPhilippineLocale;
    final regionalTop = isPH ? getTop50PhilippinesTracks() : getTop50IndonesiaTracks();
    final regionalViral = isPH ? getViral50PhilippinesTracks() : getViral50IndonesiaTracks();
    final topGlobal = getTop50GlobalTracks();
    final viralGlobal = getViral50GlobalTracks();
    const topGlobalCover = 'https://charts-images.scdn.co/assets/locale_en/regional/daily/region_global_default.jpg';

    return [
      Playlist(
        id: isPH ? 'chart_top_50_ph' : 'chart_top_50_indo',
        title: isPH ? 'Top 50 - Philippines' : 'Top 50 - Indonesia',
        subtitle: isPH ? 'Daily update • 50 most popular tracks in the Philippines' : 'Update setiap hari • 50 lagu terpopuler di Indonesia',
        coverUrl: isPH ? 'assets/images/top50_philippines.jpg' : 'assets/images/top50_indonesia.jpg',
        songs: regionalTop,
      ),
      Playlist(
        id: 'chart_top_50_global',
        title: 'Top 50 - Global',
        subtitle: 'Update setiap hari • 50 tangga lagu internasional',
        coverUrl: topGlobalCover,
        songs: topGlobal,
      ),
      Playlist(
        id: isPH ? 'chart_viral_ph' : 'chart_viral_indo',
        title: isPH ? 'Viral 50 - Philippines' : 'Viral 50 - Indonesia',
        subtitle: isPH ? 'Catch the freshest viral tracks in the Philippines • 50 tracks' : 'Lagu yang paling cepat naik daun di Indonesia • 50 lagu',
        coverUrl: isPH ? 'assets/images/viral50_philippines.jpg' : 'assets/images/viral50_indonesia.jpg',
        songs: regionalViral,
      ),
      Playlist(
        id: 'chart_viral_global',
        title: 'Viral 50 - Global',
        subtitle: 'Lagu yang viral dan trending di seluruh dunia • 50 lagu',
        coverUrl: viralGlobal[0].albumArtUrl,
        songs: viralGlobal,
      ),
    ];
  }

  // ─────────────────────────────────────────────────────────────────────────
  // NOSTALGIA & KENANGAN TERINDAH — Indonesia & Global Timeless Classics
  // ─────────────────────────────────────────────────────────────────────────
  static List<Song> getNostalgiaTracks() {
    return [
      Song(
        id: 'nos_so7_dan',
        title: 'Dan...',
        artist: 'Sheila On 7',
        album: 'Sheila On 7',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music/90/01/6d/mzi.ywjxtlbq.jpg/600x600bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=IWvo2fld3s4',
        duration: const Duration(minutes: 4, seconds: 48),
        lyrics: Song.generateSampleLyrics('Dan...'),
      ),
      Song(
        id: 'nos_so7_sephia',
        title: 'Sephia',
        artist: 'Sheila On 7',
        album: 'Kisah Klasik Untuk Masa Depan',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music/v4/99/71/5e/99715e79-687c-d3d2-232f-186050577e45/886444671422.jpg/600x600bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=dSR5dyHPUxA',
        duration: const Duration(minutes: 4, seconds: 40),
        lyrics: Song.generateSampleLyrics('Sephia'),
      ),
      Song(
        id: 'nos_chrisye_pergilahkasih',
        title: 'Pergilah Kasih',
        artist: 'Chrisye',
        album: 'Pergilah Kasih',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music71/v4/16/1f/b8/161fb8d1-edca-624b-9372-f7ebb66bc1c3/Chrisye_-_Lilin_Lilin_Kecil1.jpg/1000x1000bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=t5J5sL6aQdY',
        duration: const Duration(minutes: 4, seconds: 43),
        lyrics: null,
      ),
      Song(
        id: 'nos_dewa19_kangen',
        title: 'Kangen',
        artist: 'Dewa 19',
        album: '19',
        albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/4d621930e6f5503389642c98f5be5f2f/1000x1000-000000-80-0-0.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=Z61Ew52sYJ8',
        duration: const Duration(minutes: 5, seconds: 5),
        lyrics: null,
      ),
      Song(
        id: 'nos_dewa19_pupus',
        title: 'Pupus',
        artist: 'Dewa 19',
        album: 'Cintailah Cinta',
        albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/315919b2affeb076b7d4abbb6deb2d4d/1000x1000-000000-80-0-0.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=9jKj5i9u7vI',
        duration: const Duration(minutes: 5, seconds: 12),
        lyrics: null,
      ),
      Song(
        id: 'nos_peterpan_yangterdalam',
        title: 'Yang Terdalam',
        artist: 'Peterpan',
        album: 'Taman Langit',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/a2/04/5a/a2045ad7-9db5-1581-43b2-a8c7888dd63b/25UMGIM76219.rgb.jpg/1000x1000bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=s1X5g8b2w7c',
        duration: const Duration(minutes: 3, seconds: 20),
        lyrics: null,
      ),
      Song(
        id: 'nos_glenn_januari',
        title: 'Januari',
        artist: 'Glenn Fredly',
        album: 'Selamat Pagi, Dunia!',
        albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/bcf2fa61ddead97b48b15781ff499fd3/1000x1000-000000-80-0-0.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=T_sU6M3V2n4',
        duration: const Duration(minutes: 3, seconds: 50),
        lyrics: null,
      ),
      Song(
        id: 'nos_padi_menanti',
        title: 'Menanti Sebuah Jawaban',
        artist: 'Padi',
        album: 'Sesuatu Yang Tertunda',
        albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/e05e871e2ed9d135873d83dcde7d4377/1000x1000-000000-80-0-0.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=KzXk5j6d5uU',
        duration: const Duration(minutes: 4, seconds: 45),
        lyrics: null,
      ),
      Song(
        id: 'nos_westlife_mylove',
        title: 'My Love',
        artist: 'Westlife',
        album: 'Coast to Coast',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/80/7e/45/807e4521-50e5-7977-eb14-38605c4832be/886445671453.jpg/600x600bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=ulOb9gIGGd0',
        duration: const Duration(minutes: 3, seconds: 52),
        lyrics: Song.generateSampleLyrics('My Love'),
      ),
      Song(
        id: 'nos_bsb_iwantitthatway',
        title: 'I Want It That Way',
        artist: 'Backstreet Boys',
        album: 'Millennium',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/ef/0b/df/ef0bdfb5-b7be-4fc4-63c2-d6aa4687d329/012414168023.jpg/600x600bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=4fndeDfaWCg',
        duration: const Duration(minutes: 3, seconds: 33),
        lyrics: Song.generateSampleLyrics('I Want It That Way'),
      ),
      Song(
        id: 'nos_oasis_wonderwall',
        title: 'Wonderwall',
        artist: 'Oasis',
        album: '(What\'s the Story) Morning Glory?',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/1f/03/49/1f0349b1-ec9d-7db0-9852-73620858e722/5051961070014.jpg/600x600bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=6hzrDeceEKc',
        duration: const Duration(minutes: 4, seconds: 18),
        lyrics: Song.generateSampleLyrics('Wonderwall'),
      ),
      Song(
        id: 'nos_queen_bohemian',
        title: 'Bohemian Rhapsody',
        artist: 'Queen',
        album: 'A Night at the Opera',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/8b/fc/b8/8bfcb894-6db3-b8f4-6014-99b8449c2598/00050087310462.rgb.jpg/600x600bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=fJ9rUzIMcZQ',
        duration: const Duration(minutes: 5, seconds: 55),
        lyrics: Song.generateSampleLyrics('Bohemian Rhapsody'),
      ),
    ];
  }

  static List<Playlist> getNostalgiaPlaylists() {
    final nosTracks = getNostalgiaTracks();
    return [
      Playlist(
        id: 'pl_nostalgia_indo',
        title: 'Nostalgia & Kenangan Terindah',
        subtitle: 'Sheila On 7, Chrisye, Dewa 19, Peterpan dan hits emas legendaris',
        coverUrl: nosTracks.first.albumArtUrl,
        songs: nosTracks,
      ),
      Playlist(
        id: 'pl_nostalgia_pop_90s',
        title: 'Kenangan 90-an & 2000-an',
        subtitle: 'Kompilasi lagu terbaik masa sekolah dan masa muda',
        coverUrl: nosTracks[3].albumArtUrl,
        songs: [nosTracks[0], nosTracks[1], nosTracks[2], nosTracks[3], nosTracks[4], nosTracks[5], nosTracks[6], nosTracks[7], nosTracks[8], nosTracks[9], nosTracks[10], nosTracks[11]],
      ),
      Playlist(
        id: 'pl_nostalgia_global_classics',
        title: 'Golden Era International Hits',
        subtitle: 'Westlife, Backstreet Boys, Oasis, Queen dan lagu abadi dunia',
        coverUrl: nosTracks[8].albumArtUrl,
        songs: [nosTracks[8], nosTracks[9], nosTracks[10], nosTracks[11], nosTracks[0], nosTracks[1], nosTracks[2], nosTracks[3], nosTracks[4], nosTracks[5], nosTracks[6], nosTracks[7]],
      ),
    ];
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ALBUM DAN SINGLE POPULER (Screenshot 1: Lesung Pipi, Kisah Klasik, dsb)
  // ─────────────────────────────────────────────────────────────────────────
  static List<Playlist> getPopularReleases() {
    final feat = getFeaturedTracks();
    final nos = getNostalgiaTracks();
    final artists = getArtists();
    final raimTracks = artists.first.topTracks;

    return [
      Playlist(
        id: 'rel_lesung_pipi',
        title: 'Lesung Pipi',
        subtitle: 'Single • Raim Laode',
        coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/d6/9e/a3/d69ea311-9c75-0109-1938-1a6f00ba0cc4/5019.jpg/1000x1000bb.jpg',
        songs: raimTracks,
      ),
      Playlist(
        id: 'rel_youll_be_in_my_heart',
        title: 'You\'ll Be In My Heart',
        subtitle: 'Single • Phil Collins',
        coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/09/ff/d4/09ffd48c-f525-ae2b-be96-b12696d83a49/18UMGIM62087.rgb.jpg/1000x1000bb.jpg',
        songs: [
          Song(
            id: 'rel_youll_be_track',
            title: 'You\'ll Be In My Heart',
            artist: 'Phil Collins',
            album: 'Tarzan (Original Soundtrack)',
            albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/09/ff/d4/09ffd48c-f525-ae2b-be96-b12696d83a49/18UMGIM62087.rgb.jpg/1000x1000bb.jpg',
            audioUrl: 'https://www.youtube.com/watch?v=git6DCXSqjE',
            duration: const Duration(minutes: 4, seconds: 17),
            lyrics: Song.generateSampleLyrics('You\'ll Be In My Heart'),
          ),
        ],
      ),
      Playlist(
        id: 'rel_kisah_klasik',
        title: 'Kisah Klasik Untuk Masa Depan',
        subtitle: 'Album • Sheila On 7',
        coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music/v4/99/71/5e/99715e79-687c-d3d2-232f-186050577e45/886444671422.jpg/600x600bb.jpg',
        songs: [nos[1], nos[0], feat[7]],
      ),
      Playlist(
        id: 'rel_sialnya',
        title: 'Sialnya, Hidup Harus Tetap Berjalan',
        subtitle: 'Album • Bernadya',
        coverUrl: 'https://cdn-images.dzcdn.net/images/cover/f5809041de170abd4c84dcdede0d202a/1000x1000-000000-80-0-0.jpg',
        songs: [feat[11], feat[15], feat[16]],
      ),
      Playlist(
        id: 'rel_manusia',
        title: 'Manusia',
        subtitle: 'Album • Tulus',
        coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/6f/18/10/6f1810e0-2d6a-a456-1362-de607c70408a/cover.jpg/600x600bb.jpg',
        songs: [feat[1], feat[19]],
      ),
      Playlist(
        id: 'rel_24k_magic',
        title: '24K Magic',
        subtitle: 'Album • Bruno Mars',
        coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/e3/47/a0/e347a0cc-87ce-5d05-d560-176c7d48f66e/075679904119.jpg/1000x1000bb.jpg',
        songs: [
          Song(
            id: 'bruno_24k_1',
            title: '24K Magic',
            artist: 'Bruno Mars',
            album: '24K Magic',
            albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/e3/47/a0/e347a0cc-87ce-5d05-d560-176c7d48f66e/075679904119.jpg/1000x1000bb.jpg',
            audioUrl: 'https://www.youtube.com/watch?v=UqyT8IEBkvY',
            duration: const Duration(minutes: 3, seconds: 46),
            lyrics: Song.generateSampleLyrics('24K Magic'),
          ),
          Song(
            id: 'bruno_24k_2',
            title: 'Chunky',
            artist: 'Bruno Mars',
            album: '24K Magic',
            albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/e3/47/a0/e347a0cc-87ce-5d05-d560-176c7d48f66e/075679904119.jpg/1000x1000bb.jpg',
            audioUrl: 'https://www.youtube.com/watch?v=pX9_z3cOQeY',
            duration: const Duration(minutes: 3, seconds: 6),
            lyrics: Song.generateSampleLyrics('Chunky'),
          ),
          Song(
            id: 'bruno_24k_3',
            title: 'Perm',
            artist: 'Bruno Mars',
            album: '24K Magic',
            albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/e3/47/a0/e347a0cc-87ce-5d05-d560-176c7d48f66e/075679904119.jpg/1000x1000bb.jpg',
            audioUrl: 'https://www.youtube.com/watch?v=kXm38m5j5fU',
            duration: const Duration(minutes: 3, seconds: 30),
            lyrics: Song.generateSampleLyrics('Perm'),
          ),
          Song(
            id: 'bruno_24k_4',
            title: 'That\'s What I Like',
            artist: 'Bruno Mars',
            album: '24K Magic',
            albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/e3/47/a0/e347a0cc-87ce-5d05-d560-176c7d48f66e/075679904119.jpg/1000x1000bb.jpg',
            audioUrl: 'https://www.youtube.com/watch?v=PMivT7MJ41M',
            duration: const Duration(minutes: 3, seconds: 26),
            lyrics: Song.generateSampleLyrics('That\'s What I Like'),
          ),
          Song(
            id: 'bruno_24k_5',
            title: 'Versace on the Floor',
            artist: 'Bruno Mars',
            album: '24K Magic',
            albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/e3/47/a0/e347a0cc-87ce-5d05-d560-176c7d48f66e/075679904119.jpg/1000x1000bb.jpg',
            audioUrl: 'https://www.youtube.com/watch?v=-FyjE33PhF4',
            duration: const Duration(minutes: 4, seconds: 21),
            lyrics: Song.generateSampleLyrics('Versace on the Floor'),
          ),
          Song(
            id: 'bruno_24k_6',
            title: 'Straight Up & Down',
            artist: 'Bruno Mars',
            album: '24K Magic',
            albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/e3/47/a0/e347a0cc-87ce-5d05-d560-176c7d48f66e/075679904119.jpg/1000x1000bb.jpg',
            audioUrl: 'https://www.youtube.com/watch?v=vE-QWp_V1kY',
            duration: const Duration(minutes: 3, seconds: 18),
            lyrics: Song.generateSampleLyrics('Straight Up & Down'),
          ),
          Song(
            id: 'bruno_24k_7',
            title: 'Calling All My Lovelies',
            artist: 'Bruno Mars',
            album: '24K Magic',
            albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/e3/47/a0/e347a0cc-87ce-5d05-d560-176c7d48f66e/075679904119.jpg/1000x1000bb.jpg',
            audioUrl: 'https://www.youtube.com/watch?v=4g6V-Zg_Xoc',
            duration: const Duration(minutes: 4, seconds: 10),
            lyrics: Song.generateSampleLyrics('Calling All My Lovelies'),
          ),
          Song(
            id: 'bruno_24k_8',
            title: 'Finesse',
            artist: 'Bruno Mars',
            album: '24K Magic',
            albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/e3/47/a0/e347a0cc-87ce-5d05-d560-176c7d48f66e/075679904119.jpg/1000x1000bb.jpg',
            audioUrl: 'https://www.youtube.com/watch?v=LsoLEjrDogU',
            duration: const Duration(minutes: 3, seconds: 10),
            lyrics: Song.generateSampleLyrics('Finesse'),
          ),
          Song(
            id: 'bruno_24k_9',
            title: 'Too Good to Say Goodbye',
            artist: 'Bruno Mars',
            album: '24K Magic',
            albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/e3/47/a0/e347a0cc-87ce-5d05-d560-176c7d48f66e/075679904119.jpg/1000x1000bb.jpg',
            audioUrl: 'https://www.youtube.com/watch?v=k3uK1Z92R6c',
            duration: const Duration(minutes: 4, seconds: 41),
            lyrics: Song.generateSampleLyrics('Too Good to Say Goodbye'),
          ),
        ],
      ),
      Playlist(
        id: 'rel_hit_me_hard',
        title: 'HIT ME HARD AND SOFT',
        subtitle: 'Album • Billie Eilish',
        coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/bf/16/96/bf169651-4f11-7eb1-c67d-d1be8f1f705a/24UMGIM35300.rgb.jpg/1000x1000bb.jpg',
        songs: [
          Song(
            id: 'billie_birds',
            title: 'BIRDS OF A FEATHER',
            artist: 'Billie Eilish',
            album: 'HIT ME HARD AND SOFT',
            albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/bf/16/96/bf169651-4f11-7eb1-c67d-d1be8f1f705a/24UMGIM35300.rgb.jpg/1000x1000bb.jpg',
            audioUrl: 'https://www.youtube.com/watch?v=d5gxPg-w9y8',
            duration: const Duration(minutes: 3, seconds: 30),
            lyrics: Song.generateSampleLyrics('BIRDS OF A FEATHER'),
          ),
          Song(
            id: 'billie_lunch',
            title: 'LUNCH',
            artist: 'Billie Eilish',
            album: 'HIT ME HARD AND SOFT',
            albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/bf/16/96/bf169651-4f11-7eb1-c67d-d1be8f1f705a/24UMGIM35300.rgb.jpg/1000x1000bb.jpg',
            audioUrl: 'https://www.youtube.com/watch?v=MB3VkzPdgLA',
            duration: const Duration(minutes: 2, seconds: 59),
            lyrics: Song.generateSampleLyrics('LUNCH'),
          ),
          Song(
            id: 'billie_chihiro',
            title: 'CHIHIRO',
            artist: 'Billie Eilish',
            album: 'HIT ME HARD AND SOFT',
            albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/bf/16/96/bf169651-4f11-7eb1-c67d-d1be8f1f705a/24UMGIM35300.rgb.jpg/1000x1000bb.jpg',
            audioUrl: 'https://www.youtube.com/watch?v=BY_X0kV1Bn8',
            duration: const Duration(minutes: 5, seconds: 3),
            lyrics: Song.generateSampleLyrics('CHIHIRO'),
          ),
        ],
      ),
    ];
  }

  static List<LyricLine> getHyunBinThatManLyrics() {
    return [
      LyricLine(time: const Duration(seconds: 0), text: "그 남자 (That Man) - 현빈 (Hyun Bin)"),
      LyricLine(time: const Duration(seconds: 14), text: "한 남자가 그대를 사랑합니다"),
      LyricLine(time: const Duration(seconds: 22), text: "그 남자는 열심히 사랑합니다"),
      LyricLine(time: const Duration(seconds: 29), text: "매일 그림자처럼 그대를 따라다니며"),
      LyricLine(time: const Duration(seconds: 37), text: "그 남자는 웃으며 울고 있어요"),
      LyricLine(time: const Duration(seconds: 44), text: "얼마나 얼마나 더 너를"),
      LyricLine(time: const Duration(seconds: 51), text: "이렇게 바라만 보며 혼자"),
      LyricLine(time: const Duration(seconds: 59), text: "이 바람같은 사랑 이 거지같은 사랑"),
      LyricLine(time: const Duration(seconds: 66), text: "계속해야 네가 나를 사랑하겠니"),
      LyricLine(time: const Duration(seconds: 74), text: "조금만 가까이 와봐 한 발만 다가와 봐"),
      LyricLine(time: const Duration(seconds: 81), text: "난 매일 눈물 흘리며 너를 기다리잖아"),
      LyricLine(time: const Duration(seconds: 89), text: "오늘도 그 남자는 옆에 있답니다"),
      LyricLine(time: const Duration(seconds: 103), text: "그 남자가 날 사랑하는 줄 모르나요"),
      LyricLine(time: const Duration(seconds: 111), text: "알면서도 그렇게 모른 척하는 건가요"),
      LyricLine(time: const Duration(seconds: 118), text: "그대 눈빛 하나에 온 세상을 다 가진 듯"),
      LyricLine(time: const Duration(seconds: 126), text: "웃다가 또 눈물 흘리는 나인데"),
      LyricLine(time: const Duration(seconds: 133), text: "얼마나 얼마나 더 너를"),
      LyricLine(time: const Duration(seconds: 140), text: "이렇게 바라만 보며 혼자"),
      LyricLine(time: const Duration(seconds: 148), text: "이 바람같은 사랑 이 거지같은 사랑"),
      LyricLine(time: const Duration(seconds: 155), text: "계속해야 네가 나를 사랑하겠니"),
      LyricLine(time: const Duration(seconds: 163), text: "조금만 가까이 와봐 한 발만 다가와 봐"),
      LyricLine(time: const Duration(seconds: 171), text: "난 매일 눈물 흘리며 너를 기다리잖아"),
      LyricLine(time: const Duration(seconds: 178), text: "오늘도 그 남자는 옆에 있답니다"),
      LyricLine(time: const Duration(seconds: 192), text: "그 남자는 바로 나라는 걸 아나요"),
      LyricLine(time: const Duration(seconds: 200), text: "알면서도 모른 척하는 건가요"),
      LyricLine(time: const Duration(seconds: 207), text: "내 사랑이 그렇게 보잘것없나요"),
      LyricLine(time: const Duration(seconds: 215), text: "그대 하나만을 사랑하는 나인데"),
      LyricLine(time: const Duration(seconds: 222), text: "얼마나 얼마나 더 너를"),
      LyricLine(time: const Duration(seconds: 229), text: "이렇게 바라만 보며 혼자"),
      LyricLine(time: const Duration(seconds: 237), text: "이 바람같은 사랑 이 거지같은 사랑"),
      LyricLine(time: const Duration(seconds: 244), text: "계속해야 네가 나를 사랑하겠니"),
      LyricLine(time: const Duration(seconds: 251), text: "눈물이 흐르는 날엔 그대가 생각납니다"),
      LyricLine(time: const Duration(seconds: 259), text: "한 걸음 뒤에서 늘 그댈 지켜보는 나"),
      LyricLine(time: const Duration(seconds: 268), text: "그 남자가 바로 나라는 걸..."),
    ];
  }

  static List<Song> getNarutoOstTracks() {
    return [
      Song(
        id: 'naruto_shun_never_change',
        title: 'Never Change',
        artist: 'SHUN',
        album: 'Naruto Shippuden Ending Theme Single',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music124/v4/2e/eb/9a/2eeb9ac0-558c-7094-75b9-a4978ed82e9a/jacket_SECL01543B00Z_550.jpg/1000x1000bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=kYJvO3z3i7Y',
        duration: const Duration(minutes: 4, seconds: 12),
      ),
      Song(
        id: 'naruto_unlimits_cascade',
        title: 'Cascade',
        artist: 'UNLIMITS',
        album: 'Cascade - EP (Naruto Shippuden ED 21)',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music114/v4/50/0e/3d/500e3dc1-8b44-5d3c-e1d8-2d333386643d/jacket_SRCL07949B00Z_550.jpg/1000x1000bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=0F7xPZk_QjU',
        duration: const Duration(minutes: 3, seconds: 48),
      ),
      Song(
        id: 'naruto_flow_sign',
        title: 'Sign',
        artist: 'FLOW',
        album: 'Sign (Naruto Shippuden OP 6)',
        albumArtUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music124/v4/6c/1d/e6/6c1de681-d7fa-a93b-f347-643340afd588/jacket_KSXX00341B00Z_550.jpg/1000x1000bb.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=q9e_9p-hC34',
        duration: const Duration(minutes: 3, seconds: 57),
      ),
      Song(
        id: 'naruto_kanaboon_silhouette',
        title: 'Silhouette',
        artist: 'KANA-BOON',
        album: 'Silhouette (Naruto Shippuden OP 16)',
        albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/3b7fa1f21eb2ee3fa5c9ebdf35316be3/1000x1000-000000-80-0-0.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=dlFA0Zq1k2A',
        duration: const Duration(minutes: 4, seconds: 0),
      ),
      Song(
        id: 'naruto_akfg_harukakanata',
        title: 'Haruka Kanata',
        artist: 'Asian Kung-Fu Generation',
        album: 'Houkai Amplifier (Naruto OP 2)',
        albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/59e663cf6ec111f1969ec232aa9a0a88/1000x1000-000000-80-0-0.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=nJ6A6GC_ki4',
        duration: const Duration(minutes: 4, seconds: 3),
      ),
      Song(
        id: 'naruto_ikimono_bluebird',
        title: 'Blue Bird',
        artist: 'Ikimono Gakari',
        album: 'My Song Your Song (Naruto Shippuden OP 3)',
        albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/c938ec08bb46c750b3e58c0e7fe7cba0/1000x1000-000000-80-0-0.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=KpsJWFuVTdI',
        duration: const Duration(minutes: 3, seconds: 36),
      ),
      Song(
        id: 'naruto_sambomaster_seishun',
        title: 'Seishun Kyousoukyoku',
        artist: 'Sambomaster',
        album: 'Gekidou Narukemono (Naruto OP 5)',
        albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/c00c7cb7ef1694aa2b5a14db3582103f/1000x1000-000000-80-0-0.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=68Kk-n_kXw8',
        duration: const Duration(minutes: 4, seconds: 45),
      ),
      Song(
        id: 'naruto_nico_diver',
        title: 'Diver',
        artist: 'NICO Touches the Walls',
        album: 'PASSENGER (Naruto Shippuden OP 8)',
        albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/bfdf1d619aeefafb265dbb43f1190db0/1000x1000-000000-80-0-0.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=hGzY2R6Q8hU',
        duration: const Duration(minutes: 4, seconds: 10),
      ),
      Song(
        id: 'naruto_does_guren',
        title: 'Guren',
        artist: 'DOES',
        album: 'Guren (Naruto Shippuden OP 15)',
        albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/6c026d36e2f42a6c8b9db77b318bf973/1000x1000-000000-80-0-0.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=yPkWK8NqWfI',
        duration: const Duration(minutes: 4, seconds: 2),
      ),
      Song(
        id: 'naruto_nobodyknows_heros',
        title: 'Hero\'s Come Back!!',
        artist: 'Nobodyknows+',
        album: 'Hero\'s Come Back!! (Naruto Shippuden OP 1)',
        albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/d1c322b7a9f997cb0f19e4ffc18aa002/1000x1000-000000-80-0-0.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=uK8s1vKk8U0',
        duration: const Duration(minutes: 4, seconds: 35),
      ),
      Song(
        id: 'naruto_akeboshi_wind',
        title: 'Wind',
        artist: 'Akeboshi',
        album: 'Akeboshi (Naruto ED 1)',
        albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/78627c2f689fcf2908f51a4f00fe325c/1000x1000-000000-80-0-0.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=I6q4k7Z0qQ4',
        duration: const Duration(minutes: 3, seconds: 41),
      ),
      Song(
        id: 'naruto_seven_oops_sayonara',
        title: 'Sayonara Memory',
        artist: '7!!',
        album: 'Sayonara Memory (Naruto Shippuden ED 24)',
        albumArtUrl: 'https://cdn-images.dzcdn.net/images/cover/3bfd12eefc7f2178ff0b80f156cb8b3f/1000x1000-000000-80-0-0.jpg',
        audioUrl: 'https://www.youtube.com/watch?v=gT8v87jD8lI',
        duration: const Duration(minutes: 3, seconds: 45),
      ),
    ];
  }

  static String _buildDailyMixCoverUrl(List<Song> songs) {
    final urls = songs
        .map((s) => s.albumArtUrl)
        .where((u) => u.isNotEmpty)
        .toSet()
        .take(4)
        .toList();
    if (urls.length >= 4) return 'collage:${urls.join("|")}';
    return urls.isNotEmpty ? urls.first : '';
  }
}

