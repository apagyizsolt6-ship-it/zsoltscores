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
      home: const HomeScreen(),
    );
  }
}

// --- ADATMODELL (Később ide kötöd be az élő API-t) ---
class MatchData {
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
  final int shotsOnTargetHome;
  final int shotsOnTargetAway;
  final int cornersHome;
  final int cornersAway;
  final List<String> events;

  MatchData({
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
    required this.shotsOnTargetHome,
    required this.shotsOnTargetAway,
    required this.cornersHome,
    required this.cornersAway,
    required this.events,
  });
}

// --- MINTA MECCSEK ---
final List<MatchData> sampleMatches = [
  MatchData(
    league: 'Bajnokok Ligája',
    homeTeam: 'Real Madrid',
    awayTeam: 'Liverpool',
    homeColor: const Color(0xFF7C4DFF),
    awayColor: const Color(0xFFFF1744),
    homeScore: 2,
    awayScore: 2,
    status: "74'",
    isLive: true,
    possessionHome: 48,
    shotsOnTargetHome: 6,
    shotsOnTargetAway: 7,
    cornersHome: 5,
    cornersAway: 8,
    events: ["14' Szoboszlai (0-1)", "39' Vinícius Jr. (1-1)", "52' Salah (1-2)", "69' Bellingham (2-2)"],
  ),
  MatchData(
    league: 'NB I',
    homeTeam: 'Ferencváros',
    awayTeam: 'Puskás Akadémia',
    homeColor: const Color(0xFF00E676),
    awayColor: const Color(0xFFFFAB00),
    homeScore: 3,
    awayScore: 1,
    status: "82'",
    isLive: true,
    possessionHome: 61,
    shotsOnTargetHome: 9,
    shotsOnTargetAway: 3,
    cornersHome: 7,
    cornersAway: 2,
    events: ["19' Varga B. (1-0)", "44' Nagy Zs. (1-1)", "58' Abu Fani (2-1)", "77' Traoré (3-1)"],
  ),
  MatchData(
    league: 'Premier League',
    homeTeam: 'Arsenal',
    awayTeam: 'Man. City',
    homeColor: const Color(0xFFFF5252),
    awayColor: const Color(0xFF00B0FF),
    homeScore: 1,
    awayScore: 0,
    status: 'VÉGE',
    isLive: false,
    possessionHome: 44,
    shotsOnTargetHome: 4,
    shotsOnTargetAway: 5,
    cornersHome: 4,
    cornersAway: 6,
    events: ["86' Saka (1-0)"],
  ),
];

// --- FŐKÉPERNYŐ ---
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String selectedLeague = 'Összes';
  final List<String> leagues = ['Összes', 'Bajnokok Ligája', 'NB I', 'Premier League'];

  @override
  Widget build(BuildContext context) {
    final filteredMatches = selectedLeague == 'Összes'
        ? sampleMatches
        : sampleMatches.where((m) => m.league == selectedLeague).toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Színes fejléc
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1C2541), Color(0xFF3A506B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'zsoltscores ⚽',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Élő eredmények és statisztikák',
                        style: TextStyle(fontSize: 13, color: Colors.white70),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E676).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF00E676)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.circle, color: Color(0xFF00E676), size: 10),
                        SizedBox(width: 6),
                        Text('2 ÉLŐ', style: TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Bajnokság szűrő gombok
            SizedBox(
              height: 60,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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

            // Meccsek listája
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filteredMatches.length,
                itemBuilder: (context, index) {
                  final match = filteredMatches[index];
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
                            match.homeColor.withOpacity(0.25),
                            const Color(0xFF1C2541),
                            match.awayColor.withOpacity(0.25),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: match.isLive ? const Color(0xFF00E676).withOpacity(0.5) : Colors.white12,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(match.league, style: const TextStyle(color: Colors.white70, fontSize: 12)),
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
                            ],
                          ),
                          const SizedBox(height: 14),
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
                },
              ),
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

// --- STATISZTIKA KÉPERNYŐ ---
class MatchStatsScreen extends StatelessWidget {
  final MatchData match;
  const MatchStatsScreen({super.key, required this.match});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(match.league),
        backgroundColor: const Color(0xFF1C2541),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1C2541),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Text(match.homeTeam, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(
                    '${match.homeScore} : ${match.awayScore}',
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF00E676)),
                  ),
                  Text(match.awayTeam, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('MECCS STATISZTIKÁK', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 16),
            _statBar('Labdabirtoklás (%)', match.possessionHome, 100 - match.possessionHome, match.homeColor, match.awayColor),
            _statBar('Kapura lövések', match.shotsOnTargetHome, match.shotsOnTargetAway, match.homeColor, match.awayColor),
            _statBar('Szögletek', match.cornersHome, match.cornersAway, match.homeColor, match.awayColor),
            const SizedBox(height: 24),
            const Text('GÓLSZERZŐK', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: match.events.length,
                itemBuilder: (context, i) => Card(
                  color: const Color(0xFF1C2541),
                  child: ListTile(
                    leading: const Icon(Icons.sports_soccer, color: Color(0xFF00E676)),
                    title: Text(match.events[i]),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statBar(String title, int homeVal, int awayVal, Color c1, Color c2) {
    final total = (homeVal + awayVal) == 0 ? 1 : (homeVal + awayVal);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
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
