import 'package:flutter/material.dart';
import 'package:zsoltscores/api_service.dart';
import 'package:zsoltscores/tabs/matches_tab.dart';
import 'package:zsoltscores/theme/app_theme.dart';
import 'package:zsoltscores/widgets/common_widgets.dart';

class TeamProfileScreen extends StatefulWidget {
  final String teamName;
  final String? logoUrl;
  final Color accentColor;
  final List<String> form;
  final StandingRow? standingRow;
  final List<MatchData> relatedMatches;
  final VoidCallback onChanged;

  const TeamProfileScreen({
    super.key,
    required this.teamName,
    this.logoUrl,
    required this.accentColor,
    this.form = const [],
    this.standingRow,
    this.relatedMatches = const [],
    required this.onChanged,
  });

  @override
  State<TeamProfileScreen> createState() => _TeamProfileScreenState();
}

class _TeamProfileScreenState extends State<TeamProfileScreen> {
  late bool _isFav;

  @override
  void initState() {
    super.initState();
    _isFav = DisplayPrefs.isFavoriteTeam(widget.teamName);
  }

  Future<void> _toggleFav() async {
    await DisplayPrefs.toggleFavoriteTeam(widget.teamName);
    setState(() => _isFav = DisplayPrefs.isFavoriteTeam(widget.teamName));
    widget.onChanged();
  }

  Widget _badge(String code) {
    final p = AppThemeController.instance.palette;
    Color bg;
    if (code == 'GY') {
      bg = p.primaryAccent;
    } else if (code == 'D') {
      bg = p.goldAccent;
    } else {
      bg = p.liveRed;
    }
    return Container(
      width: 24,
      height: 24,
      margin: const EdgeInsets.only(right: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Text(code, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10.5)),
    );
  }

  Widget _statTile(AppPalette p, String label, String value, Color accent) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
        decoration: BoxDecoration(
          color: p.scaffoldBg.withAlpha(210),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: p.borderSubtle),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontWeight: FontWeight.w900, color: accent, fontSize: 13.5)),
            const SizedBox(height: 2),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: p.textMuted)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppThemeController.instance.palette;
    final effectiveForm = widget.form.isNotEmpty ? widget.form : const ['GY', 'D', 'GY', 'V', 'GY'];
    final pts = MatchData.formPoints(effectiveForm);
    final wCount = effectiveForm.where((c) => c == 'GY').length;
    final dCount = effectiveForm.where((c) => c == 'D').length;
    final lCount = effectiveForm.where((c) => c == 'V').length;

    final row = widget.standingRow;
    final played = (row != null && row.played > 0) ? row.played : 0;
    final gfAvg = played > 0 ? (row!.gf / played).toStringAsFixed(1) : '-';
    final gaAvg = played > 0 ? (row!.ga / played).toStringAsFixed(1) : '-';
    final gdText = row != null ? (row.gd > 0 ? '+${row.gd}' : '${row.gd}') : '-';
    final cleanSheetApprox = widget.relatedMatches.where((m) {
      if (!m.isFinished) return false;
      final isHome = m.homeTeam.toLowerCase().contains(widget.teamName.toLowerCase());
      return isHome ? m.awayScore == 0 : m.homeScore == 0;
    }).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.teamName),
        backgroundColor: p.cardElevated,
        actions: [
          IconButton(
            tooltip: _isFav ? 'Eltávolítás a kedvenc csapatokból' : 'Hozzáadás a kedvenc csapatokhoz',
            onPressed: _toggleFav,
            icon: Icon(_isFav ? Icons.star_rounded : Icons.star_outline_rounded, color: p.goldAccent),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [widget.accentColor.withAlpha(85), p.cardElevated],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: p.borderSubtle),
            ),
            child: Row(
              children: [
                CachedTeamLogo(teamName: widget.teamName, fallbackColor: widget.accentColor, logoUrl: widget.logoUrl, radius: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.teamName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: p.textPrimary)),
                      const SizedBox(height: 4),
                      Text(
                        row != null
                            ? '${row.pos}. hely • ${row.points} pont • GK: $gdText'
                            : (_isFav ? '★ Kedvenc csapat (kiemelt a meccseknél)' : 'Koppints a csillagra a kedvenceléshez'),
                        style: TextStyle(fontSize: 12, color: _isFav ? p.goldAccent : p.textSecondary, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: p.cardElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Utolsó 5 meccs formája', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: p.textPrimary)),
                    Text('$pts pont / 15', style: TextStyle(color: p.primaryAccent, fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(children: effectiveForm.map(_badge).toList()),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _statTile(p, 'Győzelem', '$wCount', p.primaryAccent),
                    const SizedBox(width: 8),
                    _statTile(p, 'Döntetlen', '$dCount', p.goldAccent),
                    const SizedBox(width: 8),
                    _statTile(p, 'Vereség', '$lCount', p.liveRed),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _statTile(p, 'Rúgott/meccs', gfAvg, p.secondaryAccent),
                    const SizedBox(width: 8),
                    _statTile(p, 'Kapott/meccs', gaAvg, p.textSecondary),
                    const SizedBox(width: 8),
                    _statTile(p, 'Hadosztály/CS', '$cleanSheetApprox', p.primaryAccent),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Kapcsolódó meccsek', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: p.textPrimary)),
          const SizedBox(height: 8),
          if (widget.relatedMatches.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: p.cardElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: p.borderSubtle),
              ),
              child: Text('A kiválasztott napon nincs meccs a csapattal.', style: TextStyle(color: p.textMuted)),
            )
          else
            ...widget.relatedMatches.map((m) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: p.cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: p.borderSubtle),
                  ),
                  child: MatchCard(
                    match: m,
                    isFavorite: false,
                    onToggleFavorite: () {},
                  ),
                )),
        ],
      ),
    );
  }
}

