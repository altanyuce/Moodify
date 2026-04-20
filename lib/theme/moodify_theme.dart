import 'package:flutter/material.dart';

class MoodifyColors {
  static const Color softYellow = Color(0xFFFACC15);
  static const Color amber = Color(0xFFF59E0B);
  static const Color orange = Color(0xFFFB923C);

  static const Color baseBackground = Color(0xFF0B0B0F);
  static const Color surface = Color(0xFF15151C);
  static const Color softText = Color(0xFFB7BAC7);
  static const Color warmText = Color(0xFFFFF1C2);

  static const Color glassFill = Color(0x14FFFFFF);
  static const Color glassBorder = Color(0x26FFFFFF);
}

class MoodifyGradients {
  static const LinearGradient primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      MoodifyColors.softYellow,
      MoodifyColors.amber,
      MoodifyColors.orange,
    ],
  );

  static const RadialGradient cinematicGlow = RadialGradient(
    center: Alignment(0.0, -0.75),
    radius: 1.15,
    colors: [
      Color(0x5CFACC15),
      Color(0x2EFB923C),
      Color(0x000B0B0F),
    ],
    stops: [0.0, 0.38, 1.0],
  );
}

class MoodifyTheme {
  static ThemeData dark() {
    const colorScheme = ColorScheme.dark(
      primary: MoodifyColors.softYellow,
      secondary: MoodifyColors.amber,
      surface: MoodifyColors.surface,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: MoodifyColors.baseBackground,
      splashFactory: InkRipple.splashFactory,
      snackBarTheme: SnackBarThemeData(
        backgroundColor: MoodifyColors.surface,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
