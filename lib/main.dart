import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart' hide CollapseMode;
import 'package:flutter/services.dart';
import 'api_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiConfig.load();
  await ApiCache.loadStats();
  await DisplayPrefs.load();
  await LogoCache.init();
  runApp(const ZsoltScoresApp());
}

// --- ÉRTESÍTÉSKEZELŐ (GÓL, PIROS LAP, VÉGE KAPCSOLÓKKAL + PRÓBARIASZTÁS) ---
class LiveAlertService {
  static final Map<String, String> _knownSnapshots = {};
  static bool _seeded = false;

  static void showTestAlert(BuildContext context) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Color(0xFF1C2541),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 4),
        content: Text(
          '🔔 Próbaértesítés: ⚽ GÓL! Ferencváros 3 - 1 Puskás Akadémia (82\')',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
        ),
      ),
    );
  }

  static void evaluateMatches(BuildContext context, List<MatchData> matches, Set<String> favoriteIds) {
    if (matches.isEmpty) return;

    if (!_seeded) {
      for (final m in matches) {
        _knownSnapshots[m.id] = _signature(m);
      }
      _seeded = true;
      return;
    }

    final alerts = <String>[];
    for (final m in matches) {
      final prev = _knownSnapshots[m.id];
      final curr = _signature(m);
      _knownSnapshots[m.id] = curr;

      if (prev == null || prev == curr) continue;
      final watched = favoriteIds.contains(m.id) ||
          DisplayPrefs.isFavoriteTeam(m.homeTeam) ||
          DisplayPrefs.isFavoriteTeam(m.awayTeam);
      if (!watched) continue;

      final prevParts = prev.split('|');
      final prevH = int.tryParse(prevParts[0]) ?? 0;
      final prevA = int.tryParse(prevParts[1]) ?? 0;
      final prevRed = int.tryParse(prevParts[2]) ?? 0;
      final prevFin = prevParts[3] == '1';

      final currRed = m.events.where((e) => e.type == 'red').length;

      if (DisplayPrefs.alertOnGoal && (m.homeScore > prevH || m.awayScore > prevA)) {
        alerts.add('⚽ GÓL! ${m.homeTeam} ${m.homeScore} - ${m.awayScore} ${m.awayTeam} (${m.status})');
      }
      if (DisplayPrefs.alertOnRedCard && currRed > prevRed) {
        alerts.add('🟥 Piros lap: ${m.homeTeam} - ${m.awayTeam} (${m.status})');
      }
      if (DisplayPrefs.alertOnFinish && m.isFinished && !prevFin) {
        alerts.add('🏁 VÉGE: ${m.homeTeam} ${m.homeScore} - ${m.awayScore} ${m.awayTeam}');
      }
    }

    if (alerts.isNotEmpty && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1C2541),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          content: Text(
            alerts.join('\n'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
          ),
        ),
      );
    }
  }

  static String _signature(MatchData m) {
    final reds = m.events.where((e) => e.type == 'red').length;
    return '${m.homeScore}|${m.awayScore}|$reds|${m.isFinished ? 1 : 0}';
  }
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
    'a': 1, 'á': 2, 'b': 3, 'c': 4, 'cs': 5, 'd': 6, 'dz': 7, 'dzs': 8,
    'e': 9, 'é': 10, 'f': 11, 'g': 12, 'gy': 13, 'h': 14, 'i': 15, 'í': 16,
    'j': 17, 'k': 18, 'l': 19, 'ly': 20, 'm': 21, 'n': 22, 'ny': 23, 'o': 24,
    'ó': 25, 'ö': 26, 'ő': 27, 'p': 28, 'q': 29, 'r': 30, 's': 31, 'sz': 32,
    't': 33, 'ty': 34, 'u': 35, 'ú': 36, 'ü': 37, 'ű': 38, 'v': 39, 'w': 40,
    'x': 41, 'y': 42, 'z': 43, 'zs': 44,
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

