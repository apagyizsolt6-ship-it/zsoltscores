import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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

// --- TARTÓS API KONFIGURÁCIÓ ---
class ApiConfig {
  static const _keyPref = 'highlightly_api_key';
  static const _rapidPref = 'highlightly_use_rapidapi';

  static String apiKey = '';
  static bool useRapidApi = false;

  static bool get hasValidKey => apiKey.trim().isNotEmpty;

  static String get baseUrl => useRapidApi
      ? 'https://football-highlights-api.p.rapidapi.com'
      : 'https://soccer.highlightly.net';

  static Map<String, String> get headers => {
        'x-rapidapi-key': apiKey.trim(),
        if (useRapidApi) 'x-rapidapi-host': 'football-highlights-api.p.rapidapi.com',
      };

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    apiKey = prefs.getString(_keyPref) ?? '';
    useRapidApi = prefs.getBool(_rapidPref) ?? false;
  }

  static Future<void> save(String newKey, bool rapid) async {
    apiKey = newKey.trim();
    useRapidApi = rapid;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPref, apiKey);
    await prefs.setBool(_rapidPref, useRapidApi);
  }

  static Future<void> clear() async {
    apiKey = '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPref);
  }
}

// --- HELYI TÁROLÓ (CACHE) AZ API KERET VÉDELMÉRE ---
class ApiCache {
  static const _prefix = 'zsolt_cache_';
  static const _savedKey = 'zsolt_cache_saved_count';
  static const _netKey = 'zsolt_cache_net_count';
  static const _ttlKey = 'zsolt_cache_ttl_minutes';

  static int savedRequests = 0;
  static int networkRequests = 0;
  static int cacheMinutes = 5;

  static Future<void> loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    savedRequests = prefs.getInt(_savedKey) ?? 0;
    networkRequests = prefs.getInt(_netKey) ?? 0;
    cacheMinutes = prefs.getInt(_ttlKey) ?? 5;
  }

  static Future<void> setCacheMinutes(int minutes) async {
    cacheMinutes = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_ttlKey, minutes);
  }

  static Future<void> recordNetworkCall([int count = 1]) async {
    networkRequests += count;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_netKey, networkRequests);
  }

  static Future<void> recordSavedCall([int count = 1]) async {
    savedRequests += count;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_savedKey, savedRequests);
  }

  static Future<String?> get(String key, Duration maxAge, {int savedWeight = 1}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$key');
    if (raw == null) return null;

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final ts = decoded['ts'] as int? ?? 0;
      final age = DateTime.now().millisecondsSinceEpoch - ts;
      if (age <= maxAge.inMilliseconds) {
        await recordSavedCall(savedWeight);
        return decoded['data'] as String?;
      }
    } catch (_) {}
    return null;
  }

  static Future<void> put(String key, String data) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode({
      'ts': DateTime.now().millisecondsSinceEpoch,
      'data': data,
    });
    await prefs.setString('$_prefix$key', payload);
  }

  static Future<int> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
    return keys.length;
  }
}

class FetchResult<T> {
  final T data;
  final bool fromCache;

  const FetchResult({required this.data, required this.fromCache});
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

  Map<String, dynamic> toJson() => {
        'minute': minute,
        'player': player,
        'type': type,
        'isHome': isHome,
      };

  factory MatchEvent.fromJson(Map<String, dynamic> json) => MatchEvent(
        minute: (json['minute'] ?? '').toString(),
        player: (json['player'] ?? '').toString(),
        type: (json['type'] ?? 'goal').toString(),
        isHome: json['isHome'] == true,
      );
}

class HighlightClip {
  final String title;
  final String url;
  final String? thumbnail;
  final String? source;

  const HighlightClip({
    required this.title,
    required this.url,
    this.thumbnail,
    this.source,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'url': url,
        'thumbnail': thumbnail,
        'source': source,
      };

  factory HighlightClip.fromJson(Map<String, dynamic> json) => HighlightClip(
        title: (json['title'] ?? '').toString(),
        url: (json['url'] ?? '').toString(),
        thumbnail: json['thumbnail']?.toString(),
        source: json['source']?.toString(),
      );
}

class MatchData {
  final String id;
  final String league;
  final String homeTeam;
  final String awayTeam;
  final String? homeLogo;
  final String? awayLogo;
  final Color homeColor;
  final Color awayColor;
  final int homeScore;
  final int awayScore;
  final String status;
  final bool isLive;
  final bool isFromApi;
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
  final List<HighlightClip> highlights;

