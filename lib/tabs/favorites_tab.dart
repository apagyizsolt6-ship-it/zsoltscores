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

  @override
  Widget build(BuildContext context) {
    final p = AppThemeController.instance.palette;
    final favMatches = allMatches.where((m) {
      return favoriteIds.contains(m.id) ||
          DisplayPrefs.isFavoriteTeam(m.homeTeam) ||
          DisplayPrefs.isFavoriteTeam(m.awayTeam);
    }).toList();

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
                const Text('Kedvenc Meccsek & Csapatok ⭐', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  DisplayPrefs.favoriteTeams.isEmpty
                      ? 'Csillagozott meccsek értesítésekkel'
                      : 'Kiemelt csapatok: ${DisplayPrefs.favoriteTeams.join(', ')}',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: favMatches.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Még nincs kedvenc meccsed erre a napra.\nKoppints a csillag ikonra bármelyik meccsen!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white60, height: 1.5),
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
                          border: Border.all(color: p.goldAccent.withAlpha(80)),
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
