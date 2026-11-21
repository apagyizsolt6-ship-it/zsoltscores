import 'package:flutter/material.dart';
import 'package:zsoltscores/api_service.dart';
import 'package:zsoltscores/theme/app_theme.dart';

int compareHungarianStrings(String a, String b) {
  const order = {
    'a': 1, 'á': 2, 'b': 3, 'c': 4, 'd': 5, 'e': 6, 'é': 7, 'f': 8, 'g': 9,
    'h': 10, 'i': 11, 'í': 12, 'j': 13, 'k': 14, 'l': 15, 'm': 16, 'n': 17,
    'o': 18, 'ó': 19, 'ö': 20, 'ő': 21, 'p': 22, 'q': 23, 'r': 24, 's': 25,
    't': 26, 'u': 27, 'ú': 28, 'ü': 29, 'ű': 30, 'v': 31, 'w': 32, 'x': 33,
    'y': 34, 'z': 35,
  };
  final la = a.trim().toLowerCase();
  final lb = b.trim().toLowerCase();
  final len = la.length < lb.length ? la.length : lb.length;
  for (var i = 0; i < len; i++) {
    final ca = la[i];
    final cb = lb[i];
    if (ca == cb) continue;
    final wa = order[ca] ?? (100 + ca.codeUnitAt(0));
    final wb = order[cb] ?? (100 + cb.codeUnitAt(0));
    if (wa != wb) return wa.compareTo(wb);
  }
  return la.length.compareTo(lb.length);
}

class CountryFlagBadge extends StatelessWidget {
  final String countryName;
  final String? flagUrl;
  final double width;
  final double height;

  const CountryFlagBadge({
    super.key,
    required this.countryName,
    this.flagUrl,
    this.width = 20,
    this.height = 14,
  });

  static String? _assetForCountry(String raw) {
    final c = raw.trim().toLowerCase();
    if (c.contains('england') || c.contains('anglia') || c.contains('premier league')) {
      return 'assets/flags/gb-eng.png';
    }
    if (c.contains('spain') || c.contains('spanyol') || c.contains('la liga')) {
      return 'assets/flags/es.png';
    }
    if (c.contains('italy') || c.contains('olasz') || c.contains('serie a')) {
      return 'assets/flags/it.png';
    }
    if (c.contains('germany') || c.contains('német') || c.contains('bundesliga')) {
      return 'assets/flags/de.png';
    }
    if (c.contains('france') || c.contains('francia') || c.contains('ligue 1')) {
      return 'assets/flags/fr.png';
    }
    if (c.contains('hungary') || c.contains('magyar') || c.contains('nb i') || c.contains('otp bank')) {
      return 'assets/flags/hu.png';
    }
    if (c.contains('netherlands') || c.contains('holland') || c.contains('eredivisie')) {
      return 'assets/flags/nl.png';
    }
    if (c.contains('portugal') || c.contains('portugál') || c.contains('liga portugal')) {
      return 'assets/flags/pt.png';
    }
    if (c.contains('europe') || c.contains('európa') || c.contains('champions') || c.contains('europa') || c.contains('conference')) {
      return 'assets/flags/eu.png';
    }
    if (c.contains('world') || c.contains('világ') || c.contains('international') || c.contains('fifa')) {
      return 'assets/flags/un.png';
    }
    return null;
  }

  static String _emojiFallback(String raw) {
    final c = raw.trim().toLowerCase();
    if (c.contains('england') || c.contains('anglia')) return '🏴󠁧󠁢󠁥󠁮󠁧󠁿';
    if (c.contains('spain') || c.contains('spanyol')) return '🇪🇸';
    if (c.contains('italy') || c.contains('olasz')) return '🇮🇹';
    if (c.contains('germany') || c.contains('német')) return '🇩🇪';
    if (c.contains('france') || c.contains('francia')) return '🇫🇷';
    if (c.contains('hungary') || c.contains('magyar')) return '🇭🇺';
    if (c.contains('netherlands') || c.contains('holland')) return '🇳🇱';
    if (c.contains('portugal') || c.contains('portugál')) return '🇵🇹';
    if (c.contains('europe') || c.contains('európa') || c.contains('champions') || c.contains('europa')) return '🇪🇺';
    return '🌍';
  }