  const MatchData({
    required this.id,
    required this.league,
    required this.homeTeam,
    required this.awayTeam,
    this.homeLogo,
    this.awayLogo,
    required this.homeColor,
    required this.awayColor,
    required this.homeScore,
    required this.awayScore,
    required this.status,
    required this.isLive,
    this.isFromApi = false,
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
    this.highlights = const [],
  });

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
    List<HighlightClip>? highlights,
  }) {
    return MatchData(
      id: id,
      league: league,
      homeTeam: homeTeam,
      awayTeam: awayTeam,
      homeLogo: homeLogo,
      awayLogo: awayLogo,
      homeColor: homeColor,
      awayColor: awayColor,
      homeScore: homeScore,
      awayScore: awayScore,
      status: status,
      isLive: isLive,
      isFromApi: isFromApi,
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
      highlights: highlights ?? this.highlights,
    );
  }
}

class StandingRow {
  final int pos;
  final String team;
  final String? logo;
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
    this.logo,
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

// --- HIGHLIGHTLY API SZOLGÁLTATÁS (TÁROLÓVAL) ---
class HighlightlyService {
  static Color colorFromName(String name) {
    const palette = [
      Color(0xFF00E676),
      Color(0xFF00B0FF),
      Color(0xFF7C4DFF),
      Color(0xFFFF1744),
      Color(0xFFFFAB00),
      Color(0xFF2979FF),
      Color(0xFFAA00FF),
      Color(0xFF00C853),
    ];
    final hash = name.codeUnits.fold<int>(0, (prev, elem) => prev + elem);
    return palette[hash % palette.length];
  }

  static String formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static Future<FetchResult<List<MatchData>>> fetchMatches(
    DateTime date, {
    bool forceRefresh = false,
  }) async {
    if (!ApiConfig.hasValidKey) {
      throw Exception('Nincs megadva API kulcs');
    }

    final dateStr = formatDate(date);
    final todayStr = formatDate(DateTime.now());
    final cacheKey = 'matches_$dateStr';
    final ttl = dateStr == todayStr
        ? Duration(minutes: ApiCache.cacheMinutes)
        : const Duration(hours: 12);

    if (!forceRefresh) {
      final cachedJson = await ApiCache.get(cacheKey, ttl);
      if (cachedJson != null) {
        return FetchResult(
          data: _parseMatchListBody(cachedJson),
          fromCache: true,
        );
      }
    }

    final uri = Uri.parse('${ApiConfig.baseUrl}/matches?date=$dateStr&limit=50');
    final response = await http
        .get(uri, headers: ApiConfig.headers)
        .timeout(const Duration(seconds: 12));

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw Exception('Érvénytelen API kulcs (${response.statusCode})');
    }
    if (response.statusCode != 200) {
      throw Exception('API hiba (${response.statusCode})');
    }

    await ApiCache.recordNetworkCall();
    await ApiCache.put(cacheKey, response.body);

    return FetchResult(
      data: _parseMatchListBody(response.body),
      fromCache: false,
    );
  }

  static List<MatchData> _parseMatchListBody(String body) {
    final decoded = jsonDecode(body);
    final List<dynamic> rawList = decoded is List
        ? decoded
        : (decoded is Map && decoded['data'] is List ? decoded['data'] : []);

    return rawList.whereType>().map(_parseMatch).toList();
  }