// --- ORSZÁGZÁSZLÓ WIDGET ---
class CountryFlagBadge extends StatefulWidget {
  final String countryName;
  final String? flagUrl;

  const CountryFlagBadge({
    super.key,
    required this.countryName,
    this.flagUrl,
  });

  @override
  State<CountryFlagBadge> createState() => _CountryFlagBadgeState();
}

class _CountryFlagBadgeState extends State<CountryFlagBadge> {
  File? _localFile;

  @override
  void initState() {
    super.initState();
    _loadFlag();
  }

  @override
  void didUpdateWidget(covariant CountryFlagBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.flagUrl != widget.flagUrl) {
      _localFile = null;
      _loadFlag();
    }
  }

  Future<void> _loadFlag() async {
    if (widget.flagUrl == null || widget.flagUrl!.trim().isEmpty) return;
    final file = await LogoCache.getOrDownload(widget.flagUrl);
    if (mounted && file != null) {
      setState(() => _localFile = file);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_localFile != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Image.file(
          _localFile!,
          width: 18,
          height: 13,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Text(
            HungarianLocalization.flagEmojiForCountry(widget.countryName),
            style: const TextStyle(fontSize: 13),
          ),
        ),
      );
    }
    return Text(
      HungarianLocalization.flagEmojiForCountry(widget.countryName),
      style: const TextStyle(fontSize: 13),
    );
  }
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

// --- CSAPAT-PROFIL NÉZET ---
class TeamProfileScreen extends StatefulWidget {
  final String teamName;
  final String? logoUrl;
  final Color accentColor;
  final List<String> form;
  final List<MatchData> relatedMatches;
  final VoidCallback onChanged;

