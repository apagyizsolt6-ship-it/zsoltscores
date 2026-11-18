import 'package:flutter/material.dart';

void main() {
  runApp(const ZsoltScoresApp());
}

class ZsoltScoresApp extends StatelessWidget {
  const ZsoltScoresApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'zsoltscores',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B132B),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E676),
          secondary: Color(0xFF00B0FF),
          surface: Color(0xFF1C2541),
        ),
        useMaterial3: true,
      ),
      home: const MainShell(),
    );
  }
}

// --- ADATMODELLEK ---
class MatchEvent {
  final String minute;
  final String player;
  final String type; // 'goal', 'yellow', 'red'
  final bool isHome;

  const MatchEvent({
    required this.minute,
    required this.player,
    required this.type,
    required this.isHome,
  });
}

class MatchData {
  final String id;
  final String league;
  final String homeTeam;
  final String awayTeam;
  final Color homeColor;
  final Color awayColor;
  final int homeScore;
  final int awayScore;
  final String status;
  final bool isLive;
  final int possessionHome;
  final int shotsHome;
  final int shotsAway;
  final int shotsOnTargetHome;
  final int shotsOnTargetAway;
  final int cornersHome;
  final int cornersAway;
  final int foulsHome;
  final int foulsAway;
  final List<MatchEvent> events;

  const MatchData({
    required this.id,
    required this.league,
    required this.homeTeam,
    required this.awayTeam,
    required this.homeColor,
    required this.awayColor,
    required this.homeScore,
    required this.awayScore,
    required this.status,
    required this.isLive,
    required this.possessionHome,
    required this.shotsHome,
    required this.shotsAway,
    required this.shotsOnTargetHome,
    required this.shotsOnTargetAway,
    required this.cornersHome,
    required this.cornersAway,
    required this.foulsHome,
    required this.foulsAway,
    required this.events,
  });
}

class StandingRow {
  final int pos;
  final String team;
  final Color color;
  final int played;
  final int won;
  final int drawn;
  final int lost;
  final int gd;
  final int points;
  final String zone; // 'ucl', 'uel', 'rel', 'none'

  const StandingRow({
    required this.pos,
    required this.team,
    required this.color,
    required this.played,
    required this.won,
    required this.drawn,
    required this.lost,
    required this.gd,
    required this.points,
    required this.zone,
  });
}

