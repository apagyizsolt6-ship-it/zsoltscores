import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiConfig.load();
  await ApiCache.loadStats();
  await LogoCache.init();
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

// --- MAGYAR ABC-SORRENDEZŐ SEGÉDFÜGGVÉNY ---
int compareHungarianStrings(String a, String b) {
  const order = {
    'a': 1,
    'á': 2,
    'b': 3,
    'c': 4,
    'cs': 5,
    'd': 6,
    'dz': 7,
    'dzs': 8,
    'e': 9,
    'é': 10,
    'f': 11,
    'g': 12,
    'gy': 13,
    'h': 14,
    'i': 15,
    'í': 16,
    'j': 17,
    'k': 18,
    'l': 19,
    'ly': 20,
    'm': 21,
    'n': 22,
    'ny': 23,
    'o': 24,
    'ó': 25,
    'ö': 26,
    'ő': 27,
    'p': 28,
    'q': 29,
    'r': 30,
    's': 31,
    'sz': 32,
    't': 33,
    'ty': 34,
    'u': 35,
    'ú': 36,
    'ü': 37,
    'ű': 38,
    'v': 39,
    'w': 40,
    'x': 41,
    'y': 42,
    'z': 43,
    'zs': 44,
  };

  List<int> tokenize(String s) {
    final lower = s.toLowerCase().trim();
    final tokens = <int>[];
    int i = 0;
    while (i < lower.length) {
      if (i + 2 < lower.length) {
        final tri = lower.substring(i, i + 3);
        if (order.containsKey(tri)) {
          tokens.add(order[tri]! * 10);
          i += 3;
          continue;
        }
      }
      if (i + 1 < lower.length) {
        final di = lower.substring(i, i + 2);
        if (order.containsKey(di)) {
          tokens.add(order[di]! * 10);
          i += 2;
          continue;
        }
      }
      final ch = lower[i];
      if (order.containsKey(ch)) {
        tokens.add(order[ch]! * 10);
      } else {
        tokens.add(1000 + ch.codeUnitAt(0));
      }
      i++;
    }
    return tokens;
  }

  final ta = tokenize(a);
  final tb = tokenize(b);
  final len = ta.length < tb.length ? ta.length : tb.length;
  for (int i = 0; i < len; i++) {
    if (ta[i] != tb[i]) return ta[i].compareTo(tb[i]);
  }
  return ta.length.compareTo(tb.length);
}

// --- HELYI GYORSÍTÓTÁRAZOTT CSAPATLOGÓ WIDGET ---
class CachedTeamLogo extends StatefulWidget {
  final String teamName;
  final Color fallbackColor;
  final String? logoUrl;
  final double radius;
  final bool showInitialsOnFallback;

  const CachedTeamLogo({
    super.key,
    required this.teamName,
    required this.fallbackColor,
    required this.logoUrl,
    this.radius = 22,
    this.showInitialsOnFallback = true,
  });

  @override
  State<CachedTeamLogo> createState() => _CachedTeamLogoState();
}

class _CachedTeamLogoState extends State<CachedTeamLogo> {
  File? _localFile;

  @override
  void initState() {
    super.initState();
    _resolveLogo();
  }

