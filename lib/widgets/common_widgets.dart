import 'dart:io';
import 'package:flutter/material.dart';
import 'package:zsoltscores/api_service.dart';

int compareHungarianStrings(String a, String b) {
  const order = {
    'a': 1, 'á': 2, 'b': 3, 'c': 4, 'cs': 5, 'd': 6, 'dz': 7, 'dzs': 8,
    'e': 9, 'é': 10, 'f': 11, 'g': 12, 'gy': 13, 'h': 14, 'i': 15, 'í': 16,
    'j': 17, 'k': 18, 'l': 19, 'ly': 20, 'm': 21, 'n': 22, 'ny': 23, 'o': 24,
    'ó': 25, 'ö': 26, 'ő': 27, 'p': 28, 'q': 29, 'r': 30, 's': 31, 'sz': 32,
    't': 33, 'ty': 34, 'u': 35, 'ú': 36, 'ü': 37, 'ű': 38, 'v': 39, 'w': 40,
    'x': 41, 'y': 42, 'z': 43, 'zs': 44,
  };

  List<int> tokenize(String s) {
    final lower = s.toLowerCase().trim();
    final tokens = <int>[];
    int i = 0;
    while (i < lower.length) {
      if (i + 2 < lower.length) {
        final tri = lower.substring(i, i + 3);
        if (order.containsKey(tri)) {
          tokens.add(order[tri]! * 10);
          i += 3;
          continue;
        }
      }
      if (i + 1 < lower.length) {
        final di = lower.substring(i, i + 2);
        if (order.containsKey(di)) {
          tokens.add(order[di]! * 10);
          i += 2;
          continue;
        }
      }
      final ch = lower[i];
      if (order.containsKey(ch)) {
        tokens.add(order[ch]! * 10);
      } else {
        tokens.add(1000 + ch.codeUnitAt(0));
      }
      i++;
    }
    return tokens;
  }

  final ta = tokenize(a);
  final tb = tokenize(b);
  final len = ta.length < tb.length ? ta.length : tb.length;
  for (int i = 0; i < len; i++) {
    if (ta[i] != tb[i]) return ta[i].compareTo(tb[i]);
  }
  return ta.length.compareTo(tb.length);
}

class CountryFlagBadge extends StatefulWidget {
  final String countryName;
  final String? flagUrl;

  const CountryFlagBadge({
    super.key,
    required this.countryName,
    this.flagUrl,
  });

  @override
  State<CountryFlagBadge> createState() => _CountryFlagBadgeState();
}

class _CountryFlagBadgeState extends State<CountryFlagBadge> {
  File? _localFile;

  @override
  void initState() {
    super.initState();
    _loadFlag();
  }

  @override
  void didUpdateWidget(covariant CountryFlagBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.flagUrl != widget.flagUrl) {
      _localFile = null;
      _loadFlag();
    }
  }

  Future<void> _loadFlag() async {
    if (widget.flagUrl == null || widget.flagUrl!.trim().isEmpty) return;
    final file = await LogoCache.getOrDownload(widget.flagUrl);
    if (mounted && file != null) {
      setState(() => _localFile = file);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_localFile != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Image.file(
          _localFile!,
          width: 18,
          height: 13,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Text(
            HungarianLocalization.flagEmojiForCountry(widget.countryName),
            style: const TextStyle(fontSize: 13),
          ),
        ),
      );
    }
    return Text(
      HungarianLocalization.flagEmojiForCountry(widget.countryName),
      style: const TextStyle(fontSize: 13),
    );
  }
}

class CachedTeamLogo extends StatefulWidget {
  final String teamName;
  final Color fallbackColor;
  final String? logoUrl;
  final double radius;
  final bool showInitialsOnFallback;

  const CachedTeamLogo({
    super.key,
    required this.teamName,
    required this.fallbackColor,
    required this.logoUrl,
    this.radius = 22,
    this.showInitialsOnFallback = true,
  });

  @override
  State<CachedTeamLogo> createState() => _CachedTeamLogoState();
}

class _CachedTeamLogoState extends State<CachedTeamLogo> {
  File? _localFile;

  @override
  void initState() {
    super.initState();
    _resolveLogo();
  }

  @override
  void didUpdateWidget(covariant CachedTeamLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.logoUrl != widget.logoUrl) {
      _localFile = null;
      _resolveLogo();
    }
  }

  Future<void> _resolveLogo() async {
    if (widget.logoUrl == null || widget.logoUrl!.trim().isEmpty) return;
    final file = await LogoCache.getOrDownload(widget.logoUrl);
    if (mounted && file != null) {
      setState(() => _localFile = file);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.teamName.trim();
    final initials = name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase();
    final imgSize = widget.radius * 1.55;

    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: widget.fallbackColor,
      child: _localFile != null
          ? ClipOval(
              child: Image.file(
                _localFile!,
                width: imgSize,
                height: imgSize,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => widget.showInitialsOnFallback
                    ? Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10))
                    : const SizedBox(),
              ),
            )
          : (widget.showInitialsOnFallback
              ? Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10))
              : const SizedBox()),
    );
  }
}

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

  List<List<LineupPlayer>> _buildRows(List<LineupPlayer> starters) {
    if (starters.isEmpty) return const [];
    final gk = starters.where((p) => p.position.toUpperCase() == 'GK').toList();
    final others = starters.where((p) => p.position.toUpperCase() != 'GK').toList();

    final parts = lineup.formation
        .split('-')
        .map((s) => int.tryParse(s.trim()) ?? 0)
        .where((n) => n > 0)
        .toList();

    final rows = <List<LineupPlayer>>[];
    int cursor = 0;

    if (parts.isNotEmpty && parts.length <= 5 && others.length >= 4) {
      for (final count in parts.reversed) {
        if (cursor >= others.length) break;
        final take = (cursor + count <= others.length) ? count : (others.length - cursor);
        rows.add(others.sublist(cursor, cursor + take));
        cursor += take;
      }
      if (cursor < others.length) {
        rows.add(others.sublist(cursor));
      }
    } else {
      final chunkSize = (others.length / 3).ceil().clamp(1, 5);
      for (int i = 0; i < others.length; i += chunkSize) {
        rows.add(others.sublist(i, (i + chunkSize).clamp(0, others.length)));
      }
    }

    if (gk.isNotEmpty) {
      rows.add(gk);
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final rows = _buildRows(lineup.starters);
    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF144A2B), Color(0xFF1B5E37)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withAlpha(65), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(teamName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
              Text('Formáció: ${lineup.formation}', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 11)),
            ],
          ),
          const Divider(color: Colors.white24, height: 12),
          ...rows.map((rowPlayers) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: rowPlayers.map((p) {
                  return Expanded(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 13,
                          backgroundColor: accent,
                          child: Text(
                            p.number.isNotEmpty ? p.number : '•',
                            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 10.5),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            );
          }),
        ],
      ),
    );
  }
}
