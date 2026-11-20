import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zsoltscores/api_service.dart';
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
    Color bg;
    if (code == 'GY') {
      bg = const Color(0xFF00E676);
    } else if (code == 'D') {
      bg = const Color(0xFFFFAB00);
    } else {
      bg = const Color(0xFFFF1744);
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

  @override
  Widget build(BuildContext context) {
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
                Text('Gyorsítótárból (${ApiConfig.providerName}) • Frissítve: $updClock', style: const TextStyle(fontSize: 11, color: Color(0xFF00B0FF)))
              else if (_match.isLive && _match.isFromApi)
                Text('Élő • $intervalSec mp • Frissítve: $updClock', style: const TextStyle(fontSize: 11, color: Color(0xFF00E676)))
              else
                Text('Frissítve: $updClock', style: const TextStyle(fontSize: 11, color: Colors.white60)),
            ],
          ),
          backgroundColor: const Color(0xFF1C2541),
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
            if (_loadingDetails) const LinearProgressIndicator(color: Color(0xFF00E676), backgroundColor: Colors.transparent),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [_match.homeColor.withAlpha(75), const Color(0xFF1C2541), _match.awayColor.withAlpha(75)]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        CachedTeamLogo(teamName: _match.homeTeam, fallbackColor: _match.homeColor, logoUrl: _match.homeLogo, radius: 22),
                        const SizedBox(height: 6),
                        Text(_match.homeTeam, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                        if (_match.homeForm.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Row(mainAxisAlignment: MainAxisAlignment.center, children: _match.homeForm.map(_formBadge).toList()),
                          const SizedBox(height: 3),
                          Text('${MatchData.formPoints(_match.homeForm)}p / 5 meccs', style: const TextStyle(fontSize: 10, color: Colors.white60)),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      Text('${_match.homeScore} : ${_match.awayScore}', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Color(0xFF00E676))),
                      Text(_match.isLive ? 'ÉLŐ • ${_match.status}' : _match.status, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                    ],
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        CachedTeamLogo(teamName: _match.awayTeam, fallbackColor: _match.awayColor, logoUrl: _match.awayLogo, radius: 22),
                        const SizedBox(height: 6),
                        Text(_match.awayTeam, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                        if (_match.awayForm.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Row(mainAxisAlignment: MainAxisAlignment.center, children: _match.awayForm.map(_formBadge).toList()),
                          const SizedBox(height: 3),
                          Text('${MatchData.formPoints(_match.awayForm)}p / 5 meccs', style: const TextStyle(fontSize: 10, color: Colors.white60)),
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
            const TabBar(
              indicatorColor: Color(0xFF00E676),
              labelColor: Color(0xFF00E676),
              unselectedLabelColor: Colors.white60,
              tabs: [
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
                              decoration: BoxDecoration(color: const Color(0xFF1C2541), borderRadius: BorderRadius.circular(12)),
                              child: Row(
                                children: [
                                  Text(h.dateLabel, style: const TextStyle(fontSize: 11, color: Colors.white54)),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text('${h.homeTeam} - ${h.awayTeam}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                                  Text(h.scoreLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF00E676))),
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
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(color: const Color(0xFF1C2541), borderRadius: BorderRadius.circular(14)),
                                    child: Row(
                                      children: [
                                        Text(ev.minute, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00E676))),
                                        const SizedBox(width: 10),
                                        Text(icon, style: const TextStyle(fontSize: 16)),
                                        const SizedBox(width: 10),
                                        Expanded(child: Text(ev.player, style: const TextStyle(fontWeight: FontWeight.w600))),
                                        Text(ev.isHome ? _match.homeTeam : _match.awayTeam, style: const TextStyle(fontSize: 11, color: Colors.white60)),
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
                        ..._match.homeLineup!.starters.map((p) => _lineupTile(p, _match.homeColor)),
                        if (_match.homeLineup!.substitutes.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Text('Cserék', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Colors.white70)),
                          ..._match.homeLineup!.substitutes.map((p) => _lineupTile(p, Colors.blueGrey)),
                        ],
                      ],
                      if (_match.awayLineup != null) ...[
                        const SizedBox(height: 16),
                        Text('${_match.awayTeam} – Kezdő (${_match.awayLineup!.formation})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 6),
                        ..._match.awayLineup!.starters.map((p) => _lineupTile(p, _match.awayColor)),
                        if (_match.awayLineup!.substitutes.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Text('Cserék', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Colors.white70)),
                          ..._match.awayLineup!.substitutes.map((p) => _lineupTile(p, Colors.blueGrey)),
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
                              color: const Color(0xFF1C2541),
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: const Icon(Icons.play_circle_fill, color: Color(0xFF00E676), size: 36),
                                title: Text(clip.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(clip.url, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF00B0FF))),
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
    final active = _eventFilter == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _eventFilter = key),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? const Color(0xFF00E676) : const Color(0xFF1C2541),
            borderRadius: BorderRadius.circular(10),
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

  Widget _lineupTile(LineupPlayer p, Color badgeColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFF1C2541), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: badgeColor,
            child: Text(
              p.number.isNotEmpty ? p.number : '•',
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          if (p.position.isNotEmpty)
            Text(p.position, style: const TextStyle(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _statBar(String label, int homeVal, int awayVal) {
    final total = (homeVal + awayVal) == 0 ? 1 : (homeVal + awayVal);
    final homeRatio = homeVal / total;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$homeVal', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              Text('$awayVal', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  Expanded(
                    flex: (homeRatio * 1000).round().clamp(1, 999),
                    child: Container(color: const Color(0xFF00E676)),
                  ),
                  Expanded(
                    flex: ((1 - homeRatio) * 1000).round().clamp(1, 999),
                    child: Container(color: const Color(0xFF00B0FF)),
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
