import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/discovered_track.dart';

abstract class MusicCatalogProvider {
  Future<List<DiscoveredTrack>> searchTracks(List<String> queries);
}

class DeezerCatalogProvider implements MusicCatalogProvider {
  DeezerCatalogProvider({http.Client? client}) : _client = client ?? http.Client();

  static const String sourceName = 'deezer';
  static const int _limitPerQuery = 18;

  final http.Client _client;

  @override
  Future<List<DiscoveredTrack>> searchTracks(List<String> queries) async {
    final results = <DiscoveredTrack>[];

    for (final query in queries) {
      try {
        final uri = Uri.https('api.deezer.com', '/search', {
          'q': query,
          'limit': _limitPerQuery.toString(),
        });
        final response = await _client.get(uri);

        if (response.statusCode != 200) {
          debugPrint(
            '[Discovery] deezerStatus=${response.statusCode} query=$query',
          );
          continue;
        }

        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) {
          debugPrint('[Discovery] invalidJson query=$query');
          continue;
        }

        final data = decoded['data'];
        if (data is! List) {
          continue;
        }

        for (var index = 0; index < data.length; index++) {
          final item = data[index];
          if (item is! Map<String, dynamic>) {
            continue;
          }

          final track = _trackFromDeezerItem(
            item,
            matchedQuery: query,
            rank: index,
          );
          if (track != null && track.hasUsableIdentity) {
            results.add(track);
          }
        }
      } on FormatException {
        debugPrint('[Discovery] invalidJson query=$query');
      } catch (error) {
        debugPrint('[Discovery] deezerError=$error query=$query');
      }
    }

    return results;
  }

  DiscoveredTrack? _trackFromDeezerItem(
    Map<String, dynamic> item, {
    required String matchedQuery,
    required int rank,
  }) {
    final title = _stringValue(item['title_short']) ?? _stringValue(item['title']);
    final artistMap = item['artist'];
    final albumMap = item['album'];
    final artist = artistMap is Map<String, dynamic>
        ? _stringValue(artistMap['name'])
        : null;
    final album = albumMap is Map<String, dynamic>
        ? _stringValue(albumMap['title'])
        : null;

    if (title == null || artist == null) {
      return null;
    }

    final itemId = item['id'];

    return DiscoveredTrack(
      id: itemId == null ? '$artist::$title' : '$itemId',
      title: title,
      artist: artist,
      album: album ?? '',
      coverUrl: albumMap is Map<String, dynamic>
          ? _stringValue(albumMap['cover_medium']) ??
              _stringValue(albumMap['cover_big']) ??
              _stringValue(albumMap['cover'])
          : null,
      previewUrl: _stringValue(item['preview']),
      link: _stringValue(item['link']),
      source: sourceName,
      matchedQuery: matchedQuery,
      score: 1.0 - (rank * 0.02),
    );
  }

  String? _stringValue(dynamic value) {
    if (value is! String) {
      return null;
    }

    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

class LastFmSimilarityProvider {
  const LastFmSimilarityProvider();

  Future<List<DiscoveredTrack>> expandFromSeedTracks(
    List<DiscoveredTrack> seedTracks,
  ) async {
    return const <DiscoveredTrack>[];
  }
}

class MusicDiscoveryService {
  MusicDiscoveryService({
    MusicCatalogProvider? catalogProvider,
    LastFmSimilarityProvider? similarityProvider,
  })  : _catalogProvider = catalogProvider ?? DeezerCatalogProvider(),
        _similarityProvider =
            similarityProvider ?? const LastFmSimilarityProvider();

  final MusicCatalogProvider _catalogProvider;
  final LastFmSimilarityProvider _similarityProvider;

  Future<List<DiscoveredTrack>> discoverTracks({
    required String mood,
    required String scene,
    required Iterable<String> objects,
  }) async {
    final queries = _buildQueries(
      mood: mood,
      scene: scene,
      objects: objects,
    );
    debugPrint("[Discovery] queries=${queries.join(' | ')}");

    final rawResults = await _catalogProvider.searchTracks(queries);
    debugPrint('[Discovery] rawResults=${rawResults.length}');

    final dedupedResults = _dedupe(rawResults);
    debugPrint('[Discovery] dedupedResults=${dedupedResults.length}');

    await _similarityProvider.expandFromSeedTracks(dedupedResults);

    return dedupedResults;
  }

  List<String> _buildQueries({
    required String mood,
    required String scene,
    required Iterable<String> objects,
  }) {
    final normalizedMood = _normalize(mood);
    final normalizedScene = _normalize(scene);
    final normalizedObjects = objects
        .map(_normalize)
        .where((object) => object.isNotEmpty)
        .take(2)
        .toList();
    final mappedQueries = _mappedQueries(
      mood: normalizedMood,
      scene: normalizedScene,
      objects: normalizedObjects,
    );
    final directQueries = <String>[
      if (normalizedMood.isNotEmpty) normalizedMood,
      if (normalizedMood.isNotEmpty && normalizedScene.isNotEmpty)
        '$normalizedMood $normalizedScene',
      if (normalizedMood.isNotEmpty && normalizedObjects.isNotEmpty)
        '$normalizedMood ${normalizedObjects.join(' ')}',
    ];

    return <String>[
      ...mappedQueries,
      ...directQueries,
    ].where((query) => query.trim().isNotEmpty).toSet().take(5).toList();
  }

  List<String> _mappedQueries({
    required String mood,
    required String scene,
    required List<String> objects,
  }) {
    final terms = <String>{scene, ...objects};

    if (_containsAny(
      terms,
      const {'hillside', 'mountain', 'forest', 'trees', 'sky'},
    )) {
      if (_containsAny({mood}, const {'peaceful', 'calm', 'reflective'})) {
        return const [
          'peaceful ambient',
          'nature acoustic',
          'calm instrumental',
        ];
      }
    }

    if (_containsAny(terms, const {'urban', 'city', 'street', 'night'})) {
      if (scene == 'night' || terms.contains('night')) {
        return const [
          'night drive',
          'urban chill',
          'late night hip hop',
        ];
      }
    }

    if (mood == 'romantic' || terms.contains('sunset')) {
      return const [
        'romantic acoustic',
        'love songs',
        'soft pop',
      ];
    }

    if (_containsAny({mood}, const {'energetic', 'happy', 'joyful'})) {
      return const [
        'feel good indie',
        'upbeat pop',
        'sunny dance',
      ];
    }

    if (_containsAny({mood}, const {'sad', 'melancholic', 'lonely'})) {
      return const [
        'melancholic indie',
        'sad acoustic',
        'emotional piano',
      ];
    }

    return <String>[
      if (mood.isNotEmpty) '$mood music',
      if (scene.isNotEmpty) '$scene music',
    ];
  }

  List<DiscoveredTrack> _dedupe(List<DiscoveredTrack> tracks) {
    final seen = <String>{};
    final deduped = <DiscoveredTrack>[];

    for (final track in tracks) {
      final key = track.dedupeKey;
      if (seen.add(key)) {
        deduped.add(track);
      }
    }

    return deduped;
  }

  bool _containsAny(Set<String> values, Set<String> candidates) {
    for (final candidate in candidates) {
      if (values.contains(candidate)) {
        return true;
      }
    }
    return false;
  }

  String _normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