  @override
  Widget build(BuildContext context) {
    final p = AppThemeController.instance.palette;
    final assetPath = _assetForCountry(countryName);
    final url = (flagUrl ?? '').trim();

    Widget content;
    if (assetPath != null) {
      content = Image.asset(
        assetPath,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Text(_emojiFallback(countryName), style: TextStyle(fontSize: height)),
      );
    } else if (url.startsWith('http')) {
      content = Image.network(
        url,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Text(_emojiFallback(countryName), style: TextStyle(fontSize: height)),
      );
    } else {
      content = Text(_emojiFallback(countryName), style: TextStyle(fontSize: height));
    }

    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: p.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }
}

class CachedTeamLogo extends StatelessWidget {
  final String teamName;
  final Color fallbackColor;
  final String? logoUrl;
  final double radius;
  final bool showInitialsOnFallback;

  const CachedTeamLogo({
    super.key,
    required this.teamName,
    required this.fallbackColor,
    this.logoUrl,
    this.radius = 12,
    this.showInitialsOnFallback = true,
  });

  String _initials(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return '?';
    final parts = clean.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    }
    return clean.substring(0, clean.length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppThemeController.instance.palette;
    final size = radius * 2;
    final url = (logoUrl ?? '').trim();

    Widget fallbackWidget() {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [fallbackColor, fallbackColor.withAlpha(175)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: showInitialsOnFallback
            ? Text(
                _initials(teamName),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: (radius * 0.72).clamp(8.5, 16.0),
                ),
              )
            : Icon(Icons.shield, color: Colors.white, size: radius * 1.15),
      );
    }

    if (url.startsWith('http')) {
      return Container(
        width: size,
        height: size,
        padding: EdgeInsets.all((radius * 0.12).clamp(1.5, 3.0)),
        decoration: BoxDecoration(
          color: p.scaffoldBg.withAlpha(220),
          shape: BoxShape.circle,
          border: Border.all(color: fallbackColor.withAlpha(110), width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.network(
          url,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => fallbackWidget(),
        ),
      );
    }

    return fallbackWidget();
  }
}

enum _PitchLine { gk, def, mid, fwd }

class FormationPitchView extends StatelessWidget {
  final String teamName;
  final Color accent;
  final TeamLineup lineup;

  const FormationPitchView({
    super.key,
    required this.teamName,
    required this.accent,
    required this.lineup,
  });

  String _cleanPlayerLabel(LineupPlayer pl) {
    var raw = pl.name.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
    if (raw.isEmpty) raw = pl.position.trim();
    if (raw.isEmpty) return 'Játékos';
    final parts = raw.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.length == 1) return parts.first;
    final last = parts.last;
    if (last.endsWith('.') && last.length <= 3 && parts.length >= 2) {
      return '${parts[parts.length - 2]} $last';
    }
    return last;
  }

