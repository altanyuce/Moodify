class DiscoveredTrack {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String? coverUrl;
  final String? previewUrl;
  final String? link;
  final String source;
  final String matchedQuery;
  final double score;

  const DiscoveredTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.coverUrl,
    required this.previewUrl,
    required this.link,
    required this.source,
    required this.matchedQuery,
    required this.score,
  });

  bool get hasUsableIdentity =>
      title.trim().isNotEmpty && artist.trim().isNotEmpty;

  String get dedupeKey =>
      '${title.trim().toLowerCase()}::${artist.trim().toLowerCase()}';
}