  @override
  void didUpdateWidget(covariant CachedTeamLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.logoUrl != widget.logoUrl) {
      _localFile = null;
      _resolveLogo();
    }
  }

  Future<void> _resolveLogo() async {
    if (widget.logoUrl == null || widget.logoUrl!.trim().isEmpty) return;
    final file = await LogoCache.getOrDownload(widget.logoUrl);
    if (mounted && file != null) {
      setState(() => _localFile = file);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.teamName.trim();
    final initials = name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase();
    final imgSize = widget.radius * 1.55;

    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: widget.fallbackColor,
      child: _localFile != null
          ? ClipOval(
              child: Image.file(
                _localFile!,
                width: imgSize,
                height: imgSize,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => widget.showInitialsOnFallback
                    ? Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10))
                    : const SizedBox(),
              ),
            )
          : (widget.showInitialsOnFallback
              ? Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10))
              : const SizedBox()),
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
      final result = await SportsApiService.fetchMatches(_selectedDate, forceRefresh: forceRefresh);
      setState(() {
        _matches = result.data;
        _isLiveApiData = true;
        _loadedFromCache = result.fromCache;
        _isLoading = false;
        _statusMessage = result.data.isEmpty
            ? 'Erre a napra nincs elérhető meccs (${ApiConfig.providerName}).'
            : null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isLiveApiData = false;
        _loadedFromCache = false;
        _matches = sampleMatches;
        _statusMessage = '$e – koppints a ⚙️ ikonra a beállításokhoz';
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

  void _openApiSettingsDialog() async {
    await LogoCache.refreshCount();
    if (!mounted) return;

    ApiProvider tempProvider = ApiConfig.provider;
    final hlController = TextEditingController(text: ApiConfig.highlightlyKey);
    final spController = TextEditingController(text: ApiConfig.statpalKey);
    bool tempRapid = ApiConfig.useRapidApi;
    int tempTtl = ApiCache.cacheMinutes;
    String? usageInfo;
    bool checkingUsage = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isSp = tempProvider == ApiProvider.statpal;
          final activeCtrl = isSp ? spController : hlController;

          return AlertDialog(
            backgroundColor: const Color(0xFF1C2541),
            title: const Row(
              children: [
                Icon(Icons.vpn_key, color: Color(0xFF00E676)),
                SizedBox(width: 8),
                Text('API és Gyorsítótár', style: TextStyle(fontSize: 18)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Aktív adatforrás:', style: TextStyle(fontSize: 12, color: Colors.white70)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Highlightly', style: TextStyle(fontSize: 12))),
                          selected: !isSp,
                          selectedColor: const Color(0xFF00E676),
                          backgroundColor: const Color(0xFF0B132B),
                          labelStyle: TextStyle(
                            color: !isSp ? Colors.black : Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (_) => setDialogState(() => tempProvider = ApiProvider.highlightly),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('StatPal V2', style: TextStyle(fontSize: 12))),
                          selected: isSp,
                          selectedColor: const Color(0xFF00B0FF),
                          backgroundColor: const Color(0xFF0B132B),
                          labelStyle: TextStyle(
                            color: isSp ? Colors.black : Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (_) => setDialogState(() => tempProvider = ApiProvider.statpal),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isSp ? 'StatPal.io hozzáférési kulcs (UUID):' : 'Highlightly API kulcs:',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: activeCtrl,
                    decoration: InputDecoration(
                      hintText: isSp ? 'Illeszd be a StatPal kulcsot...' : 'Illeszd be a Highlightly kulcsot...',
                      filled: true,
                      fillColor: const Color(0xFF0B132B),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.content_paste, color: Color(0xFF00B0FF)),
                        onPressed: () async {
                          final data = await Clipboard.getData(Clipboard.kTextPlain);
                          if (data?.text != null && data!.text!.trim().isNotEmpty) {
                            setDialogState(() => activeCtrl.text = data.text!.trim());
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (!isSp)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('RapidAPI végpont használata', style: TextStyle(fontSize: 13)),
                      subtitle: Text(
                        tempRapid ? 'football-highlights-api.p.rapidapi.com' : 'soccer.highlightly.net',
                        style: const TextStyle(fontSize: 11, color: Colors.white54),
                      ),
                      value: tempRapid,
                      onChanged: (val) => setDialogState(() => tempRapid = val),
                    )
                  else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00B0FF).withAlpha(25),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF00B0FF).withAlpha(90)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'statpal.io/api/v2/soccer • 15 mp-es élő frissítés',
                            style: TextStyle(fontSize: 11, color: Colors.white70),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: checkingUsage
                                  ? null
                                  : () async {
                                      setDialogState(() => checkingUsage = true);
                                      final info = await SportsApiService.fetchStatPalDailyUsage(spController.text);
                                      setDialogState(() {
                                        usageInfo = info;
                                        checkingUsage = false;
                                      });
                                    },
                              icon: const Icon(Icons.analytics_outlined, size: 16, color: Color(0xFF00E676)),
                              label: Text(
                                checkingUsage ? 'Lekérdezés...' : 'Mai StatPal keret ellenőrzése (ingyenes)',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ),
                          if (usageInfo != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              usageInfo!,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF00E676), fontWeight: FontWeight.bold),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const Divider(color: Colors.white12, height: 18),
                  const Text('Helyi tároló (API- és logókímélő)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Meccslista megőrzése:', style: TextStyle(fontSize: 12, color: Colors.white70)),
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
                        Column(
                          children: [
                            Text('${LogoCache.savedLogosCount}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00B0FF), fontSize: 15)),
                            const Text('Mentett logó', style: TextStyle(fontSize: 10, color: Colors.white60)),
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
                        final clearedJson = await ApiCache.clearAll();
                        final clearedLogos = await LogoCache.clearAll();
                        setDialogState(() {});
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Gyorsítótár törölve ($clearedJson adat, $clearedLogos logó).')),
                          );
                        }
                      },
                      icon: const Icon(Icons.delete_sweep, size: 18, color: Color(0xFF00B0FF)),
                      label: const Text('Adat- és logótároló törlése', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              if (activeCtrl.text.trim().isNotEmpty)
                TextButton(
                  onPressed: () async {
                    setDialogState(() => activeCtrl.clear());
                    await ApiConfig.save(
                      newProvider: tempProvider,
                      newHighlightlyKey: hlController.text,
                      rapid: tempRapid,
                      newStatpalKey: spController.text,
                    );
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
                  await ApiConfig.save(
                    newProvider: tempProvider,
                    newHighlightlyKey: hlController.text,
                    rapid: tempRapid,
                    newStatpalKey: spController.text,
                  );
                  await ApiCache.setCacheMinutes(tempTtl);
                  if (ctx.mounted) Navigator.pop(ctx);
                  setState(() => _settingsVersion++);
                  _loadMatches(forceRefresh: false);
                },
                child: const Text('Mentés', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
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

// --- 1. MECCSEK FÜL (ORSZÁG ALAPÚ ABC-SORREND + ÖSSZES NYITÁSA/CSUKÁSA) ---
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
  String selectedCompetition = 'Összes';
  bool onlyLive = false;
  String searchQuery = '';
  final Set<String> _collapsedCompetitions = {};

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

  void _toggleAllCompetitions(List<String> visibleCompetitions) {
    if (visibleCompetitions.isEmpty) return;
    final allCollapsed = visibleCompetitions.every((c) => _collapsedCompetitions.contains(c));
    setState(() {
      if (allCollapsed) {
        _collapsedCompetitions.removeAll(visibleCompetitions);
      } else {
        _collapsedCompetitions.addAll(visibleCompetitions);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final groupedByCompetition = <String, List<MatchData>>{};
    final liveCount = widget.matches.where((m) => m.isLive).length;

    final filteredMatches = widget.matches.where((m) {
      final matchesComp = selectedCompetition == 'Összes' || m.fullCompetitionLabel == selectedCompetition;
      final matchesLive = !onlyLive || m.isLive;
      final q = searchQuery.trim().toLowerCase();
      final matchesSearch = q.isEmpty ||
          m.homeTeam.toLowerCase().contains(q) ||
          m.awayTeam.toLowerCase().contains(q) ||
          m.league.toLowerCase().contains(q) ||
          m.country.toLowerCase().contains(q);
      return matchesComp && matchesLive && matchesSearch;
    }).toList();

    for (final m in filteredMatches) {
      groupedByCompetition.putIfAbsent(m.fullCompetitionLabel, () => []).add(m);
    }

    // ABC-sorrend ORSZÁG NÉV alapján (majd bajnokság név alapján)
    final competitionKeys = groupedByCompetition.keys.toList()
      ..sort((a, b) {
        final ma = groupedByCompetition[a]!.first;
        final mb = groupedByCompetition[b]!.first;
        final countryCmp = compareHungarianStrings(ma.country, mb.country);
        if (countryCmp != 0) return countryCmp;
        return compareHungarianStrings(ma.league, mb.league);
      });

    // A felső szűrőcsíkot is ország név szerinti ABC-sorrendben rendezzük
    final allCompSet = <String>{};
    final compSampleMap = <String, MatchData>{};
    for (final m in widget.matches) {
      allCompSet.add(m.fullCompetitionLabel);
      compSampleMap.putIfAbsent(m.fullCompetitionLabel, () => m);
    }
    final sortedChipComps = allCompSet.toList()
      ..sort((a, b) {
        final ma = compSampleMap[a]!;
        final mb = compSampleMap[b]!;
        final countryCmp = compareHungarianStrings(ma.country, mb.country);
        if (countryCmp != 0) return countryCmp;
        return compareHungarianStrings(ma.league, mb.league);
      });

    final dynamicCompetitions = ['Összes', ...sortedChipComps];
    if (!dynamicCompetitions.contains(selectedCompetition)) selectedCompetition = 'Összes';

    final areAllCollapsed =
        competitionKeys.isNotEmpty && competitionKeys.every((c) => _collapsedCompetitions.contains(c));

    final countText = '${widget.matches.length} meccs';
    final provName = ApiConfig.providerName;
    final sourceSubtitle = !widget.isLiveApiData
        ? 'Minta mód ($provName)'
        : (widget.loadedFromCache
            ? 'Gyorsítótárból ($provName) • $countText'
            : '$provName Élő • $countText');
    final sourceColor = !widget.isLiveApiData
        ? Colors.amberAccent
        : (widget.loadedFromCache ? const Color(0xFF00B0FF) : const Color(0xFF00E676));

    return SafeArea(
      child: Column(
        children: [
          // Színes felső fejléc
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1C2541), Color(0xFF2B3E63), Color(0xFF0F4C5C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
              boxShadow: [
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
                        gradient: const LinearGradient(colors: [Color(0xFF00E676), Color(0xFF00B0FF)]),
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
                            style: TextStyle(fontSize: 11, color: sourceColor, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Összes bajnokság egy gombos nyitása / csukása
                    Tooltip(
                      message: areAllCollapsed ? 'Összes bajnokság kinyitása' : 'Összes bajnokság összecsukása',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _toggleAllCompetitions(competitionKeys),
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0B132B).withAlpha(180),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF00B0FF).withAlpha(110)),
                          ),
                          child: Icon(
                            areAllCollapsed ? Icons.unfold_more : Icons.unfold_less,
                            color: const Color(0xFF00B0FF),
                            size: 19,
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => onlyLive = !onlyLive),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: onlyLive
                              ? const LinearGradient(colors: [Color(0xFFFF1744), Color(0xFFFF6D00)])
                              : null,
                          color: onlyLive ? null : const Color(0xFFFF1744).withAlpha(38),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: onlyLive ? const Color(0xFFFF5252) : const Color(0xFFFF1744).withAlpha(170),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: onlyLive ? Colors.white : const Color(0xFFFF1744),
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
                        color: ApiConfig.hasValidKey ? const Color(0xFF00E676) : Colors.amberAccent,
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
                        color: const Color(0xFF0B132B).withAlpha(200),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: const Color(0xFF00B0FF).withAlpha(70)),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
                            icon: const Icon(Icons.chevron_left, size: 19, color: Color(0xFF00B0FF)),
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
                            icon: const Icon(Icons.chevron_right, size: 19, color: Color(0xFF00B0FF)),
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
                          onChanged: (val) => setState(() => searchQuery = val),
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Keresés csapatra, országra vagy bajnokságra...',
                            hintStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                            prefixIcon: const Icon(Icons.search, color: Color(0xFF00E676), size: 18),
                            filled: true,
                            fillColor: const Color(0xFF0B132B).withAlpha(200),
                            contentPadding: EdgeInsets.zero,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(11),
                              borderSide: BorderSide(color: Colors.white.withAlpha(25)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(11),
                              borderSide: BorderSide(color: Colors.white.withAlpha(25)),
                            ),
                          ),
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
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 2),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF00E676).withAlpha(32), const Color(0xFF00B0FF).withAlpha(28)],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF00E676).withAlpha(130)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.vpn_key, color: Color(0xFF00E676), size: 19),
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
                      backgroundColor: const Color(0xFF00E676),
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

          // Gyors bajnokság-választó sáv (ország alapú ABC-sorrendben)
          SizedBox(
            height: 46,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              itemCount: dynamicCompetitions.length,
              itemBuilder: (context, index) {
                final comp = dynamicCompetitions[index];
                final isSelected = selectedCompetition == comp;
                final label = comp == 'Összes' ? 'Összes (${widget.matches.length})' : comp;
                final accent = comp == 'Összes'
                    ? const Color(0xFF00E676)
                    : SportsApiService.colorFromName(comp);

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
                        color: isSelected ? null : const Color(0xFF1C2541),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? accent : Colors.white12,
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

          // Eredmények.com stílusú meccslista, ORSZÁG + BAJNOKSÁG fejléccel, ABC-sorrendben
          Expanded(
            child: RefreshIndicator(
              color: const Color(0xFF00E676),
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
                        final isCollapsed = _collapsedCompetitions.contains(compKey);
                        final accent = SportsApiService.colorFromName(compKey);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF131D3B),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: accent.withAlpha(85)),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withAlpha(18),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              InkWell(
                                borderRadius: BorderRadius.vertical(
                                  top: const Radius.circular(14),
                                  bottom: Radius.circular(isCollapsed ? 14 : 0),
                                ),
                                onTap: () {
                                  setState(() {
                                    if (isCollapsed) {
                                      _collapsedCompetitions.remove(compKey);
                                    } else {
                                      _collapsedCompetitions.add(compKey);
                                    }
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        accent.withAlpha(72),
                                        const Color(0xFF1C2541),
                                        accent.withAlpha(26),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.vertical(
                                      top: const Radius.circular(14),
                                      bottom: Radius.circular(isCollapsed ? 14 : 0),
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
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0B132B).withAlpha(210),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: accent.withAlpha(130)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.public, size: 12, color: accent),
                                            const SizedBox(width: 4),
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
                                      const SizedBox(width: 4),
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
                                        onToggleFavorite: () => widget.onToggleFavorite(match.id),
                                      ),
                                      if (!isLast)
                                        Divider(
                                          height: 1,
                                          thickness: 1,
                                          color: Colors.white.withAlpha(14),
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
}

// --- EREDMÉNYEK.COM STÍLUSÚ, SZÍNES MECCSSOR ---
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
    final homeWinning = match.isLive || match.isFinished ? match.homeScore > match.awayScore : false;
    final awayWinning = match.isLive || match.isFinished ? match.awayScore > match.homeScore : false;
    final showScore = match.isLive || match.isFinished;

    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MatchStatsScreen(match: match))),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          gradient: match.isLive
              ? LinearGradient(
                  colors: [
                    const Color(0xFF00E676).withAlpha(24),
                    match.homeColor.withAlpha(16),
                    const Color(0xFF00B0FF).withAlpha(20),
                  ],
                )
              : LinearGradient(
                  colors: [
                    match.homeColor.withAlpha(14),
                    Colors.transparent,
                    match.awayColor.withAlpha(14),
                  ],
                ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (match.isLive) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFFF1744), Color(0xFFFF5252)]),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Text(
                        'ÉLŐ',
                        style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      match.status,
                      style: const TextStyle(color: Color(0xFF00E676), fontSize: 11, fontWeight: FontWeight.w900),
                      textAlign: TextAlign.center,
                    ),
                  ] else if (match.isFinished) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00B0FF).withAlpha(32),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: const Color(0xFF00B0FF).withAlpha(90)),
                      ),
                      child: Text(
                        match.status,
                        style: const TextStyle(color: Color(0xFF80D8FF), fontSize: 10, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ] else ...[
                    Text(
                      match.status,
                      style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
            Container(
              width: 2.5,
              height: 40,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [match.homeColor, match.awayColor],
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
                  ),
                  const SizedBox(height: 6),
                  _teamLine(
                    name: match.awayTeam,
                    color: match.awayColor,
                    logoUrl: match.awayLogo,
                    isWinning: awayWinning,
                    isFinished: match.isFinished,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 30,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: match.isLive
                          ? const Color(0xFF00E676).withAlpha(28)
                          : (homeWinning ? match.homeColor.withAlpha(35) : Colors.transparent),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      showScore ? '${match.homeScore}' : '-',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        color: match.isLive
                            ? const Color(0xFF00E676)
                            : (homeWinning ? Colors.white : Colors.white70),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: match.isLive
                          ? const Color(0xFF00B0FF).withAlpha(28)
                          : (awayWinning ? match.awayColor.withAlpha(35) : Colors.transparent),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      showScore ? '${match.awayScore}' : '-',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        color: match.isLive
                            ? const Color(0xFF00B0FF)
                            : (awayWinning ? Colors.white : Colors.white70),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onToggleFavorite,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  isFavorite ? Icons.star : Icons.star_border,
                  color: isFavorite ? const Color(0xFFFFAB00) : Colors.white38,
                  size: 20,
                ),
              ),
            ),
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
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isWinning ? FontWeight.w800 : FontWeight.w600,
              color: dimTeam ? Colors.white60 : Colors.white,
            ),
          ),
        ),
      ],
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

  @override
  void initState() {
    super.initState();
    _loadStandings();
  }

  Future<void> _loadStandings({bool forceRefresh = false}) async {
    if (!ApiConfig.hasValidKey) {
      setState(() {
        _rows = sampleStandings[selectedLeague] ?? sampleStandings['Premier League']!;
        _fromCache = false;
      });
      return;
    }

    setState(() => _loading = true);
    try {
      final result = await SportsApiService.fetchStandings(selectedLeague, forceRefresh: forceRefresh);
      setState(() {
        _rows = result.data.isNotEmpty
            ? result.data
            : (sampleStandings[selectedLeague] ?? sampleStandings['Premier League']!);
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
    final leagues = SportsApiService.highlightlyLeagueIds.keys.toList();

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
                      _fromCache
                          ? 'Gyorsítótárból (${ApiConfig.providerName}) • 2 órás védelem'
                          : '${ApiConfig.providerName} élő állások és pontok',
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
                      CachedTeamLogo(
                        teamName: r.team,
                        fallbackColor: r.color,
                        logoUrl: r.logo,
                        radius: 11,
                        showInitialsOnFallback: false,
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
                          color: const Color(0xFF131D3B),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFFAB00).withAlpha(80)),
                        ),
                        child: MatchCard(match: match, isFavorite: true, onToggleFavorite: () => onToggleFavorite(match.id)),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// --- RÉSZLETES STATISZTIKA ÉS ÖSSZEFOGLALÓK KÉPERNYŐ ---
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
    if (!ApiConfig.hasValidKey || !_match.isFromApi) return;
    setState(() => _loadingDetails = true);
    final result = await SportsApiService.enrichMatchDetails(_match, forceRefresh: forceRefresh);
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
    final intervalSec = ApiConfig.isStatPal ? 15 : 30;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${_match.country} • ${_match.league}', style: const TextStyle(fontSize: 15)),
              if (_fromCache)
                Text('Gyorsítótárból betöltve (${ApiConfig.providerName})', style: const TextStyle(fontSize: 11, color: Color(0xFF00B0FF)))
              else if (_match.isLive && _match.isFromApi)
                Text('Élő követés • $intervalSec mp-enként frissül', style: const TextStyle(fontSize: 11, color: Color(0xFF00E676))),
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
                  Expanded(
                    child: Column(
                      children: [
                        CachedTeamLogo(teamName: _match.homeTeam, fallbackColor: _match.homeColor, logoUrl: _match.homeLogo, radius: 22),
                        const SizedBox(height: 6),
                        Text(_match.homeTeam, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      Text('${_match.homeScore} : ${_match.awayScore}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF00E676))),
                      Text(_match.isLive ? 'ÉLŐ • ${_match.status}' : _match.status, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                    ],
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        CachedTeamLogo(teamName: _match.awayTeam, fallbackColor: _match.awayColor, logoUrl: _match.awayLogo, radius: 22),
                        const SizedBox(height: 6),
                        Text(_match.awayTeam, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
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
              tabs: [Tab(text: 'Statisztikák'), Tab(text: 'Események'), Tab(text: 'Összefoglalók 🎬')],
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
                      ? const Center(child: Text('Még nincs rögzített esemény ehhez a mérkőzéshez.', style: TextStyle(color: Colors.white60)))
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
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              ApiConfig.isStatPal
                                  ? 'A StatPal V2 élő állásokat és statisztikákat nyújt;\nvideós összefoglalókhoz válts Highlightly kulcsra a ⚙️ menüben.'
                                  : 'Ehhez a mérkőzéshez még nem érhető el videós összefoglaló.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white60, height: 1.5),
                            ),
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
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Videó hivatkozás másolva a vágólapra!')));
                                          },
                                          icon: const Icon(Icons.copy, size: 18),
                                          label: const Text('Hivatkozás másolása'),
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
