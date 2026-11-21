import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

enum ApiProvider {
  statpal,
}

enum CollapseMode {
  liveOrPinned,
  allExpanded,
  allCollapsed,
}

class ApiConfig {
  ApiConfig._();

  static const _prefStatpalKey = 'zsoltscores_statpal_key';

  static String statpalKey = '';

  static ApiProvider get provider => ApiProvider.statpal;
  static bool get isStatPal => true;
  static String get providerName => 'StatPal V2';

  static String get activeKey => statpalKey.trim();
  static bool get hasValidKey => activeKey.isNotEmpty;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    statpalKey = prefs.getString(_prefStatpalKey) ?? '';
  }

  static Future<void> save({
    ApiProvider newProvider = ApiProvider.statpal,
    String newHighlightlyKey = '',
    bool rapid = false,
    required String newStatpalKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    statpalKey = newStatpalKey.trim();
    await prefs.setString(_prefStatpalKey, statpalKey);
  }
}

class ApiCache {
  ApiCache._();

  static const _prefTtl = 'zsoltscores_cache_ttl_min';
  static const _prefNetReq = 'zsoltscores_net_req';
  static const _prefSavedReq = 'zsoltscores_saved_req';

  static int cacheMinutes = 5;
  static int networkRequests = 0;
  static int savedRequests = 0;

  static final Map<String, _CacheEntry> _mem = {};

  static Future<void> loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    cacheMinutes = prefs.getInt(_prefTtl) ?? 5;
    networkRequests = prefs.getInt(_prefNetReq) ?? 0;
    savedRequests = prefs.getInt(_prefSavedReq) ?? 0;
  }

  static Future<void> setCacheMinutes(int minutes) async {
    cacheMinutes = minutes.clamp(1, 60);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefTtl, cacheMinutes);
  }

  static Future<void> recordNetworkRequest() async {
    networkRequests++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefNetReq, networkRequests);
  }

  static Future<void> recordSavedRequest() async {
    savedRequests++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefSavedReq, savedRequests);
  }

  static Future<String> clearAll() async {
    final count = _mem.length;
    _mem.clear();
    final prefs = await SharedPreferences.getInstance();
    for (final k in prefs.getKeys().where((k) => k.startsWith('sp_cache_'))) {
      await prefs.remove(k);
    }
    return '$count memória elem';
  }

  static Future<dynamic> get(String key, {int? customTtlMinutes}) async {
    final ttl = Duration(minutes: customTtlMinutes ?? cacheMinutes);
    final now = DateTime.now();

    final mem = _mem[key];
    if (mem != null && now.difference(mem.savedAt) <= ttl) {
      await recordSavedRequest();
      return mem.payload;
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('sp_cache_$key');
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final ts = DateTime.tryParse(decoded['ts'] as String? ?? '');
        if (ts != null && now.difference(ts) <= ttl) {
          final data = decoded['data'];
          _mem[key] = _CacheEntry(savedAt: ts, payload: data);
          await recordSavedRequest();
          return data;
        }
      } catch (_) {}
    }

    return null;
  }

  static Future<void> set(String key, dynamic payload) async {
    final now = DateTime.now();
    _mem[key] = _CacheEntry(savedAt: now, payload: payload);
    final prefs = await SharedPreferences.getInstance();
    try {
      await prefs.setString(
        'sp_cache_$key',
        jsonEncode({'ts': now.toIso8601String(), 'data': payload}),
      );
    } catch (_) {}
  }
}

class _CacheEntry {
  final DateTime savedAt;
  final dynamic payload;
  _CacheEntry({required this.savedAt, required this.payload});
}

class DisplayPrefs {
  DisplayPrefs._();

  static const _prefCollapse = 'zsoltscores_collapse_mode';
  static const _prefAutoLive = 'zsoltscores_auto_live_list';
  static const _prefPinned = 'zsoltscores_pinned_comps';
  static const _prefFavTeams = 'zsoltscores_fav_teams';
  static const _prefRecentSearch = 'zsoltscores_recent_searches';
  static const _prefAlertGoal = 'zsoltscores_alert_goal';
  static const _prefAlertRed = 'zsoltscores_alert_red';
  static const _prefAlertEnd = 'zsoltscores_alert_end';

  static CollapseMode collapseMode = CollapseMode.liveOrPinned;
  static bool autoLiveListRefresh = true;
  static Set<String> pinnedCompetitions = {};
  static List<String> favoriteTeams = [];
  static List<String> recentSearches = [];
  static bool alertOnGoal = true;
  static bool alertOnRedCard = true;
  static bool alertOnFinish = true;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final colRaw = prefs.getString(_prefCollapse);
    if (colRaw == CollapseMode.allExpanded.name) {
      collapseMode = CollapseMode.allExpanded;
    } else if (colRaw == CollapseMode.allCollapsed.name) {
      collapseMode = CollapseMode.allCollapsed;
    } else {
      collapseMode = CollapseMode.liveOrPinned;
    }

    autoLiveListRefresh = prefs.getBool(_prefAutoLive) ?? true;
    pinnedCompetitions = (prefs.getStringList(_prefPinned) ?? []).toSet();
    favoriteTeams = prefs.getStringList(_prefFavTeams) ?? [];
    recentSearches = prefs.getStringList(_prefRecentSearch) ?? [];
    alertOnGoal = prefs.getBool(_prefAlertGoal) ?? true;
    alertOnRedCard = prefs.getBool(_prefAlertRed) ?? true;
    alertOnFinish = prefs.getBool(_prefAlertEnd) ?? true;
  }

  static Future<void> saveDisplayAndAlerts({
    required CollapseMode newCollapseMode,
    required bool newAutoLiveList,
    required List<String> newFavoriteTeams,
    required bool goalAlert,
    required bool redAlert,
    required bool endAlert,
  }) async {
    collapseMode = newCollapseMode;
    autoLiveListRefresh = newAutoLiveList;
    favoriteTeams = newFavoriteTeams
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    alertOnGoal = goalAlert;
    alertOnRedCard = redAlert;
    alertOnFinish = endAlert;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefCollapse, collapseMode.name);
    await prefs.setBool(_prefAutoLive, autoLiveListRefresh);
    await prefs.setStringList(_prefPinned, pinnedCompetitions.toList());
    await prefs.setStringList(_prefFavTeams, favoriteTeams);
    await prefs.setBool(_prefAlertGoal, alertOnGoal);
    await prefs.setBool(_prefAlertRed, alertOnRedCard);
    await prefs.setBool(_prefAlertEnd, alertOnFinish);
  }

  static Future<void> setAutoLiveListRefresh(bool enabled) async {
    autoLiveListRefresh = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefAutoLive, enabled);
  }

  static Future<void> togglePin(String compKey) async {
    if (pinnedCompetitions.contains(compKey)) {
      pinnedCompetitions.remove(compKey);
    } else {
      pinnedCompetitions.add(compKey);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefPinned, pinnedCompetitions.toList());
  }

  static bool isFavoriteTeam(String teamName) {
    final q = teamName.trim().toLowerCase();
    if (q.isEmpty) return false;
    return favoriteTeams.any((f) => q.contains(f.toLowerCase()) || f.toLowerCase().contains(q));
  }

  static Future<void> toggleFavoriteTeam(String teamName) async {
    final clean = teamName.trim();
    if (clean.isEmpty) return;
    final existsIdx = favoriteTeams.indexWhere((e) => e.toLowerCase() == clean.toLowerCase());
    if (existsIdx >= 0) {
      favoriteTeams.removeAt(existsIdx);
    } else {
      favoriteTeams.insert(0, clean);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefFavTeams, favoriteTeams);
  }

  static Future<void> addRecentSearch(String query) async {
    final clean = query.trim();
    if (clean.length < 2) return;
    recentSearches.removeWhere((e) => e.toLowerCase() == clean.toLowerCase());
    recentSearches.insert(0, clean);
    if (recentSearches.length > 8) {
      recentSearches = recentSearches.take(8).toList();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefRecentSearch, recentSearches);
  }

  static Future<void> clearRecentSearches() async {
    recentSearches.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefRecentSearch);
  }
}

class FetchResult<T> {
  final T data;
  final bool fromCache;
  final DateTime fetchedAt;
  final String? note;

  const FetchResult({
    required this.data,
    required this.fromCache,
    required this.fetchedAt,
    this.note,
  });
}

