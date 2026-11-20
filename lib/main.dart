import 'dart:async';
import 'package:flutter/material.dart' hide CollapseMode;
import 'package:flutter/services.dart';
import 'package:zsoltscores/api_service.dart';
import 'package:zsoltscores/services/live_alert_service.dart';
import 'package:zsoltscores/tabs/favorites_tab.dart';
import 'package:zsoltscores/tabs/matches_tab.dart';
import 'package:zsoltscores/tabs/standings_tab.dart';
import 'package:zsoltscores/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiConfig.load();
  await ApiCache.loadStats();
  await DisplayPrefs.load();
  await LogoCache.init();
  await AppThemeController.instance.load();
  runApp(const ZsoltScoresApp());
}

class ZsoltScoresApp extends StatelessWidget {
  const ZsoltScoresApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppThemeController.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'zsoltscores',
          debugShowCheckedModeBanner: false,
          theme: AppThemeController.instance.buildTheme(),
          home: const MainShell(),
        );
      },
    );
  }
}

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
          final p = AppThemeController.instance.palette;
          final isSp = tempProvider == ApiProvider.statpal;
          final activeCtrl = isSp ? spController : hlController;

          return AlertDialog(
            backgroundColor: p.cardElevated,
            title: Row(
              children: [
                Icon(Icons.vpn_key, color: p.primaryAccent),
                const SizedBox(width: 8),
                const Text('Beállítások és Gyorsítótár', style: TextStyle(fontSize: 17)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Megjelenés / Színvilág:', style: TextStyle(fontSize: 12, color: Colors.white70)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Klasszikus sötét', style: TextStyle(fontSize: 11.5))),
                          selected: !AppThemeController.instance.isOled,
                          selectedColor: const Color(0xFF00E676),
                          backgroundColor: p.scaffoldBg,
                          labelStyle: TextStyle(
                            color: !AppThemeController.instance.isOled ? Colors.black : Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (_) async {
                            await AppThemeController.instance.setStyle(ZsoltThemeStyle.classicDark);
                            setDialogState(() {});
                            setState(() => _settingsVersion++);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('OLED Éjszakai', style: TextStyle(fontSize: 11.5))),
                          selected: AppThemeController.instance.isOled,
                          selectedColor: const Color(0xFF38BDF8),
                          backgroundColor: Colors.black,
                          labelStyle: TextStyle(
                            color: AppThemeController.instance.isOled ? Colors.black : Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (_) async {
                            await AppThemeController.instance.setStyle(ZsoltThemeStyle.oledMidnight);
                            setDialogState(() {});
                            setState(() => _settingsVersion++);
                          },
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 18),
                  const Text('Aktív adatforrás:', style: TextStyle(fontSize: 12, color: Colors.white70)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Highlightly', style: TextStyle(fontSize: 12))),
                          selected: !isSp,
                          selectedColor: p.primaryAccent,
                          backgroundColor: p.scaffoldBg,
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
                          selectedColor: p.secondaryAccent,
                          backgroundColor: p.scaffoldBg,
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
                      fillColor: p.scaffoldBg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.content_paste, color: p.secondaryAccent),
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
                        color: p.secondaryAccent.withAlpha(25),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: p.secondaryAccent.withAlpha(90)),
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
                              icon: Icon(Icons.analytics_outlined, size: 16, color: p.primaryAccent),
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
                              style: TextStyle(fontSize: 11, color: p.primaryAccent, fontWeight: FontWeight.bold),
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
                      icon: Icon(Icons.notifications_active_outlined, size: 16, color: p.goldAccent),
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
                      fillColor: p.scaffoldBg,
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
                        selectedColor: p.primaryAccent,
                        backgroundColor: p.scaffoldBg,
                        labelStyle: TextStyle(
                          color: tempCollapseMode == CollapseMode.liveOrPinned ? Colors.black : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (_) => setDialogState(() => tempCollapseMode = CollapseMode.liveOrPinned),
                      ),
                      ChoiceChip(
                        label: const Text('Mind nyitva', style: TextStyle(fontSize: 11)),
                        selected: tempCollapseMode == CollapseMode.allExpanded,
                        selectedColor: p.secondaryAccent,
                        backgroundColor: p.scaffoldBg,
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
                        backgroundColor: p.scaffoldBg,
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
                            selectedColor: p.secondaryAccent,
                            backgroundColor: p.scaffoldBg,
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
                      color: p.scaffoldBg,
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
                            Text('${ApiCache.savedRequests}', style: TextStyle(fontWeight: FontWeight.bold, color: p.primaryAccent, fontSize: 15)),
                            const Text('Megspórolt', style: TextStyle(fontSize: 10, color: Colors.white60)),
                          ],
                        ),
                        Column(
                          children: [
                            Text('${LogoCache.savedLogosCount}', style: TextStyle(fontWeight: FontWeight.bold, color: p.secondaryAccent, fontSize: 15)),
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
                      icon: Icon(Icons.delete_sweep, size: 18, color: p.secondaryAccent),
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
                style: FilledButton.styleFrom(backgroundColor: p.primaryAccent),
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
    final p = AppThemeController.instance.palette;
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
        backgroundColor: p.cardElevated,
        indicatorColor: p.primaryAccent.withAlpha(55),
        selectedIndex: _selectedIndex,
        onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.sports_soccer_outlined),
            selectedIcon: Icon(Icons.sports_soccer, color: p.primaryAccent),
            label: 'Meccsek',
          ),
          NavigationDestination(
            icon: const Icon(Icons.leaderboard_outlined),
            selectedIcon: Icon(Icons.leaderboard, color: p.secondaryAccent),
            label: 'Tabella',
          ),
          NavigationDestination(
            icon: Badge(
              label: Text('${_favoriteIds.length}'),
              isLabelVisible: _favoriteIds.isNotEmpty,
              child: const Icon(Icons.star_border),
            ),
            selectedIcon: Icon(Icons.star, color: p.goldAccent),
            label: 'Kedvencek',
          ),
        ],
      ),
    );
  }
}
