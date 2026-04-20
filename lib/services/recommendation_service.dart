import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/song_catalog.dart';
import '../models/discovered_track.dart';
import '../models/mood_result.dart';
import 'music_discovery_service.dart';

class RecommendationService {
  static const int _recentHistoryLimit = 10;
  static const int _recentDiscoveryHistoryLimit = 20;
  static const int _recentArtistHistoryLimit = 8;
  static const int _recentMoodPickHistoryLimit = 6;
  static const int _candidatePoolSize = 30;
  static const double _strongCandidateBand = 0.6;
  static const double _strongMatchThreshold = 0.35;
  static const double _recentSongPenalty = 0.65;
  static const double _recentArtistPenalty = 0.32;
  static const double _recentMoodPickPenalty = 0.22;
  static const List<String> _fallbackSongIds = [
    'max-richter-nature-of-daylight',
    'ludovico-einaudi-experience',
    'cinematic-orchestra-arrival-birds',
    'm83-wait',
    'tycho-awake',
    'brian-eno-an-ending',
    'agnes-obel-riverside',
    'sufjan-stevens-mystery-of-love',
    'sigur-ros-hoppipolla',
    'hans-zimmer-cornfield-chase',
    'sleeping-at-last-saturn',
    'explosions-your-hand-in-mine',
    'norah-jones-sunrise',
    'max-richter-infra-5',
    'air-alone-in-kyoto',
    'billy-joel-vienna',
    'jose-gonzalez-heartbeats',
    'paper-kites-bloom',
    'hollow-coves-coastline',
    'm83-outro',
    'radiohead-weird-fishes',
    'radiohead-everything-right-place',
    'sufjan-stevens-fourth-of-july',
    'hozier-cherry-wine-live',
    'kacey-musgraves-golden-hour',
    'jack-johnson-better-together',
    'edward-sharpe-home',
    'norah-jones-come-away-with-me',
    'beatles-here-comes-the-sun',
    'corinne-bailey-rae-put-your-records-on',
    'massive-attack-teardrop',
    'james-blake-retrograde',
    'portishead-glory-box',
    'kavinsky-nightcall',
    'phoebe-bridgers-moon-song',
    'fleetwood-mac-dreams',
    'massive-attack-angel',
  ];

  static final List<String> _recentSongIds = <String>[];
  static final List<String> _recentDiscoveredTrackKeys = <String>[];
  static final List<String> _recentArtistKeys = <String>[];
  static final Map<String, List<String>> _recentSongIdsByMood =
      <String, List<String>>{};

  RecommendationService({MusicDiscoveryService? musicDiscoveryService})
      : _musicDiscoveryService =
            musicDiscoveryService ?? MusicDiscoveryService();

  final MusicDiscoveryService _musicDiscoveryService;

  Future<SongResult> recommendSong(Map<String, dynamic> analysis) async {
    final request = _RecommendationRequest.fromAnalysis(analysis);

    final discoveredSong = await _tryDiscoverSong(request);
    if (discoveredSong != null) {
      return discoveredSong;
    }

    if (request.isFallback) {
      debugPrint('[Recommendation] falling back to local catalog');
      debugPrint('[Discovery] selectedSource=local');
      return fallbackSong(mood: request.mood);
    }

    final scoredSongs = kSongCatalog
        .map((song) => _ScoredSong(song, _scoreSong(song, request)))
        .toList()
      ..sort((a, b) {
        final scoreCompare = b.score.compareTo(a.score);
        if (scoreCompare != 0) {
          return scoreCompare;
        }

        final popularityCompare =
            b.song.popularity.compareTo(a.song.popularity);
        if (popularityCompare != 0) {
          return popularityCompare;
        }

        return a.song.id.compareTo(b.song.id);
      });

    if (scoredSongs.isEmpty) {
      debugPrint(
        '[Recommendation] no scored songs; using fallback: mood=${request.mood} scene=${request.scene} objects=${request.objectTerms}',
      );
      debugPrint('[Recommendation] falling back to local catalog');
      debugPrint('[Discovery] selectedSource=local');
      return fallbackSong(mood: request.mood);
    }

    if (scoredSongs.first.score < _strongMatchThreshold) {
      debugPrint(
        '[Recommendation] low top score but continuing with AI-ranked candidates: topScore=${scoredSongs.first.score} mood=${request.mood} scene=${request.scene} objects=${request.objectTerms}',
      );
    }

    final selectedScoredSong = _selectCandidate(scoredSongs);
    debugPrint('[Discovery] selectedSource=local');
    return _songResultFromEntry(selectedScoredSong.song, mood: request.mood);
  }