class MatchEvent {
  final String minute;
  final String type; // 'goal', 'yellow', 'red', 'sub'
  final String player;
  final bool isHome;

  const MatchEvent({
    required this.minute,
    required this.type,
    required this.player,
    required this.isHome,
  });

  int get minuteSortValue {
    final cleaned = minute.replaceAll("'", '').trim();
    if (cleaned.contains('+')) {
      final parts = cleaned.split('+');
      final base = int.tryParse(parts[0]) ?? 0;
      final extra = int.tryParse(parts[1]) ?? 0;
      return base * 10 + extra;
    }
    return (int.tryParse(cleaned) ?? 0) * 10;
  }

  Map<String, dynamic> toJson() => {
        'minute': minute,
        'type': type,
        'player': player,
        'isHome': isHome,
      };

  factory MatchEvent.fromJson(Map<String, dynamic> json) => MatchEvent(
        minute: json['minute']?.toString() ?? '',
        type: json['type']?.toString() ?? 'goal',
        player: json['player']?.toString() ?? '',
        isHome: json['isHome'] == true,
      );
}

class LineupPlayer {
  final String number;
  final String name;
  final String position;

  const LineupPlayer({
    required this.number,
    required this.name,
    required this.position,
  });

  Map<String, dynamic> toJson() => {
        'number': number,
        'name': name,
        'position': position,
      };

  factory LineupPlayer.fromJson(Map<String, dynamic> json) => LineupPlayer(
        number: json['number']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        position: json['position']?.toString() ?? '',
      );
}

class TeamLineup {
  final String formation;
  final List<LineupPlayer> starters;
  final List<LineupPlayer> substitutes;

  const TeamLineup({
    required this.formation,
    required this.starters,
    this.substitutes = const [],
  });

  Map<String, dynamic> toJson() => {
        'formation': formation,
        'starters': starters.map((e) => e.toJson()).toList(),
        'substitutes': substitutes.map((e) => e.toJson()).toList(),
      };