  static MatchData _parseMatch(Map<String, dynamic> m) {
    final homeMap = m['homeTeam'] is Map ? m['homeTeam'] as Map<String, dynamic> : {};
    final awayMap = m['awayTeam'] is Map ? m['awayTeam'] as Map<String, dynamic> : {};
    final leagueMap = m['league'] is Map ? m['league'] as Map<String, dynamic> : {};
    final stateMap = m['state'] is Map ? m['state'] as Map<String, dynamic> : {};

    final homeName = (homeMap['name'] ?? m['homeTeam'] ?? 'Hazai').toString();
    final awayName = (awayMap['name'] ?? m['awayTeam'] ?? 'Vendég').toString();
    final leagueName = (leagueMap['name'] ?? m['league'] ?? 'Egyéb liga').toString();

    int homeScore = 0;
    int awayScore = 0;
    final scoreObj = stateMap['score'];
    if (scoreObj is Map && scoreObj['current'] != null) {
      final parts = scoreObj['current'].toString().split(RegExp(r'[-:]'));
      if (parts.length >= 2) {
        homeScore = int.tryParse(parts[0].trim()) ?? 0;
        awayScore = int.tryParse(parts[1].trim()) ?? 0;
      }
    } else {
      homeScore = int.tryParse('${m['homeScore'] ?? 0}') ?? 0;
      awayScore = int.tryParse('${m['awayScore'] ?? 0}') ?? 0;
    }

    final desc = (stateMap['description'] ?? m['status'] ?? '').toString();
    final descLower = desc.toLowerCase();
    final clock = stateMap['clock']?.toString() ?? '';

    final bool isLive = descLower.contains('progress') ||
        descLower.contains('half') ||
        descLower.contains('live') ||
        descLower.contains('extra');

    String statusLabel;
    if (isLive) {
      statusLabel = clock.isNotEmpty ? "$clock'" : 'ÉLŐ';
    } else if (descLower.contains('finish') || descLower.contains('ended') || descLower == 'ft') {
      statusLabel = 'VÉGE';
    } else if (m['date'] != null && m['date'].toString().contains('T')) {
      final dt = DateTime.tryParse(m['date'].toString())?.toLocal();
      statusLabel = dt != null
          ? '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
          : (desc.isNotEmpty ? desc : 'Később');
    } else {
      statusLabel = desc.isNotEmpty ? desc : 'Később';
    }

    return MatchData(
      id: (m['id'] ?? '${homeName}_$awayName').toString(),
      league: leagueName,
      homeTeam: homeName,
      awayTeam: awayName,
      homeLogo: homeMap['logo']?.toString(),
      awayLogo: awayMap['logo']?.toString(),
      homeColor: colorFromName(homeName),
      awayColor: colorFromName(awayName),
      homeScore: homeScore,
      awayScore: awayScore,
      status: statusLabel,
      isLive: isLive,
      isFromApi: true,
      possessionHome: 50,
      shotsHome: 0,
      shotsAway: 0,
      shotsOnTargetHome: 0,
      shotsOnTargetAway: 0,
      cornersHome: 0,
      cornersAway: 0,
      foulsHome: 0,
      foulsAway: 0,
      events: const [],
    );
  }