class StandingsTab extends StatefulWidget {
  final List<MatchData> allMatches;
  final VoidCallback onOpenSettings;
  final VoidCallback onTeamChanged;

  const StandingsTab({
    super.key,
    required this.allMatches,
    required this.onOpenSettings,
    required this.onTeamChanged,
  });

  @override
  State<StandingsTab> createState() => _StandingsTabState();
}

class _StandingsTabState extends State<StandingsTab> {
  String selectedLeague = 'Premier League';
  String venueMode = 'all';
  bool showScorers = false;
  bool _loading = false;
  bool _isLiveRows = false;
  String? _statusBanner;
  List<StandingRow> _rows = [];

  @override
  void initState() {
    super.initState();
    _loadStandings();
  }

  Future<void> _loadStandings({bool forceRefresh = false}) async {
    if (!ApiConfig.hasValidKey) {
      setState(() {
        _rows = sampleStandings[selectedLeague] ?? sampleStandings['Premier League'] ?? [];
        _isLiveRows = false;
        _statusBanner = 'Nincs API kulcs beállítva – koppints a ⚙️ ikonra a valódi tabellához!';
      });
      return;
    }

    setState(() {
      _loading = true;
      _statusBanner = null;
    });

    try {
      final result = await SportsApiService.fetchStandings(
        selectedLeague,
        venueFilter: venueMode,
        forceRefresh: forceRefresh,
      );
      setState(() {
        _rows = result.data;
        _isLiveRows = result.data.isNotEmpty;
        _statusBanner = result.note;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _rows = [];
        _isLiveRows = false;
        _statusBanner = 'API tabella hiba ($selectedLeague): $e';
        _loading = false;
      });
    }
  }

  Color _zoneColor(String zone) {
    final p = AppThemeController.instance.palette;
    if (zone == 'ucl') return p.primaryAccent;
    if (zone == 'uel') return p.secondaryAccent;
    if (zone == 'rel') return p.liveRed;
    return Colors.transparent;
  }

