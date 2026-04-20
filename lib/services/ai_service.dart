import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class AIService {
  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';

  static const List<String> _approvedMoods = [
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
  ];

  static const List<String> _approvedSettings = [
    'indoor',
    'outdoor',
    'mixed',
    'unknown',
  ];

  static const List<String> _approvedTimes = [
    'morning',
    'day',
    'sunset',
    'night',
    'unknown',
  ];

  static const List<String> _approvedEnergy = [
    'low',
    'medium',
    'high',
  ];

  String get _apiKey => dotenv.env['OPENAI_API_KEY'] ?? '';

  Future<Map<String, dynamic>> analyzeImage(String imagePath) async {
    if (_apiKey.isEmpty || _apiKey == 'your_openai_api_key_here') {
      debugPrint('AI analysis fallback: missing OpenAI key');
      return _fallbackAnalysis(imagePath, reason: 'missing_api_key');
    }

    try {
      final imageBytes = await File(imagePath).readAsBytes();
      final base64Image = base64Encode(imageBytes);

      final response = await http
          .post(
            Uri.parse(_baseUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
            body: jsonEncode({
              'model': 'gpt-4o-mini',
              'temperature': 0.1,
              'max_tokens': 180,
              'response_format': {'type': 'json_object'},
              'messages': [
                {
                  'role': 'system',
                  'content':
                      'You extract structured music-recommendation signals from photos. Return strict JSON only.',
                },
                {
                  'role': 'user',
                  'content': [
                    {
                      'type': 'text',
                      'text': '''
Analyze this image for music recommendation.

Return exactly this JSON shape:
{
  "scene": "classroom",
  "objects": ["chalkboard", "notes", "desk"],
  "setting": "indoor",
  "time_of_day": "day",
  "energy": "medium",
  "mood": "focused",
  "tags": ["study", "thoughtful", "academic"]
}

Rules:
- no prose
- no markdown
- no extra keys
- all values lowercase
- scene must be one short label such as classroom, beach, city, car, bedroom, cafe, forest, mountain, party, street, workspace, sunset, unknown
- objects max 5
- tags max 3
- setting must be one of: indoor, outdoor, mixed, unknown
- time_of_day must be one of: morning, day, sunset, night, unknown
- energy must be one of: low, medium, high
- mood must be one of: peaceful, nostalgic, dreamy, urban, focused, lonely, romantic, playful, cinematic, intense, melancholic, warm, mysterious, adventurous, reflective
''',
                    },
                    {
                      'type': 'image_url',
                      'image_url': {
                        'url': 'data:image/jpeg;base64,$base64Image',
                        'detail': 'high',
                      },
                    },
                  ],
                },
              ],
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        debugPrint(
          'AI analysis fallback: status=${response.statusCode} body=${response.body}',
        );
        return _fallbackAnalysis(
          imagePath,
          reason: 'http_${response.statusCode}',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final content =
          data['choices']?[0]?['message']?['content'] as String? ?? '';
      final analysis = _normalizeModelResponse(content);

      if (analysis != null) {
        debugPrint(
          'AI analysis success: mood=${analysis['mood']} scene=${analysis['scene']} setting=${analysis['setting']} time=${analysis['time_of_day']} energy=${analysis['energy']}',
        );
        return analysis;
      }

      debugPrint('AI analysis fallback: invalid JSON payload=$content');
      return _fallbackAnalysis(imagePath, reason: 'invalid_payload');
    } catch (e, st) {
      debugPrint('AI analysis fallback: error=$e');
      debugPrintStack(stackTrace: st);
      return _fallbackAnalysis(imagePath, reason: 'exception');
    }
  }

  Map<String, dynamic>? _normalizeModelResponse(String rawContent) {
    try {
      final cleaned = rawContent
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();

      final decoded = jsonDecode(cleaned) as Map<String, dynamic>;
      final mood = _normalizeMood(decoded['mood']);
      if (mood == null) {
        return null;
      }

      return {
        'scene': _normalizeToken(decoded['scene'], fallback: 'unknown'),
        'objects': _normalizeList(decoded['objects'], maxItems: 5),
        'setting': _normalizeEnum(
          decoded['setting'],
          allowed: _approvedSettings,
          fallback: 'unknown',
        ),
        'time_of_day': _normalizeEnum(
          decoded['time_of_day'],
          allowed: _approvedTimes,
          fallback: 'unknown',
        ),
        'energy': _normalizeEnum(
          decoded['energy'],
          allowed: _approvedEnergy,
          fallback: 'medium',
        ),
        'mood': mood,
        'tags': _normalizeList(decoded['tags'], maxItems: 3),
      };
    } catch (_) {
      return null;
    }
  }

  String? _normalizeMood(dynamic value) {
    if (value is! String) {
      return null;
    }

    final normalized = _cleanToken(value);
    if (_approvedMoods.contains(normalized)) {
      return normalized;
    }

    return null;
  }

  String _normalizeEnum(
    dynamic value, {
    required List<String> allowed,
    required String fallback,
  }) {
    if (value is! String) {
      return fallback;
    }

    final normalized = _cleanToken(value);
    return allowed.contains(normalized) ? normalized : fallback;
  }

  String _normalizeToken(dynamic value, {required String fallback}) {
    if (value is! String) {
      return fallback;
    }

    final normalized = _cleanToken(value);
    return normalized.isEmpty ? fallback : normalized;
  }

  List<String> _normalizeList(dynamic value, {required int maxItems}) {
    final normalized = <String>[];

    if (value is List) {
      for (final item in value) {
        if (item is! String) {
          continue;
        }

        final cleaned = _cleanToken(item);
        if (cleaned.isNotEmpty && !normalized.contains(cleaned)) {
          normalized.add(cleaned);
        }

        if (normalized.length == maxItems) {
          break;
        }
      }
    }

    return normalized;
  }

  String _cleanToken(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Map<String, dynamic> _fallbackAnalysis(
    String imagePath, {
    required String reason,
  }) {
    final fallbackRows = [
      {
        'scene': 'city',
        'objects': ['street', 'lights'],
        'setting': 'outdoor',
        'time_of_day': 'night',
        'energy': 'medium',
        'mood': 'urban',
        'tags': ['city', 'moody', 'night'],
      },
      {
        'scene': 'nature',
        'objects': ['sky', 'trees'],
        'setting': 'outdoor',
        'time_of_day': 'day',
        'energy': 'low',
        'mood': 'peaceful',
        'tags': ['calm', 'soft', 'still'],
      },
      {
        'scene': 'room',
        'objects': ['window', 'desk'],
        'setting': 'indoor',
        'time_of_day': 'day',
        'energy': 'medium',
        'mood': 'reflective',
        'tags': ['thoughtful', 'quiet', 'warm'],
      },
      {
        'scene': 'sunset',
        'objects': ['sky', 'clouds'],
        'setting': 'outdoor',
        'time_of_day': 'sunset',
        'energy': 'low',
        'mood': 'nostalgic',
        'tags': ['golden', 'faded', 'soft'],
      },
    ];

    final selected = fallbackRows[imagePath.hashCode.abs() % fallbackRows.length];

    debugPrint(
      'AI analysis fallback selected: reason=$reason mood=${selected['mood']} scene=${selected['scene']}',
    );

    return Map<String, dynamic>.from(selected);
  }
}