  _PitchLine _classifyLine(LineupPlayer pl) {
    final text = '${pl.position} ${pl.name}'.toLowerCase();
    final numStr = pl.number.trim();

    if (numStr == '1' ||
        text.contains('kapus') ||
        text.contains('gk') ||
        text.contains('goalkeeper') ||
        RegExp(r'\bg\b').hasMatch(text)) {
      return _PitchLine.gk;
    }

    if (text.contains('csatár') ||
        text.contains('szélső') ||
        text.contains('támadó') ||
        text.contains('striker') ||
        text.contains('forward') ||
        text.contains('winger') ||
        text.contains('st') ||
        text.contains('cf') ||
        text.contains('lw') ||
        text.contains('rw') ||
        text.contains('fw')) {
      return _PitchLine.fwd;
    }

    if (text.contains('hátvéd') ||
        text.contains('védő') ||
        text.contains('back') ||
        text.contains('defender') ||
        text.contains('cb') ||
        text.contains('lb') ||
        text.contains('rb') ||
        text.contains('lwb') ||
        text.contains('rwb') ||
        text.contains('def')) {
      return _PitchLine.def;
    }

    if (text.contains('irányító') ||
        text.contains('középpály') ||
        text.contains('szűrő') ||
        text.contains('kp') ||
        text.contains('mid') ||
        text.contains('cam') ||
        text.contains('cdm') ||
        text.contains('cm') ||
        text.contains('lm') ||
        text.contains('rm')) {
      return _PitchLine.mid;
    }

    final n = int.tryParse(numStr) ?? 0;
    if (n == 1) return _PitchLine.gk;
    if (n >= 2 && n <= 5) return _PitchLine.def;
    if (n >= 6 && n <= 8) return _PitchLine.mid;
    if (n >= 9 && n <= 11) return _PitchLine.fwd;
    return _PitchLine.mid;
  }

  /// Balról jobbra rendezési kulcs:
  /// -1 = bal oldal (balhátvéd, balszélső, baloldali...)
  ///  0 = középső / irányító / középcsatár / kp.
  /// +1 = jobb oldal (jobbhátvéd, jobbszélső, jobboldali...)
  int _horizontalSortOrder(LineupPlayer pl) {
    final text = '${pl.position} ${pl.name}'.toLowerCase();

    final isLeft = text.contains('bal') ||
        text.contains('left') ||
        RegExp(r'\b(lb|lwb|lw|lm)\b').hasMatch(text);
    final isRight = text.contains('jobb') ||
        text.contains('right') ||
        RegExp(r'\b(rb|rwb|rw|rm)\b').hasMatch(text);

    if (isLeft && !isRight) return -1;
    if (isRight && !isLeft) return 1;

    final isCenter = text.contains('közép') ||
        text.contains('irányító') ||
        text.contains('szűrő') ||
        text.contains('kp') ||
        RegExp(r'\b(cb|cdm|cm|cam|cf|st)\b').hasMatch(text);
    if (isCenter) return 0;

    return 0;
  }

  List<int> _parseFormationCounts(String formation) {
    return RegExp(r'\d+')
        .allMatches(formation)
        .map((m) => int.tryParse(m.group(0)!) ?? 0)
        .where((n) => n > 0)
        .toList();
  }

