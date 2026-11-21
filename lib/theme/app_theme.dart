import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ZsoltThemeStyle {
  classicDark,
  oledMidnight,
  lightDay,
}

class AppPalette {
  final Brightness brightness;
  final Color scaffoldBg;
  final Color cardBg;
  final Color cardElevated;
  final Color headerStart;
  final Color headerEnd;
  final Color primaryAccent;
  final Color secondaryAccent;
  final Color goldAccent;
  final Color liveRed;
  final Color borderSubtle;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  const AppPalette({
    required this.brightness,
    required this.scaffoldBg,
    required this.cardBg,
    required this.cardElevated,
    required this.headerStart,
    required this.headerEnd,
    required this.primaryAccent,
    required this.secondaryAccent,
    required this.goldAccent,
    required this.liveRed,
    required this.borderSubtle,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
  });

  bool get isLight => brightness == Brightness.light;

  static const classicDark = AppPalette(
    brightness: Brightness.dark,
    scaffoldBg: Color(0xFF0B132B),
    cardBg: Color(0xFF132043),
    cardElevated: Color(0xFF1C2541),
    headerStart: Color(0xFF162447),
    headerEnd: Color(0xFF1F4068),
    primaryAccent: Color(0xFF00E676),
    secondaryAccent: Color(0xFF00E5FF),
    goldAccent: Color(0xFFFFCA28),
    liveRed: Color(0xFFFF1744),
    borderSubtle: Color(0x26FFFFFF),
    textPrimary: Colors.white,
    textSecondary: Color(0xB3FFFFFF),
    textMuted: Color(0x8AFFFFFF),
  );

  static const oledMidnight = AppPalette(
    brightness: Brightness.dark,
    scaffoldBg: Color(0xFF000000),
    cardBg: Color(0xFF0A0E17),
    cardElevated: Color(0xFF111827),
    headerStart: Color(0xFF050811),
    headerEnd: Color(0xFF0F172A),
    primaryAccent: Color(0xFF38BDF8),
    secondaryAccent: Color(0xFF2DD4BF),
    goldAccent: Color(0xFFFBBF24),
    liveRed: Color(0xFFFF3B5C),
    borderSubtle: Color(0x1FFFFFFF),
    textPrimary: Colors.white,
    textSecondary: Color(0xB3FFFFFF),
    textMuted: Color(0x8AFFFFFF),
  );

  static const lightDay = AppPalette(
    brightness: Brightness.light,
    scaffoldBg: Color(0xFFF1F5F9),
    cardBg: Color(0xFFFFFFFF),
    cardElevated: Color(0xFFF8FAFC),
    headerStart: Color(0xFFE2E8F0),
    headerEnd: Color(0xFFCBD5E1),
    primaryAccent: Color(0xFF059669),
    secondaryAccent: Color(0xFF0284C7),
    goldAccent: Color(0xFFD97706),
    liveRed: Color(0xFFDC2626),
    borderSubtle: Color(0x220F172A),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF334155),
    textMuted: Color(0xFF64748B),
  );
}

class AppThemeController extends ChangeNotifier {
  AppThemeController._();
  static final AppThemeController instance = AppThemeController._();

  static const _prefKey = 'zsoltscores_theme_style';
  ZsoltThemeStyle _style = ZsoltThemeStyle.classicDark;

  ZsoltThemeStyle get style => _style;
  bool get isOled => _style == ZsoltThemeStyle.oledMidnight;
  bool get isLight => _style == ZsoltThemeStyle.lightDay;

  AppPalette get palette => switch (_style) {
        ZsoltThemeStyle.oledMidnight => AppPalette.oledMidnight,
        ZsoltThemeStyle.lightDay => AppPalette.lightDay,
        ZsoltThemeStyle.classicDark => AppPalette.classicDark,
      };

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    if (raw == ZsoltThemeStyle.oledMidnight.name) {
      _style = ZsoltThemeStyle.oledMidnight;
    } else if (raw == ZsoltThemeStyle.lightDay.name) {
      _style = ZsoltThemeStyle.lightDay;
    } else {
      _style = ZsoltThemeStyle.classicDark;
    }
  }

  Future<void> setStyle(ZsoltThemeStyle next) async {
    if (_style == next) return;
    _style = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, next.name);
    notifyListeners();
  }

  ThemeData buildTheme() {
    final p = palette;
    final colorScheme = p.isLight
        ? ColorScheme.light(
            primary: p.primaryAccent,
            secondary: p.secondaryAccent,
            surface: p.cardBg,
            onPrimary: Colors.white,
            onSecondary: Colors.white,
            onSurface: p.textPrimary,
          )
        : ColorScheme.dark(
            primary: p.primaryAccent,
            secondary: p.secondaryAccent,
            surface: p.cardBg,
            onPrimary: Colors.black,
            onSecondary: Colors.black,
            onSurface: p.textPrimary,
          );

    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      scaffoldBackgroundColor: p.scaffoldBg,
      colorScheme: colorScheme,
      cardColor: p.cardBg,
      dividerColor: p.borderSubtle,
      appBarTheme: AppBarTheme(
        backgroundColor: p.cardElevated,
        foregroundColor: p.textPrimary,
        elevation: 0,
      ),
    );
  }
}