  static Future<FetchResult<MatchData>> enrichMatchDetails(
    MatchData base, {
    bool forceRefresh = false,
  }) async {
    if (!ApiConfig.hasValidKey || !base.isFromApi) {
      return FetchResult(data: base, fromCache: false);
    }

    final cacheKey = 'detail_${base.id}';
    final ttl = base.status == 'VÉGE'
        ? const Duration(hours: 12)
        : Duration(minutes: ApiCache.cacheMinutes);

    if (!forceRefresh) {
      final cachedJson = await ApiCache.get(cacheKey, ttl, savedWeight: 3);
      if (cachedJson != null) {
        final map = jsonDecode(cachedJson) as Map<String, dynamic>;
        final evList = (map['events'] as List? ?? [])
            .whereType>()
            .map(MatchEvent.fromJson)
            .toList();
        final clipList = (map['highlights'] as List? ?? [])
            .whereType>()
            .map(HighlightClip.fromJson)
            .toList();
        return FetchResult(
          fromCache: true,
          data: base.copyWith(
            possessionHome: map['possessionHome'] as int? ?? base.possessionHome,
            shotsHome: map['shotsHome'] as int? ?? 0,
            shotsAway: map['shotsAway'] as int? ?? 0,
            shotsOnTargetHome: map['shotsOnTargetHome'] as int? ?? 0,
            shotsOnTargetAway: map['shotsOnTargetAway'] as int? ?? 0,
            cornersHome: map['cornersHome'] as int? ?? 0,
            cornersAway: map['cornersAway'] as int? ?? 0,
            foulsHome: map['foulsHome'] as int? ?? 0,
            foulsAway: map['foulsAway'] as int? ?? 0,
            events: evList,
            highlights: clipList,
          ),
        );
      }
    }

    int possHome = base.possessionHome;
    int shotsH = base.shotsHome;
    int shotsA = base.shotsAway;
    int sotH = base.shotsOnTargetHome;
    int sotA = base.shotsOnTargetAway;
    int cornH = base.cornersHome;
    int cornA = base.cornersAway;
    int foulH = base.foulsHome;
    int foulA = base.foulsAway;
    List<MatchEvent> events = List.of(base.events);
    List<HighlightClip> clips = List.of(base.highlights);

    try {
      await ApiCache.recordNetworkCall();
      final statRes = await http
          .get(Uri.parse('${ApiConfig.baseUrl}/match-statistics/${base.id}'), headers: ApiConfig.headers)
          .timeout(const Duration(seconds: 8));
      if (statRes.statusCode == 200) {
        final body = jsonDecode(statRes.body);
        final list = body is List
            ? body
            : (body is Map && body['data'] is List ? body['data'] : []);
        if (list.length >= 2 && list[0] is Map && list[1] is Map) {
          final hStats = (list[0]['statistics'] is List ? list[0]['statistics'] : []) as List;
          final aStats = (list[1]['statistics'] is List ? list[1]['statistics'] : []) as List;

          int readStat(List stats, List<String> keywords) {
            for (final item in stats) {
              if (item is Map) {
                final name = (item['displayName'] ?? item['type'] ?? item['name'] ?? '').toString().toLowerCase();
                if (keywords.any((k) => name.contains(k))) {
                  final raw = (item['value'] ?? '0').toString().replaceAll('%', '').trim();
                  return int.tryParse(raw) ?? 0;
                }
              }
            }
            return 0;
          }

          final p = readStat(hStats, ['possession']);
          if (p > 0) possHome = p;
          shotsH = readStat(hStats, ['total shots', 'shots']);
          shotsA = readStat(aStats, ['total shots', 'shots']);
          sotH = readStat(hStats, ['on target', 'shots on goal']);
          sotA = readStat(aStats, ['on target', 'shots on goal']);
          cornH = readStat(hStats, ['corner']);
          cornA = readStat(aStats, ['corner']);
          foulH = readStat(hStats, ['foul']);
          foulA = readStat(aStats, ['foul']);
        }
      }
    } catch (_) {}

    try {
      await ApiCache.recordNetworkCall();
      final evRes = await http
          .get(Uri.parse('${ApiConfig.baseUrl}/live-events/${base.id}'), headers: ApiConfig.headers)
          .timeout(const Duration(seconds: 8));
      if (evRes.statusCode == 200) {
        final body = jsonDecode(evRes.body);
        final list = body is List
            ? body
            : (body is Map && body['data'] is List ? body['data'] : []);
        final parsedEvents = <MatchEvent>[];
        for (final item in list) {
          if (item is Map) {
            final rawType = (item['type'] ?? '').toString().toLowerCase();
            String type = 'goal';
            if (rawType.contains('yellow')) {
              type = 'yellow';
            } else if (rawType.contains('red')) {
              type = 'red';
            } else if (!rawType.contains('goal') && !rawType.contains('pen')) {
              continue;
            }
            final teamObj = item['team'] is Map ? item['team'] : {};
            final teamName = (teamObj['name'] ?? '').toString();
            final isHome = teamName.toLowerCase() == base.homeTeam.toLowerCase();
            final playerObj = item['player'] is Map ? item['player'] : {};
            final player = (playerObj['name'] ?? item['player'] ?? 'Játékos').toString();
            final time = (item['time'] ?? '').toString();
            parsedEvents.add(MatchEvent(
              minute: time.endsWith("'") ? time : "$time'",
              player: player,
              type: type,
              isHome: isHome,
            ));
          }
        }
        if (parsedEvents.isNotEmpty) events = parsedEvents;
      }
    } catch (_) {}

    try {
      await ApiCache.recordNetworkCall();
      final hlRes = await http
          .get(Uri.parse('${ApiConfig.baseUrl}/highlights?matchId=${base.id}'), headers: ApiConfig.headers)
          .timeout(const Duration(seconds: 8));
      if (hlRes.statusCode == 200) {
        final body = jsonDecode(hlRes.body);
        final list = body is List
            ? body
            : (body is Map && body['data'] is List ? body['data'] : []);
        final parsedClips = <HighlightClip>[];
        for (final item in list) {
          if (item is Map && item['url'] != null) {
            parsedClips.add(HighlightClip(
              title: (item['title'] ?? '${base.homeTeam} - ${base.awayTeam} összefoglaló').toString(),
              url: item['url'].toString(),
              thumbnail: item['imgUrl']?.toString(),
              source: item['source']?.toString(),
            ));
          }
        }
        if (parsedClips.isNotEmpty) clips = parsedClips;
      }
    } catch (_) {}

    await ApiCache.put(
      cacheKey,
      jsonEncode({
        'possessionHome': possHome,
        'shotsHome': shotsH,
        'shotsAway': shotsA,
        'shotsOnTargetHome': sotH,
        'shotsOnTargetAway': sotA,
        'cornersHome': cornH,
        'cornersAway': cornA,
        'foulsHome': foulH,
        'foulsAway': foulA,
        'events': events.map((e) => e.toJson()).toList(),
        'highlights': clips.map((c) => c.toJson()).toList(),
      }),
    );

    return FetchResult(
      fromCache: false,
      data: base.copyWith(
        possessionHome: possHome,
        shotsHome: shotsH,
        shotsAway: shotsA,
        shotsOnTargetHome: sotH,
        shotsOnTargetAway: sotA,
        cornersHome: cornH,
        cornersAway: cornA,
        foulsHome: foulH,
        foulsAway: foulA,
        events: events,
        highlights: clips,
      ),
    );
  }

