import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiConfig.load();
  await ApiCache.loadStats();
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

// --- FŐ NAVIGÁCIÓS KERET ---
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  int _settingsVersion = 0;
  final Set<String> _favoriteIds = {'m1', 'm2'};
  List<MatchData> _matches = sampleMatches;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _isLiveApiData = false;
  bool _loadedFromCache = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _loadMatches();
  }

  Future<void> _loadMatches({bool forceRefresh = false}) async {
    if (!ApiConfig.hasValidKey) {
      setState(() {
        _matches = sampleMatches;
        _isLiveApiData = false;
        _loadedFromCache = false;
        _statusMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    try {
      final result = await HighlightlyService.fetchMatches(_selectedDate, forceRefresh: forceRefresh);
      setState(() {
        _matches = result.data;
        _isLiveApiData = true;
        _loadedFromCache = result.fromCache;
        _isLoading = false;
        _statusMessage = result.data.isEmpty ? 'Erre a napra nincs listázott meccs az API-ban.' : null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isLiveApiData = false;
        _loadedFromCache = false;
        _matches = sampleMatches;
        _statusMessage = '$e – koppints a ⚙️ ikonra a kulcs ellenőrzéséhez';
      });
    }
  }

  void _changeDate(int days) {
    setState(() => _selectedDate = _selectedDate.add(Duration(days: days)));
    _loadMatches(forceRefresh: false);
  }

  void _jumpToToday() {
    setState(() => _selectedDate = DateTime.now());
    _loadMatches(forceRefresh: false);
  }

  void _toggleFavorite(String id) {
    setState(() {
      if (_favoriteIds.contains(id)) {
        _favoriteIds.remove(id);
      } else {
        _favoriteIds.add(id);
      }
    });
  }

  void _openApiSettingsDialog() {
    final controller = TextEditingController(text: ApiConfig.apiKey);
    bool tempRapid = ApiConfig.useRapidApi;
    int tempTtl = ApiCache.cacheMinutes;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1C2541),
          title: const Row(
            children: [
              Icon(Icons.vpn_key, color: Color(0xFF00E676)),
              SizedBox(width: 8),
              Text('API és Tároló', style: TextStyle(fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Highlightly API kulcs:', style: TextStyle(fontSize: 12, color: Colors.white70)),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: 'Illeszd be az API kulcsot...',
                    filled: true,
                    fillColor: const Color(0xFF0B132B),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.content_paste, color: Color(0xFF00B0FF)),
                      onPressed: () async {
                        final data = await Clipboard.getData(Clipboard.kTextPlain);
                        if (data?.text != null && data!.text!.trim().isNotEmpty) {
                          setDialogState(() => controller.text = data.text!.trim());
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('RapidAPI kulcsot használok', style: TextStyle(fontSize: 13)),
                  subtitle: Text(
                    tempRapid ? 'football-highlights-api.p.rapidapi.com' : 'soccer.highlightly.net',
                    style: const TextStyle(fontSize: 11, color: Colors.white54),
                  ),
                  value: tempRapid,
                  onChanged: (val) => setDialogState(() => tempRapid = val),
                ),
                const Divider(color: Colors.white12, height: 18),
                const Text('Helyi tároló (API keretkímélő)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Élő lista tárolása:', style: TextStyle(fontSize: 12, color: Colors.white70)),
                    Wrap(
                      spacing: 6,
                      children: [2, 5, 15].map((min) {
                        final selected = tempTtl == min;
                        return ChoiceChip(
                          label: Text('$min p', style: const TextStyle(fontSize: 11)),
                          selected: selected,
                          selectedColor: const Color(0xFF00B0FF),
                          backgroundColor: const Color(0xFF0B132B),
                          labelStyle: TextStyle(
                            color: selected ? Colors.black : Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (_) => setDialogState(() => tempTtl = min),
                        );
                      }).toList(),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B132B),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text('${ApiCache.networkRequests}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amberAccent, fontSize: 15)),
                          const Text('API kérés', style: TextStyle(fontSize: 10, color: Colors.white60)),
                        ],
                      ),
                      Column(
                        children: [
                          Text('${ApiCache.savedRequests}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00E676), fontSize: 15)),
                          const Text('Megspórolt', style: TextStyle(fontSize: 10, color: Colors.white60)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final cleared = await ApiCache.clearAll();
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Tároló ürítve ($cleared mentett elem törölve).')),
                        );
                      }
                    },
                    icon: const Icon(Icons.delete_sweep, size: 18, color: Color(0xFF00B0FF)),
                    label: const Text('Tároló ürítése', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (ApiConfig.hasValidKey)
              TextButton(
                onPressed: () async {
                  await ApiConfig.clear();
                  if (ctx.mounted) Navigator.pop(ctx);
                  setState(() => _settingsVersion++);
                  _loadMatches(forceRefresh: true);
                },
                child: const Text('Kulcs törlése', style: TextStyle(color: Colors.redAccent)),
              ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Mégse')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF00E676)),
              onPressed: () async {
                await ApiConfig.save(controller.text, tempRapid);
                await ApiCache.setCacheMinutes(tempTtl);
                if (ctx.mounted) Navigator.pop(ctx);
                setState(() => _settingsVersion++);
                _loadMatches(forceRefresh: false);
              },
              child: const Text('Mentés', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      MatchesTab(
        matches: _matches,
        selectedDate: _selectedDate,
        isLoading: _isLoading,
        isLiveApiData: _isLiveApiData,
        loadedFromCache: _loadedFromCache,
        statusMessage: _statusMessage,
        favoriteIds: _favoriteIds,
        onToggleFavorite: _toggleFavorite,
        onChangeDate: _changeDate,
        onJumpToday: _jumpToToday,
        onRefresh: () => _loadMatches(forceRefresh: true),
        onOpenSettings: _openApiSettingsDialog,
      ),
      StandingsTab(key: ValueKey(_settingsVersion), onOpenSettings: _openApiSettingsDialog),
      FavoritesTab(allMatches: _matches, favoriteIds: _favoriteIds, onToggleFavorite: _toggleFavorite),
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
  final List<MatchData> matches;
  final DateTime selectedDate;
  final bool isLoading;
  final bool isLiveApiData;
  final bool loadedFromCache;
  final String? statusMessage;
  final Set<String> favoriteIds;
  final ValueChanged<String> onToggleFavorite;
  final ValueChanged<int> onChangeDate;
  final VoidCallback onJumpToday;
  final Future<void> Function() onRefresh;
  final VoidCallback onOpenSettings;

  const MatchesTab({
    super.key,
    required this.matches,
    required this.selectedDate,
    required this.isLoading,
    required this.isLiveApiData,
    required this.loadedFromCache,
    required this.statusMessage,
    required this.favoriteIds,
    required this.onToggleFavorite,
    required this.onChangeDate,
    required this.onJumpToday,
    required this.onRefresh,
    required this.onOpenSettings,
  });

  @override
  State<MatchesTab> createState() => _MatchesTabState();
}

class _MatchesTabState extends State<MatchesTab> {
  String selectedLeague = 'Összes';
  bool onlyLive = false;
  String searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final dynamicLeagues = <String>{'Összes', ...widget.matches.map((m) => m.league)}.toList();
    if (!dynamicLeagues.contains(selectedLeague)) selectedLeague = 'Összes';

    final liveCount = widget.matches.where((m) => m.isLive).length;
    final filteredMatches = widget.matches.where((m) {
      final matchesLeague = selectedLeague == 'Összes' || m.league == selectedLeague;
      final matchesLive = !onlyLive || m.isLive;
      final q = searchQuery.trim().toLowerCase();
      final matchesSearch = q.isEmpty ||
          m.homeTeam.toLowerCase().contains(q) ||
          m.awayTeam.toLowerCase().contains(q) ||
          m.league.toLowerCase().contains(q);
      return matchesLeague && matchesLive && matchesSearch;
    }).toList();

    final countText = '${widget.matches.length} meccs';
    final sourceSubtitle = !widget.isLiveApiData
        ? 'Demo mód'
        : (widget.loadedFromCache ? 'Tárolóból betöltve • $countText' : 'Highlightly Élő API • $countText');
    final sourceColor = !widget.isLiveApiData
        ? Colors.amberAccent
        : (widget.loadedFromCache ? const Color(0xFF00B0FF) : const Color(0xFF00E676));

    return SafeArea(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 14, 10, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF1C2541), Color(0xFF3A506B)]),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('zsoltscores ⚽', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                          const SizedBox(height: 2),
                          Text(sourceSubtitle, style: TextStyle(fontSize: 11, color: sourceColor, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => onlyLive = !onlyLive),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: onlyLive ? const Color(0xFF00E676) : const Color(0xFF00E676).withAlpha(45),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF00E676)),
                        ),
                        child: Text(
                          onlyLive ? 'CSAK ÉLŐ ($liveCount)' : '$liveCount ÉLŐ',
                          style: TextStyle(
                            color: onlyLive ? Colors.black : const Color(0xFF00E676),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                    if (ApiConfig.hasValidKey)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: widget.onRefresh,
                        icon: const Icon(Icons.refresh, color: Colors.white70),
                      ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: widget.onOpenSettings,
                      icon: Icon(Icons.settings, color: ApiConfig.hasValidKey ? const Color(0xFF00E676) : Colors.amberAccent),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B132B).withAlpha(180),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.chevron_left, size: 20),
                            onPressed: () => widget.onChangeDate(-1),
                          ),
                          GestureDetector(
                            onTap: widget.onJumpToday,
                            child: Text(
                              HighlightlyService.formatDate(widget.selectedDate),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.chevron_right, size: 20),
                            onPressed: () => widget.onChangeDate(1),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        onChanged: (val) => setState(() => searchQuery = val),
                        decoration: InputDecoration(
                          hintText: 'Csapat vagy liga keresése...',
                          hintStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                          prefixIcon: const Icon(Icons.search, color: Color(0xFF00B0FF), size: 20),
                          filled: true,
                          fillColor: const Color(0xFF0B132B).withAlpha(180),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (widget.isLoading)
            const LinearProgressIndicator(color: Color(0xFF00E676), backgroundColor: Colors.transparent),
          if (!ApiConfig.hasValidKey)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 2),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1C2541),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF00E676).withAlpha(140)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.vpn_key, color: Color(0xFF00E676), size: 22),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('Add meg a Highlightly API kulcsodat az élő meccsekhez!', style: TextStyle(fontSize: 12))),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF00E676), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    onPressed: widget.onOpenSettings,
                    child: const Text('Kulcs beírása', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            ),
          if (widget.statusMessage != null)
            GestureDetector(
              onTap: widget.onOpenSettings,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha(35),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withAlpha(120)),
                ),
                child: Text(widget.statusMessage!, style: const TextStyle(fontSize: 12, color: Colors.amberAccent), textAlign: TextAlign.center),
              ),
            ),
          SizedBox(
            height: 54,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: dynamicLeagues.length,
              itemBuilder: (context, index) {
                final league = dynamicLeagues[index];
                final isSelected = selectedLeague == league;
                final label = league == 'Összes' ? 'Összes (${widget.matches.length})' : league;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: isSelected,
                    selectedColor: const Color(0xFF00B0FF),
                    backgroundColor: const Color(0xFF1C2541),
                    labelStyle: TextStyle(color: isSelected ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    onSelected: (_) => setState(() => selectedLeague = league),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: const Color(0xFF00E676),
              onRefresh: widget.onRefresh,
              child: filteredMatches.isEmpty
                  ? ListView(children: const [SizedBox(height: 100), Center(child: Text('Nincs a szűrésnek megfelelő meccs.', style: TextStyle(color: Colors.white60)))])
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
          ),
        ],
      ),
    );
  }
}