// --- MINTA ADATOK ---
const List<MatchData> sampleMatches = [
  MatchData(
    id: 'm1',
    league: 'Bajnokok Ligája',
    homeTeam: 'Real Madrid',
    awayTeam: 'Liverpool',
    homeColor: Color(0xFF7C4DFF),
    awayColor: Color(0xFFFF1744),
    homeScore: 2,
    awayScore: 2,
    status: "74'",
    isLive: true,
    possessionHome: 48,
    shotsHome: 13,
    shotsAway: 15,
    shotsOnTargetHome: 6,
    shotsOnTargetAway: 7,
    cornersHome: 5,
    cornersAway: 8,
    foulsHome: 11,
    foulsAway: 9,
    events: [
      MatchEvent(minute: "14'", player: 'Szoboszlai D.', type: 'goal', isHome: false),
      MatchEvent(minute: "28'", player: 'Valverde', type: 'yellow', isHome: true),
      MatchEvent(minute: "39'", player: 'Vinícius Jr.', type: 'goal', isHome: true),
      MatchEvent(minute: "52'", player: 'Salah', type: 'goal', isHome: false),
      MatchEvent(minute: "61'", player: 'Van Dijk', type: 'yellow', isHome: false),
      MatchEvent(minute: "69'", player: 'Bellingham', type: 'goal', isHome: true),
    ],
  ),
  MatchData(
    id: 'm2',
    league: 'NB I',
    homeTeam: 'Ferencváros',
    awayTeam: 'Puskás Akadémia',
    homeColor: Color(0xFF00E676),
    awayColor: Color(0xFFFFAB00),
    homeScore: 3,
    awayScore: 1,
    status: "82'",
    isLive: true,
    possessionHome: 61,
    shotsHome: 16,
    shotsAway: 7,
    shotsOnTargetHome: 9,
    shotsOnTargetAway: 3,
    cornersHome: 7,
    cornersAway: 2,
    foulsHome: 10,
    foulsAway: 14,
    events: [
      MatchEvent(minute: "19'", player: 'Varga B.', type: 'goal', isHome: true),
      MatchEvent(minute: "44'", player: 'Nagy Zs.', type: 'goal', isHome: false),
      MatchEvent(minute: "58'", player: 'Abu Fani', type: 'goal', isHome: true),
      MatchEvent(minute: "72'", player: 'Colley', type: 'yellow', isHome: false),
      MatchEvent(minute: "77'", player: 'Traoré', type: 'goal', isHome: true),
    ],
  ),
  MatchData(
    id: 'm3',
    league: 'Premier League',
    homeTeam: 'Arsenal',
    awayTeam: 'Man. City',
    homeColor: Color(0xFFFF5252),
    awayColor: Color(0xFF00B0FF),
    homeScore: 1,
    awayScore: 0,
    status: 'VÉGE',
    isLive: false,
    possessionHome: 44,
    shotsHome: 10,
    shotsAway: 14,
    shotsOnTargetHome: 4,
    shotsOnTargetAway: 5,
    cornersHome: 4,
    cornersAway: 6,
    foulsHome: 12,
    foulsAway: 8,
    events: [
      MatchEvent(minute: "34'", player: 'Rodri', type: 'yellow', isHome: false),
      MatchEvent(minute: "86'", player: 'Saka', type: 'goal', isHome: true),
    ],
  ),
  MatchData(
    id: 'm4',
    league: 'NB I',
    homeTeam: 'Diósgyőr',
    awayTeam: 'Újpest',
    homeColor: Color(0xFFFF1744),
    awayColor: Color(0xFFAA00FF),
    homeScore: 1,
    awayScore: 1,
    status: "56'",
    isLive: true,
    possessionHome: 52,
    shotsHome: 9,
    shotsAway: 8,
    shotsOnTargetHome: 4,
    shotsOnTargetAway: 4,
    cornersHome: 5,
    cornersAway: 4,
    foulsHome: 13,
    foulsAway: 11,
    events: [
      MatchEvent(minute: "23'", player: 'Gera D.', type: 'goal', isHome: true),
      MatchEvent(minute: "49'", player: 'Brodic', type: 'goal', isHome: false),
    ],
  ),
  MatchData(
    id: 'm5',
    league: 'Bajnokok Ligája',
    homeTeam: 'Bayern München',
    awayTeam: 'Barcelona',
    homeColor: Color(0xFFD50000),
    awayColor: Color(0xFF2979FF),
    homeScore: 2,
    awayScore: 3,
    status: 'VÉGE',
    isLive: false,
    possessionHome: 49,
    shotsHome: 14,
    shotsAway: 12,
    shotsOnTargetHome: 6,
    shotsOnTargetAway: 7,
    cornersHome: 6,
    cornersAway: 3,
    foulsHome: 9,
    foulsAway: 10,
    events: [
      MatchEvent(minute: "11'", player: 'Raphinha', type: 'goal', isHome: false),
      MatchEvent(minute: "27'", player: 'Kane', type: 'goal', isHome: true),
      MatchEvent(minute: "45'", player: 'Lewandowski', type: 'goal', isHome: false),
      MatchEvent(minute: "64'", player: 'Musiala', type: 'goal', isHome: true),
      MatchEvent(minute: "81'", player: 'Yamal', type: 'goal', isHome: false),
    ],
  ),
];

