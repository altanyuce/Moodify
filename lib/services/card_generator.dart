import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import '../models/mood_result.dart';
import '../theme/moodify_theme.dart';

class CardGenerator {
  static Future<String?> captureCard(
    GlobalKey cardKey, {
    double pixelRatio = 2.0,
  }) async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));

      final BuildContext? context = cardKey.currentContext;
      if (context == null) {
        debugPrint('CARD ERROR: cardKey.currentContext is null');
        return null;
      }

      RenderObject? renderObject = context.findRenderObject();
      if (renderObject == null) {
        debugPrint('CARD ERROR: findRenderObject() returned null');
        return null;
      }

      if (renderObject is! RenderRepaintBoundary) {
        debugPrint(
          'CARD ERROR: expected RenderRepaintBoundary, got '
          '${renderObject.runtimeType}',
        );
        return null;
      }

      RenderRepaintBoundary boundary = renderObject;
      if (boundary.debugNeedsPaint) {
        await Future.delayed(const Duration(milliseconds: 50));
        final RenderObject? repaintCandidate = context.findRenderObject();
        if (repaintCandidate is RenderRepaintBoundary) {
          boundary = repaintCandidate;
        }
      }

      final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        return null;
      }

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/moodify_card.png');
      await file.writeAsBytes(pngBytes, flush: true);

      return file.path;
    } catch (e, st) {
      debugPrint('CARD ERROR: $e');
      debugPrintStack(stackTrace: st);
      return null;
    }
  }
}

class MoodCard extends StatelessWidget {
  final MoodResult result;

  const MoodCard({
    super.key,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final song = result.song;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final scale = width / 720;

        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: Image.file(
                File(result.imagePath),
                fit: BoxFit.cover,
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF0B0F0F).withOpacity(0.18),
                      const Color(0xFF0B0F0F).withOpacity(0.18),
                      const Color(0xFF0B0F0F).withOpacity(0.78),
                      const Color(0xFF0B0F0F).withOpacity(0.98),
                    ],
                    stops: const [0.0, 0.36, 0.66, 1.0],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.0, -0.92),
                    radius: 1.04,
                    colors: [
                      const Color(0xFFFFB347).withOpacity(0.34),
                      const Color(0xFF1E140A).withOpacity(0.34),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.34, 1.0],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFFFFC15C).withOpacity(0.12),
                    width: 1,
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                48 * scale,
                58 * scale,
                48 * scale,
                46 * scale,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(flex: 9),
                  Text(
                    result.mood,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFFFFF2C1),
                      fontSize: 76 * scale,
                      fontWeight: FontWeight.w900,
                      height: 0.96,
                      letterSpacing: -1.7 * scale,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.48),
                          blurRadius: 24 * scale,
                          offset: Offset(0, 8 * scale),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 58 * scale),
                  _MoodCardSongPanel(
                    title: song?.title ?? 'Captured by Moodify',
                    artist: song?.artist ?? 'Moodify',
                    scale: scale,
                  ),
                  const Spacer(flex: 4),
                  Center(
                    child: _MoodifySignature(scale: scale),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MoodCardSongPanel extends StatelessWidget {
  final String title;
  final String artist;
  final double scale;

  const _MoodCardSongPanel({
    required this.title,
    required this.artist,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28 * scale),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: 18 * scale,
          sigmaY: 18 * scale,
        ),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            30 * scale,
            24 * scale,
            30 * scale,
            24 * scale,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF0B0F0F).withOpacity(0.44),
            borderRadius: BorderRadius.circular(28 * scale),
            border: Border.all(
              color: const Color(0xFFFFB347).withOpacity(0.58),
              width: 1.2 * scale,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.36),
                blurRadius: 34 * scale,
                offset: Offset(0, 18 * scale),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 70 * scale,
                      height: 3 * scale,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB347),
                        borderRadius: BorderRadius.circular(2 * scale),
                      ),
                    ),
                    SizedBox(height: 18 * scale),
                    Text(
                      'NOW PLAYING',
                      style: TextStyle(
                        color: const Color(0xFFFFB347),
                        fontSize: 13 * scale,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 4.2 * scale,
                      ),
                    ),
                    SizedBox(height: 15 * scale),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFFFFF2C1),
                        fontSize: 34 * scale,
                        fontWeight: FontWeight.w800,
                        height: 1.05,
                      ),
                    ),
                    SizedBox(height: 14 * scale),
                    Text(
                      artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFFFFF2C1).withOpacity(0.66),
                        fontSize: 25 * scale,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 24 * scale),
              _EqualizerIcon(scale: scale),
            ],
          ),
        ),
      ),
    );
  }
}

class _EqualizerIcon extends StatelessWidget {
  final double scale;

  const _EqualizerIcon({required this.scale});

  @override
  Widget build(BuildContext context) {
    final heights = [18.0, 28.0, 42.0, 25.0, 35.0];

    return SizedBox(
      width: 42 * scale,
      height: 46 * scale,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: heights
            .map(
              (height) => Container(
                width: 4 * scale,
                height: height * scale,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB347),
                  borderRadius: BorderRadius.circular(4 * scale),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _MoodifySignature extends StatelessWidget {
  final double scale;

  const _MoodifySignature({required this.scale});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'M o o d i f y',
          style: TextStyle(
            color: const Color(0xFFFFF2C1).withOpacity(0.92),
            fontSize: 18 * scale,
            fontWeight: FontWeight.w600,
            letterSpacing: 8 * scale,
          ),
        ),
        SizedBox(height: 18 * scale),
        Container(
          width: 150 * scale,
          height: 1 * scale,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                const Color(0xFFFFB347).withOpacity(0.52),
                Colors.transparent,
              ],
            ),
          ),
        ),
        Transform.translate(
          offset: Offset(0, -4 * scale),
          child: Container(
            width: 6 * scale,
            height: 6 * scale,
            decoration: const BoxDecoration(
              color: Color(0xFFFFB347),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}
