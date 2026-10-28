import 'song.dart';

class Playlist {
  final String id;
  final String title;
  final String subtitle;
  final String coverUrl;
  final List<Song> songs;
  final bool isPinned;

  // Spotify-style playlist type flags
  final bool isDailyMix;
  final int dailyMixNumber; // 1, 2, 3, etc.
  final bool isReleaseRadar;
  final bool isDiscoverWeekly;

  Playlist({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.coverUrl,
    required List<Song> songs,
    this.isPinned = false,
    this.isDailyMix = false,
    this.dailyMixNumber = 0,
    this.isReleaseRadar = false,
    this.isDiscoverWeekly = false,
  }) : songs = normalizeCapacity(title, songs);

  /// Enforces exact song counts for playlists named "Top 10", "Top 25", "Top 50", "Top 100"
  static List<Song> normalizeCapacity(String title, List<Song> sourceSongs) {
    if (sourceSongs.isEmpty) return sourceSongs;
    final t = title.toLowerCase();
    int? requiredCount;
    if (RegExp(r'\btop\s*10\b').hasMatch(t)) {
      requiredCount = 10;
    } else if (RegExp(r'\btop\s*25\b').hasMatch(t)) {
      requiredCount = 25;
    } else if (RegExp(r'\btop\s*50\b').hasMatch(t)) {
      requiredCount = 50;
    } else if (RegExp(r'\btop\s*100\b').hasMatch(t)) {
      requiredCount = 100;
    }

    if (requiredCount == null) return sourceSongs;

    if (sourceSongs.length >= requiredCount) {
      return sourceSongs.sublist(0, requiredCount);
    }

    // If source has fewer songs, cycle through to reach exactly requiredCount
    final result = List<Song>.from(sourceSongs);
    int i = 0;
    while (result.length < requiredCount) {
      result.add(sourceSongs[i % sourceSongs.length]);
      i++;
    }
    return result;
  }

  /// Whether the coverUrl is a Daily Mix collage ("collage:url1|url2|url3|url4")
  bool get isCollageCover => coverUrl.startsWith('collage:');

  /// Parses the 4 image URLs from a collage cover
  List<String> get collageUrls {
    if (!isCollageCover) return [];
    return coverUrl.substring('collage:'.length).split('|');
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'coverUrl': coverUrl,
      'songs': songs.map((s) => s.toJson()).toList(),
      'isPinned': isPinned,
      'isDailyMix': isDailyMix,
      'dailyMixNumber': dailyMixNumber,
      'isReleaseRadar': isReleaseRadar,
      'isDiscoverWeekly': isDiscoverWeekly,
    };
  }

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      subtitle: json['subtitle'] ?? '',
      coverUrl: json['coverUrl'] ?? '',
      songs: json['songs'] != null
          ? (json['songs'] as List).map((s) => Song.fromJson(s)).toList()
          : [],
      isPinned: json['isPinned'] ?? false,
      isDailyMix: json['isDailyMix'] ?? false,
      dailyMixNumber: json['dailyMixNumber'] ?? 0,
      isReleaseRadar: json['isReleaseRadar'] ?? false,
      isDiscoverWeekly: json['isDiscoverWeekly'] ?? false,
    );
  }
}
