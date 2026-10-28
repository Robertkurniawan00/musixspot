class Song {
  final String id;
  final String title;
  final String artist;
  String album;
  String albumArtUrl;
  final String audioUrl;
  Duration duration;
  final List<LyricLine>? lyrics;
  bool isLiked;
  bool isDownloaded;
  String? localFilePath;
  bool isFlac;
  String audioFormat;
  String bitDepth;
  String sampleRate;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.albumArtUrl,
    required this.audioUrl,
    required this.duration,
    this.lyrics,
    this.isLiked = false,
    this.isDownloaded = false,
    this.localFilePath,
    this.isFlac = false,
    this.audioFormat = 'AAC',
    this.bitDepth = '16-bit',
    this.sampleRate = '44.1 kHz',
  });

  String get qualityBadge => isFlac ? 'LOSSLESS 24-BIT / 44.1 kHz' : 'HIGH QUALITY';

  factory Song.fromItunesJson(Map<String, dynamic> json) {
    // 600x600 = Apple Music standard card size
    String rawArt = json['artworkUrl100'] ?? '';
    String highResArt = rawArt.replaceAll('100x100bb.jpg', '600x600bb.jpg');

    int durationMillis = json['trackTimeMillis'] ?? 30000;
    String rawTitle = (json['trackName'] ?? 'Unknown Track').toString();
    String rawArtist = (json['artistName'] ?? 'Unknown Artist').toString();
    String rawAlbum = (json['collectionName'] ?? 'Single').toString();

    String clean(String s) => s
        .replaceAll('&#39;', "'")
        .replaceAll('&#039;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ');

    return Song(
      id: (json['trackId'] ?? DateTime.now().millisecondsSinceEpoch).toString(),
      title: clean(rawTitle),
      artist: clean(rawArtist),
      album: clean(rawAlbum),
      albumArtUrl: highResArt,
      audioUrl: json['previewUrl'] ?? '',
      duration: Duration(milliseconds: durationMillis),
      lyrics: null,
      isFlac: false,
      audioFormat: 'AAC',
      bitDepth: '16-bit',
      sampleRate: '44.1 kHz',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'albumArtUrl': albumArtUrl,
      'audioUrl': audioUrl,
      'durationMillis': duration.inMilliseconds,
      'isLiked': isLiked,
      'isDownloaded': isDownloaded,
      'localFilePath': localFilePath,
      'lyrics': lyrics?.map((l) => l.toJson()).toList(),
      'isFlac': isFlac,
      'audioFormat': audioFormat,
      'bitDepth': bitDepth,
      'sampleRate': sampleRate,
    };
  }

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      artist: json['artist'] ?? '',
      album: json['album'] ?? '',
      albumArtUrl: json['albumArtUrl'] ?? '',
      audioUrl: json['audioUrl'] ?? '',
      duration: Duration(milliseconds: json['durationMillis'] ?? 30000),
      isLiked: json['isLiked'] ?? false,
      isDownloaded: json['isDownloaded'] ?? false,
      localFilePath: json['localFilePath'],
      lyrics: json['lyrics'] != null
          ? (json['lyrics'] as List).map((l) => LyricLine.fromJson(l)).toList()
          : null,
      isFlac: json['isFlac'] ?? false,
      audioFormat: json['audioFormat'] ?? 'AAC',
      bitDepth: json['bitDepth'] ?? '16-bit',
      sampleRate: json['sampleRate'] ?? '44.1 kHz',
    );
  }

  /// Returns null so songs without confirmed lyrics never display fake placeholder text
  static List<LyricLine>? generateSampleLyrics(String songTitle) => null;
}

class LyricLine {
  final Duration time;
  final String text;

  LyricLine({required this.time, required this.text});

  Map<String, dynamic> toJson() => {
        'timeMillis': time.inMilliseconds,
        'text': text,
      };

  factory LyricLine.fromJson(Map<String, dynamic> json) => LyricLine(
        time: Duration(milliseconds: json['timeMillis'] ?? 0),
        text: json['text'] ?? '',
      );
}
