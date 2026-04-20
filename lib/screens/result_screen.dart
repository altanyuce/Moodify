import 'dart:io';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/mood_result.dart';
import '../services/card_generator.dart';
import '../services/recommendation_service.dart';
import '../theme/moodify_theme.dart';
import 'home_screen.dart';

class ResultScreen extends StatefulWidget {
  final MoodResult result;

  const ResultScreen({super.key, required this.result});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey _cardKey = GlobalKey();
  final GlobalKey _shareCardKey = GlobalKey();
  late AnimationController _entranceController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _cardScaleAnimation;
  late Animation<Offset> _slideAnimation;
  late MoodResult _result;

  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    _result = widget.result;
    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.6),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );

    _cardScaleAnimation = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.35, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> _shareCard() async {
    setState(() => _isSharing = true);

    try {
      await Future.delayed(const Duration(milliseconds: 100));
      final cardPath = await CardGenerator.captureCard(
        _shareCardKey,
        pixelRatio: 3.0,
      );

      if (cardPath != null) {
        await Share.shareXFiles(
          [XFile(cardPath)],
          text:
              'My vibe right now: ${_result.mood} | ${_result.song?.title ?? ""} by ${_result.song?.artist ?? ""} | analyzed by Moodify',
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not generate card. Try again.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not generate card. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  void _retry() {
    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
      (route) => false,
    );
  }

  Future<void> _tryAnotherSuggestion() async {
    try {
    final recommendedSong = await
          RecommendationService().recommendSong(_result.analysis);
      final hasWeakSong = recommendedSong.title.trim().isEmpty ||
          recommendedSong.artist.trim().isEmpty;
      final song = _safeSong(recommendedSong);

      setState(() {
        _result = _result.copyWith(
          song: song,
          notice: hasWeakSong
              ? "No perfect match found, here's something close."
              : _result.notice,
        );
      });
    } catch (_) {
      setState(() {
        _result = _result.copyWith(
          song: _fallbackSong(),
          notice: "No perfect match found, here's something close.",
        );
      });
    }
  }

  SongResult _safeSong(SongResult song) {
    final title = song.title.trim();
    final artist = song.artist.trim();

    if (title.isEmpty || artist.isEmpty) {
      return _fallbackSong();
    }

    return SongResult(
      title: title,
      artist: artist,
      album: song.album.trim(),
      albumArtUrl: song.albumArtUrl,
      previewUrl: song.previewUrl,
      spotifyUrl: song.spotifyUrl,
    );
  }

  SongResult _fallbackSong() {
    return RecommendationService().fallbackSong();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MoodifyColors.baseBackground,
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Image.file(
              File(_result.imagePath),
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.center,
                  colors: [
                    Color(0xE6000000),
                    Color(0x99000000),
                    Color(0x33000000),
                    Color(0x00000000),
                  ],
                  stops: [0.0, 0.3, 0.6, 1.0],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: ColoredBox(
              color: Color(0xFFB67A2D).withOpacity(0.06),
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          _IconButton(
                            icon: Icons.arrow_back_ios_new_rounded,
                            onTap: _retry,
                          ),
                          const Spacer(),
                          Text(
                            'Your Vibe',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.72),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const Spacer(),
                          _IconButton(
                            icon: Icons.refresh_rounded,
                            onTap: _retry,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 18),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: _result.tags
                                  .map((tag) => _TagChip(label: tag))
                                  .toList(),
                            ),
                            const SizedBox(height: 16),
                            if (_result.notice != null) ...[
                              _NoticeBanner(message: _result.notice!),
                              const SizedBox(height: 16),
                            ],
                            _MoodDisplay(mood: _result.mood),
                            const SizedBox(height: 8),
                            _VisionSourceDebugText(result: _result),
                            const SizedBox(height: 28),
                            Container(
                              width: 56,
                              height: 2,
                              decoration: BoxDecoration(
                                gradient: MoodifyGradients.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 28),
                            if (_result.song != null)
                              _SongCard(song: _result.song!),
                            const SizedBox(height: 36),
                            ScaleTransition(
                              scale: _cardScaleAnimation,
                              child: _CardPreviewSection(
                                result: _result,
                                cardKey: _cardKey,
                              ),
                            ),
                            const SizedBox(height: 32),
                            _ShareButton(
                              isLoading: _isSharing,
                              onTap: _shareCard,
                            ),
                            const SizedBox(height: 14),
                            _SuggestionButton(onTap: _tryAnotherSuggestion),
                            const SizedBox(height: 14),
                            _RetryButton(onTap: _retry),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: MediaQuery.sizeOf(context).width + 32,
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: RepaintBoundary(
                  key: _shareCardKey,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: SizedBox(
                      width: 720,
                      height: 1280,
                      child: MoodCard(result: _result),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: Colors.white.withOpacity(0.04),
          child: InkWell(
            onTap: onTap,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: MoodifyColors.glassBorder,
                  width: 1,
                ),
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
          ),
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;

  const _TagChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: MoodifyColors.glassBorder,
          width: 1,
        ),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: MoodifyColors.warmText.withOpacity(0.95),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _MoodDisplay extends StatelessWidget {
  final String mood;

  const _MoodDisplay({required this.mood});

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FEELING',
            style: TextStyle(
              color: Colors.white.withOpacity(0.45),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            mood,
            style: const TextStyle(
              color: MoodifyColors.warmText,
              fontSize: 56,
              fontWeight: FontWeight.w900,
              height: 0.98,
              letterSpacing: -2.0,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Your soundtrack match is curated just below.',
            style: TextStyle(
              color: MoodifyColors.softText.withOpacity(0.9),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticeBanner extends StatelessWidget {
  final String message;

  const _NoticeBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: MoodifyColors.warmText.withOpacity(0.86),
            size: 19,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: MoodifyColors.softText.withOpacity(0.94),
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VisionSourceDebugText extends StatelessWidget {
  final MoodResult result;

  const _VisionSourceDebugText({required this.result});

  @override
  Widget build(BuildContext context) {
    final source = result.analysis['source'] as String?;
    final fallbackReason = result.analysis['fallbackReason'] as String?;
    final isFallback =
        source == 'fallback' || result.analysis['_isFallback'] == true;
    final label = isFallback
        ? 'Source: Fallback${fallbackReason == null ? '' : ' (reason: $fallbackReason)'}'
        : 'Source: AI';

    return Text(
      label,
      style: TextStyle(
        color: MoodifyColors.softText.withOpacity(0.68),
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _SongCard extends StatelessWidget {
  final SongResult song;

  const _SongCard({required this.song});

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 78,
              height: 78,
              child: song.albumArtUrl != null
                  ? CachedNetworkImage(
                      imageUrl: song.albumArtUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _AlbumArtPlaceholder(),
                      errorWidget: (_, __, ___) => _AlbumArtPlaceholder(),
                    )
                  : _AlbumArtPlaceholder(),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NOW PLAYING',
                  style: TextStyle(
                    color: MoodifyColors.warmText.withOpacity(0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.6,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  song.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  song.artist,
                  style: TextStyle(
                    color: MoodifyColors.softText.withOpacity(0.94),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  song.album,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: MoodifyGradients.primary,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: MoodifyColors.amber.withOpacity(0.32),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.music_note_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _AlbumArtPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2A2214),
            Color(0xFF121217),
          ],
        ),
      ),
      child: Icon(
        Icons.album_rounded,
        color: Colors.white.withOpacity(0.3),
        size: 28,
      ),
    );
  }
}

class _CardPreviewSection extends StatelessWidget {
  final MoodResult result;
  final GlobalKey cardKey;

  const _CardPreviewSection({
    required this.result,
    required this.cardKey,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SHARE PREVIEW',
          style: TextStyle(
            color: MoodifyColors.warmText.withOpacity(0.82),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.6,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Smaller on purpose so the track stays primary.',
          style: TextStyle(
            color: MoodifyColors.softText.withOpacity(0.86),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Container(
            width: 252,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: MoodifyColors.glassBorder),
            ),
            child: RepaintBoundary(
              key: cardKey,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: SizedBox(
                  width: 252,
                  height: 448,
                  child: MoodCard(
                    result: result,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ShareButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;

  const _ShareButton({
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: isLoading
                ? const LinearGradient(
                    colors: [Color(0xFF47454D), Color(0xFF37353D)],
                  )
                : MoodifyGradients.primary,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isLoading
                ? []
                : [
                    BoxShadow(
                      color: MoodifyColors.amber.withOpacity(0.38),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
          ),
          child: InkWell(
            onTap: isLoading ? null : onTap,
            borderRadius: BorderRadius.circular(16),
            splashColor: Colors.white.withOpacity(0.12),
            highlightColor: Colors.white.withOpacity(0.06),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else
                  const Icon(
                    Icons.ios_share_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                const SizedBox(width: 12),
                Text(
                  isLoading ? 'Generating Card...' : 'Share This Vibe',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SuggestionButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SuggestionButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: MoodifyColors.amber.withOpacity(0.14),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: MoodifyColors.amber.withOpacity(0.28),
              width: 1,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            splashColor: Colors.white.withOpacity(0.08),
            highlightColor: Colors.white.withOpacity(0.04),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.shuffle_rounded,
                  color: MoodifyColors.warmText.withOpacity(0.86),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  'Try another suggestion',
                  style: TextStyle(
                    color: MoodifyColors.warmText.withOpacity(0.92),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RetryButton extends StatelessWidget {
  final VoidCallback onTap;

  const _RetryButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: MoodifyColors.glassBorder,
              width: 1,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            splashColor: Colors.white.withOpacity(0.08),
            highlightColor: Colors.white.withOpacity(0.04),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white.withOpacity(0.64),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  'Try Another Photo',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.78),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.12),
                Colors.white.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: MoodifyColors.glassBorder,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