  List<List<LineupPlayer>> _buildRows(List<LineupPlayer> starters, String formation) {
    if (starters.isEmpty) return const [];

    final gk = <LineupPlayer>[];
    final def = <LineupPlayer>[];
    final mid = <LineupPlayer>[];
    final fwd = <LineupPlayer>[];

    for (final pl in starters) {
      switch (_classifyLine(pl)) {
        case _PitchLine.gk:
          if (gk.isEmpty) {
            gk.add(pl);
          } else {
            mid.add(pl);
          }
          break;
        case _PitchLine.def:
          def.add(pl);
          break;
        case _PitchLine.mid:
          mid.add(pl);
          break;
        case _PitchLine.fwd:
          fwd.add(pl);
          break;
      }
    }

    int compareHoriz(LineupPlayer a, LineupPlayer b) {
      final ha = _horizontalSortOrder(a);
      final hb = _horizontalSortOrder(b);
      if (ha != hb) return ha.compareTo(hb);
      final na = int.tryParse(a.number.trim()) ?? 99;
      final nb = int.tryParse(b.number.trim()) ?? 99;
      return na.compareTo(nb);
    }

    def.sort(compareHoriz);
    mid.sort(compareHoriz);
    fwd.sort(compareHoriz);

    final counts = _parseFormationCounts(formation);

    // Ha pl. 4-2-3-1 (4 szám van a formációban) és a középpályásokat két sorra bontjuk
    if (counts.length == 4 && mid.length >= counts[1] + counts[2]) {
      final rows = <List<LineupPlayer>>[];
      if (fwd.isNotEmpty) rows.add(fwd);

      final amCount = counts[2].clamp(1, mid.length);
      final attackingMid = mid.sublist(0, amCount);
      final holdingMid = mid.sublist(amCount);

      if (attackingMid.isNotEmpty) rows.add(attackingMid);
      if (holdingMid.isNotEmpty) rows.add(holdingMid);
      if (def.isNotEmpty) rows.add(def);
      if (gk.isNotEmpty) rows.add(gk);
      return rows;
    }

    final rows = <List<LineupPlayer>>[];
    if (fwd.isNotEmpty) rows.add(fwd);
    if (mid.isNotEmpty) rows.add(mid);
    if (def.isNotEmpty) rows.add(def);
    if (gk.isNotEmpty) rows.add(gk);

    if (rows.isNotEmpty) return rows;

    final fallback = <List<LineupPlayer>>[];
    for (var i = 0; i < starters.length; i += 4) {
      fallback.add(starters.sublist(i, (i + 4).clamp(0, starters.length)));
    }
    return fallback.reversed.toList();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppThemeController.instance.palette;
    final rows = _buildRows(lineup.starters, lineup.formation);
    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withAlpha(135)),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 3))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: p.cardElevated,
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$teamName • ${lineup.formation}',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: p.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: accent.withAlpha(24),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    '${lineup.starters.length} kezdő',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: accent),
                  ),
                ),
              ],
            ),
          ),
          CustomPaint(
            painter: _PitchLinesPainter(accent: accent),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF14532D), Color(0xFF166534), Color(0xFF14532D)],
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: rows.map((rowPlayers) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: rowPlayers.map((pl) {
                        final label = _cleanPlayerLabel(pl);
                        return Flexible(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: accent,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 1.6),
                                  boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4)],
                                ),
                                child: Text(
                                  pl.number.isNotEmpty ? pl.number : '•',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withAlpha(155),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PitchLinesPainter extends CustomPainter {
  final Color accent;
  const _PitchLinesPainter({required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final stripePaint = Paint()..color = Colors.white.withAlpha(9);
    const stripeCount = 6;
    final stripeH = size.height / stripeCount;
    for (var i = 0; i < stripeCount; i += 2) {
      canvas.drawRect(Rect.fromLTWH(0, i * stripeH, size.width, stripeH), stripePaint);
    }

    final linePaint = Paint()
      ..color = Colors.white.withAlpha(68)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;

    final insetRect = Rect.fromLTWH(10, 8, size.width - 20, size.height - 16);
    canvas.drawRect(insetRect, linePaint);
    canvas.drawLine(
      Offset(10, size.height / 2),
      Offset(size.width - 10, size.height / 2),
      linePaint,
    );
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 28, linePaint);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 2.5, Paint()..color = Colors.white70);

    final topBoxW = size.width * 0.44;
    canvas.drawRect(
      Rect.fromLTWH((size.width - topBoxW) / 2, 8, topBoxW, 30),
      linePaint,
    );
    canvas.drawRect(
      Rect.fromLTWH((size.width - topBoxW) / 2, size.height - 38, topBoxW, 30),
      linePaint,
    );

    final goalPaint = Paint()
      ..color = accent.withAlpha(110)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final goalW = size.width * 0.2;
    canvas.drawRect(Rect.fromLTWH((size.width - goalW) / 2, 3, goalW, 5), goalPaint);
    canvas.drawRect(Rect.fromLTWH((size.width - goalW) / 2, size.height - 8, goalW, 5), goalPaint);
  }

  @override
  bool shouldRepaint(covariant _PitchLinesPainter oldDelegate) => oldDelegate.accent != accent;
}
