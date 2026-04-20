import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../services/recommendation_service.dart';
import '../services/vision_service.dart';
import '../models/mood_result.dart';
import 'result_screen.dart';
import '../theme/moodify_theme.dart';

class LoadingScreen extends StatefulWidget {
  final String imagePath;

  const LoadingScreen({super.key, required this.imagePath});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with TickerProviderStateMixin {
  late AnimationController _dotController;
  late AnimationController _progressController;
  late AnimationController _imageController;
  late Animation<double> _imageAnimation;

  int _currentPhraseIndex = 0;
  double _progress = 0.0;
  bool _isProcessing = true;

  final List<String> _loadingPhrases = [
    'Scanning the vibes...',
    'Reading the energy...',
    'Analyzing your mood...',
    'Finding the feeling...',
    'Tuning into emotions...',
    'Almost there...',
  ];

  Timer? _phraseTimer;

  @override
  void initState() {
    super.initState();

    _dotController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    _progressController = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    );

    _imageController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _imageAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _imageController, curve: Curves.easeOut),
    );

    _imageController.forward();

    _progressController.addListener(() {
      if (mounted) {
        setState(() => _progress = _progressController.value);
      }
    });

    _progressController.forward();

    _startPhraseRotation();
    _startAnalysis();
  }

  void _startPhraseRotation() {
    _phraseTimer = Timer.periodic(const Duration(milliseconds: 1400), (_) {
      if (mounted && _isProcessing) {
        setState(() {
          _currentPhraseIndex =
              (_currentPhraseIndex + 1) % _loadingPhrases.length;
        });
      }
    });
  }

  Future<void> _startAnalysis() async {
    try {
      final visionService = VisionService();
      final recommendationService = RecommendationService();

      final analysis = await visionService.analyzeImage(File(widget.imagePath));

      final rawMood = analysis['mood'] as String? ?? 'mysterious';
      final objects = (analysis['objects'] as List?)?.cast<String>() ?? [];
      final scene = analysis['scene'] as String? ?? 'unknown';
      final tags = objects.isNotEmpty ? objects.take(3).toList() : [scene];
      final mood = _formatMoodLabel(rawMood);
      final recommendedSong = await recommendationService.recommendSong(analysis);
      final hasWeakSong = recommendedSong.title.trim().isEmpty ||
          recommendedSong.artist.trim().isEmpty;
      final song = _safeSong(recommendedSong);
      final notice = analysis['_isFallback'] == true
          ? 'Could not analyze image, showing default recommendation.'
          : hasWeakSong
              ? "No perfect match found, here's something close."
          : null;

      if (mounted) {
        final elapsed = _progressController.value;
        if (elapsed < 0.7) {
          await Future.delayed(
            Duration(milliseconds: ((0.7 - elapsed) * 5000).toInt()),
          );
        }

        if (!mounted) {
          return;
        }

        setState(() => _isProcessing = false);

        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => ResultScreen(
              result: MoodResult(
                mood: mood,
                tags: tags,
                imagePath: widget.imagePath,
                analysis: analysis,
                notice: notice,
                song: song,
              ),
            ),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        final fallbackAnalysis = {
          'mood': 'peaceful',
          'scene': 'unknown',
          'objects': <String>[],
          '_isFallback': true,
          'source': 'fallback',
          'fallbackReason': 'analysis_exception',
        };
        final fallbackSong = _fallbackSong();

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ResultScreen(
              result: MoodResult(
                mood: 'Peaceful',
                tags: ['unknown'],
                imagePath: widget.imagePath,
                analysis: fallbackAnalysis,
                notice:
                    'Could not analyze image, showing default recommendation.',
                song: fallbackSong,
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _dotController.dispose();
    _progressController.dispose();
    _imageController.dispose();
    _phraseTimer?.cancel();
    super.dispose();
  }

  SongResult _safeSong(SongResult song) {
    if (song.title.trim().isEmpty || song.artist.trim().isEmpty) {
      return _fallbackSong();
    }

    return SongResult(
      title: song.title.trim(),
      artist: song.artist.trim(),
      album: song.album.trim(),
      albumArtUrl: song.albumArtUrl,
      previewUrl: song.previewUrl,
      spotifyUrl: song.spotifyUrl,
    );
  }

  SongResult _fallbackSong() {
    return RecommendationService().fallbackSong();
  }

  String _formatMoodLabel(String mood) {
    if (mood.isEmpty) {
      return 'Mysterious';
    }

    return mood
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map(
          (part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isProcessing,
      child: AbsorbPointer(
        absorbing: _isProcessing,
        child: Scaffold(
          backgroundColor: MoodifyColors.baseBackground,
          body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _imageAnimation,
              builder: (_, child) => Opacity(
                opacity: _imageAnimation.value * 0.4,
                child: child,
              ),
              child: Image.file(
                File(widget.imagePath),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.5),
                    MoodifyColors.baseBackground.withOpacity(0.88),
                    MoodifyColors.baseBackground,
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: MoodifyGradients.cinematicGlow,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),
                _ScanIndicator(animation: _dotController),
                const SizedBox(height: 48),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.3),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    _isProcessing
                        ? 'Analyzing image...'
                        : _loadingPhrases[_currentPhraseIndex],
                    key: ValueKey(_currentPhraseIndex),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This takes just a moment',
                  style: TextStyle(
                    color: MoodifyColors.softText.withOpacity(0.85),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const Spacer(flex: 2),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _progress,
                          backgroundColor: Colors.white.withOpacity(0.1),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            MoodifyColors.amber,
                          ),
                          minHeight: 3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${(_progress * 100).toInt()}%',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 60),
              ],
            ),
          ),
        ],
      ),
        ),
      ),
    );
  }
}

class _ScanIndicator extends StatelessWidget {
  final AnimationController animation;

  const _ScanIndicator({required this.animation});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: animation,
            builder: (_, __) => Transform.scale(
              scale: 0.9 + animation.value * 0.1,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: MoodifyColors.softYellow
                        .withOpacity(0.3 + animation.value * 0.3),
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: animation,
            builder: (_, __) => Transform.scale(
              scale: 0.85 + animation.value * 0.05,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: MoodifyColors.softYellow.withOpacity(0.12),
                  border: Border.all(
                    color: MoodifyColors.amber.withOpacity(0.6),
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: MoodifyGradients.primary,
            ),
            child: const Icon(
              Icons.psychology_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }
}