// --- MECCSKÁRTYA ---
class MatchCard extends StatelessWidget {
  final MatchData match;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  const MatchCard({super.key, required this.match, required this.isFavorite, required this.onToggleFavorite});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MatchStatsScreen(match: match))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [match.homeColor.withAlpha(64), const Color(0xFF1C2541), match.awayColor.withAlpha(64)]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: match.isLive ? const Color(0xFF00E676).withAlpha(128) : Colors.white12),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(match.league, style: const TextStyle(color: Colors.white70, fontSize: 12), overflow: TextOverflow.ellipsis)),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: match.isLive ? const Color(0xFFFF1744) : Colors.white12, borderRadius: BorderRadius.circular(8)),
                      child: Text(match.isLive ? 'ÉLŐ ${match.status}' : match.status, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: onToggleFavorite,
                      child: Icon(isFavorite ? Icons.star : Icons.star_border, color: isFavorite ? const Color(0xFFFFAB00) : Colors.white54, size: 22),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _teamBadge(match.homeTeam, match.homeColor, match.homeLogo),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(14)),
                  child: Text('${match.homeScore} - ${match.awayScore}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                ),
                _teamBadge(match.awayTeam, match.awayColor, match.awayLogo),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _teamBadge(String name, Color color, String? logoUrl) {
    final initials = name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase();
    return SizedBox(
      width: 100,
      child: Column(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: color,
            child: logoUrl != null && logoUrl.isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      logoUrl,
                      width: 34,
                      height: 34,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  )
                : Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 6),
          Text(name, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}

// --- 2. TABELLA FÜL ---
class StandingsTab extends StatefulWidget {
  final VoidCallback onOpenSettings;
  const StandingsTab({super.key, required this.onOpenSettings});

  @override
  State<StandingsTab> createState() => _StandingsTabState();
}

class _StandingsTabState extends State<StandingsTab> {
  String selectedLeague = 'Premier League';
  bool _loading = false;
  bool _fromCache = false;
  List<StandingRow> _rows = sampleStandings['Premier League']!;

  static const leagueIds = {
    'Premier League': 33973,
    'Bajnokok Ligája': 2486,
    'La Liga': 119924,
    'Bundesliga': 67162,
    'Serie A': 115669,
  };

  @override
  void initState() {
    super.initState();
    _loadStandings();
  }

  Future<void> _loadStandings({bool forceRefresh = false}) async {
    final id = leagueIds[selectedLeague];
    if (!ApiConfig.hasValidKey || id == null) {
      setState(() {
        _rows = sampleStandings[selectedLeague] ?? sampleStandings['Premier League']!;
        _fromCache = false;
      });
      return;
    }

    setState(() => _loading = true);
    try {
      final result = await HighlightlyService.fetchStandings(id, forceRefresh: forceRefresh);
      setState(() {
        _rows = result.data.isNotEmpty ? result.data : (sampleStandings[selectedLeague] ?? sampleStandings['Premier League']!);
        _fromCache = result.fromCache;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _rows = sampleStandings[selectedLeague] ?? sampleStandings['Premier League']!;
        _fromCache = false;
        _loading = false;
      });
    }
  }

  Color _zoneColor(String zone) {
    if (zone == 'ucl') return const Color(0xFF00E676);
    if (zone == 'uel') return const Color(0xFF00B0FF);
    if (zone == 'rel') return const Color(0xFFFF1744);
    return Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    final leagues = leagueIds.keys.toList();

    return SafeArea(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF1C2541), Color(0xFF3A506B)]),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Bajnoki Tabellák 🏆', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      _fromCache ? 'Tárolóból betöltve (2 órás védelem)' : 'Highlightly élő állások és pontszámok',
                      style: TextStyle(fontSize: 12, color: _fromCache ? const Color(0xFF00B0FF) : Colors.white70),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (ApiConfig.hasValidKey)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _loadStandings(forceRefresh: true),
                        icon: const Icon(Icons.refresh, color: Colors.white70),
                      ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: widget.onOpenSettings,
                      icon: const Icon(Icons.settings, color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(color: Color(0xFF00E676), backgroundColor: Colors.transparent),
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
                    labelStyle: TextStyle(color: isSelected ? Colors.black : Colors.white, fontWeight: FontWeight.bold),
                    onSelected: (_) {
                      setState(() => selectedLeague = l);
                      _loadStandings(forceRefresh: false);
                    },
                  ),
                );
              },
            ),
          ),
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
              itemCount: _rows.length,
              itemBuilder: (context, index) {
                final r = _rows[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C2541),
                    borderRadius: BorderRadius.circular(14),
                    border: Border(left: BorderSide(color: _zoneColor(r.zone), width: 4)),
                  ),
                  child: Row(
                    children: [
                      SizedBox(width: 24, child: Text('${r.pos}.', style: const TextStyle(fontWeight: FontWeight.bold))),
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: r.color,
                        child: r.logo != null && r.logo!.isNotEmpty
                            ? ClipOval(child: Image.network(r.logo!, width: 18, height: 18, errorBuilder: (_, __, ___) => const SizedBox()))
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(r.team, style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                      SizedBox(width: 28, child: Text('${r.played}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70))),
                      SizedBox(width: 36, child: Text(r.gd > 0 ? '+${r.gd}' : '${r.gd}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70))),
                      SizedBox(width: 34, child: Text('${r.points}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF00E676)))),
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

// --- 3. KEDVENCEK FÜL ---
class FavoritesTab extends StatelessWidget {
  final List<MatchData> allMatches;
  final Set<String> favoriteIds;
  final ValueChanged<String> onToggleFavorite;

  const FavoritesTab({super.key, required this.allMatches, required this.favoriteIds, required this.onToggleFavorite});

  @override
  Widget build(BuildContext context) {
    final favMatches = allMatches.where((m) => favoriteIds.contains(m.id)).toList();

    return SafeArea(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF1C2541), Color(0xFF3A506B)]),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kedvenc Meccsek ⭐', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('Kiemelt találkozóid egy helyen', style: TextStyle(fontSize: 12, color: Colors.white70)),
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
                        'Még nincs kedvenc meccsed erre a napra.\nKoppints a csillag ikonra bármelyik meccskártyán!',
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
                      return MatchCard(match: match, isFavorite: true, onToggleFavorite: () => onToggleFavorite(match.id));
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// --- RÉSZLETES STATISZTIKA ÉS HIGHLIGHTS KÉPERNYŐ ---
class MatchStatsScreen extends StatefulWidget {
  final MatchData match;
  const MatchStatsScreen({super.key, required this.match});

  @override
  State<MatchStatsScreen> createState() => _MatchStatsScreenState();
}

class _MatchStatsScreenState extends State<MatchStatsScreen> {
  late MatchData _match;
  bool _loadingDetails = false;
  bool _fromCache = false;
  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();
    _match = widget.match;
    _fetchDetails();
    if (_match.isLive && _match.isFromApi) {
      _autoTimer = Timer.periodic(const Duration(seconds: 30), (_) {
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
    if (!ApiConfig.hasValidKey || !_match.isFromApi) return;
    setState(() => _loadingDetails = true);
    final result = await HighlightlyService.enrichMatchDetails(_match, forceRefresh: forceRefresh);
    if (mounted) {
      setState(() {
        _match = result.data;
        _fromCache = result.fromCache;
        _loadingDetails = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_match.league, style: const TextStyle(fontSize: 16)),
              if (_fromCache)
                const Text('Tárolóból betöltve (45 mp védelem)', style: TextStyle(fontSize: 11, color: Color(0xFF00B0FF)))
              else if (_match.isLive && _match.isFromApi)
                const Text('Élő követés • 30 mp-enként frissül', style: TextStyle(fontSize: 11, color: Color(0xFF00E676))),
            ],
          ),
          backgroundColor: const Color(0xFF1C2541),
          actions: [
            if (ApiConfig.hasValidKey && _match.isFromApi)
              IconButton(onPressed: () => _fetchDetails(forceRefresh: true), icon: const Icon(Icons.refresh)),
          ],
        ),
        body: Column(
          children: [
            if (_loadingDetails) const LinearProgressIndicator(color: Color(0xFF00E676), backgroundColor: Colors.transparent),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [_match.homeColor.withAlpha(75), const Color(0xFF1C2541), _match.awayColor.withAlpha(75)]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(child: Text(_match.homeTeam, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
                  Column(
                    children: [
                      Text('${_match.homeScore} : ${_match.awayScore}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF00E676))),
                      Text(_match.isLive ? 'ÉLŐ • ${_match.status}' : _match.status, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                    ],
                  ),
                  Expanded(child: Text(_match.awayTeam, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
                ],
              ),
            ),
            if (_match.detailNote != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00B0FF).withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF00B0FF).withAlpha(100)),
                ),
                child: Text(
                  _match.detailNote!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ),
            const TabBar(
              indicatorColor: Color(0xFF00E676),
              labelColor: Color(0xFF00E676),
              unselectedLabelColor: Colors.white60,
              tabs: [Tab(text: 'Statisztikák'), Tab(text: 'Események'), Tab(text: 'Highlights 🎬')],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _statBar('Labdabirtoklás (%)', _match.possessionHome, 100 - _match.possessionHome, _match.homeColor, _match.awayColor),
                      _statBar('Összes lövés', _match.shotsHome, _match.shotsAway, _match.homeColor, _match.awayColor),
                      _statBar('Kapura lövések', _match.shotsOnTargetHome, _match.shotsOnTargetAway, _match.homeColor, _match.awayColor),
                      _statBar('Szögletek', _match.cornersHome, _match.cornersAway, _match.homeColor, _match.awayColor),
                      _statBar('Szabálytalanságok', _match.foulsHome, _match.foulsAway, _match.homeColor, _match.awayColor),
                    ],
                  ),
                  _match.events.isEmpty
                      ? const Center(child: Text('Még nincs rögzített esemény ehhez a meccshez.', style: TextStyle(color: Colors.white60)))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _match.events.length,
                          itemBuilder: (context, i) {
                            final ev = _match.events[i];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(color: const Color(0xFF1C2541), borderRadius: BorderRadius.circular(14)),
                              child: Row(
                                mainAxisAlignment: ev.isHome ? MainAxisAlignment.start : MainAxisAlignment.end,
                                children: ev.isHome
                                    ? [
                                        Text(ev.minute, style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold)),
                                        const SizedBox(width: 8),
                                        _eventIcon(ev.type),
                                        const SizedBox(width: 8),
                                        Text(ev.player, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      ]
                                    : [
                                        Text(ev.player, style: const TextStyle(fontWeight: FontWeight.bold)),
                                        const SizedBox(width: 8),
                                        _eventIcon(ev.type),
                                        const SizedBox(width: 8),
                                        Text(ev.minute, style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold)),
                                      ],
                              ),
                            );
                          },
                        ),
                  _match.highlights.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('Ehhez a meccshez még nem érhető el videós összefoglaló.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60)),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _match.highlights.length,
                          itemBuilder: (context, i) {
                            final clip = _match.highlights[i];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(color: const Color(0xFF1C2541), borderRadius: BorderRadius.circular(16)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (clip.thumbnail != null && clip.thumbnail!.isNotEmpty)
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                      child: Image.network(clip.thumbnail!, height: 170, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox()),
                                    ),
                                  Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(clip.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                        const SizedBox(height: 10),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676), foregroundColor: Colors.black),
                                          onPressed: () {
                                            Clipboard.setData(ClipboardData(text: clip.url));
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Videó link másolva a vágólapra!')));
                                          },
                                          icon: const Icon(Icons.copy, size: 18),
                                          label: const Text('Videó link másolása'),
                                        ),
                                      ],
                                    ),
                                  ),
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
      return Container(width: 14, height: 18, decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(3)));
    }
    if (type == 'red') {
      return Container(width: 14, height: 18, decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(3)));
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