  const TeamProfileScreen({
    super.key,
    required this.teamName,
    this.logoUrl,
    required this.accentColor,
    this.form = const [],
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
    Color bg;
    if (code == 'GY') {
      bg = const Color(0xFF00E676);
    } else if (code == 'D') {
      bg = const Color(0xFFFFAB00);
    } else {
      bg = const Color(0xFFFF1744);
    }
    return Container(
      width: 24,
      height: 24,
      margin: const EdgeInsets.only(right: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Text(code, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 10.5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveForm = widget.form.isNotEmpty ? widget.form : const ['GY', 'D', 'GY', 'V', 'GY'];
    final pts = MatchData.formPoints(effectiveForm);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.teamName),
        backgroundColor: const Color(0xFF1C2541),
        actions: [
          IconButton(
            tooltip: _isFav ? 'Eltávolítás a kedvenc csapatokból' : 'Hozzáadás a kedvenc csapatokhoz',
            onPressed: _toggleFav,
            icon: Icon(_isFav ? Icons.star : Icons.star_border, color: const Color(0xFFFFAB00)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [widget.accentColor.withAlpha(80), const Color(0xFF1C2541)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                CachedTeamLogo(teamName: widget.teamName, fallbackColor: widget.accentColor, logoUrl: widget.logoUrl, radius: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.teamName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(
                        _isFav ? '★ Kedvenc csapat (kiemelt a meccseknél)' : 'Koppints a csillagra a kedvenceléshez',
                        style: TextStyle(fontSize: 12, color: _isFav ? const Color(0xFFFFD54F) : Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFF1C2541), borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Utolsó 5 meccs formája', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                    Text('$pts pont / 15', style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(children: effectiveForm.map(_badge).toList()),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('Kapcsolódó meccsek', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          if (widget.relatedMatches.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFF1C2541), borderRadius: BorderRadius.circular(14)),
              child: const Text('A kiválasztott napon nincs meccs a csapattal.', style: TextStyle(color: Colors.white60)),
            )
          else
            ...widget.relatedMatches.map((m) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(color: const Color(0xFF131D3B), borderRadius: BorderRadius.circular(14)),
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
  Map<String, int> _prevScores = {};
  Set<String> _recentlyScoredIds = {};
  DateTime _selectedDate = DateTime.now();
  DateTime _lastUpdatedAt = DateTime.now();
  bool _isLoading = false;
  bool _isLiveApiData = false;
  bool _loadedFromCache = false;
  String? _statusMessage;
  Timer? _listLiveTimer;

  @override
  void initState() {
    super.initState();
    for (final m in _matches) {
      _prevScores[m.id] = m.homeScore * 100 + m.awayScore;
    }
    _loadMatches();
    _restartLiveListTimer();
  }

  @override
  void dispose() {
    _listLiveTimer?.cancel();
    super.dispose();
  }

  void _restartLiveListTimer() {
    _listLiveTimer?.cancel();
    if (!DisplayPrefs.autoLiveListRefresh) return;
    _listLiveTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      final isToday = SportsApiService.formatDate(_selectedDate) == SportsApiService.formatDate(DateTime.now());
      final hasLive = _matches.any((m) => m.isLive);
      if (mounted && ApiConfig.hasValidKey && isToday && hasLive) {
        _loadMatches(forceRefresh: true, silent: true);
      }
    });
  }

  Future<void> _loadMatches({bool forceRefresh = false, bool silent = false}) async {
    if (!ApiConfig.hasValidKey) {
      setState(() {
        _matches = sampleMatches;
        _isLiveApiData = false;
        _loadedFromCache = false;
        _lastUpdatedAt = DateTime.now();
        _statusMessage = null;
      });
      return;
    }

    if (!silent) {
      setState(() {
        _isLoading = true;
        _statusMessage = null;
      });
    }

    try {
      final result = await SportsApiService.fetchMatches(_selectedDate, forceRefresh: forceRefresh);
      final scoredNow = <String>{};
      final nextScores = <String, int>{};

      for (final m in result.data) {
        final code = m.homeScore * 100 + m.awayScore;
        nextScores[m.id] = code;
        if (_prevScores.containsKey(m.id) && _prevScores[m.id] != code) {
          scoredNow.add(m.id);
        }
      }
      _prevScores = nextScores;

      setState(() {
        _matches = result.data;
        _isLiveApiData = true;
        _loadedFromCache = result.fromCache;
        _lastUpdatedAt = result.fetchedAt;
        _isLoading = false;
        if (scoredNow.isNotEmpty) {
          _recentlyScoredIds.addAll(scoredNow);
        }
        _statusMessage = result.data.isEmpty
            ? 'Erre a napra nincs elérhető meccs (${ApiConfig.providerName}).'
            : null;
      });

      if (scoredNow.isNotEmpty) {
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) {
            setState(() => _recentlyScoredIds.removeAll(scoredNow));
          }
        });
      }

      if (mounted) {
        LiveAlertService.evaluateMatches(context, result.data, _favoriteIds);
      }
    } catch (e) {
      if (!silent) {
        setState(() {
          _isLoading = false;
          _isLiveApiData = false;
          _loadedFromCache = false;
          _lastUpdatedAt = DateTime.now();
          _matches = sampleMatches;
          _statusMessage = '$e – koppints a ⚙️ ikonra a beállításokhoz';
        });
      }
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

  Future<void> _togglePinCompetition(String compKey) async {
    await DisplayPrefs.togglePin(compKey);
    if (mounted) {
      setState(() => _settingsVersion++);
    }
  }

  void _openApiSettingsDialog() async {
    await LogoCache.refreshCount();
    if (!mounted) return;

    ApiProvider tempProvider = ApiConfig.provider;
    final hlController = TextEditingController(text: ApiConfig.highlightlyKey);
    final spController = TextEditingController(text: ApiConfig.statpalKey);
    final favTeamsController = TextEditingController(text: DisplayPrefs.favoriteTeams.join(', '));
    bool tempRapid = ApiConfig.useRapidApi;
    int tempTtl = ApiCache.cacheMinutes;
    CollapseMode tempCollapseMode = DisplayPrefs.collapseMode;
    bool tempAutoLiveList = DisplayPrefs.autoLiveListRefresh;
    bool tempAlertGoal = DisplayPrefs.alertOnGoal;
    bool tempAlertRed = DisplayPrefs.alertOnRedCard;
    bool tempAlertEnd = DisplayPrefs.alertOnFinish;
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
                Text('Beállítások és Gyorsítótár', style: TextStyle(fontSize: 17)),
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
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Élő követés (60 mp-es listafrissítés)', style: TextStyle(fontSize: 13)),
                    subtitle: const Text(
                      'Gól esetén zöld jelzés + kiemelt meccs riasztás',
                      style: TextStyle(fontSize: 11, color: Colors.white54),
                    ),
                    value: tempAutoLiveList,
                    onChanged: (val) => setDialogState(() => tempAutoLiveList = val),
                  ),
                  const Divider(color: Colors.white12, height: 14),
                  const Text('Értesítési típusok:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('⚽ Gól értesítés', style: TextStyle(fontSize: 12.5)),
                    value: tempAlertGoal,
                    onChanged: (v) => setDialogState(() => tempAlertGoal = v),
                  ),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('🟥 Piros lap értesítés', style: TextStyle(fontSize: 12.5)),
                    value: tempAlertRed,
                    onChanged: (v) => setDialogState(() => tempAlertRed = v),
                  ),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('🏁 Mérkőzés vége értesítés', style: TextStyle(fontSize: 12.5)),
                    value: tempAlertEnd,
                    onChanged: (v) => setDialogState(() => tempAlertEnd = v),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => LiveAlertService.showTestAlert(context),
                      icon: const Icon(Icons.notifications_active_outlined, size: 16, color: Color(0xFFFFAB00)),
                      label: const Text('Próbaértesítés küldése', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const Divider(color: Colors.white12, height: 16),
                  const Text('Kedvenc csapatok (vesszővel elválasztva):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: favTeamsController,
                    decoration: InputDecoration(
                      hintText: 'pl. Ferencváros, Liverpool, Real Madrid',
                      filled: true,
                      fillColor: const Color(0xFF0B132B),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const Divider(color: Colors.white12, height: 16),
                  const Text('Bajnokságok kezdőállapota:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ChoiceChip(
                        label: const Text('Élő / Kitűzött nyitva', style: TextStyle(fontSize: 11)),
                        selected: tempCollapseMode == CollapseMode.liveOrPinned,
                        selectedColor: const Color(0xFF00E676),
                        backgroundColor: const Color(0xFF0B132B),
                        labelStyle: TextStyle(
                          color: tempCollapseMode == CollapseMode.liveOrPinned ? Colors.black : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (_) => setDialogState(() => tempCollapseMode = CollapseMode.liveOrPinned),
                      ),
                      ChoiceChip(
                        label: const Text('Mind nyitva', style: TextStyle(fontSize: 11)),
                        selected: tempCollapseMode == CollapseMode.allExpanded,
                        selectedColor: const Color(0xFF00B0FF),
                        backgroundColor: const Color(0xFF0B132B),
                        labelStyle: TextStyle(
                          color: tempCollapseMode == CollapseMode.allExpanded ? Colors.black : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (_) => setDialogState(() => tempCollapseMode = CollapseMode.allExpanded),
                      ),
                      ChoiceChip(
                        label: const Text('Mind csukva', style: TextStyle(fontSize: 11)),
                        selected: tempCollapseMode == CollapseMode.allCollapsed,
                        selectedColor: Colors.amberAccent,
                        backgroundColor: const Color(0xFF0B132B),
                        labelStyle: TextStyle(
                          color: tempCollapseMode == CollapseMode.allCollapsed ? Colors.black : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (_) => setDialogState(() => tempCollapseMode = CollapseMode.allCollapsed),
                      ),
                    ],
                  ),
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
                    await DisplayPrefs.saveDisplayAndAlerts(
                      newCollapseMode: tempCollapseMode,
                      newAutoLiveList: tempAutoLiveList,
                      newFavoriteTeams: favTeamsController.text.split(','),
                      goalAlert: tempAlertGoal,
                      redAlert: tempAlertRed,
                      endAlert: tempAlertEnd,
                    );
                    _restartLiveListTimer();
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
                  await DisplayPrefs.saveDisplayAndAlerts(
                    newCollapseMode: tempCollapseMode,
                    newAutoLiveList: tempAutoLiveList,
                    newFavoriteTeams: favTeamsController.text.split(','),
                    goalAlert: tempAlertGoal,
                    redAlert: tempAlertRed,
                    endAlert: tempAlertEnd,
                  );
                  _restartLiveListTimer();
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
        key: ValueKey('matches_$_settingsVersion'),
        matches: _matches,
        recentlyScoredIds: _recentlyScoredIds,
        selectedDate: _selectedDate,
        lastUpdatedAt: _lastUpdatedAt,
        isLoading: _isLoading,
        isLiveApiData: _isLiveApiData,
        loadedFromCache: _loadedFromCache,
        statusMessage: _statusMessage,
        favoriteIds: _favoriteIds,
        onToggleFavorite: _toggleFavorite,
        onTogglePinCompetition: _togglePinCompetition,
        onChangeDate: _changeDate,
        onJumpToday: _jumpToToday,
        onRefresh: () => _loadMatches(forceRefresh: true),
        onOpenSettings: _openApiSettingsDialog,
      ),
      StandingsTab(
        key: ValueKey('standings_$_settingsVersion'),
        allMatches: _matches,
        onOpenSettings: _openApiSettingsDialog,
        onTeamChanged: () => setState(() => _settingsVersion++),
      ),
      FavoritesTab(
        allMatches: _matches,
        recentlyScoredIds: _recentlyScoredIds,
        favoriteIds: _favoriteIds,
        onToggleFavorite: _toggleFavorite,
      ),
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
        : (widget.loadedFromCache ? const Color(0xFF00B0FF) : const Color(0xFF00E676));

    final quickChips = <String>{
      ...DisplayPrefs.favoriteTeams,
      ...DisplayPrefs.recentSearches,
    }.take(7).toList();

    return SafeArea(
      child: Column(
        children: [
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
                            color: const Color(0xFF0B132B).withAlpha(180),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: DisplayPrefs.autoLiveListRefresh
                                  ? const Color(0xFF00E676).withAlpha(130)
                                  : Colors.white24,
                            ),
                          ),
                          child: Icon(
                            Icons.sensors,
                            color: DisplayPrefs.autoLiveListRefresh ? const Color(0xFF00E676) : Colors.white38,
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
                      onTap: () => setState(() => quickFilter = quickFilter == 'live' ? 'all' : 'live'),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: quickFilter == 'live'
                              ? const LinearGradient(colors: [Color(0xFFFF1744), Color(0xFFFF6D00)])
                              : null,
                          color: quickFilter == 'live' ? null : const Color(0xFFFF1744).withAlpha(38),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: quickFilter == 'live' ? const Color(0xFFFF5252) : const Color(0xFFFF1744).withAlpha(170),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: quickFilter == 'live' ? Colors.white : const Color(0xFFFF1744),
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
                            prefixIcon: const Icon(Icons.search, color: Color(0xFF00E676), size: 18),
                            suffixIcon: searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.close, size: 16, color: Colors.white54),
                                    onPressed: () => _applyQuickSearch(''),
                                  )
                                : null,
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
                                  color: active ? const Color(0xFFFFAB00) : const Color(0xFF0B132B).withAlpha(175),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: active ? const Color(0xFFFFAB00) : Colors.white12),
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
                    _quickFilterChip('Mind', 'all', const Color(0xFF00E676)),
                    const SizedBox(width: 6),
                    _quickFilterChip('Élő', 'live', const Color(0xFFFF1744)),
                    const SizedBox(width: 6),
                    _quickFilterChip('Vége', 'finished', const Color(0xFF00B0FF)),
                    const SizedBox(width: 6),
                    _quickFilterChip('Kedvencek', 'favs', const Color(0xFFFFAB00)),
                  ],
                ),
              ],
            ),
          ),

          if (liveMatches.isNotEmpty)
            SizedBox(
              height: 58,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
                itemCount: liveMatches.length,
                itemBuilder: (ctx, idx) {
                  final lm = liveMatches[idx];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => MatchStatsScreen(match: lm))),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C2541),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF00E676).withAlpha(110)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(lm.status, style: const TextStyle(color: Color(0xFFFF5252), fontWeight: FontWeight.w900, fontSize: 11)),
                            const SizedBox(width: 7),
                            Text(
                              '${lm.homeTeam} ${lm.homeScore}-${lm.awayScore} ${lm.awayTeam}',
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
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
                    ? const Color(0xFF00E676)
                    : (isPinned ? const Color(0xFFFFAB00) : SportsApiService.colorFromName(comp));

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
                          color: isSelected ? accent : (isPinned ? const Color(0xFFFFAB00).withAlpha(110) : Colors.white12),
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
                        final isPinned = DisplayPrefs.pinnedCompetitions.contains(compKey);
                        final isCollapsed = _isCompetitionCollapsed(compKey, compMatches);
                        final accent = isPinned
                            ? const Color(0xFFFFAB00)
                            : SportsApiService.colorFromName(compKey);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF131D3B),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: accent.withAlpha(isPinned ? 140 : 85)),
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
                                onTap: () => _toggleSingleCompetition(compKey),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        accent.withAlpha(78),
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
                                      const SizedBox(width: 7),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0B132B).withAlpha(215),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: accent.withAlpha(130)),
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
                                            color: isPinned ? const Color(0xFFFFAB00) : Colors.white38,
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

  Widget _quickFilterChip(String label, String value, Color accent) {
    final active = quickFilter == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => quickFilter = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 5),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? accent : const Color(0xFF0B132B).withAlpha(190),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: active ? accent : Colors.white12),
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