const Map<String, List<StandingRow>> sampleStandings = {
  'NB I': [
    StandingRow(pos: 1, team: 'Ferencváros', color: Color(0xFF00E676), played: 14, won: 10, drawn: 2, lost: 2, gd: 18, points: 32, zone: 'ucl'),
    StandingRow(pos: 2, team: 'Puskás Akadémia', color: Color(0xFFFFAB00), played: 14, won: 9, drawn: 2, lost: 3, gd: 11, points: 29, zone: 'uel'),
    StandingRow(pos: 3, team: 'Paks', color: Color(0xFF00C853), played: 14, won: 8, drawn: 3, lost: 3, gd: 9, points: 27, zone: 'uel'),
    StandingRow(pos: 4, team: 'Diósgyőr', color: Color(0xFFFF1744), played: 14, won: 6, drawn: 5, lost: 3, gd: 4, points: 23, zone: 'none'),
    StandingRow(pos: 5, team: 'Újpest', color: Color(0xFFAA00FF), played: 14, won: 6, drawn: 4, lost: 4, gd: 3, points: 22, zone: 'none'),
    StandingRow(pos: 11, team: 'Debrecen', color: Color(0xFFD50000), played: 14, won: 3, drawn: 3, lost: 8, gd: -10, points: 12, zone: 'rel'),
    StandingRow(pos: 12, team: 'Kecskemét', color: Color(0xFF7C4DFF), played: 14, won: 2, drawn: 4, lost: 8, gd: -13, points: 10, zone: 'rel'),
  ],
  'Premier League': [
    StandingRow(pos: 1, team: 'Liverpool', color: Color(0xFFFF1744), played: 12, won: 10, drawn: 1, lost: 1, gd: 17, points: 31, zone: 'ucl'),
    StandingRow(pos: 2, team: 'Man. City', color: Color(0xFF00B0FF), played: 12, won: 8, drawn: 2, lost: 2, gd: 11, points: 26, zone: 'ucl'),
    StandingRow(pos: 3, team: 'Arsenal', color: Color(0xFFFF5252), played: 12, won: 7, drawn: 3, lost: 2, gd: 9, points: 24, zone: 'ucl'),
    StandingRow(pos: 4, team: 'Chelsea', color: Color(0xFF2979FF), played: 12, won: 6, drawn: 4, lost: 2, gd: 8, points: 22, zone: 'ucl'),
    StandingRow(pos: 5, team: 'Aston Villa', color: Color(0xFF8E24AA), played: 12, won: 6, drawn: 3, lost: 3, gd: 3, points: 21, zone: 'uel'),
    StandingRow(pos: 18, team: 'Southampton', color: Color(0xFFD50000), played: 12, won: 1, drawn: 2, lost: 9, gd: -16, points: 5, zone: 'rel'),
  ],
  'Bajnokok Ligája': [
    StandingRow(pos: 1, team: 'Liverpool', color: Color(0xFFFF1744), played: 5, won: 5, drawn: 0, lost: 0, gd: 11, points: 15, zone: 'ucl'),
    StandingRow(pos: 2, team: 'Barcelona', color: Color(0xFF2979FF), played: 5, won: 4, drawn: 0, lost: 1, gd: 13, points: 12, zone: 'ucl'),
    StandingRow(pos: 3, team: 'Arsenal', color: Color(0xFFFF5252), played: 5, won: 3, drawn: 1, lost: 1, gd: 6, points: 10, zone: 'ucl'),
    StandingRow(pos: 4, team: 'Bayern München', color: Color(0xFFD50000), played: 5, won: 3, drawn: 0, lost: 2, gd: 5, points: 9, zone: 'uel'),
    StandingRow(pos: 5, team: 'Real Madrid', color: Color(0xFF7C4DFF), played: 5, won: 2, drawn: 1, lost: 2, gd: 1, points: 7, zone: 'uel'),
  ],
};

