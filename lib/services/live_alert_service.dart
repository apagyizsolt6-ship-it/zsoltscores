import 'package:flutter/material.dart';
import 'package:zsoltscores/api_service.dart';

class LiveAlertService {
  static final Map<String, String> _knownSnapshots = {};
  static bool _seeded = false;

  static void showTestAlert(BuildContext context) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Color(0xFF1C2541),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 4),
        content: Text(
          '🔔 Próbaértesítés: ⚽ GÓL! Ferencváros 3 - 1 Puskás Akadémia (82\')',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
        ),
      ),
    );
  }

  static void evaluateMatches(BuildContext context, List<MatchData> matches, Set<String> favoriteIds) {
    if (matches.isEmpty) return;

    if (!_seeded) {
      for (final m in matches) {
        _knownSnapshots[m.id] = _signature(m);
      }
      _seeded = true;
      return;
    }

    final alerts = <String>[];
    for (final m in matches) {
      final prev = _knownSnapshots[m.id];
      final curr = _signature(m);
      _knownSnapshots[m.id] = curr;

      if (prev == null || prev == curr) continue;
      final watched = favoriteIds.contains(m.id) ||
          DisplayPrefs.isFavoriteTeam(m.homeTeam) ||
          DisplayPrefs.isFavoriteTeam(m.awayTeam);
      if (!watched) continue;

      final prevParts = prev.split('|');
      final prevH = int.tryParse(prevParts[0]) ?? 0;
      final prevA = int.tryParse(prevParts[1]) ?? 0;
      final prevRed = int.tryParse(prevParts[2]) ?? 0;
      final prevFin = prevParts[3] == '1';

      final currRed = m.events.where((e) => e.type == 'red').length;

      if (DisplayPrefs.alertOnGoal && (m.homeScore > prevH || m.awayScore > prevA)) {
        alerts.add('⚽ GÓL! ${m.homeTeam} ${m.homeScore} - ${m.awayScore} ${m.awayTeam} (${m.status})');
      }
      if (DisplayPrefs.alertOnRedCard && currRed > prevRed) {
        alerts.add('🟥 Piros lap: ${m.homeTeam} - ${m.awayTeam} (${m.status})');
      }
      if (DisplayPrefs.alertOnFinish && m.isFinished && !prevFin) {
        alerts.add('🏁 VÉGE: ${m.homeTeam} ${m.homeScore} - ${m.awayScore} ${m.awayTeam}');
      }
    }

    if (alerts.isNotEmpty && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1C2541),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          content: Text(
            alerts.join('\n'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
          ),
        ),
      );
    }
  }

  static String _signature(MatchData m) {
    final reds = m.events.where((e) => e.type == 'red').length;
    return '${m.homeScore}|${m.awayScore}|$reds|${m.isFinished ? 1 : 0}';
  }
}
