import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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

// --- HELYI TÁROLÓ (CACHE) ---
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
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final ts = decoded['ts'] as int? ?? 0;
        if (DateTime.now().millisecondsSinceEpoch - ts <= maxAge.inMilliseconds) {
          await recordSavedCall(savedWeight);
          return decoded['data'] as String?;
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<void> put(String key, String data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_prefix$key',
      jsonEncode({'ts': DateTime.now().millisecondsSinceEpoch, 'data': data}),
    );
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
  final String type;
  final bool isHome;

  const MatchEvent({
    required this.minute,
    required this.player,
    required this.type,
    required this.isHome,
  });

  Map toJson() => {'minute': minute, 'player': player, 'type': type, 'isHome': isHome};

  factory MatchEvent.fromJson(Map json) => MatchEvent(
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

  const HighlightClip({required this.title, required this.url, this.thumbnail});

  Map toJson() => {'title': title, 'url': url, 'thumbnail': thumbnail};

  factory HighlightClip.fromJson(Map json) => HighlightClip(
        title: (json['title'] ?? '').toString(),
        url: (json['url'] ?? '').toString(),
        thumbnail: json['thumbnail']?.toString(),
      );
}

class MatchData {
  final String id;
  final String league;
  final String homeTeam;
  final String awayTeam;
  final String? homeTeamId;
  final String? awayTeamId;
  final String? homeLogo;
  final String? awayLogo;
  final Color homeColor;
  final Color awayColor;
  final int homeScore;
  final int awayScore;
  final String status;
  final bool isLive;
  final bool isFinished;
  final DateTime? kickoff;
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
  final String? detailNote;

  const MatchData({
    required this.id,
    required this.league,
    required this.homeTeam,
    required this.awayTeam,
    this.homeTeamId,
    this.awayTeamId,
    this.homeLogo,
    this.awayLogo,
    required this.homeColor,
    required this.awayColor,
    required this.homeScore,
    required this.awayScore,
    required this.status,
    required this.isLive,
    this.isFinished = false,
    this.kickoff,
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
    this.detailNote,
  });

  MatchData copyWith({
    int? homeScore,
    int? awayScore,
    String? status,
    bool? isLive,
    bool? isFinished,
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
    String? detailNote,
  }) {
    return MatchData(
      id: id,
      league: league,
      homeTeam: homeTeam,
      awayTeam: awayTeam,
      homeTeamId: homeTeamId,
      awayTeamId: awayTeamId,
      homeLogo: homeLogo,
      awayLogo: awayLogo,
      homeColor: homeColor,
      awayColor: awayColor,
      homeScore: homeScore ?? this.homeScore,
      awayScore: awayScore ?? this.awayScore,
      status: status ?? this.status,
      isLive: isLive ?? this.isLive,
      isFinished: isFinished ?? this.isFinished,
      kickoff: kickoff,
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
      detailNote: detailNote,
    );
  }
}

class StandingRow {
  final int pos;
  final String team;
  final String? logo;
  final Color color;
  final int played;
  final int gd;
  final int points;
  final String zone;

  const StandingRow({
    required this.pos,
    required this.team,
    this.logo,
    required this.color,
    required this.played,
    required this.gd,
    required this.points,
    required this.zone,
  });
}

// --- HIGHLIGHTLY API SZOLGÁLTATÁS ---
class HighlightlyService {
  static List _asMapList(dynamic input) {
    if (input is! List) return [];
    final out = [];
    for (final item in input) {
      if (item is Map) out.add(item);
    }
    return out;
  }

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

  static List<MatchData> _sortMatches(List<MatchData> list) {
    final sorted = List<MatchData>.of(list);
    sorted.sort((a, b) {
      // 1. Élő meccsek legelöl
      if (a.isLive != b.isLive) return a.isLive ? -1 : 1;
      // 2. Közelgő meccsek a befejezettek előtt
      if (a.isFinished != b.isFinished) return a.isFinished ? 1 : -1;
      // 3. Időrend szerint
      if (a.kickoff != null && b.kickoff != null) {
        final cmp = a.kickoff!.compareTo(b.kickoff!);
        if (cmp != 0) return cmp;
      }
      return a.league.compareTo(b.league);
    });
    return sorted;
  }

  static Future<FetchResult<List<MatchData>>> fetchMatches(
    DateTime date, {
    bool forceRefresh = false,
  }) async {
    if (!ApiConfig.hasValidKey) throw Exception('Nincs megadva API kulcs');

    final dateStr = formatDate(date);
    final todayStr = formatDate(DateTime.now());
    final cacheKey = 'matches_all_$dateStr';
    final ttl = dateStr == todayStr
        ? Duration(minutes: ApiCache.cacheMinutes)
        : const Duration(hours: 12);

    if (!forceRefresh) {
      final cachedJson = await ApiCache.get(cacheKey, ttl);
      if (cachedJson != null) {
        return FetchResult(data: _parseMatchListBody(cachedJson), fromCache: true);
      }
    }

    const int pageSize = 100;
    int offset = 0;
    final allRawItems = [];
    final allMatches = <MatchData>[];
    final seenIds = <String>{};

    // Lapozva lekérjük az adott nap ÖSSZES meccsét
    for (int page = 0; page < 10; page++) {
      final uri = Uri.parse(
        '${ApiConfig.baseUrl}/matches?date=$dateStr&timezone=Europe/Budapest&limit=$pageSize&offset=$offset',
      );
      final response = await http.get(uri, headers: ApiConfig.headers).timeout(const Duration(seconds: 12));

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('Érvénytelen API kulcs (${response.statusCode})');
      }
      if (response.statusCode == 429) {
        if (allMatches.isNotEmpty) break;
        throw Exception('API kéréskorlát (429) – várj pár másodpercet');
      }
      if (response.statusCode != 200) {
        if (allMatches.isNotEmpty) break;
        throw Exception('API hiba (${response.statusCode})');
      }

      await ApiCache.recordNetworkCall();

      final decoded = jsonDecode(response.body);
      final rawList = decoded is List
          ? decoded
          : (decoded is Map && decoded['data'] is List ? decoded['data'] : []);

      final mapItems = _asMapList(rawList);
      int newlyAdded = 0;
      for (final item in mapItems) {
        final mObj = _parseMatch(item as Map);
        if (!seenIds.contains(mObj.id)) {
          seenIds.add(mObj.id);
          allRawItems.add(item);
          allMatches.add(mObj);
          newlyAdded++;
        }
      }

      int? totalCount;
      if (decoded is Map && decoded['pagination'] is Map) {
        totalCount = int.tryParse('${decoded['pagination']['totalCount'] ?? ''}');
      }

      if (mapItems.length < pageSize || newlyAdded == 0) break;
      if (totalCount != null && allMatches.length >= totalCount) break;

      offset += pageSize;
      await Future.delayed(const Duration(milliseconds: 280));
    }

    if (allRawItems.isNotEmpty) {
      await ApiCache.put(cacheKey, jsonEncode(allRawItems));
    }

    return FetchResult(data: _sortMatches(allMatches), fromCache: false);
  }

  static List<MatchData> _parseMatchListBody(String body) {
    final decoded = jsonDecode(body);
    final rawList = decoded is List
        ? decoded
        : (decoded is Map && decoded['data'] is List ? decoded['data'] : []);
    final list = _asMapList(rawList).map((e) => _parseMatch(e as Map)).toList();
    return _sortMatches(list);
  }

  static MatchData _parseMatch(Map m) {
    final homeMap = m['homeTeam'] is Map ? m['homeTeam'] as Map : {};
    final awayMap = m['awayTeam'] is Map ? m['awayTeam'] as Map : {};
    final leagueMap = m['league'] is Map ? m['league'] as Map : {};
    final stateMap = m['state'] is Map ? m['state'] as Map : {};

    final homeName = (homeMap['name'] ?? m['homeTeam'] ?? 'Hazai').toString();
    final awayName = (awayMap['name'] ?? m['awayTeam'] ?? 'Vendég').toString();
    final homeId = homeMap['id']?.toString();
    final awayId = awayMap['id']?.toString();
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

    final isLive = descLower.contains('progress') ||
        descLower.contains('half') ||
        descLower.contains('live') ||
        descLower.contains('extra');

    final isFinished = descLower.contains('finish') ||
        descLower.contains('ended') ||
        descLower == 'ft' ||
        descLower == 'aet' ||
        descLower == 'pen';

    DateTime? kickoffDt;
    if (m['date'] != null && m['date'].toString().contains('T')) {
      kickoffDt = DateTime.tryParse(m['date'].toString())?.toLocal();
    }

    String statusLabel;
    if (isLive) {
      statusLabel = clock.isNotEmpty ? "$clock'" : 'ÉLŐ';
    } else if (isFinished) {
      statusLabel = 'VÉGE';
    } else if (kickoffDt != null) {
      statusLabel =
          '${kickoffDt.hour.toString().padLeft(2, '0')}:${kickoffDt.minute.toString().padLeft(2, '0')}';
    } else {
      statusLabel = desc.isNotEmpty ? desc : 'Később';
    }

    final parsedEvents = m['events'] is List
        ? _parseEventsList(m['events'] as List, homeName, homeId)
        : <MatchEvent>[];

    final statsParsed = m['statistics'] is List
        ? _parseStatisticsList(m['statistics'] as List)
        : null;

    return MatchData(
      id: (m['id'] ?? '${homeName}_$awayName').toString(),
      league: leagueName,
      homeTeam: homeName,
      awayTeam: awayName,
      homeTeamId: homeId,
      awayTeamId: awayId,
      homeLogo: homeMap['logo']?.toString(),
      awayLogo: awayMap['logo']?.toString(),
      homeColor: colorFromName(homeName),
      awayColor: colorFromName(awayName),
      homeScore: homeScore,
      awayScore: awayScore,
      status: statusLabel,
      isLive: isLive,
      isFinished: isFinished,
      kickoff: kickoffDt,
      isFromApi: true,
      possessionHome: statsParsed?['poss'] ?? 50,
      shotsHome: statsParsed?['shotsH'] ?? 0,
      shotsAway: statsParsed?['shotsA'] ?? 0,
      shotsOnTargetHome: statsParsed?['sotH'] ?? 0,
      shotsOnTargetAway: statsParsed?['sotA'] ?? 0,
      cornersHome: statsParsed?['cornH'] ?? 0,
      cornersAway: statsParsed?['cornA'] ?? 0,
      foulsHome: statsParsed?['foulH'] ?? 0,
      foulsAway: statsParsed?['foulA'] ?? 0,
      events: parsedEvents,
    );
  }

  static Map<String, int>? _parseStatisticsList(List list) {
    if (list.length < 2 || list[0] is! Map || list[1] is! Map) return null;
    final hStats = (list[0]['statistics'] is List ? list[0]['statistics'] : []) as List;
    final aStats = (list[1]['statistics'] is List ? list[1]['statistics'] : []) as List;
    if (hStats.isEmpty && aStats.isEmpty) return null;

    int readStat(List stats, List<String> keywords) {
      for (final item in stats) {
        if (item is Map) {
          final name = (item['displayName'] ?? item['type'] ?? item['name'] ?? item['title'] ?? '')
              .toString()
              .toLowerCase();
          if (keywords.any((k) => name.contains(k))) {
            final raw = (item['value'] ?? '0').toString().replaceAll('%', '').trim();
            return int.tryParse(raw) ?? 0;
          }
        }
      }
      return 0;
    }

    final p = readStat(hStats, ['possession']);
    return {
      'poss': p > 0 ? p : 50,
      'shotsH': readStat(hStats, ['total shots', 'shots']),
      'shotsA': readStat(aStats, ['total shots', 'shots']),
      'sotH': readStat(hStats, ['on target', 'shots on goal']),
      'sotA': readStat(aStats, ['on target', 'shots on goal']),
      'cornH': readStat(hStats, ['corner']),
      'cornA': readStat(aStats, ['corner']),
      'foulH': readStat(hStats, ['foul']),
      'foulA': readStat(aStats, ['foul']),
    };
  }

  static List<MatchEvent> _parseEventsList(List list, String homeTeamName, String? homeTeamId) {
    final parsed = <MatchEvent>[];
    for (final item in list) {
      if (item is Map) {
        final rawType = (item['type'] ?? item['event'] ?? '').toString().toLowerCase();
        String type = 'goal';
        if (rawType.contains('yellow')) {
          type = 'yellow';
        } else if (rawType.contains('red')) {
          type = 'red';
        } else if (!rawType.contains('goal') && !rawType.contains('pen')) {
          continue;
        }
        final teamObj = item['team'] is Map ? item['team'] as Map : {};
        final evTeamId = (teamObj['id'] ?? item['teamId'] ?? '').toString();
        final evTeamName = (teamObj['name'] ?? item['teamName'] ?? '').toString();
        final isHome = (homeTeamId != null && evTeamId.isNotEmpty && evTeamId == homeTeamId) ||
            evTeamName.toLowerCase() == homeTeamName.toLowerCase();

        final playerObj = item['player'] is Map ? item['player'] as Map : {};
        final player = (playerObj['name'] ?? item['player'] ?? item['playerName'] ?? 'Játékos').toString();
        final time = (item['time'] ?? item['minute'] ?? '').toString();
        parsed.add(MatchEvent(
          minute: time.endsWith("'") ? time : "$time'",
          player: player,
          type: type,
          isHome: isHome,
        ));
      }
    }
    return parsed;
  }

  static Future<FetchResult<MatchData>> enrichMatchDetails(
    MatchData base, {
    bool forceRefresh = false,
  }) async {
    if (!ApiConfig.hasValidKey || !base.isFromApi) {
      return FetchResult(data: base, fromCache: false);
    }

    final cacheKey = 'detail_${base.id}';
    final ttl = base.isFinished
        ? const Duration(hours: 12)
        : const Duration(seconds: 45);

    if (!forceRefresh) {
      final cachedJson = await ApiCache.get(cacheKey, ttl, savedWeight: 2);
      if (cachedJson != null) {
        final decoded = jsonDecode(cachedJson);
        if (decoded is Map) {
          final evList = _asMapList(decoded['events'])
              .map((e) => MatchEvent.fromJson(e as Map))
              .toList();
          final clipList = _asMapList(decoded['highlights'])
              .map((e) => HighlightClip.fromJson(e as Map))
              .toList();
          return FetchResult(
            fromCache: true,
            data: base.copyWith(
              homeScore: decoded['homeScore'] as int? ?? base.homeScore,
              awayScore: decoded['awayScore'] as int? ?? base.awayScore,
              status: decoded['status']?.toString() ?? base.status,
              isLive: decoded['isLive'] as bool? ?? base.isLive,
              isFinished: decoded['isFinished'] as bool? ?? base.isFinished,
              possessionHome: decoded['possessionHome'] as int? ?? base.possessionHome,
              shotsHome: decoded['shotsHome'] as int? ?? 0,
              shotsAway: decoded['shotsAway'] as int? ?? 0,
              shotsOnTargetHome: decoded['shotsOnTargetHome'] as int? ?? 0,
              shotsOnTargetAway: decoded['shotsOnTargetAway'] as int? ?? 0,
              cornersHome: decoded['cornersHome'] as int? ?? 0,
              cornersAway: decoded['cornersAway'] as int? ?? 0,
              foulsHome: decoded['foulsHome'] as int? ?? 0,
              foulsAway: decoded['foulsAway'] as int? ?? 0,
              events: evList,
              highlights: clipList,
              detailNote: decoded['detailNote']?.toString(),
            ),
          );
        }
      }
    }

    MatchData current = base;
    List<HighlightClip> clips = List.of(base.highlights);
    bool rateLimited = false;

    try {
      await ApiCache.recordNetworkCall();
      final matchRes = await http
          .get(Uri.parse('${ApiConfig.baseUrl}/matches/${base.id}'), headers: ApiConfig.headers)
          .timeout(const Duration(seconds: 9));
      if (matchRes.statusCode == 429) {
        rateLimited = true;
      } else if (matchRes.statusCode == 200) {
        final body = jsonDecode(matchRes.body);
        final obj = body is List && body.isNotEmpty
            ? body[0]
            : (body is Map && body['data'] is Map
                ? body['data']
                : (body is Map && body['data'] is List && (body['data'] as List).isNotEmpty
                    ? (body['data'] as List)[0]
                    : body));
        if (obj is Map) {
          final updated = _parseMatch(obj);
          current = current.copyWith(
            homeScore: updated.homeScore,
            awayScore: updated.awayScore,
            status: updated.status,
            isLive: updated.isLive,
            isFinished: updated.isFinished,
            possessionHome: updated.possessionHome,
            shotsHome: updated.shotsHome,
            shotsAway: updated.shotsAway,
            shotsOnTargetHome: updated.shotsOnTargetHome,
            shotsOnTargetAway: updated.shotsOnTargetAway,
            cornersHome: updated.cornersHome,
            cornersAway: updated.cornersAway,
            foulsHome: updated.foulsHome,
            foulsAway: updated.foulsAway,
            events: updated.events.isNotEmpty ? updated.events : current.events,
          );
        }
      }
    } catch (_) {}

    if (!rateLimited && current.shotsHome == 0 && current.shotsAway == 0) {
      await Future.delayed(const Duration(milliseconds: 350));
      try {
        await ApiCache.recordNetworkCall();
        final statRes = await http
            .get(Uri.parse('${ApiConfig.baseUrl}/match-statistics/${base.id}'), headers: ApiConfig.headers)
            .timeout(const Duration(seconds: 8));
        if (statRes.statusCode == 429) {
          rateLimited = true;
        } else if (statRes.statusCode == 200) {
          final body = jsonDecode(statRes.body);
          final list = body is List ? body : (body is Map && body['data'] is List ? body['data'] : []);
          final parsedStats = _parseStatisticsList(list);
          if (parsedStats != null) {
            current = current.copyWith(
              possessionHome: parsedStats['poss'],
              shotsHome: parsedStats['shotsH'],
              shotsAway: parsedStats['shotsA'],
              shotsOnTargetHome: parsedStats['sotH'],
              shotsOnTargetAway: parsedStats['sotA'],
              cornersHome: parsedStats['cornH'],
              cornersAway: parsedStats['cornA'],
              foulsHome: parsedStats['foulH'],
              foulsAway: parsedStats['foulA'],
            );
          }
        }
      } catch (_) {}
    }

    if (!rateLimited && current.events.isEmpty) {
      await Future.delayed(const Duration(milliseconds: 350));
      try {
        await ApiCache.recordNetworkCall();
        final evRes = await http
            .get(Uri.parse('${ApiConfig.baseUrl}/live-events/${base.id}'), headers: ApiConfig.headers)
            .timeout(const Duration(seconds: 8));
        if (evRes.statusCode == 429) {
          rateLimited = true;
        } else if (evRes.statusCode == 200) {
          final body = jsonDecode(evRes.body);
          final list = body is List ? body : (body is Map && body['data'] is List ? body['data'] : []);
          final parsedEvents = _parseEventsList(list, current.homeTeam, current.homeTeamId);
          if (parsedEvents.isNotEmpty) {
            current = current.copyWith(events: parsedEvents);
          }
        }
      } catch (_) {}
    }

    if (!rateLimited) {
      await Future.delayed(const Duration(milliseconds: 350));
      try {
        await ApiCache.recordNetworkCall();
        final hlRes = await http
            .get(Uri.parse('${ApiConfig.baseUrl}/highlights?matchId=${base.id}'), headers: ApiConfig.headers)
            .timeout(const Duration(seconds: 8));
        if (hlRes.statusCode == 200) {
          final body = jsonDecode(hlRes.body);
          final list = body is List ? body : (body is Map && body['data'] is List ? body['data'] : []);
          final parsedClips = <HighlightClip>[];
          for (final item in list) {
            if (item is Map && item['url'] != null) {
              parsedClips.add(HighlightClip(
                title: (item['title'] ?? '${base.homeTeam} - ${base.awayTeam} összefoglaló').toString(),
                url: item['url'].toString(),
                thumbnail: item['imgUrl']?.toString(),
              ));
            }
          }
          if (parsedClips.isNotEmpty) clips = parsedClips;
        }
      } catch (_) {}
    }

    String? note;
    if (rateLimited) {
      note = 'API kéréskorlát (429) – várj pár másodpercet, majd koppints a frissítésre!';
    } else if (current.events.isEmpty && current.shotsHome == 0 && current.shotsAway == 0) {
      note = 'Ehhez a bajnoksághoz az API jelenleg csak az élő állást közli, részletes statisztikát nem.';
    }

    final finalMatch = current.copyWith(highlights: clips, detailNote: note);

    if (!rateLimited) {
      await ApiCache.put(
        cacheKey,
        jsonEncode({
          'homeScore': finalMatch.homeScore,
          'awayScore': finalMatch.awayScore,
          'status': finalMatch.status,
          'isLive': finalMatch.isLive,
          'isFinished': finalMatch.isFinished,
          'possessionHome': finalMatch.possessionHome,
          'shotsHome': finalMatch.shotsHome,
          'shotsAway': finalMatch.shotsAway,
          'shotsOnTargetHome': finalMatch.shotsOnTargetHome,
          'shotsOnTargetAway': finalMatch.shotsOnTargetAway,
          'cornersHome': finalMatch.cornersHome,
          'cornersAway': finalMatch.cornersAway,
          'foulsHome': finalMatch.foulsHome,
          'foulsAway': finalMatch.foulsAway,
          'events': finalMatch.events.map((e) => e.toJson()).toList(),
          'highlights': finalMatch.highlights.map((c) => c.toJson()).toList(),
          'detailNote': note,
        }),
      );
    }

    return FetchResult(fromCache: false, data: finalMatch);
  }

  static Future<FetchResult<List<StandingRow>>> fetchStandings(
    int leagueId, {
    bool forceRefresh = false,
  }) async {
    if (!ApiConfig.hasValidKey) throw Exception('Nincs API kulcs');

    final cacheKey = 'standings_$leagueId';
    if (!forceRefresh) {
      final cachedJson = await ApiCache.get(cacheKey, const Duration(hours: 2));
      if (cachedJson != null) {
        return FetchResult(data: _parseStandingsBody(cachedJson), fromCache: true);
      }
    }

    final uri = Uri.parse('${ApiConfig.baseUrl}/standings?leagueId=$leagueId');
    final res = await http.get(uri, headers: ApiConfig.headers).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) throw Exception('Tabella hiba (${res.statusCode})');

    await ApiCache.recordNetworkCall();
    await ApiCache.put(cacheKey, res.body);

    return FetchResult(data: _parseStandingsBody(res.body), fromCache: false);
  }

  static List<StandingRow> _parseStandingsBody(String body) {
    final decoded = jsonDecode(body);
    List rows = [];
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

    return _asMapList(rows).map((item) {
      final r = item as Map;
      final teamMap = r['team'] is Map ? r['team'] as Map : {};
      final totalMap = r['total'] is Map ? r['total'] as Map : r;
      final teamName = (teamMap['name'] ?? r['teamName'] ?? 'Csapat').toString();
      final pos = int.tryParse('${r['position'] ?? r['pos'] ?? 0}') ?? 0;
      final played = int.tryParse('${totalMap['games'] ?? totalMap['played'] ?? 0}') ?? 0;
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
      HighlightClip(title: 'Real Madrid - Liverpool 2-2 | Összefoglaló (Demo)', url: 'https://highlightly.net'),
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
    isFinished: true,
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

const sampleStandings = {
  'Premier League': [
    StandingRow(pos: 1, team: 'Liverpool', color: Color(0xFFFF1744), played: 12, gd: 17, points: 31, zone: 'ucl'),
    StandingRow(pos: 2, team: 'Man. City', color: Color(0xFF00B0FF), played: 12, gd: 11, points: 26, zone: 'ucl'),
    StandingRow(pos: 3, team: 'Arsenal', color: Color(0xFFFF5252), played: 12, gd: 9, points: 24, zone: 'ucl'),
    StandingRow(pos: 4, team: 'Chelsea', color: Color(0xFF2979FF), played: 12, gd: 8, points: 22, zone: 'ucl'),
  ],
  'Bajnokok Ligája': [
    StandingRow(pos: 1, team: 'Liverpool', color: Color(0xFFFF1744), played: 5, gd: 11, points: 15, zone: 'ucl'),
    StandingRow(pos: 2, team: 'Barcelona', color: Color(0xFF2979FF), played: 5, gd: 13, points: 12, zone: 'ucl'),
    StandingRow(pos: 3, team: 'Arsenal', color: Color(0xFFFF5252), played: 5, gd: 6, points: 10, zone: 'ucl'),
  ],
  'La Liga': [
    StandingRow(pos: 1, team: 'Barcelona', color: Color(0xFF2979FF), played: 13, gd: 28, points: 33, zone: 'ucl'),
    StandingRow(pos: 2, team: 'Real Madrid', color: Color(0xFF7C4DFF), played: 13, gd: 16, points: 30, zone: 'ucl'),
  ],
};
