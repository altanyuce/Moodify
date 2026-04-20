import 'package:flutter_test/flutter_test.dart';
import 'package:moodify/data/song_catalog.dart';
import 'package:moodify/services/recommendation_service.dart';

void main() {
  const requiredMoods = {
    'peaceful',
    'nostalgic',
    'dreamy',
    'urban',
    'focused',
    'lonely',
    'romantic',
    'playful',
    'cinematic',
    'intense',
    'melancholic',
    'warm',
    'mysterious',
    'adventurous',
    'reflective',
  };

  const requiredScenes = {
    'room',
    'home',
    'bedroom',
    'kitchen',
    'city',
    'street',
    'car',
    'train',
    'bus',
    'park',
    'forest',
    'beach',
    'lake',
    'mountain',
    'rain',
    'snow',
    'sunset',
    'sunrise',
    'night',
    'cafe',
    'restaurant',
    'classroom',
    'library',
    'office',
    'concert',
    'party',
    'gym',
    'roadtrip',
  };

  test('catalog has about 500 unique song IDs', () {
    final ids = kSongCatalog.map((song) => song.id).toList();
    final uniqueIds = ids.toSet();

    expect(kSongCatalog.length, 500);
    expect(uniqueIds.length, ids.length);
  });

  test('catalog covers every supported mood', () {
    final moodCounts = {
      for (final mood in requiredMoods)
        mood: kSongCatalog.where((song) => song.moods.contains(mood)).length,
    };

    // Printed only when running validation locally; keeps the summary close to
    // the check that enforces it.
    // ignore: avoid_print
    print('Mood coverage summary: $moodCounts');

    for (final mood in requiredMoods) {
      expect(moodCounts[mood], greaterThanOrEqualTo(20), reason: mood);
    }
  });

  test('catalog covers common photo scenes', () {
    final sceneCounts = {
      for (final scene in requiredScenes)
        scene: kSongCatalog.where((song) => song.scenes.contains(scene)).length,
    };

    // ignore: avoid_print
    print('Scene coverage summary: $sceneCounts');

    for (final scene in requiredScenes) {
      expect(sceneCounts[scene], greaterThan(0), reason: scene);
    }
  });

  test('fallback recommendations rotate through a safe varied pool', () {
    final service = RecommendationService();
    final seen = <String>{};

    for (var i = 0; i < 8; i++) {
      final song = service.fallbackSong();
      seen.add('${song.title}::${song.artist}');
    }

    expect(seen.length, greaterThanOrEqualTo(6));
    expect(seen, isNot(contains('Holocene::Bon Iver')));
  });

  test('near-identical recommendation requests avoid fixed repetition', () {
    final service = RecommendationService();
    final seen = <String>{};
    String? previous;

    for (var i = 0; i < 12; i++) {
      final song = service.recommendSong(const {
        'mood': 'urban',
        'scene': 'street',
        'objects': ['car', 'lights', 'buildings'],
        'setting': 'outdoor',
        'time_of_day': 'night',
        'energy': 'medium',
        'tags': ['city', 'neon'],
      });
      final key = '${song.title}::${song.artist}';

      expect(key, isNot(previous));
      seen.add(key);
      previous = key;
    }

    expect(seen.length, greaterThanOrEqualTo(8));
  });
}