// --- MECCSKÁRTYA ---
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
    final homeWinning = match.isLive || match.isFinished ? match.homeScore > match.awayScore : false;
    final awayWinning = match.isLive || match.isFinished ? match.awayScore > match.homeScore : false;
    final showScore = match.isLive || match.isFinished;

    final homeFavTeam = DisplayPrefs.isFavoriteTeam(match.homeTeam);
    final awayFavTeam = DisplayPrefs.isFavoriteTeam(match.awayTeam);
    final hasFavTeam = homeFavTeam || awayFavTeam;

    final keyEvents = match.events.where((e) => e.type == 'goal' || e.type == 'red').toList();

    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MatchStatsScreen(match: match))),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 450),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: isGoalFlash ? const Color(0xFF00E676).withAlpha(65) : null,
          border: hasFavTeam
              ? Border(left: BorderSide(color: const Color(0xFFFFAB00), width: 3.5))
              : null,
          gradient: isGoalFlash
              ? null
              : (hasFavTeam
                  ? LinearGradient(
                      colors: [
                        const Color(0xFFFFAB00).withAlpha(24),
                        Colors.transparent,
                      ],
                    )
                  : (match.isLive
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
                        ))),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                        isFavTeam: homeFavTeam,
                      ),
                      const SizedBox(height: 6),
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
            if (keyEvents.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: keyEvents.map((ev) {
                  final isRed = ev.type == 'red';
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(isRed ? '🟥' : '⚽', style: const TextStyle(fontSize: 10.5)),
                      const SizedBox(width: 3),
                      Text(
                        '${ev.player} (${ev.minute})',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isRed ? Colors.redAccent : Colors.white70,
                          fontWeight: isRed ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ],
                  );
                }).toList(),
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
              fontSize: 13,
              fontWeight: (isWinning || isFavTeam) ? FontWeight.w800 : FontWeight.w600,
              color: isFavTeam ? const Color(0xFFFFD54F) : (dimTeam ? Colors.white60 : Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

// --- 2. NAGYON RÉSZLETES TABELLA FÜL ---
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
      final result = await SportsApiService.fetchStandings(
        selectedLeague,
        venueFilter: venueMode,
        forceRefresh: forceRefresh,
      );
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

  Widget _miniFormDot(String code) {
    Color bg;
    if (code == 'GY') {
      bg = const Color(0xFF00E676);
    } else if (code == 'D') {
      bg = const Color(0xFFFFAB00);
    } else {
      bg = const Color(0xFFFF1744);
    }
    return Container(
      width: 14,
      height: 14,
      margin: const EdgeInsets.only(right: 2),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(3)),
      child: Text(
        code.substring(0, 1),
        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 8.5),
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
                          ? 'Gyorsítótárból (${ApiConfig.providerName}) • GY/D/V & Gólok'
                          : '${ApiConfig.providerName} • Részletes állás, gólok & forma',
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Összes', style: TextStyle(fontSize: 11)),
                  selected: !showScorers && venueMode == 'all',
                  selectedColor: const Color(0xFF00B0FF),
                  backgroundColor: const Color(0xFF1C2541),
                  labelStyle: TextStyle(color: (!showScorers && venueMode == 'all') ? Colors.black : Colors.white, fontWeight: FontWeight.bold),
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
                  selectedColor: const Color(0xFF00B0FF),
                  backgroundColor: const Color(0xFF1C2541),
                  labelStyle: TextStyle(color: (!showScorers && venueMode == 'home') ? Colors.black : Colors.white, fontWeight: FontWeight.bold),
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
                  selectedColor: const Color(0xFF00B0FF),
                  backgroundColor: const Color(0xFF1C2541),
                  labelStyle: TextStyle(color: (!showScorers && venueMode == 'away') ? Colors.black : Colors.white, fontWeight: FontWeight.bold),
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
                  selectedColor: const Color(0xFFFFAB00),
                  backgroundColor: const Color(0xFF1C2541),
                  labelStyle: TextStyle(color: showScorers ? Colors.black : Colors.white, fontWeight: FontWeight.bold),
                  onSelected: (_) => setState(() => showScorers = true),
                ),
              ],
            ),
          ),
          if (!showScorers) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: const [
                  SizedBox(width: 24, child: Text('#', style: TextStyle(color: Colors.white54, fontSize: 11))),
                  Expanded(child: Text('Csapat', style: TextStyle(color: Colors.white54, fontSize: 11))),
                  SizedBox(width: 24, child: Text('M', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 11))),
                  SizedBox(width: 58, child: Text('GY/D/V', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 10.5))),
                  SizedBox(width: 44, child: Text('Gól', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 11))),
                  SizedBox(width: 34, child: Text('GK', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 11))),
                  SizedBox(width: 32, child: Text('P', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 11))),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: _rows.length,
                itemBuilder: (context, index) {
                  final r = _rows[index];
                  final isFav = DisplayPrefs.isFavoriteTeam(r.team);
                  final hasWdl = (r.won + r.drawn + r.lost) > 0;
                  final wdlText = hasWdl ? '${r.won}/${r.drawn}/${r.lost}' : '-';
                  final goalsText = (r.gf > 0 || r.ga > 0) ? '${r.gf}:${r.ga}' : '-';

                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _openTeamProfile(r),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C2541),
                        borderRadius: BorderRadius.circular(14),
                        border: Border(left: BorderSide(color: _zoneColor(r.zone), width: 4)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              SizedBox(width: 22, child: Text('${r.pos}.', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
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
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12.5,
                                    color: isFav ? const Color(0xFFFFD54F) : Colors.white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(width: 24, child: Text('${r.played}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 11.5))),
                              SizedBox(width: 58, child: Text(wdlText, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 11))),
                              SizedBox(width: 44, child: Text(goalsText, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 11))),
                              SizedBox(width: 34, child: Text(r.gd > 0 ? '+${r.gd}' : '${r.gd}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 11.5))),
                              SizedBox(width: 32, child: Text('${r.points}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF00E676), fontSize: 13))),
                            ],
                          ),
                          if (r.form.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const SizedBox(width: 30),
                                Row(children: r.form.map(_miniFormDot).toList()),
                                const Spacer(),
                                const Text('Profil ›', style: TextStyle(fontSize: 10, color: Colors.white38)),
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
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(color: const Color(0xFF1C2541), borderRadius: BorderRadius.circular(14)),
                    child: Row(
                      children: [
                        Text('${sc.rank}.', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFFAB00))),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(sc.player, style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text(sc.team, style: const TextStyle(fontSize: 11, color: Colors.white60)),
                            ],
                          ),
                        ),
                        Text('⚽ ${sc.goals}', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF00E676))),
                        const SizedBox(width: 12),
                        Text('🅰️ ${sc.assists}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
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
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF1C2541), Color(0xFF3A506B)]),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
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
                          color: const Color(0xFF131D3B),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFFAB00).withAlpha(80)),
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