  static Future<FetchResult<List<StandingRow>>> fetchStandings(
    int leagueId, {
    bool forceRefresh = false,
  }) async {
    if (!ApiConfig.hasValidKey) {
      throw Exception('Nincs API kulcs');
    }

    final cacheKey = 'standings_$leagueId';
    if (!forceRefresh) {
      final cachedJson = await ApiCache.get(cacheKey, const Duration(hours: 2));
      if (cachedJson != null) {
        return FetchResult(
          data: _parseStandingsBody(cachedJson),
          fromCache: true,
        );
      }
    }

    final uri = Uri.parse('${ApiConfig.baseUrl}/standings?leagueId=$leagueId');
    final res = await http.get(uri, headers: ApiConfig.headers).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw Exception('Tabella hiba (${res.statusCode})');
    }

    await ApiCache.recordNetworkCall();
    await ApiCache.put(cacheKey, res.body);

    return FetchResult(
      data: _parseStandingsBody(res.body),
      fromCache: false,
    );
  }

  static List<StandingRow> _parseStandingsBody(String body) {
    final decoded = jsonDecode(body);
    List<dynamic> rows = [];
    if (decoded is Map && decoded['groups'] is List && (decoded['groups'] as List).isNotEmpty) {
      final firstGroup = decoded['groups'][0];
      if (firstGroup is Map && firstGroup['standings'] is List) {
        rows = firstGroup['standings'];
      }
    } else if (decoded is Map && decoded['data'] is List) {
      rows = decoded['data'];
    } else if (decoded is List) {
      rows = decoded;
    }

    return rows.whereType>().map((r) {
      final teamMap = r['team'] is Map ? r['team'] as Map<String, dynamic> : {};
      final totalMap = r['total'] is Map ? r['total'] as Map<String, dynamic> : r;
      final teamName = (teamMap['name'] ?? r['teamName'] ?? 'Csapat').toString();
      final pos = int.tryParse('${r['position'] ?? r['pos'] ?? 0}') ?? 0;
      final played = int.tryParse('${totalMap['games'] ?? totalMap['played'] ?? 0}') ?? 0;
      final won = int.tryParse('${totalMap['wins'] ?? totalMap['won'] ?? 0}') ?? 0;
      final drawn = int.tryParse('${totalMap['draws'] ?? totalMap['drawn'] ?? 0}') ?? 0;
      final lost = int.tryParse('${totalMap['loses'] ?? totalMap['lost'] ?? 0}') ?? 0;
      final gf = int.tryParse('${totalMap['scoredGoals'] ?? 0}') ?? 0;
      final ga = int.tryParse('${totalMap['receivedGoals'] ?? 0}') ?? 0;
      final gd = int.tryParse('${r['goalDifference'] ?? (gf - ga)}') ?? (gf - ga);
      final pts = int.tryParse('${r['points'] ?? 0}') ?? 0;

      String zone = 'none';
      if (pos >= 1 && pos <= 4) {
        zone = 'ucl';
      } else if (pos == 5 || pos == 6) {
        zone = 'uel';
      } else if (pos >= 18) {
        zone = 'rel';
      }

      return StandingRow(
        pos: pos,
        team: teamName,
        logo: teamMap['logo']?.toString(),
        color: colorFromName(teamName),
        played: played,
        won: won,
        drawn: drawn,
        lost: lost,
        gd: gd,
        points: pts,
        zone: zone,
      );
    }).toList();
  }
}

