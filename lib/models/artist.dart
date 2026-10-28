import 'song.dart';

class ArtistAlbum {
  final String id;
  final String title;
  final String coverUrl;
  final String releaseYear;
  final String type; // 'Album', 'EP', 'Single'
  final int trackCount;
  final List<Song> songs;

  const ArtistAlbum({
    required this.id,
    required this.title,
    required this.coverUrl,
    required this.releaseYear,
    this.type = 'Album',
    this.trackCount = 0,
    this.songs = const [],
  });
}

class Artist {
  final String id;
  final String name;
  final String imageUrl;
  final String headerImageUrl;
  final String monthlyListeners;
  final String bio;
  final bool isVerified;
  final List<Song> topTracks;
  final List<ArtistAlbum> albums;
  final String country;
  final List<String> genres;

  const Artist({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.headerImageUrl,
    required this.monthlyListeners,
    required this.bio,
    this.isVerified = true,
    required this.topTracks,
    this.albums = const [],
    this.country = 'Indonesia',
    this.genres = const ['Pop'],
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'imageUrl': imageUrl,
      'headerImageUrl': headerImageUrl,
      'monthlyListeners': monthlyListeners,
      'bio': bio,
      'isVerified': isVerified,
      'country': country,
      'genres': genres,
    };
  }

  factory Artist.fromJson(Map<String, dynamic> json) {
    return Artist(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      headerImageUrl: json['headerImageUrl'] ?? (json['imageUrl'] ?? ''),
      monthlyListeners: json['monthlyListeners'] ?? '10.000 pendengar bulanan',
      bio: json['bio'] ?? '${json['name']} adalah artis di katalog musik global.',
      isVerified: json['isVerified'] ?? true,
      topTracks: const [],
      albums: const [],
      country: json['country'] ?? 'Global',
      genres: (json['genres'] as List?)?.map((e) => e.toString()).toList() ?? const ['Pop'],
    );
  }
}