// --- 2D-S FUTBALLPÁLYA FORMÁCIÓ WIDGET ---
class FormationPitchView extends StatelessWidget {
  final String teamName;
  final Color accent;
  final TeamLineup lineup;

  const FormationPitchView({
    super.key,
    required this.teamName,
    required this.accent,
    required this.lineup,
  });

  List<List<LineupPlayer>> _buildRows(List<LineupPlayer> starters) {
    if (starters.isEmpty) return const [];
    final gk = starters.where((p) => p.position.toUpperCase() == 'GK').toList();
    final others = starters.where((p) => p.position.toUpperCase() != 'GK').toList();

    final parts = lineup.formation
        .split('-')
        .map((s) => int.tryParse(s.trim()) ?? 0)
        .where((n) => n > 0)
        .toList();

    final rows = <List<LineupPlayer>>[];
    int cursor = 0;

    if (parts.isNotEmpty && parts.length <= 5 && others.length >= 4) {
      for (final count in parts.reversed) {
        if (cursor >= others.length) break;
        final take = (cursor + count <= others.length) ? count : (others.length - cursor);
        rows.add(others.sublist(cursor, cursor + take));
        cursor += take;
      }
      if (cursor < others.length) {
        rows.add(others.sublist(cursor));
      }
    } else {
      final chunkSize = (others.length / 3).ceil().clamp(1, 5);
      for (int i = 0; i < others.length; i += chunkSize) {
        rows.add(others.sublist(i, (i + chunkSize).clamp(0, others.length)));
      }
    }

    if (gk.isNotEmpty) {
      rows.add(gk);
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final rows = _buildRows(lineup.starters);
    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF144A2B), Color(0xFF1B5E37)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withAlpha(65), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(teamName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
              Text('Formáció: ${lineup.formation}', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 11)),
            ],
          ),
          const Divider(color: Colors.white24, height: 12),
          ...rows.map((rowPlayers) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: rowPlayers.map((p) {
                  return Expanded(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 13,
                          backgroundColor: accent,
                          child: Text(
                            p.number.isNotEmpty ? p.number : '•',
                            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 10.5),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// --- RÉSZLETES NÉZET: STATISZTIKA & H2H + IDŐVONAL + KEZDŐCSAPATOK + ÖSSZEFOGLALÓK ---
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
  String _eventFilter = 'all'; // 'all', 'goal', 'cards', 'sub'
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