  Future<SongResult?> _tryDiscoverSong(_RecommendationRequest request) async {
    try {
      final discoveredTracks = await _musicDiscoveryService.discoverTracks(
        mood: request.mood,
        scene: request.scene,
        objects: request.objectTerms,
      );
      if (discoveredTracks.isEmpty) {
        debugPrint('[Recommendation] falling back to local catalog');
        return null;
      }

      final selectedTrack = _selectDiscoveredTrack(discoveredTracks, request);
      if (selectedTrack == null) {
        debugPrint('[Recommendation] falling back to local catalog');
        return null;
      }

      debugPrint('[Recommendation] using online discovery');
      debugPrint('[Discovery] selectedSource=${selectedTrack.source}');
      debugPrint(
        '[Discovery] selectedTrack=${selectedTrack.title} by ${selectedTrack.artist}',
      );
      return _songResultFromDiscoveredTrack(selectedTrack);
    } catch (error) {
      debugPrint('[Discovery] error=$error');
      debugPrint('[Recommendation] falling back to local catalog');
      return null;
    }
  }

  SongResult fallbackSong({String mood = 'reflective'}) {
    final normalizedMood = _RecommendationRequest.normalizeToken(
      mood,
      fallback: 'reflective',
    );
    final fallbackEntries = _fallbackSongIds
        .map(_songById)
        .whereType<SongCatalogEntry>()
        .toList();
    final curatedMoodEntries = fallbackEntries
        .where((song) => song.moods.contains(normalizedMood))
        .toList();
    final catalogMoodEntries = kSongCatalog
        .where((song) => song.moods.contains(normalizedMood))
        .toList();
    final entries = curatedMoodEntries.isNotEmpty
        ? curatedMoodEntries
        : catalogMoodEntries.isNotEmpty
            ? catalogMoodEntries
            : fallbackEntries.isNotEmpty
                ? fallbackEntries
                : kSongCatalog;
    final scoredSongs = entries
        .map((song) {
          var score = 0.2 + (song.popularity / 100);
          if (song.mood == normalizedMood) {
            score += 0.5;
          } else if (song.moods.contains(normalizedMood)) {
            score += 0.35;
          }
          if (song.moods.contains('reflective') ||
              song.moods.contains('peaceful')) {
            score += 0.1;
          }
          if (song.moods.contains('cinematic')) {
            score += 0.1;
          }
          if (_recentSongIds.contains(song.id)) {
            score -= _recentSongPenalty;
          }
          if (_recentArtistKeys.contains(_artistKey(song.artist))) {
            score -= _recentArtistPenalty;
          }
          return _ScoredSong(song, score);
        })
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    return _songResultFromEntry(
      _selectCandidate(scoredSongs).song,
      mood: normalizedMood,
    );
  }

  SongResult _songResultFromEntry(SongCatalogEntry selected, {String? mood}) {
    _remember(selected, mood: mood);
    return SongResult(
      title: selected.title,
      artist: selected.artist,
      album: selected.album,
      albumArtUrl: selected.albumArtUrl,
    );
  }

  SongResult _songResultFromDiscoveredTrack(DiscoveredTrack selected) {
    _rememberDiscovered(selected);
    return SongResult(
      title: selected.title,
      artist: selected.artist,
      album: selected.album,
      albumArtUrl: selected.coverUrl ?? '',
    );
  }

  _ScoredSong _selectCandidate(List<_ScoredSong> scoredSongs) {
    if (scoredSongs.isEmpty) {
      throw StateError('Song catalog is empty');
    }

    final candidatePool = scoredSongs.take(_candidatePoolSize).toList();
    debugPrint('[Recommendation] candidatePoolSize=${candidatePool.length}');

    final bestScore = candidatePool.first.score;
    final strongCandidates = candidatePool
        .where((item) => item.score >= bestScore - _strongCandidateBand)
        .toList();
    debugPrint(
      '[Recommendation] strongCandidatesSize=${strongCandidates.length}',
    );

    final shuffled = strongCandidates.toList()..shuffle();
    return shuffled.first;
  }

  DiscoveredTrack? _selectDiscoveredTrack(
    List<DiscoveredTrack> discoveredTracks,
    _RecommendationRequest request,
  ) {
    final scoredTracks = discoveredTracks
        .where((track) => track.hasUsableIdentity)
        .map((track) => _ScoredDiscoveredTrack(
              track,
              _scoreDiscoveredTrack(track, request),
            ))
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    if (scoredTracks.isEmpty) {
      return null;
    }

    final unseenTracks = scoredTracks
        .where((item) => !_recentDiscoveredTrackKeys.contains(
              _discoveredTrackKey(item.track),
            ))
        .toList();
    final rotationPool = unseenTracks.isNotEmpty ? unseenTracks : scoredTracks;
    final differentArtistPool = rotationPool
        .where((item) => !_recentArtistKeys.contains(
              _artistKey(item.track.artist),
            ))
        .toList();
    final candidatePool =
        differentArtistPool.isNotEmpty ? differentArtistPool : rotationPool;
    final bestScore = candidatePool.first.score;
    final strongCandidates = candidatePool
        .where((item) => item.score >= bestScore - _strongCandidateBand)
        .toList();
    final shuffled = strongCandidates.toList()..shuffle();

    return shuffled.first.track;
  }