  Widget _zoneLegendItem(Color color, String label, AppPalette p) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10.5, color: p.textSecondary, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _posBadge(int pos, AppPalette p) {
    if (pos == 1) {
      return Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: p.goldAccent.withAlpha(35), borderRadius: BorderRadius.circular(6)),
        child: const Text('🥇', style: TextStyle(fontSize: 12)),
      );
    }
    if (pos == 2) {
      return Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: p.borderSubtle, borderRadius: BorderRadius.circular(6)),
        child: const Text('🥈', style: TextStyle(fontSize: 12)),
      );
    }
    if (pos == 3) {
      return Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: const Color(0xFFFF8A65).withAlpha(35), borderRadius: BorderRadius.circular(6)),
        child: const Text('🥉', style: TextStyle(fontSize: 12)),
      );
    }
    return SizedBox(
      width: 22,
      child: Text('$pos.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: p.primaryAccent)),
    );
  }

  Widget _miniFormDot(String code) {
    final p = AppThemeController.instance.palette;
    Color bg;
    if (code == 'GY') {
      bg = p.primaryAccent;
    } else if (code == 'D') {
      bg = p.goldAccent;
    } else {
      bg = p.liveRed;
    }
    return Container(
      width: 14,
      height: 14,
      margin: const EdgeInsets.only(right: 2),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(3)),
      child: Text(
        code.substring(0, 1),
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 8.5),
      ),
    );
  }

  void _openTeamProfile(StandingRow row) {
    final related = widget.allMatches
        .where((m) =>
            m.homeTeam.toLowerCase().contains(row.team.toLowerCase()) ||
            m.awayTeam.toLowerCase().contains(row.team.toLowerCase()))
        .toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TeamProfileScreen(
          teamName: row.team,
          logoUrl: row.logo,
          accentColor: row.color,
          form: row.form,
          standingRow: row,
          relatedMatches: related,
          onChanged: () {
            setState(() {});
            widget.onTeamChanged();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppThemeController.instance.palette;
    final leagues = SportsApiService.highlightlyLeagueIds.keys.toList();
    final scorers = sampleTopScorers[selectedLeague] ??
        const [
          TopScorerRow(rank: 1, player: 'Liga gólkirály', team: 'Éllovas', goals: 9, assists: 3),
          TopScorerRow(rank: 2, player: 'Támadó #2', team: 'Üldöző', goals: 7, assists: 2),
        ];

    return SafeArea(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [p.headerStart, p.headerEnd]),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
              border: Border(bottom: BorderSide(color: p.borderSubtle)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bajnoki Tabellák 🏆', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: p.textPrimary)),
                    const SizedBox(height: 4),
                    Text(
                      _isLiveRows
                          ? '${ApiConfig.providerName} • ${_rows.length} csapatos állás'
                          : '${ApiConfig.providerName} • Részletes állás, gólok & forma',
                      style: TextStyle(fontSize: 12, color: _isLiveRows ? p.primaryAccent : p.goldAccent, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (ApiConfig.hasValidKey)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _loadStandings(forceRefresh: true),
                        icon: Icon(Icons.refresh, color: p.textSecondary),
                      ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: widget.onOpenSettings,
                      icon: Icon(Icons.settings, color: p.textPrimary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_loading) LinearProgressIndicator(color: p.primaryAccent, backgroundColor: Colors.transparent),
          if (_statusBanner != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: _isLiveRows ? p.primaryAccent.withAlpha(24) : p.goldAccent.withAlpha(28),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _isLiveRows ? p.primaryAccent.withAlpha(90) : p.goldAccent.withAlpha(120)),
              ),
              child: Text(
                _statusBanner!,
                style: TextStyle(fontSize: 11, color: _isLiveRows ? p.primaryAccent : p.goldAccent, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ),
          SizedBox(
            height: 52,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              itemCount: leagues.length,
              itemBuilder: (context, index) {
                final l = leagues[index];
                final isSelected = selectedLeague == l;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(l, style: const TextStyle(fontSize: 12)),
                    selected: isSelected,
                    selectedColor: p.primaryAccent,
                    backgroundColor: p.cardElevated,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : p.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    onSelected: (_) {
                      setState(() => selectedLeague = l);
                      _loadStandings(forceRefresh: false);
                    },
                  ),
                );
              },
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Összes', style: TextStyle(fontSize: 11)),
                  selected: !showScorers && venueMode == 'all',
                  selectedColor: p.secondaryAccent,
                  backgroundColor: p.cardElevated,
                  labelStyle: TextStyle(
                    color: (!showScorers && venueMode == 'all') ? Colors.white : p.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  onSelected: (_) {
                    setState(() {
                      showScorers = false;
                      venueMode = 'all';
                    });
                    _loadStandings(forceRefresh: false);
                  },
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('Hazai', style: TextStyle(fontSize: 11)),
                  selected: !showScorers && venueMode == 'home',
                  selectedColor: p.secondaryAccent,
                  backgroundColor: p.cardElevated,
                  labelStyle: TextStyle(
                    color: (!showScorers && venueMode == 'home') ? Colors.white : p.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  onSelected: (_) {
                    setState(() {
                      showScorers = false;
                      venueMode = 'home';
                    });
                    _loadStandings(forceRefresh: false);
                  },
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('Vendég', style: TextStyle(fontSize: 11)),
                  selected: !showScorers && venueMode == 'away',
                  selectedColor: p.secondaryAccent,
                  backgroundColor: p.cardElevated,
                  labelStyle: TextStyle(
                    color: (!showScorers && venueMode == 'away') ? Colors.white : p.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  onSelected: (_) {
                    setState(() {
                      showScorers = false;
                      venueMode = 'away';
                    });
                    _loadStandings(forceRefresh: false);
                  },
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('⚽ Góllövők', style: TextStyle(fontSize: 11)),
                  selected: showScorers,
                  selectedColor: p.goldAccent,
                  backgroundColor: p.cardElevated,
                  labelStyle: TextStyle(
                    color: showScorers ? Colors.white : p.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  onSelected: (_) => setState(() => showScorers = true),
                ),
              ],
            ),
          ),
          if (!showScorers) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
              child: Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  _zoneLegendItem(p.primaryAccent, 'BL / Top', p),
                  _zoneLegendItem(p.secondaryAccent, 'EL / EKL', p),
                  _zoneLegendItem(p.liveRed, 'Kieső zóna', p),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  SizedBox(width: 26, child: Text('#', style: TextStyle(color: p.textMuted, fontSize: 11))),
                  Expanded(child: Text('Csapat', style: TextStyle(color: p.textMuted, fontSize: 11))),
                  SizedBox(width: 24, child: Text('M', textAlign: TextAlign.center, style: TextStyle(color: p.textMuted, fontSize: 11))),
                  SizedBox(width: 58, child: Text('GY/D/V', textAlign: TextAlign.center, style: TextStyle(color: p.textMuted, fontSize: 10.5))),
                  SizedBox(width: 44, child: Text('Gól', textAlign: TextAlign.center, style: TextStyle(color: p.textMuted, fontSize: 11))),
                  SizedBox(width: 34, child: Text('GK', textAlign: TextAlign.center, style: TextStyle(color: p.textMuted, fontSize: 11))),
                  SizedBox(width: 32, child: Text('P', textAlign: TextAlign.center, style: TextStyle(color: p.textSecondary, fontWeight: FontWeight.bold, fontSize: 11))),
                ],
              ),
            ),
            Expanded(
              child: _rows.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _statusBanner ?? 'Ehhez a bajnoksághoz jelenleg nem érhető el tabella.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: p.textMuted),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      itemCount: _rows.length,
                      itemBuilder: (context, index) {
                        final r = _rows[index];
                        final isFav = DisplayPrefs.isFavoriteTeam(r.team);
                        final hasWdl = (r.won + r.drawn + r.lost) > 0;
                        final wdlText = hasWdl ? '${r.won}/${r.drawn}/${r.lost}' : '-';
                        final goalsText = (r.gf > 0 || r.ga > 0) ? '${r.gf}:${r.ga}' : '-';
                        final isTop3 = r.pos <= 3;

                        return InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _openTeamProfile(r),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            decoration: BoxDecoration(
                              color: isTop3 ? p.cardElevated : p.cardBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border(
                                left: BorderSide(color: _zoneColor(r.zone), width: 4),
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    _posBadge(r.pos, p),
                                    const SizedBox(width: 4),
                                    CachedTeamLogo(
                                      teamName: r.team,
                                      fallbackColor: r.color,
                                      logoUrl: r.logo,
                                      radius: 10,
                                      showInitialsOnFallback: false,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        isFav ? '★ ${r.team}' : r.team,
                                        style: TextStyle(
                                          fontWeight: isTop3 || isFav ? FontWeight.w800 : FontWeight.w700,
                                          fontSize: 12.5,
                                          color: isFav ? p.goldAccent : p.textPrimary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    SizedBox(width: 24, child: Text('${r.played}', textAlign: TextAlign.center, style: TextStyle(color: p.textSecondary, fontSize: 11.5))),
                                    SizedBox(width: 58, child: Text(wdlText, textAlign: TextAlign.center, style: TextStyle(color: p.textSecondary, fontSize: 11))),
                                    SizedBox(width: 44, child: Text(goalsText, textAlign: TextAlign.center, style: TextStyle(color: p.textSecondary, fontSize: 11))),
                                    SizedBox(width: 34, child: Text(r.gd > 0 ? '+${r.gd}' : '${r.gd}', textAlign: TextAlign.center, style: TextStyle(color: p.textSecondary, fontSize: 11.5))),
                                    SizedBox(width: 32, child: Text('${r.points}', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w900, color: p.primaryAccent, fontSize: 13))),
                                  ],
                                ),
                                if (r.form.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const SizedBox(width: 30),
                                      Row(children: r.form.map(_miniFormDot).toList()),
                                      const Spacer(),
                                      Text('Profil ›', style: TextStyle(fontSize: 10, color: p.textMuted)),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ] else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: scorers.length,
                itemBuilder: (context, idx) {
                  final sc = scorers[idx];
                  final isTop = sc.rank == 1;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: p.cardElevated,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isTop ? p.goldAccent.withAlpha(120) : p.borderSubtle,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isTop ? p.goldAccent.withAlpha(35) : p.borderSubtle,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${sc.rank}.',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: isTop ? p.goldAccent : p.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(sc.player, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: p.textPrimary)),
                              Text(sc.team, style: TextStyle(fontSize: 11, color: p.textSecondary)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: p.primaryAccent.withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('⚽ ${sc.goals}', style: TextStyle(fontWeight: FontWeight.w900, color: p.primaryAccent, fontSize: 12)),
                        ),
                        const SizedBox(width: 8),
                        Text('🅰️ ${sc.assists}', style: TextStyle(fontSize: 12, color: p.textSecondary)),
                      ],
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