// --- FŐ NAVIGÁCIÓS KERET ---
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  final Set<String> _favoriteIds = {'m1', 'm2'};

  void _toggleFavorite(String id) {
    setState(() {
      if (_favoriteIds.contains(id)) {
        _favoriteIds.remove(id);
      } else {
        _favoriteIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      MatchesTab(favoriteIds: _favoriteIds, onToggleFavorite: _toggleFavorite),
      const StandingsTab(),
      FavoritesTab(favoriteIds: _favoriteIds, onToggleFavorite: _toggleFavorite),
    ];

    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF1C2541),
        indicatorColor: const Color(0xFF00E676).withAlpha(55),
        selectedIndex: _selectedIndex,
        onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.sports_soccer_outlined),
            selectedIcon: Icon(Icons.sports_soccer, color: Color(0xFF00E676)),
            label: 'Meccsek',
          ),
          const NavigationDestination(
            icon: Icon(Icons.leaderboard_outlined),
            selectedIcon: Icon(Icons.leaderboard, color: Color(0xFF00B0FF)),
            label: 'Tabella',
          ),
          NavigationDestination(
            icon: Badge(
              label: Text('${_favoriteIds.length}'),
              isLabelVisible: _favoriteIds.isNotEmpty,
              child: const Icon(Icons.star_border),
            ),
            selectedIcon: const Icon(Icons.star, color: Color(0xFFFFAB00)),
            label: 'Kedvencek',
          ),
        ],
      ),
    );
  }
}

// --- 1. MECCSEK FÜL ---
class MatchesTab extends StatefulWidget {
  final Set<String> favoriteIds;
  final ValueChanged<String> onToggleFavorite;

  const MatchesTab({
    super.key,
    required this.favoriteIds,
    required this.onToggleFavorite,
  });

  @override
  State<MatchesTab> createState() => _MatchesTabState();
}

class _MatchesTabState extends State<MatchesTab> {
  String selectedLeague = 'Összes';
  bool onlyLive = false;
  String searchQuery = '';
  final List<String> leagues = ['Összes', 'Bajnokok Ligája', 'NB I', 'Premier League'];

