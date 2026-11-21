import 'package:flutter/material.dart';
import 'package:zsoltscores/api_service.dart';
import 'package:zsoltscores/screens/match_stats_screen.dart';
import 'package:zsoltscores/theme/app_theme.dart';

class LiveAlertEntry {
  final String id;
  final String matchId;
  final String title;
  final String subtitle;
  final Color accent;
  final DateTime timestamp;
  final MatchData? match;

  const LiveAlertEntry({
    required this.id,
    required this.matchId,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.timestamp,
    this.match,
  });
}

class LiveAlertService {
  LiveAlertService._();

  static final Map<String, int> _lastScores = {};
  static final Map<String, bool> _lastFinishedState = {};
  static final Set<String> _seenRedEventKeys = {};
  static final List<LiveAlertEntry> _history = [];

  static List<LiveAlertEntry> get history => List.unmodifiable(_history);

  static void clearHistory() {
    _history.clear();
  }

  static void _recordAlert(LiveAlertEntry entry) {
    _history.insert(0, entry);
    if (_history.length > 40) {
      _history.removeRange(40, _history.length);
    }
  }

  static void _showBanner(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Color accent,
    MatchData? match,
  }) {
    if (!context.mounted) return;
    final p = AppThemeController.instance.palette;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: p.cardElevated,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: accent.withAlpha(150), width: 1.2),
        ),
        content: Row(
          children: [
            Container(
              width: 4,
              height: 36,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w900,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: p.textPrimary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        action: match != null
            ? SnackBarAction(
                label: 'Megnyitás',
                textColor: accent,
                onPressed: () {
                  if (!context.mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => MatchStatsScreen(match: match)),
                  );
                },
              )
            : null,
      ),
    );
  }

  static void showTestAlert(BuildContext context) {
    final p = AppThemeController.instance.palette;
    final entry = LiveAlertEntry(
      id: 'test_${DateTime.now().millisecondsSinceEpoch}',
      matchId: 'sample_test',
      title: '⚽ GÓL! • Bajnokok Ligája',
      subtitle: 'Real Madrid 2 - 2 Liverpool (74\')',
      accent: p.primaryAccent,
      timestamp: DateTime.now(),
    );
    _recordAlert(entry);
    _showBanner(
      context,
      title: entry.title,
      subtitle: '${entry.subtitle} • Teszt riasztás',
      accent: entry.accent,
    );
  }

  static void evaluateMatches(
    BuildContext context,
    List<MatchData> matches,
    Set<String> favoriteMatchIds,
  ) {
    if (!context.mounted || matches.isEmpty) return;
    final p = AppThemeController.instance.palette;
    final now = DateTime.now();

    for (final m in matches) {
      final isTracked = favoriteMatchIds.contains(m.id) ||
          DisplayPrefs.isFavoriteTeam(m.homeTeam) ||
          DisplayPrefs.isFavoriteTeam(m.awayTeam);

      final scoreKey = m.homeScore * 100 + m.awayScore;
      final prevScore = _lastScores[m.id];
      _lastScores[m.id] = scoreKey;

      if (DisplayPrefs.alertOnGoal &&
          isTracked &&
          prevScore != null &&
          prevScore != scoreKey &&
          (m.isLive || m.isFinished)) {
        final goalEvents = m.events.where((e) => e.type == 'goal').toList();
        final lastGoal = goalEvents.isNotEmpty ? goalEvents.last : null;
        final scorerText = lastGoal != null ? ' • ${lastGoal.player} (${lastGoal.minute})' : '';
        final title = '⚽ GÓL! • ${m.league}';
        final subtitle = '${m.homeTeam} ${m.homeScore} - ${m.awayScore} ${m.awayTeam}$scorerText';
        _recordAlert(
          LiveAlertEntry(
            id: '${m.id}_g_${scoreKey}_${now.millisecondsSinceEpoch}',
            matchId: m.id,
            title: title,
            subtitle: subtitle,
            accent: p.primaryAccent,
            timestamp: now,
            match: m,
          ),
        );
        _showBanner(context, title: title, subtitle: subtitle, accent: p.primaryAccent, match: m);
      }

      if (DisplayPrefs.alertOnRedCard && isTracked) {
        for (final ev in m.events.where((e) => e.type == 'red')) {
          final redId = '${m.id}_${ev.minute}_${ev.player}';
          if (_seenRedEventKeys.add(redId)) {
            final title = '🟥 PIROS LAP • ${m.league}';
            final subtitle = '${ev.player} (${ev.minute}) • ${m.homeTeam} - ${m.awayTeam}';
            _recordAlert(
              LiveAlertEntry(
                id: redId,
                matchId: m.id,
                title: title,
                subtitle: subtitle,
                accent: p.liveRed,
                timestamp: now,
                match: m,
              ),
            );
            _showBanner(context, title: title, subtitle: subtitle, accent: p.liveRed, match: m);
          }
        }
      }

      final wasFinished = _lastFinishedState[m.id] ?? m.isFinished;
      _lastFinishedState[m.id] = m.isFinished;
      if (DisplayPrefs.alertOnFinish && isTracked && !wasFinished && m.isFinished) {
        final title = '🏁 VÉGE • ${m.league}';
        final subtitle = 'Végeredmény: ${m.homeTeam} ${m.homeScore} - ${m.awayScore} ${m.awayTeam}';
        _recordAlert(
          LiveAlertEntry(
            id: '${m.id}_ft_${m.homeScore}_${m.awayScore}',
            matchId: m.id,
            title: title,
            subtitle: subtitle,
            accent: p.secondaryAccent,
            timestamp: now,
            match: m,
          ),
        );
        _showBanner(context, title: title, subtitle: subtitle, accent: p.secondaryAccent, match: m);
      }
    }
  }

  static void openHistoryDialog(BuildContext context) {
    final p = AppThemeController.instance.palette;
    final items = history;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: p.cardElevated,
          title: Row(
            children: [
              Icon(Icons.notifications_active, color: p.goldAccent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Élő riasztási napló (${items.length})',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: p.textPrimary),
                ),
              ),
              if (items.isNotEmpty)
                TextButton(
                  onPressed: () {
                    clearHistory();
                    setLocal(() {});
                  },
                  child: Text('Törlés', style: TextStyle(color: p.liveRed, fontSize: 12)),
                ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 320,
            child: history.isEmpty
                ? Center(
                    child: Text(
                      'Még nem érkezett élő riasztás.\nA kedvenc meccseid és csapatod góljait, lapjait és lefújásait itt listázzuk.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: p.textMuted, fontSize: 12.5),
                    ),
                  )
                : ListView.builder(
                    itemCount: history.length,
                    itemBuilder: (_, idx) {
                      final item = history[idx];
                      final hh = item.timestamp.hour.toString().padLeft(2, '0');
                      final mm = item.timestamp.minute.toString().padLeft(2, '0');
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: p.cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border(left: BorderSide(color: item.accent, width: 3.5)),
                        ),
                        child: InkWell(
                          onTap: item.match != null
                              ? () {
                                  Navigator.pop(ctx);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => MatchStatsScreen(match: item.match!)),
                                  );
                                }
                              : null,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.title,
                                      style: TextStyle(color: item.accent, fontWeight: FontWeight.w800, fontSize: 11.5),
                                    ),
                                  ),
                                  Text('$hh:$mm', style: TextStyle(color: p.textMuted, fontSize: 10.5)),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                item.subtitle,
                                style: TextStyle(color: p.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Bezárás', style: TextStyle(color: p.primaryAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
