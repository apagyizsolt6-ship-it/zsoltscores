import 'package:flutter/material.dart';
import 'package:zsoltscores/api_service.dart';
import 'package:zsoltscores/tabs/matches_tab.dart';
import 'package:zsoltscores/theme/app_theme.dart';

class FavoritesTab extends StatelessWidget {
  final List<MatchData> allMatches;
  final Set<String> recentlyScoredIds;
  final Set<String> favoriteIds;
  final ValueChanged<String> onToggleFavorite;

  const FavoritesTab({
    super.key,
    required this.allMatches,
    required this.recentlyScoredIds,
    required this.favoriteIds,
    required this.onToggleFavorite,
  });

  Widget _summaryPill(AppPalette p, String label, String value, Color accent) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
        decoration: BoxDecoration(
          color: p.cardElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withAlpha(95)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: accent),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.5, color: p.textMuted, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppThemeController.instance.palette;
    final favMatches = allMatches.where((m) {
      return favoriteIds.contains(m.id) ||
          DisplayPrefs.isFavoriteTeam(m.homeTeam) ||
          DisplayPrefs.isFavoriteTeam(m.awayTeam);
    }).toList();
    final liveFavCount = favMatches.where((m) => m.isLive).length;
    final finishedFavCount = favMatches.where((m) => m.isFinished).length;

    return SafeArea(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [p.headerStart, p.headerEnd]),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
              border: Border(bottom: BorderSide(color: p.borderSubtle)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Kedvenc Meccsek & Csapatok ⭐',
                        style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: p.textPrimary),
                      ),
                    ),
                    if (liveFavCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: p.liveRed,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$liveFavCount ÉLŐ',
                          style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w900),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  DisplayPrefs.favoriteTeams.isEmpty
                      ? 'Csillagozott meccsek értesítésekkel'
                      : 'Kiemelt csapatok: ${DisplayPrefs.favoriteTeams.join(', ')}',
                  style: TextStyle(fontSize: 12, color: p.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (favMatches.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Row(
                children: [
                  _summaryPill(p, 'Összes', '${favMatches.length}', p.goldAccent),
                  const SizedBox(width: 8),
                  _summaryPill(p, 'Élőben', '$liveFavCount', p.primaryAccent),
                  const SizedBox(width: 8),
                  _summaryPill(p, 'Lezárt', '$finishedFavCount', p.secondaryAccent),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: favMatches.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Még nincs kedvenc meccsed erre a napra.\nKoppints a csillag ikonra bármelyik meccsen!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: p.textMuted, height: 1.5),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: favMatches.length,
                    itemBuilder: (context, index) {
                      final match = favMatches[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: p.cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: match.isLive ? p.primaryAccent.withAlpha(110) : p.goldAccent.withAlpha(80),
                          ),
                        ),
                        child: MatchCard(
                          match: match,
                          isFavorite: favoriteIds.contains(match.id),
                          isGoalFlash: recentlyScoredIds.contains(match.id),
                          onToggleFavorite: () => onToggleFavorite(match.id),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
