import 'package:flutter/material.dart' hide CollapseMode;
import 'package:zsoltscores/api_service.dart';
import 'package:zsoltscores/screens/match_stats_screen.dart';
import 'package:zsoltscores/theme/app_theme.dart';
import 'package:zsoltscores/widgets/common_widgets.dart';

class MatchesTab extends StatefulWidget {
  final List<MatchData> matches;
  final Set<String> recentlyScoredIds;
  final DateTime selectedDate;
  final DateTime lastUpdatedAt;
  final bool isLoading;
  final bool isLiveApiData;
  final bool loadedFromCache;
  final String? statusMessage;
  final Set<String> favoriteIds;
  final ValueChanged<String> onToggleFavorite;
  final ValueChanged<String> onTogglePinCompetition;
  final ValueChanged<int> onChangeDate;
  final VoidCallback onJumpToday;
  final Future<void> Function() onRefresh;
  final VoidCallback onOpenSettings;

  const MatchesTab({
    super.key,
    required this.matches,
    required this.recentlyScoredIds,
    required this.selectedDate,
    required this.lastUpdatedAt,
    required this.isLoading,
    required this.isLiveApiData,
    required this.loadedFromCache,
    required this.statusMessage,
    required this.favoriteIds,
    required this.onToggleFavorite,
    required this.onTogglePinCompetition,
    required this.onChangeDate,
    required this.onJumpToday,
    required this.onRefresh,
    required this.onOpenSettings,
  });

  @override
  State<MatchesTab> createState() => _MatchesTabState();
}

