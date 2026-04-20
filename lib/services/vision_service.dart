import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class VisionService {
  static const String _model = 'gemini-2.5-flash';
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  static const List<String> _allowedMoods = [
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

  static const String _primaryPrompt = '''
Output only one raw JSON object.
No intro text. No explanation. No markdown. No code fences.
No text before or after the JSON.

Example:
{"mood":"peaceful","scene":"beach","objects":["water","sky","sand"]}

mood must be one of: peaceful, nostalgic, dreamy, urban, focused, lonely, romantic, playful, cinematic, intense, melancholic, warm, mysterious, adventurous, reflective.
scene must be one short lowercase word.
objects must be visible lowercase objects, max 5.
''';

  static const String _retryPrompt = '''
Return only raw JSON. No prose.
No markdown. No code fences. No text outside JSON.
Format: {"mood":"peaceful","scene":"room","objects":["window"]}
Allowed moods: peaceful, nostalgic, dreamy, urban, focused, lonely, romantic, playful, cinematic, intense, melancholic, warm, mysterious, adventurous, reflective.
''';

  static const List<Map<String, dynamic>> _fallbackAnalyses = [
    {
      'mood': 'reflective',
      'scene': 'unknown',
      'objects': <String>[],
      '_isFallback': true,
      'source': 'fallback',
    },
    {
      'mood': 'cinematic',
      'scene': 'unknown',
      'objects': <String>[],
      '_isFallback': true,
      'source': 'fallback',
    },
    {
      'mood': 'dreamy',
      'scene': 'night',
      'objects': <String>['light'],
      '_isFallback': true,
      'source': 'fallback',
    },
    {
      'mood': 'peaceful',
      'scene': 'room',
      'objects': <String>['window'],
      '_isFallback': true,
      'source': 'fallback',
    },
    {
      'mood': 'warm',
      'scene': 'home',
      'objects': <String>['light'],
      '_isFallback': true,
      'source': 'fallback',
    },
  ];

  static const Map<String, dynamic> _defaultFallbackAnalysis = {
    'mood': 'reflective',
    'scene': 'unknown',
    'objects': <String>[],
    '_isFallback': true,
    'source': 'fallback',
  };

  static const Duration _fallbackCacheTtl = Duration(seconds: 30);

  static final Map<String, Map<String, dynamic>> _realCache = {};
  static final Map<String, _CachedFallbackAnalysis> _fallbackCache = {};

  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');
  static bool _didLogMissingApiKey = false;

  String get _apiKeySource {
    if (_apiKey.isNotEmpty) {
      return 'dart_define';
    }
    return 'missing';
  }

  bool get _hasConfiguredApiKey =>
      _apiKey.isNotEmpty && _apiKey != 'your_gemini_api_key_here';

  Future<Map<String, dynamic>> analyzeImage(File image) async {
    final cachedAnalysis = _realCache[image.path];
    if (cachedAnalysis != null) {
      final analysis = Map<String, dynamic>.from(cachedAnalysis);
      _logResult('cached real result', analysis);
      return analysis;
    }

    if (!_hasConfiguredApiKey) {
      if (!_didLogMissingApiKey) {
        debugPrint('[Vision] api key present: no');
        debugPrint('[Vision] result source: fallback');
        debugPrint('[Vision] fallback reason: missing_api_key');
        _didLogMissingApiKey = true;
      }

      final cachedFallback = _validCachedFallback(image.path);
      if (cachedFallback != null) {
        _logResult('cached fallback result', cachedFallback);
        return cachedFallback;
      }

      return _fallback(image.path, reason: 'missing_api_key', cacheFallback: true);
    }

    try {
      final imageBytes = await image.readAsBytes();
      final base64Image = base64Encode(imageBytes);
      final mimeType = _mimeTypeForPath(image.path);
      _logRequest(
        imagePath: image.path,
        byteCount: imageBytes.length,
        base64Length: base64Image.length,
        mimeType: mimeType,
      );

      final response = await http
          .post(
            Uri.parse('$_baseUrl?key=$_apiKey'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'generationConfig': {
                'temperature': 0.1,
                'topK': 1,
                'topP': 0.8,
                'maxOutputTokens': 400,
                'responseMimeType': 'application/json',
              },
              'contents': [
                {
                  'role': 'user',
                  'parts': [
                    {'text': _primaryPrompt},
                    {
                      'inline_data': {
                        'mime_type': mimeType,
                        'data': base64Image,
                      },
                    },
                  ],
                },
              ],
            }),
          )
          .timeout(const Duration(seconds: 20));

      debugPrint('Vision API status: ${response.statusCode}');
      if (response.statusCode == 429) {
        debugPrint(
          'Vision API quota exhausted or rate limited: status=429',
        );
        return _fallback(
          image.path,
          reason: 'quota_exhausted_http_429',
        );
      }

      if (response.statusCode != 200) {
        return _fallback(
          image.path,
          reason: 'api_fail_http_${response.statusCode}',
        );
      }

      try {
        final analysis = _parseResponseAnalysis(response.body);
        return _cacheAiResult(image.path, analysis, 'real AI result');
      } on FormatException catch (error) {
        debugPrint('[Vision] first attempt parse failed: ${error.message}');
        debugPrint('[Vision] retry started');

        final retryResponse = await http
            .post(
              Uri.parse('$_baseUrl?key=$_apiKey'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(_requestBody(
                mimeType: mimeType,
                base64Image: base64Image,
                prompt: _retryPrompt,
              )),
            )
            .timeout(const Duration(seconds: 20));

        debugPrint('[Vision] retry response status: ${retryResponse.statusCode}');
        if (retryResponse.statusCode == 429) {
          debugPrint(
            'Vision API quota exhausted or rate limited on retry: status=429',
          );
          return _fallback(
            image.path,
            reason: 'quota_exhausted_http_429',
          );
        }

        if (retryResponse.statusCode != 200) {
          debugPrint('[Vision] retry failed: http_${retryResponse.statusCode}');
          return _fallback(
            image.path,
            reason: 'api_fail_retry_http_${retryResponse.statusCode}',
          );
        }

        try {
          final retryAnalysis = _parseResponseAnalysis(retryResponse.body);
          debugPrint('[Vision] retry succeeded');
          return _cacheAiResult(
            image.path,
            retryAnalysis,
            'retry AI result',
          );
        } on FormatException catch (retryError) {
          debugPrint('[Vision] retry failed: ${retryError.message}');
          return _fallback(
            image.path,
            reason: 'parse_fail_retry_${retryError.message}',
          );
        }
      }
    } on FormatException catch (error) {
      return _fallback(image.path, reason: 'parse_fail_${error.message}');
    } catch (error, stackTrace) {
      debugPrint('Vision API unexpected failure: $error');
      debugPrintStack(stackTrace: stackTrace);
      return _fallback(
        image.path,
        reason: 'api_fail_${error.runtimeType}',
      );
    }
  }

  Map<String, dynamic> _fallback(
    String imagePath, {
    required String reason,
    bool cacheFallback = false,
  }) {
    final analysis = {
      ...Map<String, dynamic>.from(_fallbackForImage(imagePath)),
      '_isFallback': true,
      'source': 'fallback',
      'fallbackReason': reason,
    };
    if (cacheFallback) {
      _fallbackCache[imagePath] = _CachedFallbackAnalysis(
        Map<String, dynamic>.from(analysis),
        DateTime.now(),
      );
    }
    _logResult('fallback result reason=$reason', analysis);
    debugPrint('[Vision] final result source: fallback');
    return analysis;
  }

  Map<String, dynamic> _cacheAiResult(
    String imagePath,
    Map<String, dynamic> analysis,
    String logSource,
  ) {
    _realCache[imagePath] = Map<String, dynamic>.from(analysis);
    _fallbackCache.remove(imagePath);
    _logResult(logSource, analysis);
    debugPrint('[Vision] final result source: ai');
    return analysis;
  }

  Map<String, dynamic> _requestBody({
    required String mimeType,
    required String base64Image,
    required String prompt,
  }) {
    return {
      'generationConfig': {
        'temperature': 0.1,
        'topK': 1,
        'topP': 0.8,
        'maxOutputTokens': 400,
        'responseMimeType': 'application/json',
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt},
            {
              'inline_data': {
                'mime_type': mimeType,
                'data': base64Image,
              },
            },
          ],
        },
      ],
    };
  }

  Map<String, dynamic> _parseResponseAnalysis(String responseBody) {
    final responseJson = _decodeResponseBody(responseBody);
    debugPrint('Vision parsed API JSON: $responseJson');
    final text = _extractText(responseJson);
    return _applyMoodCorrection(_parseAnalysis(text));
  }

  Map<String, dynamic>? _validCachedFallback(String imagePath) {
    final cached = _fallbackCache[imagePath];
    if (cached == null) {
      return null;
    }

    if (DateTime.now().difference(cached.createdAt) > _fallbackCacheTtl) {
      _fallbackCache.remove(imagePath);
      return null;
    }

    return Map<String, dynamic>.from(cached.analysis);
  }

  Map<String, dynamic> _fallbackForImage(String imagePath) {
    if (imagePath.isEmpty) {
      return _defaultFallbackAnalysis;
    }

    final index = imagePath.codeUnits.fold<int>(
          0,
          (hash, value) => (hash * 31 + value) & 0x7fffffff,
        ) %
        _fallbackAnalyses.length;
    return _fallbackAnalyses[index];
  }

  void _logResult(String source, Map<String, dynamic> analysis) {
    debugPrint(
      'Vision result: source=$source resultSource=${analysis['source']} fallbackReason=${analysis['fallbackReason']} mood=${analysis['mood']} scene=${analysis['scene']} fallback=${analysis['_isFallback'] == true} objects=${analysis['objects']}',
    );
  }

  void _logRequest({
    required String imagePath,
    required int byteCount,
    required int base64Length,
    required String mimeType,
  }) {
    debugPrint(
      'Vision API request start: model=$_model endpoint=$_baseUrl apiKeyPresent=$_hasConfiguredApiKey apiKeySource=$_apiKeySource imagePath=$imagePath bytes=$byteCount base64Length=$base64Length mimeType=$mimeType',
    );
  }

  Map<String, dynamic> _decodeResponseBody(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      throw const FormatException('Gemini response root was not an object');
    } on FormatException {
      rethrow;
    } catch (error) {
      throw FormatException('Gemini response body was not valid JSON: $error');
    }
  }

  String _extractText(Map<String, dynamic> responseJson) {
    final candidates = responseJson['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw const FormatException('Gemini response had no candidates');
    }

    for (final candidate in candidates) {
      if (candidate is! Map<String, dynamic>) {
        continue;
      }

      final finishReason = candidate['finishReason'];
      if (finishReason != null && finishReason != 'STOP') {
        debugPrint('Vision candidate finishReason=$finishReason');
      }

      final content = candidate['content'];
      final parts = content is Map<String, dynamic> ? content['parts'] : null;
      if (parts is! List || parts.isEmpty) {
        continue;
      }

      for (final part in parts) {
        if (part is! Map<String, dynamic>) {
          continue;
        }

        final text = part['text'];
        if (text is String && text.trim().isNotEmpty) {
          debugPrint('Vision Gemini text part: $text');
          return text;
        }
      }
    }

    throw const FormatException('Gemini response had no usable text part');
  }

  Map<String, dynamic> _parseAnalysis(String rawText) {
    final jsonObject = _extractJsonObject(rawText);
    debugPrint('Vision extracted JSON object: $jsonObject');
    final decoded = _decodeAnalysisJson(jsonObject);
    debugPrint('Vision decoded analysis JSON: $decoded');
    final mood = _normalizeMood(decoded['mood']);

    if (mood == null) {
      throw const FormatException('Gemini response mood was missing or invalid');
    }

    return {
      'mood': mood,
      'scene': _normalizeToken(decoded['scene'], fallback: 'unknown'),
      'objects': _normalizeObjects(decoded['objects']),
      '_isFallback': false,
      'source': 'ai',
    };
  }

  Map<String, dynamic> _applyMoodCorrection(Map<String, dynamic> analysis) {
    const weakMoods = {'peaceful', 'reflective', 'dreamy'};
    const strongMoods = {'intense', 'cinematic', 'mysterious'};

    final mood = analysis['mood'];
    if (mood is! String || strongMoods.contains(mood)) {
      return analysis;
    }

    if (!weakMoods.contains(mood)) {
      return analysis;
    }

    final scene = analysis['scene'];
    final objects = analysis['objects'];
    final objectSet = objects is List
        ? objects.whereType<String>().map(_cleanToken).toSet()
        : <String>{};
    String? correctedMood;

    if (scene == 'gym' || objectSet.contains('dumbbell')) {
      correctedMood = 'intense';
    } else if (scene == 'concert' || objectSet.contains('stage')) {
      correctedMood = 'cinematic';
    } else if (scene == 'forest' || objectSet.contains('tree')) {
      correctedMood = 'peaceful';
    } else if (scene == 'city') {
      correctedMood = 'urban';
    }

    if (correctedMood == null || correctedMood == mood) {
      return analysis;
    }

    debugPrint(
      'Vision mood correction: mood=$mood correctedMood=$correctedMood scene=$scene objects=$objectSet',
    );
    return {
      ...analysis,
      'mood': correctedMood,
    };
  }

  Map<String, dynamic> _decodeAnalysisJson(String jsonObject) {
    try {
      final decoded = jsonDecode(jsonObject);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      throw const FormatException('Gemini analysis JSON was not an object');
    } on FormatException {
      rethrow;
    } catch (error) {
      throw FormatException('Gemini analysis JSON decode failed: $error');
    }
  }

  String _extractJsonObject(String rawText) {
    final text = rawText.trim();
    if (text.isEmpty) {
      throw const FormatException('Gemini response text was empty');
    }

    for (var start = 0; start < text.length; start++) {
      if (text.codeUnitAt(start) != 123) {
        continue;
      }

      final jsonObject = _balancedJsonObjectFrom(text, start);
      if (jsonObject == null) {
        continue;
      }

      try {
        _decodeAnalysisJson(jsonObject);
        return jsonObject;
      } catch (_) {
        continue;
      }
    }

    throw FormatException(
      'Gemini response text did not contain a valid JSON object: $text',
    );
  }

  String? _balancedJsonObjectFrom(String text, int start) {
    var depth = 0;
    var inString = false;
    var escaped = false;

    for (var index = start; index < text.length; index++) {
      final char = text[index];

      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (char == '\\') {
          escaped = true;
        } else if (char == '"') {
          inString = false;
        }
        continue;
      }

      if (char == '"') {
        inString = true;
        continue;
      }

      if (char == '{') {
        depth++;
      } else if (char == '}') {
        depth--;
        if (depth == 0) {
          return text.substring(start, index + 1);
        }
      }
    }

    return null;
  }

  String? _normalizeMood(dynamic value) {
    if (value is! String) {
      return null;
    }

    final mood = _cleanToken(value);
    return _allowedMoods.contains(mood) ? mood : null;
  }

  String _normalizeToken(dynamic value, {required String fallback}) {
    if (value is! String) {
      return fallback;
    }

    final token = _cleanToken(value);
    return token.isEmpty ? fallback : token.split(' ').first;
  }

  List<String> _normalizeObjects(dynamic value) {
    if (value is! List) {
      return const [];
    }

    final objects = <String>[];
    for (final item in value) {
      if (item is! String) {
        continue;
      }

      final object = _cleanToken(item);
      if (object.isNotEmpty && !objects.contains(object)) {
        objects.add(object);
      }

      if (objects.length == 5) {
        break;
      }
    }

    return objects;
  }

  String _cleanToken(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _mimeTypeForPath(String path) {
    final lowerPath = path.toLowerCase();
    if (lowerPath.endsWith('.png')) {
      return 'image/png';
    }
    if (lowerPath.endsWith('.webp')) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }
}

class _CachedFallbackAnalysis {
  final Map<String, dynamic> analysis;
  final DateTime createdAt;

  const _CachedFallbackAnalysis(this.analysis, this.createdAt);
}