  double _scoreSong(SongCatalogEntry song, _RecommendationRequest request) {
    final inputObjects = request.objectTerms;
    final moodScore = song.mood == request.mood ? 1.0 : 0.0;
    final sceneScore = song.sceneTags.contains(request.scene) ? 1.0 : 0.0;
    final objectScore =
        _matchCount(song.objectTags, inputObjects) / max(1, inputObjects.length);

    var score = moodScore * 0.5 + sceneScore * 0.3 + objectScore * 0.2;

    if (_recentSongIds.contains(song.id)) {
      score -= _recentSongPenalty;
    }

    if (_recentArtistKeys.contains(_artistKey(song.artist))) {
      score -= _recentArtistPenalty;
    }

    final moodRecentIds = _recentSongIdsByMood[request.mood] ?? const <String>[];
    if (moodRecentIds.contains(song.id)) {
      score -= _recentMoodPickPenalty;
    }

    return score;
  }

  double _scoreDiscoveredTrack(
    DiscoveredTrack track,
    _RecommendationRequest request,
  ) {
    final searchableText = [
      track.title,
      track.artist,
      track.album,
      track.matchedQuery,
    ].join(' ').toLowerCase();
    var score = track.score;

    if (searchableText.contains(request.mood)) {
      score += 0.35;
    }

    if (request.scene.isNotEmpty && searchableText.contains(request.scene)) {
      score += 0.2;
    }

    for (final object in request.objectTerms.take(3)) {
      if (searchableText.contains(object)) {
        score += 0.08;
      }
    }

    if (_recentDiscoveredTrackKeys.contains(_discoveredTrackKey(track))) {
      score -= _recentSongPenalty;
    }

    if (_recentArtistKeys.contains(_artistKey(track.artist))) {
      score -= _recentArtistPenalty;
    }

    return score;
  }

  int _matchCount(List<String> songTerms, Set<String> requestTerms) {
    var count = 0;
    for (final term in songTerms) {
      if (requestTerms.contains(term)) {
        count++;
      }
    }
    return count;
  }

  SongCatalogEntry? _songById(String id) {
    for (final song in kSongCatalog) {
      if (song.id == id) {
        return song;
      }
    }
    return null;
  }

  void _remember(SongCatalogEntry song, {String? mood}) {
    _recentSongIds.remove(song.id);
    _recentSongIds.add(song.id);

    if (_recentSongIds.length > _recentHistoryLimit) {
      _recentSongIds.removeAt(0);
    }

    final artist = _artistKey(song.artist);
    _recentArtistKeys.remove(artist);
    _recentArtistKeys.add(artist);

    if (_recentArtistKeys.length > _recentArtistHistoryLimit) {
      _recentArtistKeys.removeAt(0);
    }

    if (mood != null && mood.isNotEmpty) {
      final moodRecentIds =
          _recentSongIdsByMood.putIfAbsent(mood, () => <String>[]);
      moodRecentIds.remove(song.id);
      moodRecentIds.add(song.id);

      if (moodRecentIds.length > _recentMoodPickHistoryLimit) {
        moodRecentIds.removeAt(0);
      }
    }
  }

  void _rememberDiscovered(DiscoveredTrack track) {
    final key = _discoveredTrackKey(track);
    _recentDiscoveredTrackKeys.remove(key);
    _recentDiscoveredTrackKeys.add(key);

    if (_recentDiscoveredTrackKeys.length > _recentDiscoveryHistoryLimit) {
      _recentDiscoveredTrackKeys.removeAt(0);
    }

    final artist = _artistKey(track.artist);
    _recentArtistKeys.remove(artist);
    _recentArtistKeys.add(artist);

    if (_recentArtistKeys.length > _recentArtistHistoryLimit) {
      _recentArtistKeys.removeAt(0);
    }
  }

  String _artistKey(String artist) => artist.trim().toLowerCase();

  String _discoveredTrackKey(DiscoveredTrack track) => track.dedupeKey;
}

class _RecommendationRequest {
  final String mood;
  final String scene;
  final Set<String> objectTerms;
  final bool isFallback;

  const _RecommendationRequest({
    required this.mood,
    required this.scene,
    required this.objectTerms,
    required this.isFallback,
  });

  factory _RecommendationRequest.fromAnalysis(Map<String, dynamic> analysis) {
    final scene = normalizeToken(analysis['scene'], fallback: 'unknown');
    final objects = _normalizeList(analysis['objects']);

    return _RecommendationRequest(
      mood: normalizeToken(analysis['mood'], fallback: 'reflective'),
      scene: scene,
      objectTerms: objects.toSet(),
      isFallback: analysis['_isFallback'] == true,
    );
  }

  static String normalizeToken(dynamic value, {required String fallback}) {
    if (value is! String) {
      return fallback;
    }

    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return normalized.isEmpty ? fallback : normalized;
  }

  static List<String> _normalizeList(dynamic value) {
    if (value is! List) {
      return const [];
    }

    return value
        .whereType<String>()
        .map((item) => normalizeToken(item, fallback: ''))
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }
}

class _ScoredSong {
  final SongCatalogEntry song;
  final double score;

  const _ScoredSong(this.song, this.score);
}

class _ScoredDiscoveredTrack {
  final DiscoveredTrack track;
  final double score;

  const _ScoredDiscoveredTrack(this.track, this.score);
}