// --- DEMO MINTA ADATOK ---
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
      MatchEvent(minute: "69'", player: 'Bellingham', type: 'goal', isHome: true),
    ],
    highlights: [
      HighlightClip(
        title: 'Real Madrid - Liverpool 2-2 | Összefoglaló (Demo)',
        url: 'https://highlightly.net',
        source: 'Highlightly Demo',
      ),
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
];

const Map<String, List<StandingRow>> sampleStandings = {
  'Premier League': [
    StandingRow(pos: 1, team: 'Liverpool', color: Color(0xFFFF1744), played: 12, won: 10, drawn: 1, lost: 1, gd: 17, points: 31, zone: 'ucl'),
    StandingRow(pos: 2, team: 'Man. City', color: Color(0xFF00B0FF), played: 12, won: 8, drawn: 2, lost: 2, gd: 11, points: 26, zone: 'ucl'),
    StandingRow(pos: 3, team: 'Arsenal', color: Color(0xFFFF5252), played: 12, won: 7, drawn: 3, lost: 2, gd: 9, points: 24, zone: 'ucl'),
    StandingRow(pos: 4, team: 'Chelsea', color: Color(0xFF2979FF), played: 12, won: 6, drawn: 4, lost: 2, gd: 8, points: 22, zone: 'ucl'),
  ],
  'Bajnokok Ligája': [
    StandingRow(pos: 1, team: 'Liverpool', color: Color(0xFFFF1744), played: 5, won: 5, drawn: 0, lost: 0, gd: 11, points: 15, zone: 'ucl'),
    StandingRow(pos: 2, team: 'Barcelona', color: Color(0xFF2979FF), played: 5, won: 4, drawn: 0, lost: 1, gd: 13, points: 12, zone: 'ucl'),
    StandingRow(pos: 3, team: 'Arsenal', color: Color(0xFFFF5252), played: 5, won: 3, drawn: 1, lost: 1, gd: 6, points: 10, zone: 'ucl'),
  ],
  'La Liga': [
    StandingRow(pos: 1, team: 'Barcelona', color: Color(0xFF2979FF), played: 13, won: 11, drawn: 0, lost: 2, gd: 28, points: 33, zone: 'ucl'),
    StandingRow(pos: 2, team: 'Real Madrid', color: Color(0xFF7C4DFF), played: 13, won: 9, drawn: 3, lost: 1, gd: 16, points: 30, zone: 'ucl'),
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
      final result = await HighlightlyService.fetchMatches(
        _selectedDate,
        forceRefresh: forceRefresh,
      );
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
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
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
              Text('API és Tároló Beállítások', style: TextStyle(fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Highlightly API kulcs (a telefonod elmenti):',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: 'Illeszd be az API kulcsot...',
                    filled: true,
                    fillColor: const Color(0xFF0B132B),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    suffixIcon: IconButton(
                      tooltip: 'Beillesztés vágólapról',
                      icon: const Icon(Icons.content_paste, color: Color(0xFF00B0FF)),
                      onPressed: () async {
                        final data = await Clipboard.getData(Clipboard.kTextPlain);
                        if (data?.text != null && data!.text!.trim().isNotEmpty) {
                          setDialogState(() {
                            controller.text = data.text!.trim();
                          });
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
                    tempRapid
                        ? 'football-highlights-api.p.rapidapi.com'
                        : 'soccer.highlightly.net (közvetlen)',
                    style: const TextStyle(fontSize: 11, color: Colors.white54),
                  ),
                  value: tempRapid,
                  onChanged: (val) => setDialogState(() => tempRapid = val),
                ),
                const Divider(color: Colors.white12, height: 20),
                // Tároló beállítások
                const Row(
                  children: [
                    Icon(Icons.storage, color: Color(0xFF00B0FF), size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Helyi tároló (API keretkímélő)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Élő adatok tárolása:', style: TextStyle(fontSize: 12, color: Colors.white70)),
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
                          Text(
                            '${ApiCache.networkRequests}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amberAccent, fontSize: 15),
                          ),
                          const Text('API kérés', style: TextStyle(fontSize: 10, color: Colors.white60)),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            '${ApiCache.savedRequests}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00E676), fontSize: 15),
                          ),
                          const Text('Megspórolt (tároló)', style: TextStyle(fontSize: 10, color: Colors.white60)),
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
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Mégse'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF00E676)),
              onPressed: () async {
                await ApiConfig.save(controller.text, tempRapid);
                await ApiCache.setCacheMinutes(tempTtl);
                if (ctx.mounted) Navigator.pop(ctx);
                setState(() => _settingsVersion++);
                _loadMatches(forceRefresh: false);
              },
              child: const Text(
                'Mentés',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
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
        onRefresh: () => _loadMatches(forceRefresh: true),
        onOpenSettings: _openApiSettingsDialog,
      ),
      StandingsTab(
        key: ValueKey(_settingsVersion),
        onOpenSettings: _openApiSettingsDialog,
      ),
      FavoritesTab(
        allMatches: _matches,
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
  final DateTime selectedDate;
  final bool isLoading;
  final bool isLiveApiData;
  final bool loadedFromCache;
  final String? statusMessage;
  final Set<String> favoriteIds;
  final ValueChanged<String> onToggleFavorite;
  final ValueChanged<int> onChangeDate;
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
    final dynamicLeagues = <String>{
      'Összes',
      ...widget.matches.map((m) => m.league),
    }.toList();

    if (!dynamicLeagues.contains(selectedLeague)) {
      selectedLeague = 'Összes';
    }

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

    String sourceSubtitle;
    Color sourceColor;
    if (!widget.isLiveApiData) {
      sourceSubtitle = 'Demo mód';
      sourceColor = Colors.amberAccent;
    } else if (widget.loadedFromCache) {
      sourceSubtitle = 'Tárolóból betöltve • API keret kímélve';
      sourceColor = const Color(0xFF00B0FF);
    } else {
      sourceSubtitle = 'Highlightly Élő API • Frissítve';
      sourceColor = const Color(0xFF00E676);
    }

    return SafeArea(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 14, 10, 16),
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
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'zsoltscores ⚽',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            sourceSubtitle,
                            style: TextStyle(
                              fontSize: 11,
                              color: sourceColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => onlyLive = !onlyLive),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: onlyLive
                              ? const Color(0xFF00E676)
                              : const Color(0xFF00E676).withAlpha(45),
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
                        tooltip: 'Frissítés az API-ról',
                      ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: widget.onOpenSettings,
                      icon: Icon(
                        Icons.settings,
                        color: ApiConfig.hasValidKey ? const Color(0xFF00E676) : Colors.amberAccent,
                      ),
                      tooltip: 'API és tároló beállítások',
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
                          Text(
                            HighlightlyService.formatDate(widget.selectedDate),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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
                          hintText: 'Csapat keresése...',
                          hintStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                          prefixIcon: const Icon(Icons.search, color: Color(0xFF00B0FF), size: 20),
                          filled: true,
                          fillColor: const Color(0xFF0B132B).withAlpha(180),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
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
            const LinearProgressIndicator(
              color: Color(0xFF00E676),
              backgroundColor: Colors.transparent,
            ),

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
                  const Expanded(
                    child: Text(
                      'Add meg a Highlightly API kulcsodat az élő meccsekhez!',
                      style: TextStyle(fontSize: 12, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF00E676),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onPressed: widget.onOpenSettings,
                    child: const Text(
                      'Kulcs beírása',
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
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
                child: Text(
                  widget.statusMessage!,
                  style: const TextStyle(fontSize: 12, color: Colors.amberAccent),
                  textAlign: TextAlign.center,
                ),
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
                      fontSize: 12,
                    ),
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
                  ? ListView(
                      children: const [
                        SizedBox(height: 100),
                        Center(
                          child: Text(
                            'Nincs a szűrésnek megfelelő meccs.',
                            style: TextStyle(color: Colors.white60),
                          ),
                        ),
                      ],
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
                Expanded(
                  child: Text(
                    match.league,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
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
                _teamBadge(match.homeTeam, match.homeColor, match.homeLogo),
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
                      errorBuilder: (_, __, ___) => Text(
                        initials,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
                : Text(
                    initials,
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

  static const Map<String, int> leagueIds = {
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
      final result = await HighlightlyService.fetchStandings(
        id,
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
    final leagues = leagueIds.keys.toList();

    return SafeArea(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1C2541), Color(0xFF3A506B)],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bajnoki Tabellák 🏆',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _fromCache
                          ? 'Tárolóból betöltve (2 órás védelem)'
                          : 'Highlightly élő állások és pontszámok',
                      style: TextStyle(
                        fontSize: 12,
                        color: _fromCache ? const Color(0xFF00B0FF) : Colors.white70,
                      ),
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
          if (_loading)
            const LinearProgressIndicator(
              color: Color(0xFF00E676),
              backgroundColor: Colors.transparent,
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
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: r.color,
                        child: r.logo != null && r.logo!.isNotEmpty
                            ? ClipOval(
                                child: Image.network(
                                  r.logo!,
                                  width: 18,
                                  height: 18,
                                  errorBuilder: (_, __, ___) => const SizedBox(),
                                ),
                              )
                            : null,
                      ),
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

  const FavoritesTab({
    super.key,
    required this.allMatches,
    required this.favoriteIds,
    required this.onToggleFavorite,
  });

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

// --- RÉSZLETES STATISZTIKA, ESEMÉNYEK ÉS HIGHLIGHTS KÉPERNYŐ ---
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

  @override
  void initState() {
    super.initState();
    _match = widget.match;
    _fetchDetails();
  }

  Future<void> _fetchDetails({bool forceRefresh = false}) async {
    if (!ApiConfig.hasValidKey || !_match.isFromApi) return;
    setState(() => _loadingDetails = true);
    final result = await HighlightlyService.enrichMatchDetails(
      _match,
      forceRefresh: forceRefresh,
    );
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
                const Text(
                  'Tárolóból betöltve (3 API kérés megspórolva)',
                  style: TextStyle(fontSize: 11, color: Color(0xFF00B0FF)),
                ),
            ],
          ),
          backgroundColor: const Color(0xFF1C2541),
          actions: [
            if (ApiConfig.hasValidKey && _match.isFromApi)
              IconButton(
                onPressed: () => _fetchDetails(forceRefresh: true),
                icon: const Icon(Icons.refresh),
                tooltip: 'Részletek frissítése',
              ),
          ],
        ),
        body: Column(
          children: [
            if (_loadingDetails)
              const LinearProgressIndicator(
                color: Color(0xFF00E676),
                backgroundColor: Colors.transparent,
              ),
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _match.homeColor.withAlpha(75),
                    const Color(0xFF1C2541),
                    _match.awayColor.withAlpha(75),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: Text(
                      _match.homeTeam,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Column(
                    children: [
                      Text(
                        '${_match.homeScore} : ${_match.awayScore}',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF00E676),
                        ),
                      ),
                      Text(
                        _match.isLive ? 'ÉLŐ • ${_match.status}' : _match.status,
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Text(
                      _match.awayTeam,
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
                Tab(text: 'Highlights 🎬'),
              ],
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
                      ? const Center(
                          child: Text(
                            'Még nincs rögzített esemény ehhez a meccshez.',
                            style: TextStyle(color: Colors.white60),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _match.events.length,
                          itemBuilder: (context, i) {
                            final ev = _match.events[i];
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
                  _match.highlights.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Ehhez a meccshez még nem érhető el videós összefoglaló.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white60),
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
                              decoration: BoxDecoration(
                                color: const Color(0xFF1C2541),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (clip.thumbnail != null && clip.thumbnail!.isNotEmpty)
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                      child: Image.network(
                                        clip.thumbnail!,
                                        height: 170,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const SizedBox(),
                                      ),
                                    ),
                                  Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          clip.title,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                        const SizedBox(height: 10),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF00E676),
                                            foregroundColor: Colors.black,
                                          ),
                                          onPressed: () {
                                            Clipboard.setData(ClipboardData(text: clip.url));
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Videó link másolva a vágólapra!')),
                                            );
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
