import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zsoltscores/api_service.dart';
import 'package:zsoltscores/theme/app_theme.dart';
import 'package:zsoltscores/widgets/common_widgets.dart';

class MatchStatsScreen extends StatefulWidget {
  final MatchData match;
  const MatchStatsScreen({super.key, required this.match});

  @override
  State<MatchStatsScreen> createState() => _MatchStatsScreenState();
}

class _MatchStatsScreenState extends State<MatchStatsScreen> {
  late MatchData _match;
  DateTime _updatedAt = DateTime.now();
  bool _loadingDetails = false;
  bool _fromCache = false;
  String _eventFilter = 'all';
  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();
    _match = widget.match;
    _fetchDetails();
    if (_match.isLive && _match.isFromApi) {
      final intervalSec = ApiConfig.isStatPal ? 15 : 30;
      _autoTimer = Timer.periodic(Duration(seconds: intervalSec), (_) {
        if (mounted && _match.isLive) {
          _fetchDetails(forceRefresh: true);
        }
      });
    }
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchDetails({bool forceRefresh = false}) async {
    setState(() => _loadingDetails = true);
    final result = await SportsApiService.enrichMatchDetails(_match, forceRefresh: forceRefresh);
    if (mounted) {
      setState(() {
        _match = result.data;
        _fromCache = result.fromCache;
        _updatedAt = result.fetchedAt;
        _loadingDetails = false;
      });
    }
  }

  void _shareMatchSummary() {
    Clipboard.setData(ClipboardData(text: _match.buildShareText()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Meccsállás és góllövők másolva a vágólapra!')),
    );
  }

  Widget _formBadge(String code) {
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
      width: 22,
      height: 22,
      margin: const EdgeInsets.only(right: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Text(
        code,
        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 10),
      ),
    );
  }

  int _shotAccuracy(int onTarget, int totalShots) {
    if (totalShots <= 0) return 0;
    return ((onTarget * 100) / totalShots).round().clamp(0, 100);
  }