class _MatchesTabState extends State<MatchesTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  String selectedCompetition = 'Összes';
  String quickFilter = 'all';
  String searchQuery = '';
  final Set<String> _manualOverrides = {};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _applyQuickSearch(String value) {
    setState(() {
      searchQuery = value;
      _searchCtrl.text = value;
      _searchCtrl.selection = TextSelection.fromPosition(TextPosition(offset: value.length));
    });
    if (value.trim().length >= 2) {
      DisplayPrefs.addRecentSearch(value.trim());
    }
  }

  String _formatHungarianDayLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dt.year, dt.month, dt.day);
    final diff = target.difference(today).inDays;

    const weekdays = ['HÉ', 'KE', 'SZE', 'CSÜ', 'PÉN', 'SZO', 'VAS'];
    const months = ['JAN', 'FEB', 'MÁR', 'ÁPR', 'MÁJ', 'JÚN', 'JÚL', 'AUG', 'SZE', 'OKT', 'NOV', 'DEC'];
    final wd = weekdays[(dt.weekday - 1).clamp(0, 6)];
    final mo = months[(dt.month - 1).clamp(0, 11)];
    final base = '$wd, ${dt.day.toString().padLeft(2, '0')} $mo';

    if (diff == 0) return 'MA • $base';
    if (diff == -1) return 'TEGNAP • $base';
    if (diff == 1) return 'HOLNAP • $base';
    return base;
  }

  bool _defaultCollapsedFor(String compKey, List<MatchData> compMatches) {
    switch (DisplayPrefs.collapseMode) {
      case CollapseMode.allExpanded:
        return false;
      case CollapseMode.allCollapsed:
        return true;
      case CollapseMode.liveOrPinned:
        final isPinned = DisplayPrefs.pinnedCompetitions.contains(compKey);
        final hasLiveOrFavTeam = compMatches.any(
          (m) => m.isLive || DisplayPrefs.isFavoriteTeam(m.homeTeam) || DisplayPrefs.isFavoriteTeam(m.awayTeam),
        );
        return !(isPinned || hasLiveOrFavTeam);
    }
  }

  bool _isCompetitionCollapsed(String compKey, List<MatchData> compMatches) {
    final def = _defaultCollapsedFor(compKey, compMatches);
    return _manualOverrides.contains(compKey) ? !def : def;
  }

  void _toggleSingleCompetition(String compKey) {
    setState(() {
      if (_manualOverrides.contains(compKey)) {
        _manualOverrides.remove(compKey);
      } else {
        _manualOverrides.add(compKey);
      }
    });
  }

  void _toggleAllCompetitions(Map<String, List<MatchData>> grouped, List<String> visibleCompetitions) {
    if (visibleCompetitions.isEmpty) return;
    final allCollapsed =
        visibleCompetitions.every((c) => _isCompetitionCollapsed(c, grouped[c]!));
    setState(() {
      _manualOverrides.clear();
      for (final c in visibleCompetitions) {
        final def = _defaultCollapsedFor(c, grouped[c]!);
        final targetCollapsed = !allCollapsed;
        if (def != targetCollapsed) {
          _manualOverrides.add(c);
        }
      }
    });
  }

  int _compareCompetitions(MatchData ma, MatchData mb) {
    final ka = ma.fullCompetitionLabel;
    final kb = mb.fullCompetitionLabel;
    final pinA = DisplayPrefs.pinnedCompetitions.contains(ka);
    final pinB = DisplayPrefs.pinnedCompetitions.contains(kb);
    if (pinA != pinB) return pinA ? -1 : 1;

    final countryCmp = compareHungarianStrings(ma.country, mb.country);
    if (countryCmp != 0) return countryCmp;
    return compareHungarianStrings(ma.league, mb.league);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppThemeController.instance.palette;
    final groupedByCompetition = <String, List<MatchData>>{};
    final liveMatches = widget.matches.where((m) => m.isLive).toList();
    final liveCount = liveMatches.length;

    final filteredMatches = widget.matches.where((m) {
      final matchesComp = selectedCompetition == 'Összes' || m.fullCompetitionLabel == selectedCompetition;
      final isFavMatch = widget.favoriteIds.contains(m.id) ||
          DisplayPrefs.isFavoriteTeam(m.homeTeam) ||
          DisplayPrefs.isFavoriteTeam(m.awayTeam);
      final matchesQuick = switch (quickFilter) {
        'live' => m.isLive,
        'finished' => m.isFinished,
        'favs' => isFavMatch,
        _ => true,
      };
      final q = searchQuery.trim().toLowerCase();
      final matchesSearch = q.isEmpty ||
          m.homeTeam.toLowerCase().contains(q) ||
          m.awayTeam.toLowerCase().contains(q) ||
          m.league.toLowerCase().contains(q) ||
          m.country.toLowerCase().contains(q);
      return matchesComp && matchesQuick && matchesSearch;
    }).toList();

    for (final m in filteredMatches) {
      groupedByCompetition.putIfAbsent(m.fullCompetitionLabel, () => []).add(m);
    }

    final competitionKeys = groupedByCompetition.keys.toList()
      ..sort((a, b) => _compareCompetitions(groupedByCompetition[a]!.first, groupedByCompetition[b]!.first));

    final allCompSet = <String>{};
    final compSampleMap = <String, MatchData>{};
    for (final m in widget.matches) {
      allCompSet.add(m.fullCompetitionLabel);
      compSampleMap.putIfAbsent(m.fullCompetitionLabel, () => m);
    }
    final sortedChipComps = allCompSet.toList()
      ..sort((a, b) => _compareCompetitions(compSampleMap[a]!, compSampleMap[b]!));

    final dynamicCompetitions = ['Összes', ...sortedChipComps];
    if (!dynamicCompetitions.contains(selectedCompetition)) selectedCompetition = 'Összes';

    final areAllCollapsed = competitionKeys.isNotEmpty &&
        competitionKeys.every((c) => _isCompetitionCollapsed(c, groupedByCompetition[c]!));

    final countText = '${widget.matches.length} meccs';
    final updClock = SportsApiService.formatClock(widget.lastUpdatedAt);
    final provName = ApiConfig.providerName;
    final liveAutoTag = DisplayPrefs.autoLiveListRefresh ? ' • 60mp' : '';
    final sourceSubtitle = !widget.isLiveApiData
        ? 'Minta mód ($provName) • $updClock'
        : (widget.loadedFromCache
            ? 'Gyorsítótár ($provName) • $countText • $updClock'
            : '$provName Élő$liveAutoTag • $countText • $updClock');
    final sourceColor = !widget.isLiveApiData
        ? Colors.amberAccent
        : (widget.loadedFromCache ? p.secondaryAccent : p.primaryAccent);

    final quickChips = <String>{
      ...DisplayPrefs.favoriteTeams,
      ...DisplayPrefs.recentSearches,
    }.take(7).toList();

    return SafeArea(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [p.headerStart, p.headerEnd],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
              border: Border(bottom: BorderSide(color: p.borderSubtle)),
              boxShadow: const [
                BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 3)),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [p.primaryAccent, p.secondaryAccent]),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(Icons.sports_soccer, color: Color(0xFF0B132B), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'zsoltscores',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.3),
                          ),
                          Text(
                            sourceSubtitle,
                            style: TextStyle(fontSize: 10.5, color: sourceColor, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Tooltip(
                      message: DisplayPrefs.autoLiveListRefresh ? 'Élő követés aktív (60 mp)' : 'Élő követés kikapcsolva',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () async {
                          await DisplayPrefs.setAutoLiveListRefresh(!DisplayPrefs.autoLiveListRefresh);
                          setState(() {});
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  DisplayPrefs.autoLiveListRefresh
                                      ? 'Élő követés (60 mp) bekapcsolva!'
                                      : 'Élő követés kikapcsolva.',
                                ),
                              ),
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: p.scaffoldBg.withAlpha(190),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: DisplayPrefs.autoLiveListRefresh
                                  ? p.primaryAccent.withAlpha(130)
                                  : Colors.white24,
                            ),
                          ),
                          child: Icon(
                            Icons.sensors,
                            color: DisplayPrefs.autoLiveListRefresh ? p.primaryAccent : Colors.white38,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                    Tooltip(
                      message: areAllCollapsed ? 'Összes bajnokság kinyitása' : 'Összes bajnokság összecsukása',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _toggleAllCompetitions(groupedByCompetition, competitionKeys),
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: p.scaffoldBg.withAlpha(190),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: p.secondaryAccent.withAlpha(110)),
                          ),
                          child: Icon(
                            areAllCollapsed ? Icons.unfold_more : Icons.unfold_less,
                            color: p.secondaryAccent,
                            size: 19,
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => quickFilter = quickFilter == 'live' ? 'all' : 'live'),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: quickFilter == 'live' ? p.liveRed : p.liveRed.withAlpha(38),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: quickFilter == 'live' ? const Color(0xFFFF5252) : p.liveRed.withAlpha(170),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: quickFilter == 'live' ? Colors.white : p.liveRed,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'ÉLŐ ($liveCount)',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (ApiConfig.hasValidKey)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: widget.onRefresh,
                        icon: const Icon(Icons.refresh, color: Colors.white70, size: 21),
                      ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: widget.onOpenSettings,
                      icon: Icon(
                        Icons.settings,
                        color: ApiConfig.hasValidKey ? p.primaryAccent : Colors.amberAccent,
                        size: 21,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: p.scaffoldBg.withAlpha(210),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: p.secondaryAccent.withAlpha(70)),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
                            icon: Icon(Icons.chevron_left, size: 19, color: p.secondaryAccent),
                            onPressed: () => widget.onChangeDate(-1),
                          ),
                          GestureDetector(
                            onTap: widget.onJumpToday,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                _formatHungarianDayLabel(widget.selectedDate),
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                              ),
                            ),
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
                            icon: Icon(Icons.chevron_right, size: 19, color: p.secondaryAccent),
                            onPressed: () => widget.onChangeDate(1),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (val) => setState(() => searchQuery = val),
                          onSubmitted: (val) async {
                            if (val.trim().length >= 2) {
                              await DisplayPrefs.addRecentSearch(val.trim());
                              setState(() {});
                            }
                          },
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Keresés csapatra, országra vagy bajnokságra...',
                            hintStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                            prefixIcon: Icon(Icons.search, color: p.primaryAccent, size: 18),
                            suffixIcon: searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.close, size: 16, color: Colors.white54),
                                    onPressed: () => _applyQuickSearch(''),
                                  )
                                : null,
                            filled: true,
                            fillColor: p.scaffoldBg.withAlpha(210),
                            contentPadding: EdgeInsets.zero,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(11),
                              borderSide: BorderSide(color: p.borderSubtle),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(11),
                              borderSide: BorderSide(color: p.borderSubtle),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (quickChips.isNotEmpty || DisplayPrefs.recentSearches.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  SizedBox(
                    height: 26,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        ...quickChips.map((chipText) {
                          final active = searchQuery.toLowerCase() == chipText.toLowerCase();
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: GestureDetector(
                              onTap: () => _applyQuickSearch(active ? '' : chipText),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: active ? p.goldAccent : p.scaffoldBg.withAlpha(185),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: active ? p.goldAccent : Colors.white12),
                                ),
                                child: Text(
                                  chipText,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: active ? Colors.black : Colors.white70,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                        if (DisplayPrefs.recentSearches.isNotEmpty)
                          GestureDetector(
                            onTap: () async {
                              await DisplayPrefs.clearRecentSearches();
                              setState(() {});
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withAlpha(30),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.redAccent.withAlpha(90)),
                              ),
                              child: const Text(
                                '✕ Előzmény',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.redAccent),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    _quickFilterChip('Mind', 'all', p.primaryAccent),
                    const SizedBox(width: 6),
                    _quickFilterChip('Élő', 'live', p.liveRed),
                    const SizedBox(width: 6),
                    _quickFilterChip('Vége', 'finished', p.secondaryAccent),
                    const SizedBox(width: 6),
                    _quickFilterChip('Kedvencek', 'favs', p.goldAccent),
                  ],
                ),
              ],
            ),
          ),

          if (liveMatches.isNotEmpty)
            SizedBox(
              height: 64,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
                itemCount: liveMatches.length,
                itemBuilder: (ctx, idx) {
                  final lm = liveMatches[idx];
                  final lastKeyEv = lm.events.where((e) => e.type == 'goal' || e.type == 'red').toList();
                  final badgeSuffix = lastKeyEv.isNotEmpty
                      ? ' • ${lastKeyEv.last.type == 'red' ? '🟥' : '⚽'} ${lastKeyEv.last.player} ${lastKeyEv.last.minute}'
                      : '';
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(13),
                      onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => MatchStatsScreen(match: lm))),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              p.primaryAccent.withAlpha(24),
                              p.cardElevated,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(color: p.primaryAccent.withAlpha(120)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: p.liveRed,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                lm.status,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10.5),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${lm.homeTeam}  ${lm.homeScore} - ${lm.awayScore}  ${lm.awayTeam}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                            ),
                            if (badgeSuffix.isNotEmpty)
                              Text(
                                badgeSuffix,
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: p.primaryAccent),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          if (widget.isLoading)
            LinearProgressIndicator(color: p.primaryAccent, backgroundColor: Colors.transparent),

          if (!ApiConfig.hasValidKey)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 2),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [p.primaryAccent.withAlpha(32), p.secondaryAccent.withAlpha(28)],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: p.primaryAccent.withAlpha(130)),
              ),
              child: Row(
                children: [
                  Icon(Icons.vpn_key, color: p.primaryAccent, size: 19),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Add meg a ${ApiConfig.providerName} kulcsodat az élő meccsekhez!',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 6),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: p.primaryAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                    ),
                    onPressed: widget.onOpenSettings,
                    child: const Text('Kulcs', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ],
              ),
            ),

          if (widget.statusMessage != null)
            GestureDetector(
              onTap: widget.onOpenSettings,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withAlpha(120)),
                ),
                child: Text(
                  widget.statusMessage!,
                  style: const TextStyle(fontSize: 11, color: Colors.amberAccent),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

          SizedBox(
            height: 46,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              itemCount: dynamicCompetitions.length,
              itemBuilder: (context, index) {
                final comp = dynamicCompetitions[index];
                final isSelected = selectedCompetition == comp;
                final isPinned = DisplayPrefs.pinnedCompetitions.contains(comp);
                final label = comp == 'Összes'
                    ? 'Összes (${widget.matches.length})'
                    : (isPinned ? '📌 $comp' : comp);
                final accent = comp == 'Összes'
                    ? p.primaryAccent
                    : (isPinned ? p.goldAccent : SportsApiService.colorFromName(comp));

                return Padding(
                  padding: const EdgeInsets.only(right: 7),
                  child: GestureDetector(
                    onTap: () => setState(() => selectedCompetition = comp),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(colors: [accent, accent.withAlpha(190)])
                            : null,
                        color: isSelected ? null : p.cardElevated,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? accent : (isPinned ? p.goldAccent.withAlpha(110) : p.borderSubtle),
                        ),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              color: p.primaryAccent,
              onRefresh: widget.onRefresh,
              child: competitionKeys.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 100),
                        Center(child: Text('Nincs a szűrésnek megfelelő meccs.', style: TextStyle(color: Colors.white60))),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                      itemCount: competitionKeys.length,
                      itemBuilder: (context, cIdx) {
                        final compKey = competitionKeys[cIdx];
                        final compMatches = groupedByCompetition[compKey]!;
                        final firstMatch = compMatches.first;
                        final countryName = firstMatch.country.toUpperCase();
                        final leagueName = firstMatch.league.toUpperCase();
                        final isPinned = DisplayPrefs.pinnedCompetitions.contains(compKey);
                        final isCollapsed = _isCompetitionCollapsed(compKey, compMatches);
                        final accent = isPinned
                            ? p.goldAccent
                            : SportsApiService.colorFromName(compKey);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: p.cardBg,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: accent.withAlpha(isPinned ? 135 : 75)),
                          ),
                          child: Column(
                            children: [
                              InkWell(
                                borderRadius: BorderRadius.vertical(
                                  top: const Radius.circular(15),
                                  bottom: Radius.circular(isCollapsed ? 15 : 0),
                                ),
                                onTap: () => _toggleSingleCompetition(compKey),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        accent.withAlpha(62),
                                        p.cardElevated,
                                        accent.withAlpha(20),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.vertical(
                                      top: const Radius.circular(15),
                                      bottom: Radius.circular(isCollapsed ? 15 : 0),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 4,
                                        height: 18,
                                        decoration: BoxDecoration(
                                          color: accent,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      ),
                                      const SizedBox(width: 7),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                        decoration: BoxDecoration(
                                          color: p.scaffoldBg.withAlpha(215),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: accent.withAlpha(120)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            CountryFlagBadge(
                                              countryName: firstMatch.country,
                                              flagUrl: firstMatch.countryFlagUrl,
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              countryName,
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w900,
                                                color: accent,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 7),
                                      Expanded(
                                        child: Text(
                                          leagueName,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                            letterSpacing: 0.3,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => widget.onTogglePinCompetition(compKey),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                          child: Icon(
                                            isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                                            size: 16,
                                            color: isPinned ? p.goldAccent : Colors.white38,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.black38,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          '${compMatches.length}',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: accent),
                                        ),
                                      ),
                                      const SizedBox(width: 3),
                                      Icon(
                                        isCollapsed ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                                        size: 18,
                                        color: Colors.white70,
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              if (!isCollapsed)
                                ...List.generate(compMatches.length, (mIdx) {
                                  final match = compMatches[mIdx];
                                  final isLast = mIdx == compMatches.length - 1;
                                  return Column(
                                    children: [
                                      MatchCard(
                                        match: match,
                                        isFavorite: widget.favoriteIds.contains(match.id),
                                        isGoalFlash: widget.recentlyScoredIds.contains(match.id),
                                        onToggleFavorite: () => widget.onToggleFavorite(match.id),
                                      ),
                                      if (!isLast)
                                        Divider(
                                          height: 1,
                                          thickness: 1,
                                          color: p.borderSubtle,
                                        ),
                                    ],
                                  );
                                }),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickFilterChip(String label, String value, Color accent) {
    final p = AppThemeController.instance.palette;
    final active = quickFilter == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => quickFilter = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 5.5),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? accent : p.scaffoldBg.withAlpha(200),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: active ? accent : p.borderSubtle),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: active ? Colors.black : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }
}

class MatchCard extends StatelessWidget {
  final MatchData match;
  final bool isFavorite;
  final bool isGoalFlash;
  final VoidCallback onToggleFavorite;

  const MatchCard({
    super.key,
    required this.match,
    required this.isFavorite,
    this.isGoalFlash = false,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppThemeController.instance.palette;
    final homeWinning = match.isLive || match.isFinished ? match.homeScore > match.awayScore : false;
    final awayWinning = match.isLive || match.isFinished ? match.awayScore > match.homeScore : false;
    final showScore = match.isLive || match.isFinished;

    final homeFavTeam = DisplayPrefs.isFavoriteTeam(match.homeTeam);
    final awayFavTeam = DisplayPrefs.isFavoriteTeam(match.awayTeam);
    final hasFavTeam = homeFavTeam || awayFavTeam;

    final keyEvents = match.events
        .where((e) => e.type == 'goal' || e.type == 'red' || e.type == 'yellow' || e.type == 'sub')
        .toList();

    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MatchStatsScreen(match: match))),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 450),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        decoration: BoxDecoration(
          color: isGoalFlash
              ? p.primaryAccent.withAlpha(55)
              : (match.isLive ? p.primaryAccent.withAlpha(14) : Colors.transparent),
          border: hasFavTeam
              ? Border(left: BorderSide(color: p.goldAccent, width: 3.5))
              : (match.isLive ? Border(left: BorderSide(color: p.primaryAccent, width: 3)) : null),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 50,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (match.isLive) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: p.liveRed,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'ÉLŐ',
                            style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w900, letterSpacing: 0.4),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          match.status,
                          style: TextStyle(color: p.primaryAccent, fontSize: 11, fontWeight: FontWeight.w900),
                          textAlign: TextAlign.center,
                        ),
                      ] else if (match.isFinished) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(14),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            match.status,
                            style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ] else ...[
                        Text(
                          match.status,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  width: 2,
                  height: 38,
                  margin: const EdgeInsets.symmetric(horizontal: 9),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [match.homeColor.withAlpha(200), match.awayColor.withAlpha(200)],
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _teamLine(
                        name: match.homeTeam,
                        color: match.homeColor,
                        logoUrl: match.homeLogo,
                        isWinning: homeWinning,
                        isFinished: match.isFinished,
                        isFavTeam: homeFavTeam,
                      ),
                      const SizedBox(height: 7),
                      _teamLine(
                        name: match.awayTeam,
                        color: match.awayColor,
                        logoUrl: match.awayLogo,
                        isWinning: awayWinning,
                        isFinished: match.isFinished,
                        isFavTeam: awayFavTeam,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 34,
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  decoration: BoxDecoration(
                    color: match.isLive
                        ? p.primaryAccent.withAlpha(22)
                        : Colors.white.withAlpha(10),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: match.isLive ? p.primaryAccent.withAlpha(90) : Colors.white10,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        showScore ? '${match.homeScore}' : '-',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          color: match.isLive
                              ? p.primaryAccent
                              : (homeWinning ? Colors.white : Colors.white60),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        showScore ? '${match.awayScore}' : '-',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          color: match.isLive
                              ? p.primaryAccent
                              : (awayWinning ? Colors.white : Colors.white60),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onToggleFavorite,
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: Icon(
                      isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: isFavorite ? p.goldAccent : Colors.white30,
                      size: 21,
                    ),
                  ),
                ),
              ],
            ),
            if (keyEvents.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 59),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  children: keyEvents.map((ev) {
                    final isRed = ev.type == 'red';
                    final isYellow = ev.type == 'yellow';
                    final isSub = ev.type == 'sub';
                    final icon = isRed ? '🟥' : (isYellow ? '🟨' : (isSub ? '🔄' : '⚽'));
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: isRed
                            ? p.liveRed.withAlpha(32)
                            : (isYellow
                                ? p.goldAccent.withAlpha(22)
                                : Colors.white.withAlpha(12)),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                          color: isRed
                              ? p.liveRed.withAlpha(110)
                              : (isYellow ? p.goldAccent.withAlpha(90) : Colors.white12),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(icon, style: const TextStyle(fontSize: 10)),
                          const SizedBox(width: 4),
                          Text(
                            '${ev.player} ${ev.minute}',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isRed
                                  ? const Color(0xFFFF8A80)
                                  : (isYellow ? const Color(0xFFFFE082) : Colors.white70),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _teamLine({
    required String name,
    required Color color,
    required String? logoUrl,
    required bool isWinning,
    required bool isFinished,
    required bool isFavTeam,
  }) {
    final dimTeam = isFinished && !isWinning;
    return Row(
      children: [
        CachedTeamLogo(
          teamName: name,
          fallbackColor: color,
          logoUrl: logoUrl,
          radius: 10,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            isFavTeam ? '★ $name' : name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: (isWinning || isFavTeam) ? FontWeight.w800 : FontWeight.w600,
              color: isFavTeam ? const Color(0xFFFFD54F) : (dimTeam ? Colors.white54 : Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
