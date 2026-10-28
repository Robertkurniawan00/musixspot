class PlatinumProfile {
  final String id;
  String name;
  String subtitle;
  String avatarLetter;
  List<String> preferredGenres;
  bool isPrimary;

  PlatinumProfile({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.avatarLetter,
    required this.preferredGenres,
    this.isPrimary = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'subtitle': subtitle,
        'avatarLetter': avatarLetter,
        'preferredGenres': preferredGenres,
        'isPrimary': isPrimary,
      };

  factory PlatinumProfile.fromJson(Map<String, dynamic> json) => PlatinumProfile(
        id: json['id'] ?? 'prof_default',
        name: json['name'] ?? 'Akun Utama',
        subtitle: json['subtitle'] ?? 'Profil Aktif',
        avatarLetter: json['avatarLetter'] ?? 'K',
        preferredGenres: List<String>.from(json['preferredGenres'] ?? ['Indie', 'Pop']),
        isPrimary: json['isPrimary'] ?? false,
      );
}

enum AudioFidelityTier {
  standard160k,
  veryHigh320k,
  platinumLossless24Bit,
}