  Widget _dominanceSummaryCard(AppPalette p, int homeAttackIndex, int awayAttackIndex, int homeAcc, int awayAcc) {
    final totalDominance = (homeAttackIndex + awayAttackIndex) == 0 ? 1 : (homeAttackIndex + awayAttackIndex);
    final homeDomPct = ((homeAttackIndex * 100) / totalDominance).round().clamp(0, 100);
    final awayDomPct = 100 - homeDomPct;

    String verdict;
    Color verdictColor;
    if ((homeDomPct - awayDomPct).abs() <= 4) {
      verdict = 'Kiegyenlített játék • Szoros mutatók';
      verdictColor = p.goldAccent;
    } else if (homeDomPct > awayDomPct) {
      verdict = '${_match.homeTeam} mezőnyfölényben ($homeDomPct%)';
      verdictColor = p.primaryAccent;
    } else {
      verdict = '${_match.awayTeam} mezőnyfölényben ($awayDomPct%)';
      verdictColor = p.secondaryAccent;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.cardElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: verdictColor.withAlpha(90)),
        gradient: LinearGradient(
          colors: [
            p.primaryAccent.withAlpha(18),
            p.cardElevated,
            p.secondaryAccent.withAlpha(18),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, color: verdictColor, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  verdict,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: verdictColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _miniMetricBox(
                  p: p,
                  label: 'Hazai pontosság',
                  value: '$homeAcc%',
                  accent: p.primaryAccent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniMetricBox(
                  p: p,
                  label: 'Játék-arány',
                  value: '$homeDomPct : $awayDomPct',
                  accent: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniMetricBox(
                  p: p,
                  label: 'Vendég pontosság',
                  value: '$awayAcc%',
                  accent: p.secondaryAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniMetricBox({
    required AppPalette p,
    required String label,
    required String value,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: p.scaffoldBg.withAlpha(175),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: p.borderSubtle),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: accent)),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppThemeController.instance.palette;
    final intervalSec = ApiConfig.isStatPal ? 15 : 30;
    final updClock = SportsApiService.formatClock(_updatedAt);
    final sortedEvents = (List<MatchEvent>.of(_match.events)
          ..sort((a, b) => a.minuteSortValue.compareTo(b.minuteSortValue)))
        .where((ev) {
      if (_eventFilter == 'goal') return ev.type == 'goal';
      if (_eventFilter == 'cards') return ev.type == 'yellow' || ev.type == 'red';
      if (_eventFilter == 'sub') return ev.type == 'sub';
      return true;
    }).toList();

    final homeAcc = _shotAccuracy(_match.shotsOnTargetHome, _match.shotsHome);
    final awayAcc = _shotAccuracy(_match.shotsOnTargetAway, _match.shotsAway);
    final homeAttackIndex = (_match.shotsHome * 2 + _match.shotsOnTargetHome * 3 + _match.cornersHome + (_match.possessionHome ~/ 10));
    final awayAttackIndex = (_match.shotsAway * 2 + _match.shotsOnTargetAway * 3 + _match.cornersAway + ((100 - _match.possessionHome) ~/ 10));

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CountryFlagBadge(countryName: _match.country, flagUrl: _match.countryFlagUrl),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('${_match.country} • ${_match.league}', style: const TextStyle(fontSize: 15), overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
              if (_fromCache)
                Text('Gyorsítótárból (${ApiConfig.providerName}) • Frissítve: $updClock', style: TextStyle(fontSize: 11, color: p.secondaryAccent))
              else if (_match.isLive && _match.isFromApi)
                Text('Élő • $intervalSec mp • Frissítve: $updClock', style: TextStyle(fontSize: 11, color: p.primaryAccent))
              else
                Text('Frissítve: $updClock', style: const TextStyle(fontSize: 11, color: Colors.white60)),
            ],
          ),
          backgroundColor: p.cardElevated,
          actions: [
            IconButton(
              tooltip: 'Eredmény másolása',
              onPressed: _shareMatchSummary,
              icon: const Icon(Icons.share_outlined),
            ),
            IconButton(
              onPressed: () => _fetchDetails(forceRefresh: true),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: Column(
          children: [
            if (_loadingDetails) LinearProgressIndicator(color: p.primaryAccent, backgroundColor: Colors.transparent),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
              decoration: BoxDecoration(
                color: p.cardElevated,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: _match.isLive ? p.primaryAccent.withAlpha(110) : p.borderSubtle,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _match.homeColor.withAlpha(55),
                    p.cardElevated,
                    _match.awayColor.withAlpha(55),
                  ],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        CachedTeamLogo(teamName: _match.homeTeam, fallbackColor: _match.homeColor, logoUrl: _match.homeLogo, radius: 24),
                        const SizedBox(height: 8),
                        Text(_match.homeTeam, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                        if (_match.homeForm.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(mainAxisAlignment: MainAxisAlignment.center, children: _match.homeForm.map(_formBadge).toList()),
                          const SizedBox(height: 3),
                          Text('${MatchData.formPoints(_match.homeForm)}p / 5 meccs', style: const TextStyle(fontSize: 10, color: Colors.white54)),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(85),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${_match.homeScore} : ${_match.awayScore}',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            color: _match.isLive ? p.primaryAccent : Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _match.isLive ? 'ÉLŐ • ${_match.status}' : _match.status,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _match.isLive ? p.primaryAccent : Colors.white60,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        CachedTeamLogo(teamName: _match.awayTeam, fallbackColor: _match.awayColor, logoUrl: _match.awayLogo, radius: 24),
                        const SizedBox(height: 8),
                        Text(_match.awayTeam, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                        if (_match.awayForm.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(mainAxisAlignment: MainAxisAlignment.center, children: _match.awayForm.map(_formBadge).toList()),
                          const SizedBox(height: 3),
                          Text('${MatchData.formPoints(_match.awayForm)}p / 5 meccs', style: const TextStyle(fontSize: 10, color: Colors.white54)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_match.detailNote != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(_match.detailNote!, style: const TextStyle(fontSize: 11.5, color: Colors.amberAccent), textAlign: TextAlign.center),
              ),
            TabBar(
              indicatorColor: p.primaryAccent,
              labelColor: p.primaryAccent,
              unselectedLabelColor: Colors.white60,
              tabs: const [
                Tab(text: 'Statisztika'),
                Tab(text: 'Idővonal'),
                Tab(text: 'Felállás'),
                Tab(text: 'Videók'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _dominanceSummaryCard(p, homeAttackIndex, awayAttackIndex, homeAcc, awayAcc),
                      _statBar('Labdabirtoklás (%)', _match.possessionHome, 100 - _match.possessionHome),
                      _statBar('Összes lövés', _match.shotsHome, _match.shotsAway),
                      _statBar('Kaput eltaláló lövés', _match.shotsOnTargetHome, _match.shotsOnTargetAway),
                      _statBar('Lövési pontosság (%)', homeAcc, awayAcc),
                      _statBar('Támadási index', homeAttackIndex, awayAttackIndex),
                      _statBar('Szögletek', _match.cornersHome, _match.cornersAway),
                      _statBar('Szabálytalanságok', _match.foulsHome, _match.foulsAway),
                      if (_match.h2hFixtures.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Text('Egymás elleni meccsek (H2H)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 8),
                        ..._match.h2hFixtures.map((h) => Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                              decoration: BoxDecoration(
                                color: p.cardElevated,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: p.borderSubtle),
                              ),
                              child: Row(
                                children: [
                                  Text(h.dateLabel, style: const TextStyle(fontSize: 11, color: Colors.white54)),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text('${h.homeTeam} - ${h.awayTeam}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                                  Text(h.scoreLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: p.primaryAccent)),
                                ],
                              ),
                            )),
                      ],
                    ],
                  ),
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Row(
                          children: [
                            _eventFilterChip('Mind', 'all'),
                            const SizedBox(width: 6),
                            _eventFilterChip('⚽ Gólok', 'goal'),
                            const SizedBox(width: 6),
                            _eventFilterChip('🟨/🟥 Lapok', 'cards'),
                            const SizedBox(width: 6),
                            _eventFilterChip('🔄 Cserék', 'sub'),
                          ],
                        ),
                      ),
                      Expanded(
                        child: sortedEvents.isEmpty
                            ? const Center(child: Text('Nincs a szűrőnek megfelelő esemény.', style: TextStyle(color: Colors.white60)))
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: sortedEvents.length,
                                itemBuilder: (context, idx) {
                                  final ev = sortedEvents[idx];
                                  final icon = ev.type == 'goal'
                                      ? '⚽'
                                      : (ev.type == 'red' ? '🟥' : (ev.type == 'sub' ? '🔄' : '🟨'));
                                  final sideColor = ev.isHome ? p.primaryAccent : p.secondaryAccent;
                                  final isGoal = ev.type == 'goal';
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isGoal ? sideColor.withAlpha(18) : p.cardElevated,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border(
                                        left: BorderSide(color: sideColor, width: 3.5),
                                        top: BorderSide(color: isGoal ? sideColor.withAlpha(90) : p.borderSubtle),
                                        right: BorderSide(color: isGoal ? sideColor.withAlpha(90) : p.borderSubtle),
                                        bottom: BorderSide(color: isGoal ? sideColor.withAlpha(90) : p.borderSubtle),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 42,
                                          child: Text(
                                            ev.minute,
                                            style: TextStyle(fontWeight: FontWeight.w900, color: sideColor, fontSize: 12),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(icon, style: const TextStyle(fontSize: 16)),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(ev.player, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                              Text(
                                                ev.isHome ? _match.homeTeam : _match.awayTeam,
                                                style: const TextStyle(fontSize: 10.5, color: Colors.white54),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: sideColor.withAlpha(24),
                                            borderRadius: BorderRadius.circular(7),
                                          ),
                                          child: Text(
                                            ev.isHome ? 'HAZAI' : 'VENDÉG',
                                            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: sideColor),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_match.homeLineup != null)
                        FormationPitchView(
                          teamName: _match.homeTeam,
                          accent: _match.homeColor,
                          lineup: _match.homeLineup!,
                        ),
                      if (_match.awayLineup != null)
                        FormationPitchView(
                          teamName: _match.awayTeam,
                          accent: _match.awayColor,
                          lineup: _match.awayLineup!,
                        ),
                      if (_match.homeLineup != null) ...[
                        const SizedBox(height: 6),
                        Text('${_match.homeTeam} – Kezdő (${_match.homeLineup!.formation})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 6),
                        ..._match.homeLineup!.starters.map((pl) => _lineupTile(pl, _match.homeColor)),
                        if (_match.homeLineup!.substitutes.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Text('Cserék', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Colors.white70)),
                          ..._match.homeLineup!.substitutes.map((pl) => _lineupTile(pl, Colors.blueGrey)),
                        ],
                      ],
                      if (_match.awayLineup != null) ...[
                        const SizedBox(height: 16),
                        Text('${_match.awayTeam} – Kezdő (${_match.awayLineup!.formation})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 6),
                        ..._match.awayLineup!.starters.map((pl) => _lineupTile(pl, _match.awayColor)),
                        if (_match.awayLineup!.substitutes.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Text('Cserék', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Colors.white70)),
                          ..._match.awayLineup!.substitutes.map((pl) => _lineupTile(pl, Colors.blueGrey)),
                        ],
                      ],
                    ],
                  ),
                  _match.highlights.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Ehhez a mérkőzéshez még nincs elérhető videó összefoglaló.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white60),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _match.highlights.length,
                          itemBuilder: (context, idx) {
                            final clip = _match.highlights[idx];
                            return Card(
                              color: p.cardElevated,
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: Icon(Icons.play_circle_fill, color: p.primaryAccent, size: 36),
                                title: Text(clip.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(clip.url, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: p.secondaryAccent)),
                                trailing: const Icon(Icons.copy, size: 18),
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: clip.url));
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Videó link másolva a vágólapra!')));
                                },
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _eventFilterChip(String label, String key) {
    final p = AppThemeController.instance.palette;
    final active = _eventFilter == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _eventFilter = key),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? p.primaryAccent : p.cardElevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: active ? p.primaryAccent : p.borderSubtle),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: active ? Colors.black : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }

  Widget _lineupTile(LineupPlayer pl, Color badgeColor) {
    final p = AppThemeController.instance.palette;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: p.cardElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.borderSubtle),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: badgeColor,
            child: Text(
              pl.number.isNotEmpty ? pl.number : '•',
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(pl.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          if (pl.position.isNotEmpty)
            Text(pl.position, style: const TextStyle(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _statBar(String label, int homeVal, int awayVal) {
    final p = AppThemeController.instance.palette;
    final total = (homeVal + awayVal) == 0 ? 1 : (homeVal + awayVal);
    final homeRatio = homeVal / total;
    final homeLeads = homeVal > awayVal;
    final awayLeads = awayVal > homeVal;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: p.cardElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.borderSubtle),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$homeVal',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13.5,
                  color: homeLeads ? p.primaryAccent : Colors.white,
                ),
              ),
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
              Text(
                '$awayVal',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13.5,
                  color: awayLeads ? p.secondaryAccent : Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  Expanded(
                    flex: (homeRatio * 1000).round().clamp(1, 999),
                    child: Container(color: p.primaryAccent),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    flex: ((1 - homeRatio) * 1000).round().clamp(1, 999),
                    child: Container(color: p.secondaryAccent),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