  @override
  Widget build(BuildContext context) {
    final liveCount = sampleMatches.where((m) => m.isLive).length;

    final filteredMatches = sampleMatches.where((m) {
      final matchesLeague = selectedLeague == 'Összes' || m.league == selectedLeague;
      final matchesLive = !onlyLive || m.isLive;
      final q = searchQuery.trim().toLowerCase();
      final matchesSearch = q.isEmpty ||
          m.homeTeam.toLowerCase().contains(q) ||
          m.awayTeam.toLowerCase().contains(q) ||
          m.league.toLowerCase().contains(q);
      return matchesLeague && matchesLive && matchesSearch;
    }).toList();

    return SafeArea(
      child: Column(
        children: [
          // Fejléc
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1C2541), Color(0xFF3A506B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'zsoltscores ⚽',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Élő eredmények és statisztikák',
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => setState(() => onlyLive = !onlyLive),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: onlyLive
                              ? const Color(0xFF00E676)
                              : const Color(0xFF00E676).withAlpha(45),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF00E676)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.circle,
                              color: onlyLive ? Colors.black : const Color(0xFF00E676),
                              size: 9,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              onlyLive ? 'CSAK ÉLŐ ($liveCount)' : '$liveCount ÉLŐ',
                              style: TextStyle(
                                color: onlyLive ? Colors.black : const Color(0xFF00E676),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Keresőmező
                TextField(
                  onChanged: (val) => setState(() => searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Csapat vagy bajnokság keresése...',
                    hintStyle: const TextStyle(color: Colors.white54, fontSize: 14),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF00B0FF)),
                    filled: true,
                    fillColor: const Color(0xFF0B132B).withAlpha(180),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bajnokság szűrők
          SizedBox(
            height: 56,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: leagues.length,
              itemBuilder: (context, index) {
                final league = leagues[index];
                final isSelected = selectedLeague == league;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(league),
                    selected: isSelected,
                    selectedColor: const Color(0xFF00B0FF),
                    backgroundColor: const Color(0xFF1C2541),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.black : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    onSelected: (_) => setState(() => selectedLeague = league),
                  ),
                );
              },
            ),
          ),

          // Meccslista
          Expanded(
            child: filteredMatches.isEmpty
                ? const Center(
                    child: Text(
                      'Nincs a szűrésnek megfelelő meccs.',
                      style: TextStyle(color: Colors.white60),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredMatches.length,
                    itemBuilder: (context, index) {
                      final match = filteredMatches[index];
                      return MatchCard(
                        match: match,
                        isFavorite: widget.favoriteIds.contains(match.id),
                        onToggleFavorite: () => widget.onToggleFavorite(match.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// --- MECCSKÁRTYA WIDGET ---
class MatchCard extends StatelessWidget {
  final MatchData match;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  const MatchCard({
    super.key,
    required this.match,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MatchStatsScreen(match: match)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              match.homeColor.withAlpha(64),
              const Color(0xFF1C2541),
              match.awayColor.withAlpha(64),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: match.isLive ? const Color(0xFF00E676).withAlpha(128) : Colors.white12,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(match.league, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: match.isLive ? const Color(0xFFFF1744) : Colors.white12,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        match.isLive ? 'ÉLŐ ${match.status}' : match.status,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: onToggleFavorite,
                      child: Icon(
                        isFavorite ? Icons.star : Icons.star_border,
                        color: isFavorite ? const Color(0xFFFFAB00) : Colors.white54,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _teamBadge(match.homeTeam, match.homeColor),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '${match.homeScore} - ${match.awayScore}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                ),
                _teamBadge(match.awayTeam, match.awayColor),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _teamBadge(String name, Color color) {
    return SizedBox(
      width: 100,
      child: Column(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: color,
            child: Text(
              name.substring(0, 2).toUpperCase(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// --- 2. TABELLA FÜL ---
class StandingsTab extends StatefulWidget {
  const StandingsTab({super.key});

  @override
  State<StandingsTab> createState() => _StandingsTabState();
}

class _StandingsTabState extends State<StandingsTab> {
  String selectedLeague = 'NB I';
  final List<String> leagues = ['NB I', 'Premier League', 'Bajnokok Ligája'];

  Color _zoneColor(String zone) {
    switch (zone) {
      case 'ucl':
        return const Color(0xFF00E676);
      case 'uel':
        return const Color(0xFF00B0FF);
      case 'rel':
        return const Color(0xFFFF1744);
      default:
        return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = sampleStandings[selectedLeague] ?? [];

    return SafeArea(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1C2541), Color(0xFF3A506B)],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bajnoki Tabellák 🏆',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'Élő állás, pontszámok és kupazónák',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 56,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: leagues.length,
              itemBuilder: (context, index) {
                final l = leagues[index];
                final isSelected = selectedLeague == l;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(l),
                    selected: isSelected,
                    selectedColor: const Color(0xFF00E676),
                    backgroundColor: const Color(0xFF1C2541),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.black : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    onSelected: (_) => setState(() => selectedLeague = l),
                  ),
                );
              },
            ),
          ),
          // Fejléc sor
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: const [
                SizedBox(width: 28, child: Text('#', style: TextStyle(color: Colors.white54, fontSize: 12))),
                Expanded(child: Text('Csapat', style: TextStyle(color: Colors.white54, fontSize: 12))),
                SizedBox(width: 28, child: Text('M', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 12))),
                SizedBox(width: 36, child: Text('GK', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 12))),
                SizedBox(width: 34, child: Text('P', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 12))),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final r = rows[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C2541),
                    borderRadius: BorderRadius.circular(14),
                    border: Border(
                      left: BorderSide(color: _zoneColor(r.zone), width: 4),
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        child: Text('${r.pos}.', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      CircleAvatar(radius: 10, backgroundColor: r.color),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          r.team,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 28, child: Text('${r.played}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70))),
                      SizedBox(
                        width: 36,
                        child: Text(
                          r.gd > 0 ? '+${r.gd}' : '${r.gd}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                      SizedBox(
                        width: 34,
                        child: Text(
                          '${r.points}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF00E676)),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Színmagyarázat
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _legendItem(const Color(0xFF00E676), 'BL-zóna'),
                _legendItem(const Color(0xFF00B0FF), 'Európa-liga'),
                _legendItem(const Color(0xFFFF1744), 'Kieső hely'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
      ],
    );
  }
}

// --- 3. KEDVENCEK FÜL ---
class FavoritesTab extends StatelessWidget {
  final Set<String> favoriteIds;
  final ValueChanged<String> onToggleFavorite;

  const FavoritesTab({
    super.key,
    required this.favoriteIds,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final favMatches = sampleMatches.where((m) => favoriteIds.contains(m.id)).toList();

    return SafeArea(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1C2541), Color(0xFF3A506B)],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kedvenc Meccsek ⭐',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'Kiemelt találkozóid egy helyen',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
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
                        'Még nincs kedvenc meccsed.\nKoppints a csillag ikonra bármelyik meccskártyán!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white60, height: 1.5),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: favMatches.length,
                    itemBuilder: (context, index) {
                      final match = favMatches[index];
                      return MatchCard(
                        match: match,
                        isFavorite: true,
                        onToggleFavorite: () => onToggleFavorite(match.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// --- RÉSZLETES STATISZTIKA ÉS ESEMÉNYEK KÉPERNYŐ ---
class MatchStatsScreen extends StatelessWidget {
  final MatchData match;
  const MatchStatsScreen({super.key, required this.match});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(match.league),
          backgroundColor: const Color(0xFF1C2541),
        ),
        body: Column(
          children: [
            // Eredményjelző
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    match.homeColor.withAlpha(75),
                    const Color(0xFF1C2541),
                    match.awayColor.withAlpha(75),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: Text(
                      match.homeTeam,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Column(
                    children: [
                      Text(
                        '${match.homeScore} : ${match.awayScore}',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF00E676),
                        ),
                      ),
                      Text(
                        match.isLive ? 'ÉLŐ • ${match.status}' : match.status,
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Text(
                      match.awayTeam,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

            const TabBar(
              indicatorColor: Color(0xFF00E676),
              labelColor: Color(0xFF00E676),
              unselectedLabelColor: Colors.white60,
              tabs: [
                Tab(text: 'Statisztikák'),
                Tab(text: 'Események'),
              ],
            ),

            Expanded(
              child: TabBarView(
                children: [
                  // 1. fül: Statisztika csíkok
                  ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _statBar('Labdabirtoklás (%)', match.possessionHome, 100 - match.possessionHome, match.homeColor, match.awayColor),
                      _statBar('Összes lövés', match.shotsHome, match.shotsAway, match.homeColor, match.awayColor),
                      _statBar('Kapura lövések', match.shotsOnTargetHome, match.shotsOnTargetAway, match.homeColor, match.awayColor),
                      _statBar('Szögletek', match.cornersHome, match.cornersAway, match.homeColor, match.awayColor),
                      _statBar('Szabálytalanságok', match.foulsHome, match.foulsAway, match.homeColor, match.awayColor),
                    ],
                  ),
                  // 2. fül: Gólok és lapok időrendben
                  ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: match.events.length,
                    itemBuilder: (context, i) {
                      final ev = match.events[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C2541),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: ev.isHome ? MainAxisAlignment.start : MainAxisAlignment.end,
                          children: [
                            if (!ev.isHome) ...[
                              Text(ev.player, style: const TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              _eventIcon(ev.type),
                              const SizedBox(width: 8),
                              Text(ev.minute, style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold)),
                            ] else ...[
                              Text(ev.minute, style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              _eventIcon(ev.type),
                              const SizedBox(width: 8),
                              Text(ev.player, style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ],
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

  Widget _eventIcon(String type) {
    if (type == 'yellow') {
      return Container(
        width: 14,
        height: 18,
        decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(3)),
      );
    }
    if (type == 'red') {
      return Container(
        width: 14,
        height: 18,
        decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(3)),
      );
    }
    return const Icon(Icons.sports_soccer, color: Color(0xFF00E676), size: 18);
  }

  Widget _statBar(String title, int homeVal, int awayVal, Color c1, Color c2) {
    final total = (homeVal + awayVal) == 0 ? 1 : (homeVal + awayVal);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$homeVal', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(title, style: const TextStyle(color: Colors.white70)),
              Text('$awayVal', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Row(
              children: [
                Expanded(flex: (homeVal * 100 ~/ total).clamp(5, 95), child: Container(height: 10, color: c1)),
                const SizedBox(width: 4),
                Expanded(flex: (awayVal * 100 ~/ total).clamp(5, 95), child: Container(height: 10, color: c2)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