  factory TeamLineup.fromJson(Map<String, dynamic> json) => TeamLineup(
        formation: json['formation']?.toString() ?? '4-3-3',
        starters: ((json['starters'] as List?) ?? const [])
            .map((e) => LineupPlayer.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        substitutes: ((json['substitutes'] as List?) ?? const [])
            .map((e) => LineupPlayer.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

class HighlightClip {
  final String title;
  final String url;

  const HighlightClip({required this.title, required this.url});

  Map<String, dynamic> toJson() => {'title': title, 'url': url};

  factory HighlightClip.fromJson(Map<String, dynamic> json) => HighlightClip(
        title: json['title']?.toString() ?? '',
        url: json['url']?.toString() ?? '',
      );
}

class H2HFixture {
  final String dateLabel;
  final String homeTeam;
  final String awayTeam;
  final String scoreLabel;

  const H2HFixture({
    required this.dateLabel,
    required this.homeTeam,
    required this.awayTeam,
    required this.scoreLabel,
  });

  Map<String, dynamic> toJson() => {
        'dateLabel': dateLabel,
        'homeTeam': homeTeam,
        'awayTeam': awayTeam,
        'scoreLabel': scoreLabel,
      };

  factory H2HFixture.fromJson(Map<String, dynamic> json) => H2HFixture(
        dateLabel: json['dateLabel']?.toString() ?? '',
        homeTeam: json['homeTeam']?.toString() ?? '',
        awayTeam: json['awayTeam']?.toString() ?? '',
        scoreLabel: json['scoreLabel']?.toString() ?? '',
      );
}

class MatchData {
  final String id;
  final String country;
  final String? countryFlagUrl;
  final String league;
  final String homeTeam;
  final String awayTeam;
  final String? homeLogo;
  final String? awayLogo;
  final int homeScore;
  final int awayScore;
  final String status;
  final bool isLive;
  final bool isFinished;
  final Color homeColor;
  final Color awayColor;
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
  final TeamLineup? homeLineup;
  final TeamLineup? awayLineup;
  final List<HighlightClip> highlights;
  final List<String> homeForm;
  final List<String> awayForm;
  final List<H2HFixture> h2hFixtures;
  final bool isFromApi;
  final String? detailNote;

  const MatchData({
    required this.id,
    required this.country,
    this.countryFlagUrl,
    required this.league,
    required this.homeTeam,
    required this.awayTeam,
    this.homeLogo,
    this.awayLogo,
    required this.homeScore,
    required this.awayScore,
    required this.status,
    required this.isLive,
    required this.isFinished,
    required this.homeColor,
    required this.awayColor,
    this.possessionHome = 50,
    this.shotsHome = 0,
    this.shotsAway = 0,
    this.shotsOnTargetHome = 0,
    this.shotsOnTargetAway = 0,
    this.cornersHome = 0,
    this.cornersAway = 0,
    this.foulsHome = 0,
    this.foulsAway = 0,
    this.events = const [],
    this.homeLineup,
    this.awayLineup,
    this.highlights = const [],
    this.homeForm = const [],
    this.awayForm = const [],
    this.h2hFixtures = const [],
    this.isFromApi = false,
    this.detailNote,
  });

  String get fullCompetitionLabel => '$country • $league';

  static int formPoints(List<String> form) {
    var total = 0;
    for (final f in form) {
      if (f == 'GY') total += 3;
      if (f == 'D') total += 1;
    }
    return total;
  }

  String buildShareText() {
    final goals = events
        .where((e) => e.type == 'goal')
        .map((e) => '${e.player} (${e.minute})')
        .join(', ');
    final buf = StringBuffer()
      ..writeln('⚽ $homeTeam $homeScore - $awayScore $awayTeam')
      ..writeln('🏆 $country • $league ($status)');
    if (goals.isNotEmpty) buf.writeln('Gólok: $goals');
    buf.write('— zsoltscores');
    return buf.toString();
  }

  MatchData copyWith({
    int? possessionHome,
    int? shotsHome,
    int? shotsAway,
    int? shotsOnTargetHome,
    int? shotsOnTargetAway,
    int? cornersHome,
    int? cornersAway,
    int? foulsHome,
    int? foulsAway,
    List<MatchEvent>? events,
    TeamLineup? homeLineup,
    TeamLineup? awayLineup,
    List<HighlightClip>? highlights,
    List<String>? homeForm,
    List<String>? awayForm,
    List<H2HFixture>? h2hFixtures,
    String? detailNote,
  }) {
    return MatchData(
      id: id,
      country: country,
      countryFlagUrl: countryFlagUrl,
      league: league,
      homeTeam: homeTeam,
      awayTeam: awayTeam,
      homeLogo: homeLogo,
      awayLogo: awayLogo,
      homeScore: homeScore,
      awayScore: awayScore,
      status: status,
      isLive: isLive,
      isFinished: isFinished,
      homeColor: homeColor,
      awayColor: awayColor,
      possessionHome: possessionHome ?? this.possessionHome,
      shotsHome: shotsHome ?? this.shotsHome,
      shotsAway: shotsAway ?? this.shotsAway,
      shotsOnTargetHome: shotsOnTargetHome ?? this.shotsOnTargetHome,
      shotsOnTargetAway: shotsOnTargetAway ?? this.shotsOnTargetAway,
      cornersHome: cornersHome ?? this.cornersHome,
      cornersAway: cornersAway ?? this.cornersAway,
      foulsHome: foulsHome ?? this.foulsHome,
      foulsAway: foulsAway ?? this.foulsAway,
      events: events ?? this.events,
      homeLineup: homeLineup ?? this.homeLineup,
      awayLineup: awayLineup ?? this.awayLineup,
      highlights: highlights ?? this.highlights,
      homeForm: homeForm ?? this.homeForm,
      awayForm: awayForm ?? this.awayForm,
      h2hFixtures: h2hFixtures ?? this.h2hFixtures,
      isFromApi: isFromApi,
      detailNote: detailNote ?? this.detailNote,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'country': country,
        'countryFlagUrl': countryFlagUrl,
        'league': league,
        'homeTeam': homeTeam,
        'awayTeam': awayTeam,
        'homeLogo': homeLogo,
        'awayLogo': awayLogo,
        'homeScore': homeScore,
        'awayScore': awayScore,
        'status': status,
        'isLive': isLive,
        'isFinished': isFinished,
        'homeColor': homeColor.toARGB32(),
        'awayColor': awayColor.toARGB32(),
        'possessionHome': possessionHome,
        'shotsHome': shotsHome,
        'shotsAway': shotsAway,
        'shotsOnTargetHome': shotsOnTargetHome,
        'shotsOnTargetAway': shotsOnTargetAway,
        'cornersHome': cornersHome,
        'cornersAway': cornersAway,
        'foulsHome': foulsHome,
        'foulsAway': foulsAway,
        'events': events.map((e) => e.toJson()).toList(),
        'homeLineup': homeLineup?.toJson(),
        'awayLineup': awayLineup?.toJson(),
        'highlights': highlights.map((e) => e.toJson()).toList(),
        'homeForm': homeForm,
        'awayForm': awayForm,
        'h2hFixtures': h2hFixtures.map((e) => e.toJson()).toList(),
        'isFromApi': isFromApi,
        'detailNote': detailNote,
      };

  factory MatchData.fromJson(Map<String, dynamic> json) => MatchData(
        id: json['id']?.toString() ?? '',
        country: SportsApiService.localizeCountry(json['country']?.toString() ?? 'Nemzetközi'),
        countryFlagUrl: json['countryFlagUrl']?.toString(),
        league: SportsApiService.localizeLeague(json['league']?.toString() ?? 'Bajnokság'),
        homeTeam: json['homeTeam']?.toString() ?? 'Hazai',
        awayTeam: json['awayTeam']?.toString() ?? 'Vendég',
        homeLogo: json['homeLogo']?.toString(),
        awayLogo: json['awayLogo']?.toString(),
        homeScore: (json['homeScore'] as num?)?.toInt() ?? 0,
        awayScore: (json['awayScore'] as num?)?.toInt() ?? 0,
        status: json['status']?.toString() ?? '',
        isLive: json['isLive'] == true,
        isFinished: json['isFinished'] == true,
        homeColor: Color((json['homeColor'] as num?)?.toInt() ?? 0xFF00E676),
        awayColor: Color((json['awayColor'] as num?)?.toInt() ?? 0xFF00E5FF),
        possessionHome: (json['possessionHome'] as num?)?.toInt() ?? 50,
        shotsHome: (json['shotsHome'] as num?)?.toInt() ?? 0,
        shotsAway: (json['shotsAway'] as num?)?.toInt() ?? 0,
        shotsOnTargetHome: (json['shotsOnTargetHome'] as num?)?.toInt() ?? 0,
        shotsOnTargetAway: (json['shotsOnTargetAway'] as num?)?.toInt() ?? 0,
        cornersHome: (json['cornersHome'] as num?)?.toInt() ?? 0,
        cornersAway: (json['cornersAway'] as num?)?.toInt() ?? 0,
        foulsHome: (json['foulsHome'] as num?)?.toInt() ?? 0,
        foulsAway: (json['foulsAway'] as num?)?.toInt() ?? 0,
        events: ((json['events'] as List?) ?? const [])
            .map((e) => MatchEvent.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        homeLineup: json['homeLineup'] != null
            ? TeamLineup.fromJson(Map<String, dynamic>.from(json['homeLineup'] as Map))
            : null,
        awayLineup: json['awayLineup'] != null
            ? TeamLineup.fromJson(Map<String, dynamic>.from(json['awayLineup'] as Map))
            : null,
        highlights: ((json['highlights'] as List?) ?? const [])
            .map((e) => HighlightClip.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        homeForm: ((json['homeForm'] as List?) ?? const []).map((e) => e.toString()).toList(),
        awayForm: ((json['awayForm'] as List?) ?? const []).map((e) => e.toString()).toList(),
        h2hFixtures: ((json['h2hFixtures'] as List?) ?? const [])
            .map((e) => H2HFixture.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        isFromApi: json['isFromApi'] == true,
        detailNote: json['detailNote']?.toString(),
      );
}

class StandingRow {
  final int pos;
  final String team;
  final String? logo;
  final int played;
  final int won;
  final int drawn;
  final int lost;
  final int gf;
  final int ga;
  final int gd;
  final int points;
  final String zone; // 'ucl', 'uel', 'rel', 'none'
  final Color color;
  final List<String> form;

  const StandingRow({
    required this.pos,
    required this.team,
    this.logo,
    required this.played,
    this.won = 0,
    this.drawn = 0,
    this.lost = 0,
    this.gf = 0,
    this.ga = 0,
    required this.gd,
    required this.points,
    required this.zone,
    required this.color,
    this.form = const [],
  });

  Map<String, dynamic> toJson() => {
        'pos': pos,
        'team': team,
        'logo': logo,
        'played': played,
        'won': won,
        'drawn': drawn,
        'lost': lost,
        'gf': gf,
        'ga': ga,
        'gd': gd,
        'points': points,
        'zone': zone,
        'color': color.toARGB32(),
        'form': form,
      };

  factory StandingRow.fromJson(Map<String, dynamic> json) => StandingRow(
        pos: (json['pos'] as num?)?.toInt() ?? 1,
        team: json['team']?.toString() ?? '',
        logo: json['logo']?.toString(),
        played: (json['played'] as num?)?.toInt() ?? 0,
        won: (json['won'] as num?)?.toInt() ?? 0,
        drawn: (json['drawn'] as num?)?.toInt() ?? 0,
        lost: (json['lost'] as num?)?.toInt() ?? 0,
        gf: (json['gf'] as num?)?.toInt() ?? 0,
        ga: (json['ga'] as num?)?.toInt() ?? 0,
        gd: (json['gd'] as num?)?.toInt() ?? 0,
        points: (json['points'] as num?)?.toInt() ?? 0,
        zone: json['zone']?.toString() ?? 'none',
        color: Color((json['color'] as num?)?.toInt() ?? 0xFF00E676),
        form: ((json['form'] as List?) ?? const []).map((e) => e.toString()).toList(),
      );
}

class TopScorerRow {
  final int rank;
  final String player;
  final String team;
  final int goals;
  final int assists;

  const TopScorerRow({
    required this.rank,
    required this.player,
    required this.team,
    required this.goals,
    required this.assists,
  });
}

const List<MatchData> sampleMatches = [
  MatchData(
    id: 'm1',
    country: 'Európa',
    league: 'Bajnokok Ligája',
    homeTeam: 'Real Madrid',
    awayTeam: 'Liverpool',
    homeScore: 2,
    awayScore: 2,
    status: "74'",
    isLive: true,
    isFinished: false,
    homeColor: Color(0xFF7E57C2),
    awayColor: Color(0xFFEF5350),
    possessionHome: 54,
    shotsHome: 14,
    shotsAway: 11,
    shotsOnTargetHome: 6,
    shotsOnTargetAway: 5,
    cornersHome: 7,
    cornersAway: 4,
    foulsHome: 8,
    foulsAway: 10,
    homeForm: ['GY', 'GY', 'D', 'GY', 'GY'],
    awayForm: ['GY', 'GY', 'GY', 'D', 'GY'],
    events: [
      MatchEvent(minute: "12'", type: 'goal', player: 'Vinícius Júnior', isHome: true),
      MatchEvent(minute: "28'", type: 'goal', player: 'Mohamed Salah', isHome: false),
      MatchEvent(minute: "51'", type: 'goal', player: 'Jude Bellingham', isHome: true),
      MatchEvent(minute: "67'", type: 'goal', player: 'Luis Díaz', isHome: false),
      MatchEvent(minute: "71'", type: 'yellow', player: 'Aurélien Tchouaméni', isHome: true),
    ],
    homeLineup: TeamLineup(
      formation: '4-3-3',
      starters: [
        LineupPlayer(number: '1', name: 'Thibaut Courtois', position: 'GK'),
        LineupPlayer(number: '2', name: 'Dani Carvajal', position: 'RB'),
        LineupPlayer(number: '22', name: 'Antonio Rüdiger', position: 'CB'),
        LineupPlayer(number: '4', name: 'David Alaba', position: 'CB'),
        LineupPlayer(number: '23', name: 'Ferland Mendy', position: 'LB'),
        LineupPlayer(number: '8', name: 'Federico Valverde', position: 'CM'),
        LineupPlayer(number: '18', name: 'Aurélien Tchouaméni', position: 'CDM'),
        LineupPlayer(number: '5', name: 'Jude Bellingham', position: 'CAM'),
        LineupPlayer(number: '11', name: 'Rodrygo', position: 'RW'),
        LineupPlayer(number: '9', name: 'Kylian Mbappé', position: 'ST'),
        LineupPlayer(number: '7', name: 'Vinícius Júnior', position: 'LW'),
      ],
      substitutes: [
        LineupPlayer(number: '10', name: 'Luka Modrić', position: 'CM'),
        LineupPlayer(number: '21', name: 'Brahim Díaz', position: 'RW'),
      ],
    ),
    awayLineup: TeamLineup(
      formation: '4-3-3',
      starters: [
        LineupPlayer(number: '1', name: 'Alisson Becker', position: 'GK'),
        LineupPlayer(number: '66', name: 'Trent Alexander-Arnold', position: 'RB'),
        LineupPlayer(number: '5', name: 'Ibrahima Konaté', position: 'CB'),
        LineupPlayer(number: '4', name: 'Virgil van Dijk', position: 'CB'),
        LineupPlayer(number: '26', name: 'Andrew Robertson', position: 'LB'),
        LineupPlayer(number: '38', name: 'Ryan Gravenberch', position: 'CDM'),
        LineupPlayer(number: '10', name: 'Alexis Mac Allister', position: 'CM'),
        LineupPlayer(number: '8', name: 'Dominik Szoboszlai', position: 'CAM'),
        LineupPlayer(number: '11', name: 'Mohamed Salah', position: 'RW'),
        LineupPlayer(number: '9', name: 'Darwin Núñez', position: 'ST'),
        LineupPlayer(number: '7', name: 'Luis Díaz', position: 'LW'),
      ],
      substitutes: [
        LineupPlayer(number: '17', name: 'Curtis Jones', position: 'CM'),
        LineupPlayer(number: '20', name: 'Diogo Jota', position: 'ST'),
      ],
    ),
    h2hFixtures: [
      H2HFixture(dateLabel: '2024.11', homeTeam: 'Liverpool', awayTeam: 'Real Madrid', scoreLabel: '2 - 0'),
      H2HFixture(dateLabel: '2023.03', homeTeam: 'Real Madrid', awayTeam: 'Liverpool', scoreLabel: '1 - 0'),
      H2HFixture(dateLabel: '2023.02', homeTeam: 'Liverpool', awayTeam: 'Real Madrid', scoreLabel: '2 - 5'),
    ],
  ),
  MatchData(
    id: 'm2',
    country: 'Anglia',
    league: 'Premier League',
    homeTeam: 'Arsenal',
    awayTeam: 'Manchester City',
    homeScore: 1,
    awayScore: 0,
    status: "38'",
    isLive: true,
    isFinished: false,
    homeColor: Color(0xFFE53935),
    awayColor: Color(0xFF29B6F6),
    possessionHome: 48,
    shotsHome: 7,
    shotsAway: 9,
    shotsOnTargetHome: 3,
    shotsOnTargetAway: 2,
    cornersHome: 4,
    cornersAway: 5,
    foulsHome: 6,
    foulsAway: 7,
    homeForm: ['GY', 'GY', 'GY', 'D', 'GY'],
    awayForm: ['GY', 'V', 'GY', 'GY', 'D'],
    events: [
      MatchEvent(minute: "23'", type: 'goal', player: 'Bukayo Saka', isHome: true),
    ],
  ),
  MatchData(
    id: 'm3',
    country: 'Magyarország',
    league: 'NB I',
    homeTeam: 'Ferencváros',
    awayTeam: 'Újpest',
    homeScore: 3,
    awayScore: 1,
    status: 'VÉGE',
    isLive: false,
    isFinished: true,
    homeColor: Color(0xFF00E676),
    awayColor: Color(0xFFAB47BC),
    possessionHome: 61,
    shotsHome: 18,
    shotsAway: 6,
    shotsOnTargetHome: 9,
    shotsOnTargetAway: 3,
    cornersHome: 8,
    cornersAway: 2,
    foulsHome: 9,
    foulsAway: 13,
    homeForm: ['GY', 'GY', 'GY', 'GY', 'D'],
    awayForm: ['V', 'D', 'V', 'GY', 'V'],
    events: [
      MatchEvent(minute: "14'", type: 'goal', player: 'Barnabás Varga', isHome: true),
      MatchEvent(minute: "39'", type: 'goal', player: 'Kristoffer Zachariassen', isHome: true),
      MatchEvent(minute: "62'", type: 'goal', player: 'Fran Brodić', isHome: false),
      MatchEvent(minute: "84'", type: 'goal', player: 'Adama Traoré', isHome: true),
    ],
  ),
];

final Map<String, List<StandingRow>> sampleStandings = {
  'Premier League': [
    const StandingRow(pos: 1, team: 'Arsenal', played: 12, won: 9, drawn: 2, lost: 1, gf: 26, ga: 9, gd: 17, points: 29, zone: 'ucl', color: Color(0xFFE53935), form: ['GY', 'GY', 'GY', 'D', 'GY']),
    const StandingRow(pos: 2, team: 'Liverpool', played: 12, won: 9, drawn: 1, lost: 2, gf: 25, ga: 10, gd: 15, points: 28, zone: 'ucl', color: Color(0xFFEF5350), form: ['GY', 'GY', 'GY', 'D', 'GY']),
    const StandingRow(pos: 3, team: 'Manchester City', played: 12, won: 8, drawn: 2, lost: 2, gf: 24, ga: 12, gd: 12, points: 26, zone: 'ucl', color: Color(0xFF29B6F6), form: ['GY', 'V', 'GY', 'GY', 'D']),
    const StandingRow(pos: 4, team: 'Chelsea', played: 12, won: 7, drawn: 3, lost: 2, gf: 22, ga: 13, gd: 9, points: 24, zone: 'ucl', color: Color(0xFF3B82F6), form: ['GY', 'D', 'GY', 'GY', 'V']),
    const StandingRow(pos: 5, team: 'Newcastle', played: 12, won: 6, drawn: 3, lost: 3, gf: 18, ga: 14, gd: 4, points: 21, zone: 'uel', color: Color(0xFF64748B), form: ['D', 'GY', 'V', 'GY', 'D']),
    const StandingRow(pos: 18, team: 'Southampton', played: 12, won: 1, drawn: 2, lost: 9, gf: 8, ga: 26, gd: -18, points: 5, zone: 'rel', color: Color(0xFFDC2626), form: ['V', 'V', 'D', 'V', 'V']),
  ],
  'NB I': [
    const StandingRow(pos: 1, team: 'Ferencváros', played: 13, won: 10, drawn: 2, lost: 1, gf: 31, ga: 10, gd: 21, points: 32, zone: 'ucl', color: Color(0xFF00E676), form: ['GY', 'GY', 'GY', 'GY', 'D']),
    const StandingRow(pos: 2, team: 'Puskás Akadémia', played: 13, won: 9, drawn: 2, lost: 2, gf: 24, ga: 12, gd: 12, points: 29, zone: 'uel', color: Color(0xFF0284C7), form: ['GY', 'D', 'GY', 'GY', 'V']),
    const StandingRow(pos: 3, team: 'Paks', played: 13, won: 7, drawn: 3, lost: 3, gf: 22, ga: 16, gd: 6, points: 24, zone: 'uel', color: Color(0xFF16A34A), form: ['GY', 'GY', 'V', 'D', 'GY']),
    const StandingRow(pos: 11, team: 'Kecskemét', played: 13, won: 2, drawn: 4, lost: 7, gf: 11, ga: 21, gd: -10, points: 10, zone: 'rel', color: Color(0xFFDC2626), form: ['V', 'D', 'V', 'V', 'D']),
  ],
};

final Map<String, List<TopScorerRow>> sampleTopScorers = {
  'Premier League': const [
    TopScorerRow(rank: 1, player: 'Erling Haaland', team: 'Manchester City', goals: 12, assists: 2),
    TopScorerRow(rank: 2, player: 'Mohamed Salah', team: 'Liverpool', goals: 10, assists: 6),
    TopScorerRow(rank: 3, player: 'Bukayo Saka', team: 'Arsenal', goals: 8, assists: 7),
  ],
  'NB I': const [
    TopScorerRow(rank: 1, player: 'Barnabás Varga', team: 'Ferencváros', goals: 11, assists: 3),
    TopScorerRow(rank: 2, player: 'Jonathan Levi', team: 'Puskás Akadémia', goals: 7, assists: 4),
  ],
};

class SportsApiService {
  SportsApiService._();

  /// StatPal Soccer API V2 base URL (csak v2)
  static const String _statpalBaseUrl = 'https://statpal.io/api/v2/soccer';

  /// StatPal V2 liga azonosítók (fallback; a /leagues végpont felülírhatja)
  static const Map<String, String> statpalLeagueIds = {
    'Premier League': '1007',
    'La Liga': '1397',
    'Serie A': '1283',
    'Bundesliga': '1229',
    'Ligue 1': '1221',
    'NB I': '1563',
    'Bajnokok Ligája': '1075',
    'Championship': '3038',
  };

  static final Map<String, String> _resolvedLeagueIds = {};

  static Map<String, String> get statpalLeagueSlugs => {
        ...statpalLeagueIds,
        ..._resolvedLeagueIds,
      };

  static String teamLogoUrl(String teamId) {
    final key = ApiConfig.activeKey;
    if (teamId.isEmpty || key.isEmpty) return '';
    return '$_statpalBaseUrl/images?type=team&id=$teamId&access_key=$key';
  }

  static String? countryFlagCdnUrl(String countryHu) {
    const codes = {
      'Anglia': 'gb-eng',
      'Spanyolország': 'es',
      'Olaszország': 'it',
      'Németország': 'de',
      'Franciaország': 'fr',
      'Magyarország': 'hu',
      'Portugália': 'pt',
      'Hollandia': 'nl',
      'Belgium': 'be',
      'Skócia': 'gb-sct',
      'Törökország': 'tr',
      'Görögország': 'gr',
      'Ausztria': 'at',
      'Svájc': 'ch',
      'Lengyelország': 'pl',
      'Csehország': 'cz',
      'Szlovákia': 'sk',
      'Románia': 'ro',
      'Szerbia': 'rs',
      'Horvátország': 'hr',
      'Szlovénia': 'si',
      'Bulgária': 'bg',
      'Ukrajna': 'ua',
      'Dánia': 'dk',
      'Svédország': 'se',
      'Norvégia': 'no',
      'Finnország': 'fi',
      'Írország': 'ie',
      'Wales': 'gb-wls',
      'Brazília': 'br',
      'Argentína': 'ar',
      'Mexikó': 'mx',
      'USA': 'us',
      'Japán': 'jp',
      'Dél-Korea': 'kr',
      'Ausztrália': 'au',
      'Egyiptom': 'eg',
      'Marokkó': 'ma',
      'Európa': 'eu',
    };
    final code = codes[countryHu];
    if (code == null) return null;
    return 'https://flagcdn.com/w40/$code.png';
  }

  /// Országnevek angol → magyar
  static const Map<String, String> _countryHu = {
    'england': 'Anglia',
    'spain': 'Spanyolország',
    'italy': 'Olaszország',
    'germany': 'Németország',
    'france': 'Franciaország',
    'hungary': 'Magyarország',
    'portugal': 'Portugália',
    'netherlands': 'Hollandia',
    'holland': 'Hollandia',
    'belgium': 'Belgium',
    'scotland': 'Skócia',
    'turkey': 'Törökország',
    'greece': 'Görögország',
    'austria': 'Ausztria',
    'switzerland': 'Svájc',
    'poland': 'Lengyelország',
    'czech': 'Csehország',
    'czechia': 'Csehország',
    'slovakia': 'Szlovákia',
    'romania': 'Románia',
    'serbia': 'Szerbia',
    'croatia': 'Horvátország',
    'slovenia': 'Szlovénia',
    'bulgaria': 'Bulgária',
    'ukraine': 'Ukrajna',
    'russia': 'Oroszország',
    'denmark': 'Dánia',
    'sweden': 'Svédország',
    'norway': 'Norvégia',
    'finland': 'Finnország',
    'ireland': 'Írország',
    'wales': 'Wales',
    'northern ireland': 'Észak-Írország',
    'bosnia': 'Bosznia-Hercegovina',
    'bosnia and herzegovina': 'Bosznia-Hercegovina',
    'albania': 'Albánia',
    'north macedonia': 'Észak-Macedónia',
    'macedonia': 'Észak-Macedónia',
    'montenegro': 'Montenegró',
    'kosovo': 'Koszovó',
    'cyprus': 'Ciprus',
    'malta': 'Málta',
    'iceland': 'Izland',
    'israel': 'Izrael',
    'brazil': 'Brazília',
    'argentina': 'Argentína',
    'uruguay': 'Uruguay',
    'chile': 'Chile',
    'colombia': 'Kolumbia',
    'mexico': 'Mexikó',
    'usa': 'USA',
    'united states': 'USA',
    'canada': 'Kanada',
    'japan': 'Japán',
    'south korea': 'Dél-Korea',
    'korea': 'Dél-Korea',
    'china': 'Kína',
    'australia': 'Ausztrália',
    'saudi arabia': 'Szaúd-Arábia',
    'qatar': 'Katar',
    'uae': 'Egyesült Arab Emírségek',
    'egypt': 'Egyiptom',
    'morocco': 'Marokkó',
    'tunisia': 'Tunézia',
    'algeria': 'Algéria',
    'nigeria': 'Nigéria',
    'south africa': 'Dél-Afrika',
    'ghana': 'Ghána',
    'cameroon': 'Kamerun',
    'senegal': 'Szenegál',
    'ivory coast': 'Elefántcsontpart',
    'africa': 'Afrika',
    'asia': 'Ázsia',
    'europe': 'Európa',
    'world': 'Világ',
    'international': 'Nemzetközi',
    'concacaf': 'CONCACAF',
    'conmebol': 'CONMEBOL',
    'uefa': 'UEFA',
    'afc': 'Ázsia',
    'caf': 'Afrika',
  };

  /// Gyakori bajnokságnevek angol → magyar
  static const Map<String, String> _leagueHu = {
    'premier league': 'Premier League',
    'la liga': 'La Liga',
    'primera division': 'La Liga',
    'serie a': 'Serie A',
    'bundesliga': 'Bundesliga',
    'ligue 1': 'Ligue 1',
    'eredivisie': 'Eredivisie',
    'primeira liga': 'Primeira Liga',
    'liga portugal': 'Primeira Liga',
    'super lig': 'Süper Lig',
    'süper lig': 'Süper Lig',
    'championship': 'Championship',
    'league one': 'League One',
    'league two': 'League Two',
    'fa cup': 'FA-kupa',
    'efl cup': 'EFL-kupa',
    'carabao cup': 'EFL-kupa',
    'community shield': 'Community Shield',
    'copa del rey': 'Király-kupa',
    'supercopa': 'Spanyol Szuperkupa',
    'coppa italia': 'Olasz Kupa',
    'dfb pokal': 'Német Kupa',
    'coupe de france': 'Francia Kupa',
    'taca de portugal': 'Portugál Kupa',
    'nb i': 'NB I',
    'nb 1': 'NB I',
    'otp bank liga': 'NB I',
    'magyar kupa': 'Magyar Kupa',
    'uefa champions league': 'Bajnokok Ligája',
    'champions league': 'Bajnokok Ligája',
    'uefa europa league': 'Európa-liga',
    'europa league': 'Európa-liga',
    'uefa europa conference league': 'Konferencia-liga',
    'conference league': 'Konferencia-liga',
    'uefa super cup': 'UEFA-szuperkupa',
    'fifa club world cup': 'Klubvilágbajnokság',
    'club world cup': 'Klubvilágbajnokság',
    'world cup': 'Világbajnokság',
    'euro': 'Európa-bajnokság',
    'european championship': 'Európa-bajnokság',
    'nations league': 'Nemzetek Ligája',
    'uefa nations league': 'Nemzetek Ligája',
    'copa america': 'Copa América',
    'africa cup of nations': 'Afrikai Nemzetek Kupája',
    'afcon': 'Afrikai Nemzetek Kupája',
    'asian cup': 'Ázsia-kupa',
    'gold cup': 'CONCACAF Gold Cup',
    'friendlies': 'Barátságos',
    'friendly': 'Barátságos',
    'international friendly': 'Barátságos',
    'women': 'Női',
    'u21': 'U21',
    'u20': 'U20',
    'u19': 'U19',
    'u17': 'U17',
  };

  /// Országnév magyarítása
  static String localizeCountry(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return 'Nemzetközi';
    final key = t.toLowerCase();
    if (_countryHu.containsKey(key)) return _countryHu[key]!;
    // "England - Premier League" jellegű
    final dash = key.split(RegExp(r'\s*[-–:]\s*')).first.trim();
    if (_countryHu.containsKey(dash)) return _countryHu[dash]!;
    // Már magyar / ismert
    if (t.contains(RegExp(r'[áéíóöőúüűÁÉÍÓÖŐÚÜŰ]'))) return t;
    // Title case megőrzése ha nincs fordítás
    return t
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  /// Bajnokságnév magyarítása + "Country: League" szétválasztás
  static String localizeLeague(String raw, {String? countryHint}) {
    var t = raw.trim();
    if (t.isEmpty) return 'Bajnokság';

    // "England: Premier League" / "Africa: Africa Cup Of Nations"
    if (t.contains(':')) {
      final parts = t.split(':');
      if (parts.length >= 2) {
        final after = parts.sublist(1).join(':').trim();
        if (after.isNotEmpty) t = after;
      }
    }

    final key = t.toLowerCase();
    if (_leagueHu.containsKey(key)) return _leagueHu[key]!;

    // Részleges egyezés (pl. "Premier League - Round 12")
    for (final e in _leagueHu.entries) {
      if (key.contains(e.key)) {
        return e.value;
      }
    }

    // Ha a liga neve megegyezik az ország hinttel, ne ismételjük
    if (countryHint != null && t.toLowerCase() == countryHint.toLowerCase()) {
      return 'Bajnokság';
    }

    return t;
  }

  /// Ország + liga kinyerése egy API liga objektumból / névből
  static ({String country, String league}) localizeCompetition({
    String? countryRaw,
    String? leagueRaw,
    String? fallbackLeague,
  }) {
    var country = (countryRaw ?? '').trim();
    var league = (leagueRaw ?? fallbackLeague ?? '').trim();

    // Ha a liga "Country: League" formátumú és nincs külön country
    if (country.isEmpty && league.contains(':')) {
      final parts = league.split(':');
      country = parts.first.trim();
      league = parts.sublist(1).join(':').trim();
    }

    final huCountry = localizeCountry(country.isEmpty ? 'international' : country);
    final huLeague = localizeLeague(league, countryHint: huCountry);
    return (country: huCountry, league: huLeague);
  }

  static String formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Aktuális szezon címke (pl. 2025-2026)
  static String _currentSeasonLabel() {
    final now = DateTime.now();
    final startYear = now.month >= 7 ? now.year : now.year - 1;
    return '$startYear-${startYear + 1}';
  }

  /// Liga ID-k feloldása a V2 /leagues listából (név egyezés)
  static Future<void> _ensureLeagueIdsResolved() async {
    if (_resolvedLeagueIds.isNotEmpty || !ApiConfig.hasValidKey) return;
    try {
      await ApiCache.recordNetworkRequest();
      final uri = Uri.parse('$_statpalBaseUrl/leagues?access_key=${ApiConfig.activeKey}');
      final res = await http.get(uri).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return;
      final decoded = jsonDecode(res.body);
      final root = decoded is Map ? (decoded['leagues'] ?? decoded) : decoded;
      final list = root is Map && root['league'] != null
          ? (root['league'] is List ? root['league'] as List : [root['league']])
          : (root is List ? root : const []);
      for (final item in list) {
        if (item is! Map) continue;
        final id = (item['id'] ?? '').toString();
        final name = (item['name'] ?? '').toString();
        if (id.isEmpty || name.isEmpty) continue;
        final lower = name.toLowerCase();
        for (final wanted in statpalLeagueIds.keys) {
          final w = wanted.toLowerCase();
          if (lower == w || lower.contains(w) || w.contains(lower)) {
            _resolvedLeagueIds[wanted] = id;
          }
        }
        // gyakori aliasok
        if (lower.contains('premier league') && lower.contains('england')) {
          _resolvedLeagueIds['Premier League'] = id;
        } else if (lower.contains('la liga') || lower.contains('primera division')) {
          _resolvedLeagueIds['La Liga'] = id;
        } else if (lower.contains('serie a') && lower.contains('italy')) {
          _resolvedLeagueIds['Serie A'] = id;
        } else if (lower == 'bundesliga' || lower.contains('bundesliga 1')) {
          _resolvedLeagueIds['Bundesliga'] = id;
        } else if (lower.contains('ligue 1')) {
          _resolvedLeagueIds['Ligue 1'] = id;
        } else if (lower.contains('nb i') || lower.contains('otp bank liga') || lower.contains('hungary')) {
          if (lower.contains('nb') || lower.contains('otp') || lower.contains('magyar')) {
            _resolvedLeagueIds['NB I'] = id;
          }
        } else if (lower.contains('champions league')) {
          _resolvedLeagueIds['Bajnokok Ligája'] = id;
        }
      }
    } catch (_) {}
  }

  static String formatClock(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static Color colorFromName(String raw) {
    final hash = raw.toLowerCase().codeUnits.fold<int>(0, (acc, c) => (acc * 31 + c) & 0x7fffffff);
    const palette = [
      Color(0xFF00E676),
      Color(0xFF00E5FF),
      Color(0xFFFFCA28),
      Color(0xFF38BDF8),
      Color(0xFFF472B6),
      Color(0xFFA78BFA),
      Color(0xFFFB923C),
      Color(0xFF34D399),
    ];
    return palette[hash % palette.length];
  }

  static Future<String> fetchStatPalDailyUsage(String rawKey) async {
    final key = rawKey.trim().isNotEmpty ? rawKey.trim() : ApiConfig.activeKey;
    if (key.isEmpty) return 'Add meg a StatPal kulcsot az ellenőrzéshez.';

    try {
      // V2 hivatalos live endpoint
      final uri = Uri.parse('$_statpalBaseUrl/matches/live?access_key=$key');
      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final rem = res.headers['x-ratelimit-remaining'] ?? res.headers['ratelimit-remaining'];
        final lim = res.headers['x-ratelimit-limit'] ?? res.headers['ratelimit-limit'];
        if (rem != null && lim != null) {
          return 'Kapcsolat OK ✓ • Hátralévő keret: $rem / $lim kérés';
        }
        final decoded = jsonDecode(res.body);
        final list = _extractMatchesFromStatPal(decoded);
        return 'StatPal V2 kapcsolat aktív ✓ (${list.length} élő meccs)';
      }
      if (res.statusCode == 401 || res.statusCode == 403) {
        return 'Érvénytelen StatPal access_key (HTTP ${res.statusCode})';
      }
      return 'StatPal válasz: HTTP ${res.statusCode}';
    } catch (e) {
      return 'Kapcsolati hiba: $e';
    }
  }

  static Future<FetchResult<List<MatchData>>> fetchMatches(
    DateTime date, {
    bool forceRefresh = false,
  }) async {
    final dateStr = formatDate(date);
    final todayStr = formatDate(DateTime.now());
    final isToday = dateStr == todayStr;
    final cacheKey = 'sp_matches_$dateStr';
    final now = DateTime.now();

    if (!forceRefresh) {
      final cached = await ApiCache.get(cacheKey, customTtlMinutes: isToday ? 1 : ApiCache.cacheMinutes);
      if (cached is List) {
        final list = cached
            .map((e) => MatchData.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        return FetchResult(data: list, fromCache: true, fetchedAt: now);
      }
    }

    if (!ApiConfig.hasValidKey) {
      throw Exception('Hiányzó StatPal API kulcs');
    }

    final key = ApiConfig.activeKey;
    final collected = <String, MatchData>{};

    // Napi offset a mai naphoz képest (−7 … +7) — hivatalos V2 matches/daily
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final target = DateTime(date.year, date.month, date.day);
    final offset = target.difference(today).inDays.clamp(-7, 7);

    await ApiCache.recordNetworkRequest();
    final dailyUri = Uri.parse('$_statpalBaseUrl/matches/daily?offset=$offset&access_key=$key');
    final dailyRes = await http.get(dailyUri).timeout(const Duration(seconds: 20));
    if (dailyRes.statusCode == 200) {
      final decoded = jsonDecode(dailyRes.body);
      for (final m in _extractMatchesFromStatPal(decoded, filterDate: dateStr)) {
        collected[m.id] = m;
      }
    } else if (dailyRes.statusCode == 401 || dailyRes.statusCode == 403) {
      throw Exception('Érvénytelen StatPal access_key (HTTP ${dailyRes.statusCode})');
    }

    // Mai nap: élő lista kiegészítés
    if (isToday) {
      try {
        await ApiCache.recordNetworkRequest();
        final liveUri = Uri.parse('$_statpalBaseUrl/matches/live?access_key=$key');
        final liveRes = await http.get(liveUri).timeout(const Duration(seconds: 15));
        if (liveRes.statusCode == 200) {
          final decoded = jsonDecode(liveRes.body);
          for (final m in _extractMatchesFromStatPal(decoded)) {
            collected[m.id] = m;
          }
        }
      } catch (_) {}
    }

    final parsed = collected.values.toList();
    await ApiCache.set(cacheKey, parsed.map((m) => m.toJson()).toList());
    return FetchResult(data: parsed, fromCache: false, fetchedAt: now);
  }

  static Future<FetchResult<MatchData>> enrichMatchDetails(
    MatchData match, {
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();
    if (!match.isFromApi || !ApiConfig.hasValidKey) {
      return FetchResult(data: match, fromCache: false, fetchedAt: now);
    }

    final cacheKey = 'sp_detail_${match.id}';
    if (!forceRefresh) {
      final cached = await ApiCache.get(cacheKey, customTtlMinutes: 2);
      if (cached is Map) {
        final enriched = _applyDetailPayload(match, Map<String, dynamic>.from(cached));
        return FetchResult(data: enriched, fromCache: true, fetchedAt: now);
      }
    }

    try {
      await ApiCache.recordNetworkRequest();
      final uri = Uri.parse('$_statpalBaseUrl/match/${match.id}?access_key=${ApiConfig.activeKey}');
      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final detailMap = decoded is Map<String, dynamic>
            ? (decoded['data'] is Map<String, dynamic>
                ? Map<String, dynamic>.from(decoded['data'] as Map)
                : decoded)
            : <String, dynamic>{};
        await ApiCache.set(cacheKey, detailMap);
        final enriched = _applyDetailPayload(match, detailMap);
        return FetchResult(data: enriched, fromCache: false, fetchedAt: now);
      }
    } catch (_) {}

    return FetchResult(data: match, fromCache: false, fetchedAt: now);
  }

  static Future<FetchResult<List<StandingRow>>> fetchStandings(
    String leagueName, {
    String venueFilter = 'all',
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();
    final leagueId = statpalLeagueIds[leagueName] ?? '152';
    final cacheKey = 'sp_standings_${leagueId}_$venueFilter';

    if (!forceRefresh) {
      final cached = await ApiCache.get(cacheKey, customTtlMinutes: 15);
      if (cached is List) {
        final rows = cached
            .map((e) => StandingRow.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        return FetchResult(data: rows, fromCache: true, fetchedAt: now);
      }
    }

    if (!ApiConfig.hasValidKey) {
      final sample = sampleStandings[leagueName] ?? sampleStandings['Premier League'] ?? const [];
      return FetchResult(data: sample, fromCache: false, fetchedAt: now);
    }

    await _ensureLeagueIdsResolved();
    final resolvedId = _resolvedLeagueIds[leagueName] ??
        statpalLeagueIds[leagueName] ??
        leagueId;

    await ApiCache.recordNetworkRequest();
    // V2: /leagues/{id}/standings (+ aktuális szezon)
    final season = _currentSeasonLabel();
    final uri = Uri.parse(
      '$_statpalBaseUrl/leagues/$resolvedId/standings?season=$season&access_key=${ApiConfig.activeKey}',
    );
    var res = await http.get(uri).timeout(const Duration(seconds: 15));

    // Szezon paraméter nélkül újra, ha 4xx/5xx
    if (res.statusCode != 200) {
      await ApiCache.recordNetworkRequest();
      final uri2 = Uri.parse(
        '$_statpalBaseUrl/leagues/$resolvedId/standings?access_key=${ApiConfig.activeKey}',
      );
      res = await http.get(uri2).timeout(const Duration(seconds: 15));
    }

    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}');
    }

    final decoded = jsonDecode(res.body);
    final rawRows = _extractStandingsRows(decoded);
    final rows = <StandingRow>[];
    for (var i = 0; i < rawRows.length; i++) {
      final m = rawRows[i];
      final teamName = (m['name'] ?? m['team_name'] ?? m['team'] ?? 'Csapat').toString();
      final pos = int.tryParse((m['position'] ?? m['rank'] ?? m['pos'] ?? '${i + 1}').toString()) ?? (i + 1);

      final overall = m['overall'] is Map ? Map<String, dynamic>.from(m['overall'] as Map) : m;
      final scope = venueFilter == 'home' && m['home'] is Map
          ? Map<String, dynamic>.from(m['home'] as Map)
          : (venueFilter == 'away' && m['away'] is Map
              ? Map<String, dynamic>.from(m['away'] as Map)
              : overall);

      final played = int.tryParse((scope['games_played'] ?? scope['gp'] ?? scope['played'] ?? scope['matches_played'] ?? '0').toString()) ?? 0;
      final won = int.tryParse((scope['wins'] ?? scope['w'] ?? scope['won'] ?? '0').toString()) ?? 0;
      final drawn = int.tryParse((scope['draws'] ?? scope['d'] ?? scope['drawn'] ?? '0').toString()) ?? 0;
      final lost = int.tryParse((scope['losses'] ?? scope['l'] ?? scope['lost'] ?? '0').toString()) ?? 0;
      final gf = int.tryParse((scope['goals_scored'] ?? scope['gs'] ?? scope['goals_for'] ?? scope['gf'] ?? '0').toString()) ?? 0;
      final ga = int.tryParse((scope['goals_allowed'] ?? scope['ga'] ?? scope['goals_against'] ?? '0').toString()) ?? 0;
      final totalMap = m['total'] is Map ? Map<String, dynamic>.from(m['total'] as Map) : <String, dynamic>{};
      final gd = int.tryParse((totalMap['goal_difference'] ?? m['gd'] ?? m['goal_difference'] ?? '${gf - ga}').toString()) ?? (gf - ga);
      final points = int.tryParse((totalMap['points'] ?? totalMap['p'] ?? scope['p'] ?? m['points'] ?? m['pts'] ?? '0').toString()) ?? 0;

      String zone = 'none';
      if (pos <= 4) {
        zone = 'ucl';
      } else if (pos <= 6) {
        zone = 'uel';
      } else if (rawRows.length >= 10 && pos > rawRows.length - 3) {
        zone = 'rel';
      }

      rows.add(StandingRow(
        pos: pos,
        team: teamName,
        logo: () {
          final existing = m['logo']?.toString();
          if (existing != null && existing.startsWith('http')) return existing;
          final tid = (m['id'] ?? m['team_id'] ?? '').toString();
          return tid.isNotEmpty ? teamLogoUrl(tid) : existing;
        }(),
        played: played,
        won: won,
        drawn: drawn,
        lost: lost,
        gf: gf,
        ga: ga,
        gd: gd,
        points: points,
        zone: zone,
        color: colorFromName(teamName),
      ));
    }

    await ApiCache.set(cacheKey, rows.map((r) => r.toJson()).toList());
    return FetchResult(data: rows, fromCache: false, fetchedAt: now);
  }

  static List<MatchData> _extractMatchesFromStatPal(
    dynamic decoded, {
    String? filterDate,
    String? fallbackLeague,
  }) {
    final out = <MatchData>[];
    if (decoded is! Map<String, dynamic>) return out;

    dynamic root = decoded['live_matches'] ??
        decoded['livescores'] ??
        decoded['livescore'] ??
        decoded['fixtures'] ??
        decoded['data'];
    // matches/daily válasz: matches_DD_MM_YYYY
    if (root == null) {
      for (final e in decoded.entries) {
        final k = e.key.toString();
        if (k.startsWith('matches_') || k.startsWith('match_')) {
          root = e.value;
          break;
        }
      }
    }
    root ??= decoded;
    if (root is Map<String, dynamic> && root['league'] != null) {
      final leaguesRaw = root['league'] is List ? root['league'] as List : [root['league']];
      for (final lg in leaguesRaw) {
        if (lg is! Map) continue;
        final lgMap = Map<String, dynamic>.from(lg);
        final localized = localizeCompetition(
          countryRaw: lgMap['country']?.toString(),
          leagueRaw: (lgMap['name'] ?? fallbackLeague)?.toString(),
          fallbackLeague: fallbackLeague,
        );
        final matchesRaw = lgMap['match'] is List
            ? lgMap['match'] as List
            : (lgMap['match'] != null ? [lgMap['match']] : const []);
        for (final item in matchesRaw) {
          if (item is Map) {
            final mm = Map<String, dynamic>.from(item);
            if (filterDate != null) {
              final mDate = (mm['date'] ?? mm['formatted_date'] ?? '').toString();
              if (mDate.isNotEmpty && !mDate.contains(filterDate) && !_matchesNormalizedDate(mDate, filterDate)) {
                continue;
              }
            }
            out.add(_parseStatPalMatch(
              mm,
              countryOverride: localized.country,
              leagueOverride: localized.league,
            ));
          }
        }
      }
      return out;
    }

    if (root is List) {
      for (final item in root) {
        if (item is Map) {
          out.add(_parseStatPalMatch(Map<String, dynamic>.from(item), leagueOverride: fallbackLeague));
        }
      }
    }
    return out;
  }

  static bool _matchesNormalizedDate(String rawDate, String isoDate) {
    final parts = rawDate.split('.');
    if (parts.length == 3) {
      final normalized = '${parts[2].padLeft(4, '0')}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
      return normalized == isoDate;
    }
    return false;
  }

  static List<Map<String, dynamic>> _extractStandingsRows(dynamic decoded) {
    final rows = <Map<String, dynamic>>[];
    if (decoded is! Map<String, dynamic>) return rows;
    final root = decoded['standings'] ?? decoded['data'] ?? decoded;

    void addTeams(dynamic teamsRaw) {
      final teams = teamsRaw is List ? teamsRaw : (teamsRaw != null ? [teamsRaw] : const []);
      for (final t in teams) {
        if (t is Map) rows.add(Map<String, dynamic>.from(t));
      }
    }

    if (root is Map<String, dynamic>) {
      // Hivatalos V2: standings.tournament.team
      final tournament = root['tournament'];
      if (tournament is Map && tournament['team'] != null) {
        addTeams(tournament['team']);
      } else if (root['team'] != null) {
        addTeams(root['team']);
      } else if (root['league'] != null) {
        final lg = root['league'] is List ? (root['league'] as List).first : root['league'];
        if (lg is Map && lg['team'] != null) addTeams(lg['team']);
      }
    } else if (root is List) {
      for (final t in root) {
        if (t is Map) rows.add(Map<String, dynamic>.from(t));
      }
    }
    return rows;
  }

  static MatchData _parseStatPalMatch(
    Map<String, dynamic> m, {
    String? countryOverride,
    String? leagueOverride,
  }) {
    final id = (m['id'] ?? m['main_id'] ?? m['static_id'] ?? m['alternate_id'] ?? UniqueKey().toString()).toString();
    final localized = localizeCompetition(
      countryRaw: countryOverride ?? m['country']?.toString(),
      leagueRaw: leagueOverride ?? m['league_name']?.toString() ?? m['league']?.toString(),
    );
    final country = localized.country;
    final league = localized.league;

    final homeObj = m['home'] is Map ? Map<String, dynamic>.from(m['home'] as Map) : <String, dynamic>{};
    final awayObj = m['away'] is Map ? Map<String, dynamic>.from(m['away'] as Map) : <String, dynamic>{};

    final homeTeam = (homeObj['name'] ?? m['home_team'] ?? 'Hazai').toString();
    final awayTeam = (awayObj['name'] ?? m['away_team'] ?? 'Vendég').toString();

    final homeScore = int.tryParse((homeObj['goals'] ?? homeObj['score'] ?? m['home_score'] ?? '0').toString()) ?? 0;
    final awayScore = int.tryParse((awayObj['goals'] ?? awayObj['score'] ?? m['away_score'] ?? '0').toString()) ?? 0;

    final rawStatus = (m['status'] ?? '').toString().trim();
    final upperStatus = rawStatus.toUpperCase();

    final isFinished = upperStatus == 'FT' || upperStatus == 'AET' || upperStatus == 'PEN' || upperStatus.contains('FIN');
    final isNumericMinute = RegExp(r'^\d+(\+\d+)?$').hasMatch(rawStatus);
    final isLive = !isFinished && (isNumericMinute || upperStatus == 'HT' || upperStatus == 'LIVE');

    String statusLabel;
    if (isFinished) {
      statusLabel = 'VÉGE';
    } else if (isNumericMinute) {
      statusLabel = "$rawStatus'";
    } else if (upperStatus == 'HT') {
      statusLabel = 'SZÜNET';
    } else if (rawStatus.isNotEmpty) {
      statusLabel = rawStatus;
    } else {
      final t = (m['time'] ?? '').toString();
      statusLabel = t.length >= 5 ? t.substring(0, 5) : (t.isNotEmpty ? t : 'HAMAROSAN');
    }

    final events = <MatchEvent>[];
    final eventsWrapper = m['events'] is Map ? Map<String, dynamic>.from(m['events'] as Map) : <String, dynamic>{};
    final rawEvents = eventsWrapper['event'] is List
        ? eventsWrapper['event'] as List
        : (eventsWrapper['event'] != null ? [eventsWrapper['event']] : (m['events'] is List ? m['events'] as List : const []));

    for (final ev in rawEvents) {
      if (ev is Map) {
        final em = Map<String, dynamic>.from(ev);
        final evTypeRaw = (em['type'] ?? '').toString().toLowerCase();
        String mappedType = 'goal';
        if (evTypeRaw.contains('red')) {
          mappedType = 'red';
        } else if (evTypeRaw.contains('yellow') || evTypeRaw.contains('card')) {
          mappedType = 'yellow';
        } else if (evTypeRaw.contains('subst')) {
          mappedType = 'sub';
        }
        final minStr = (em['minute'] ?? '').toString();
        final teamSide = (em['team'] ?? '').toString().toLowerCase();
        events.add(MatchEvent(
          minute: minStr.isEmpty ? '' : (minStr.endsWith("'") ? minStr : "$minStr'"),
          type: mappedType,
          player: (em['player'] ?? em['result'] ?? '').toString(),
          isHome: teamSide == 'home' || teamSide == 'localteam',
        ));
      }
    }

    final homeId = (homeObj['id'] ?? m['home_id'] ?? '').toString();
    final awayId = (awayObj['id'] ?? m['away_id'] ?? '').toString();
    final homeLogo = homeId.isNotEmpty ? teamLogoUrl(homeId) : null;
    final awayLogo = awayId.isNotEmpty ? teamLogoUrl(awayId) : null;
    final flagUrl = countryFlagCdnUrl(country);

    return MatchData(
      id: id,
      country: country,
      countryFlagUrl: flagUrl,
      league: league,
      homeTeam: homeTeam,
      awayTeam: awayTeam,
      homeLogo: homeLogo,
      awayLogo: awayLogo,
      homeScore: homeScore,
      awayScore: awayScore,
      status: statusLabel,
      isLive: isLive,
      isFinished: isFinished,
      homeColor: colorFromName(homeTeam),
      awayColor: colorFromName(awayTeam),
      events: events,
      isFromApi: true,
    );
  }

  static MatchData _applyDetailPayload(MatchData base, Map<String, dynamic> d) {
    final stats = d['statistics'] is Map ? Map<String, dynamic>.from(d['statistics'] as Map) : d;
    final possH = int.tryParse((stats['possession_home'] ?? base.possessionHome).toString()) ?? base.possessionHome;
    final shotsH = int.tryParse((stats['shots_home'] ?? base.shotsHome).toString()) ?? base.shotsHome;
    final shotsA = int.tryParse((stats['shots_away'] ?? base.shotsAway).toString()) ?? base.shotsAway;
    final sotH = int.tryParse((stats['shots_on_target_home'] ?? base.shotsOnTargetHome).toString()) ?? base.shotsOnTargetHome;
    final sotA = int.tryParse((stats['shots_on_target_away'] ?? base.shotsOnTargetAway).toString()) ?? base.shotsOnTargetAway;
    final corH = int.tryParse((stats['corners_home'] ?? base.cornersHome).toString()) ?? base.cornersHome;
    final corA = int.tryParse((stats['corners_away'] ?? base.cornersAway).toString()) ?? base.cornersAway;
    final foulH = int.tryParse((stats['fouls_home'] ?? base.foulsHome).toString()) ?? base.foulsHome;
    final foulA = int.tryParse((stats['fouls_away'] ?? base.foulsAway).toString()) ?? base.foulsAway;

    return base.copyWith(
      possessionHome: possH.clamp(0, 100),
      shotsHome: shotsH,
      shotsAway: shotsA,
      shotsOnTargetHome: sotH,
      shotsOnTargetAway: sotA,
      cornersHome: corH,
      cornersAway: corA,
      foulsHome: foulH,
      foulsAway: foulA,
    );
  }
}
