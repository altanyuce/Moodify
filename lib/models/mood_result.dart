// lib/models/mood_result.dart

class MoodResult {
  final String mood;
  final List<String> tags;
  final SongResult? song;
  final String imagePath;
  final Map<String, dynamic> analysis;
  final String? notice;

  MoodResult({
    required this.mood,
    required this.tags,
    required this.imagePath,
    this.analysis = const {},
    this.notice,
    this.song,
  });

  MoodResult copyWith({
    String? mood,
    List<String>? tags,
    SongResult? song,
    String? imagePath,
    Map<String, dynamic>? analysis,
    String? notice,
  }) {
    return MoodResult(
      mood: mood ?? this.mood,
      tags: tags ?? this.tags,
      song: song ?? this.song,
      imagePath: imagePath ?? this.imagePath,
      analysis: analysis ?? this.analysis,
      notice: notice ?? this.notice,
    );
  }
}

class SongResult {
  final String title;
  final String artist;
  final String album;
  final String? albumArtUrl;
  final String? previewUrl;
  final String? spotifyUrl;

  SongResult({
    required this.title,
    required this.artist,
    required this.album,
    this.albumArtUrl,
    this.previewUrl,
    this.spotifyUrl,
  });

  factory SongResult.fromJson(Map<String, dynamic> json) {
    return SongResult(
      title: json['title'] ?? 'Unknown',
      artist: json['artist'] ?? 'Unknown Artist',
      album: json['album'] ?? '',
      albumArtUrl: json['albumArtUrl'],
      previewUrl: json['previewUrl'],
      spotifyUrl: json['spotifyUrl'],
    );
  }
}

// Mood color palette — top-level so it's accessible from the extension
const Map<String, List<int>> _kMoodColors = {
  'Melancholic': [0xFF1a1a2e, 0xFF16213e],
  'Energetic':   [0xFFFF6B35, 0xFFFF2D55],
  'Romantic':    [0xFF8B0000, 0xFF4a0030],
  'Peaceful':    [0xFF0f3460, 0xFF1b4332],
  'Anxious':     [0xFF2d1b69, 0xFF11998e],
  'Joyful':      [0xFFf7971e, 0xFFffd200],
  'Nostalgic':   [0xFF6b4423, 0xFF3d2b1f],
  'Mysterious':  [0xFF1a1a2e, 0xFF4a0030],
  'Hopeful':     [0xFF005c97, 0xFF363795],
  'Dark':        [0xFF0f0f0f, 0xFF1a1a1a],
  'Default':     [0xFF1a1a2e, 0xFF16213e],
};

extension MoodColor on String {
  List<int> get moodColors {
    for (final key in _kMoodColors.keys) {
      if (toLowerCase().contains(key.toLowerCase())) {
        return _kMoodColors[key]!;
      }
    }
    return _kMoodColors['Default']!;
  }
}
