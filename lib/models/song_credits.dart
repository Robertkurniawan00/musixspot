class SongCreditItem {
  final String name;
  final String role; // e.g., 'Artis Utama', 'Komposer', 'Penulis Lirik', 'Produser'
  final String? imageUrl;
  final bool isArtist;

  const SongCreditItem({
    required this.name,
    required this.role,
    this.imageUrl,
    this.isArtist = false,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'role': role,
    'imageUrl': imageUrl,
    'isArtist': isArtist,
  };

  factory SongCreditItem.fromJson(Map<String, dynamic> json) => SongCreditItem(
    name: json['name'] ?? '',
    role: json['role'] ?? '',
    imageUrl: json['imageUrl'],
    isArtist: json['isArtist'] ?? false,
  );
}

class SongCredits {
  final String trackTitle;
  final List<SongCreditItem> performers;
  final List<SongCreditItem> writers;
  final List<SongCreditItem> producers;
  final String source;
  final String copyright;

  const SongCredits({
    required this.trackTitle,
    required this.performers,
    required this.writers,
    required this.producers,
    this.source = 'musixspot Audio Library',
    this.copyright = 'Hak Cipta Dilindungi Undang-Undang',
  });
}
