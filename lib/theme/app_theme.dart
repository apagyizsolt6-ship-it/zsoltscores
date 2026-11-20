import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ZsoltThemeStyle { classicDark, oledMidnight }

class AppPalette {
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

  const AppPalette({
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
  });

  static const classic = AppPalette(
    scaffoldBg: Color(0xFF0B132B),
    cardBg: Color(0xFF131D3B),
    cardElevated: Color(0xFF1C2541),
    headerStart: Color(0xFF1C2541),
    headerEnd: Color(0xFF0F4C5C),
    primaryAccent: Color(0xFF00E676),
    secondaryAccent: Color(0xFF00B0FF),
    goldAccent: Color(0xFFFFAB00),
    liveRed: Color(0xFFFF1744),
    borderSubtle: Color(0x22FFFFFF),
  );

  static const oled = AppPalette(
    scaffoldBg: Color(0xFF000000),
    cardBg: Color(0xFF0C1018),
    cardElevated: Color(0xFF141B29),
    headerStart: Color(0xFF0B101B),
    headerEnd: Color(0xFF112233),
    primaryAccent: Color(0xFF2EE58A),
    secondaryAccent: Color(0xFF38BDF8),
    goldAccent: Color(0xFFFBBF24),
    liveRed: Color(0xFFF43F5E),
    borderSubtle: Color(0x1FFFFFFF),
  );
}

class AppThemeController extends ChangeNotifier {
  static final AppThemeController instance = AppThemeController._();
  AppThemeController._();

  static const _prefKey = 'zsoltscores_theme_style';
  ZsoltThemeStyle _style = ZsoltThemeStyle.classicDark;

  ZsoltThemeStyle get style => _style;
  bool get isOled => _style == ZsoltThemeStyle.oledMidnight;
  AppPalette get palette => isOled ? AppPalette.oled : AppPalette.classic;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved == 'oled') {
      _style = ZsoltThemeStyle.oledMidnight;
    }
  }

  Future<void> setStyle(ZsoltThemeStyle newStyle) async {
    if (_style == newStyle) return;
    _style = newStyle;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefKey,
      newStyle == ZsoltThemeStyle.oledMidnight ? 'oled' : 'classic',
    );
  }

  ThemeData buildTheme() {
    final p = palette;
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: p.scaffoldBg,
      colorScheme: ColorScheme.dark(
        primary: p.primaryAccent,
        secondary: p.secondaryAccent,
        surface: p.cardElevated,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: p.cardElevated,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: p.cardElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: p.borderSubtle),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: p.borderSubtle,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.cardElevated,
        indicatorColor: p.primaryAccent.withAlpha(48),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? Colors.white : Colors.white60,
          );
        }),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.cardElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: p.borderSubtle),
        ),
      ),
    );
  }
}
