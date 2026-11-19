import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ApiProvider { highlightly, statpal }

// --- MAGYAROSÍTÓ SEGÉDOSZTÁLY (ORSZÁG ÉS BAJNOKSÁG NEVEK) ---
class HungarianLocalization {
  static const Map<String, String> _countryMap = {
    'england': 'Anglia',
    'spain': 'Spanyolország',
    'germany': 'Németország',
    'italy': 'Olaszország',
    'france': 'Franciaország',
    'hungary': 'Magyarország',
    'netherlands': 'Hollandia',
    'portugal': 'Portugália',
    'belgium': 'Belgium',
    'austria': 'Ausztria',
    'switzerland': 'Svájc',
    'scotland': 'Skócia',
    'wales': 'Wales',
    'ireland': 'Írország',
    'poland': 'Lengyelország',
    'czech republic': 'Csehország',
    'czechia': 'Csehország',
    'slovakia': 'Szlovákia',
    'romania': 'Románia',
    'croatia': 'Horvátország',
    'serbia': 'Szerbia',
    'greece': 'Görögország',
    'turkey': 'Törökország',
    'ukraine': 'Ukrajna',
    'russia': 'Oroszország',
    'sweden': 'Svédország',
    'norway': 'Norvégia',
    'denmark': 'Dánia',
    'finland': 'Finnország',
    'brazil': 'Brazília',
    'argentina': 'Argentína',
    'usa': 'Egyesült Államok',
    'united states': 'Egyesült Államok',
    'mexico': 'Mexikó',
    'japan': 'Japán',
    'south korea': 'Dél-Korea',
    'china': 'Kína',
    'saudi arabia': 'Szaúd-Arábia',
    'qatar': 'Katar',
    'australia': 'Ausztrália',
    'world': 'Nemzetközi',
    'international': 'Nemzetközi',
    'europe': 'Európa',
  };

  static const Map<String, String> _leagueMap = {
    'champions league': 'Bajnokok Ligája',
    'uefa champions league': 'Bajnokok Ligája',
    'europa league': 'Európa Liga',
    'uefa europa league': 'Európa Liga',
    'conference league': 'Konferencia Liga',
    'uefa europa conference league': 'Konferencia Liga',
    'premier league': 'Premier League',
    'la liga': 'La Liga',
    'laliga': 'La Liga',
    'bundesliga': 'Bundesliga',
    '2. bundesliga': 'Bundesliga 2',
    'serie a': 'Serie A',
    'serie b': 'Serie B',
    'ligue 1': 'Ligue 1',
    'ligue 2': 'Ligue 2',
    'nb i': 'NB I',
    'otp bank liga': 'NB I',
    'nemzeti bajnoksag i': 'NB I',
    'eredivisie': 'Eredivisie',
    'primeira liga': 'Liga Portugal',
    'liga portugal': 'Liga Portugal',
    'super lig': 'Süper Lig',
    'süper lig': 'Süper Lig',
    'ekstraklasa': 'Ekstraklasa',
    'major league soccer': 'MLS',
    'mls': 'MLS',
    'world cup': 'Világbajnokság',
    'euro': 'Európa-bajnokság',
    'european championship': 'Európa-bajnokság',
    'fa cup': 'FA-kupa',
    'copa del rey': 'Spanyol Király-kupa',
    'dfb pokal': 'Német Kupa',
    'dfb-pokal': 'Német Kupa',
    'coppa italia': 'Olasz Kupa',
    'coupe de france': 'Francia Kupa',
    'magyar kupa': 'Magyar Kupa',
  };

  static const Map<String, String> _leagueToCountryFallback = {
    'premier league': 'Anglia',
    'fa cup': 'Anglia',
    'efl cup': 'Anglia',
    'championship': 'Anglia',
    'la liga': 'Spanyolország',
    'laliga': 'Spanyolország',
    'copa del rey': 'Spanyolország',
    'bundesliga': 'Németország',
    '2. bundesliga': 'Németország',
    'dfb pokal': 'Németország',
    'dfb-pokal': 'Németország',
    'serie a': 'Olaszország',
    'serie b': 'Olaszország',
    'coppa italia': 'Olaszország',
    'ligue 1': 'Franciaország',
    'ligue 2': 'Franciaország',
    'coupe de france': 'Franciaország',
    'nb i': 'Magyarország',
    'otp bank liga': 'Magyarország',
    'magyar kupa': 'Magyarország',
    'eredivisie': 'Hollandia',
    'primeira liga': 'Portugália',
    'liga portugal': 'Portugália',
    'super lig': 'Törökország',
    'süper lig': 'Törökország',
    'ekstraklasa': 'Lengyelország',
    'mls': 'Egyesült Államok',
    'major league soccer': 'Egyesült Államok',
    'bajnokok ligája': 'Európa',
    'champions league': 'Európa',
    'európa liga': 'Európa',
    'europa league': 'Európa',
    'konferencia liga': 'Európa',
    'conference league': 'Európa',
  };

  static String localizeCountry(String? rawCountry, {String? leagueName}) {
    final cleaned = (rawCountry ?? '').trim();
    if (cleaned.isNotEmpty) {
      final lower = cleaned.toLowerCase();
      if (_countryMap.containsKey(lower)) return _countryMap[lower]!;
      return _titleCase(cleaned);
    }

    final lCleaned = (leagueName ?? '').trim().toLowerCase();
    for (final entry in _leagueToCountryFallback.entries) {
      if (lCleaned.contains(entry.key)) return entry.value;
    }
    return 'Nemzetközi';
  }

  static String localizeLeague(String? rawLeague, {String? countryName}) {
    var cleaned = (rawLeague ?? '').trim();
    if (cleaned.isEmpty) return 'Egyéb bajnokság';

    final lower = cleaned.toLowerCase();
    if (_leagueMap.containsKey(lower)) {
      return _leagueMap[lower]!;
    }

    // Ha az ország neve szerepel a liga elején (pl. "England - Premier League"), szétválasztjuk
    if (countryName != null && countryName.trim().isNotEmpty) {
      final cLower = countryName.trim().toLowerCase();
      final prefixPattern = RegExp('^${RegExp.escape(cLower)}\\s*[-:–|]\\s*', caseSensitive: false);
      cleaned = cleaned.replaceFirst(prefixPattern, '').trim();
    }

    for (final entry in _leagueMap.entries) {
      if (cleaned.toLowerCase() == entry.key) return entry.value;
    }

    return _titleCase(cleaned);
  }

  static String _titleCase(String input) {
    if (input.isEmpty) return input;
    return input
        .split(RegExp(r'\s+'))
        .map((w) {
          if (w.isEmpty) return w;
          final upperCheck = w.toUpperCase();
          if (upperCheck == 'UEFA' || upperCheck == 'FIFA' || upperCheck == 'MLS' || upperCheck == 'NB') {
            return upperCheck;
          }
          return w[0].toUpperCase() + w.substring(1);
        })
        .join(' ');
  }
}

// --- TARTÓS API KONFIGURÁCIÓ ---
class ApiConfig {
  static const _providerPref = 'zsolt_api_provider';
  static const _hlKeyPref = 'highlightly_api_key';
  static const _hlRapidPref = 'highlightly_use_rapidapi';
  static const _spKeyPref = 'statpal_api_key';

  static ApiProvider provider = ApiProvider.highlightly;
  static String highlightlyKey = '';
  static bool useRapidApi = false;
  static String statpalKey = '';

  static bool get isStatPal => provider == ApiProvider.statpal;
  static String get activeKey => isStatPal ? statpalKey : highlightlyKey;
  static bool get hasValidKey => activeKey.trim().isNotEmpty;
  static String get providerTag => isStatPal ? 'sp2' : 'hl';
  static String get providerName => isStatPal ? 'StatPal V2' : 'Highlightly';

  static String get highlightlyBaseUrl => useRapidApi
      ? 'https://football-highlights-api.p.rapidapi.com'
      : 'https://soccer.highlightly.net';

  static Map<String, String> get highlightlyHeaders => {
        'x-rapidapi-key': highlightlyKey.trim(),
        if (useRapidApi) 'x-rapidapi-host': 'football-highlights-api.p.rapidapi.com',
      };

  static const String statpalV2BaseUrl = 'https://statpal.io/api/v2/soccer';
  static const String statpalV1BaseUrl = 'https://statpal.io/api/v1/soccer';
  static const String statpalUsageUrl = 'https://statpal.io/api/user-request-count';

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedProv = prefs.getString(_providerPref) ?? 'highlightly';
    provider = savedProv == 'statpal' ? ApiProvider.statpal : ApiProvider.highlightly;
    highlightlyKey = prefs.getString(_hlKeyPref) ?? '';
    useRapidApi = prefs.getBool(_hlRapidPref) ?? false;
    statpalKey = prefs.getString(_spKeyPref) ?? '';
  }

  static Future<void> save({
    required ApiProvider newProvider,
    required String newHighlightlyKey,
    required bool rapid,
    required String newStatpalKey,
  }) async {
    provider = newProvider;
    highlightlyKey = newHighlightlyKey.trim();
    useRapidApi = rapid;
    statpalKey = newStatpalKey.trim();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_providerPref, isStatPal ? 'statpal' : 'highlightly');
    await prefs.setString(_hlKeyPref, highlightlyKey);
    await prefs.setBool(_hlRapidPref, useRapidApi);
    await prefs.setString(_spKeyPref, statpalKey);
  }
}

// --- HELYI LOGÓ LETÖLTŐ ÉS TÁROLÓ (A RATE LIMIT ELKERÜLÉSÉRE) ---
class LogoCache {
  static Directory? _logoDir;
  static final Map<String, File> _memoryIndex = {};
  static final Set<String> _inFlight = {};
  static int savedLogosCount = 0;

  static Future<void> init() async {
    try {
      final baseDir = await getTemporaryDirectory();
      final dir = Directory('${baseDir.path}/zsoltscores_logos');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      _logoDir = dir;
      await refreshCount();
    } catch (_) {}
  }

  static Future<void> refreshCount() async {
    final dir = _logoDir;
    if (dir == null || !await dir.exists()) {
      savedLogosCount = 0;
      return;
    }
    try {
      final entities = await dir.list().toList();
      savedLogosCount = entities.whereType<File>().length;
    } catch (_) {}
  }

  static String _safeFileName(String url) {
    final hash = url.codeUnits.fold<int>(5381, (h, c) => ((h << 5) + h) ^ c) & 0x7fffffff;
    final cleanTail = url.split('?').first.toLowerCase();
    final ext = cleanTail.endsWith('.jpg') || cleanTail.endsWith('.jpeg') ? 'jpg' : 'png';
    return 'logo_$hash.$ext';
  }

  static String? normalizeUrl(String? rawUrl) {
    if (rawUrl == null) return null;
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('//')) {
      return 'https:$trimmed';
    }
    if (trimmed.startsWith('/')) {
      return 'https://statpal.io$trimmed';
    }
    return 'https://statpal.io/$trimmed';
  }

  static Future<File?> getOrDownload(String? rawUrl) async {
    final url = normalizeUrl(rawUrl);
    if (url == null) return null;

    if (_memoryIndex.containsKey(url)) {
      final cachedFile = _memoryIndex[url]!;
      if (await cachedFile.exists()) return cachedFile;
    }

    if (_logoDir == null) await init();
    final dir = _logoDir;
    if (dir == null) return null;

    final file = File('${dir.path}/${_safeFileName(url)}');
    if (await file.exists()) {
      final len = await file.length();
      if (len > 0) {
        _memoryIndex[url] = file;
        return file;
      }
    }

    if (_inFlight.contains(url)) return null;
    _inFlight.add(url);

    try {
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        await file.writeAsBytes(res.bodyBytes, flush: true);
        _memoryIndex[url] = file;
        savedLogosCount++;
        return file;
      }
    } catch (_) {
    } finally {
      _inFlight.remove(url);
    }
    return null;
  }

  static Future<int> clearAll() async {
    _memoryIndex.clear();
    final dir = _logoDir;
    if (dir == null || !await dir.exists()) return 0;
    int removed = 0;
    try {
      await for (final entity in dir.list()) {
        if (entity is File) {
          await entity.delete();
          removed++;
        }
      }
    } catch (_) {}
    savedLogosCount = 0;
    return removed;
  }
}

// --- HELYI JSON ADATTÁROLÓ (CACHE) ---
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
  final String country;
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
    this.country = 'Nemzetközi',
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

  String get fullCompetitionLabel => '$country • $league';

  Map toCacheMap() => {
        'id': id,
        'country': country,
        'league': league,
        'homeTeam': homeTeam,
        'awayTeam': awayTeam,
        'homeTeamId': homeTeamId,
        'awayTeamId': awayTeamId,
        'homeLogo': homeLogo,
        'awayLogo': awayLogo,
        'homeScore': homeScore,
        'awayScore': awayScore,
        'status': status,
        'isLive': isLive,
        'isFinished': isFinished,
        'kickoff': kickoff?.toIso8601String(),
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
        'highlights': highlights.map((c) => c.toJson()).toList(),
        'detailNote': detailNote,
      };

  factory MatchData.fromCacheMap(Map json) {
    final homeName = (json['homeTeam'] ?? 'Hazai').toString();
    final awayName = (json['awayTeam'] ?? 'Vendég').toString();
    final rawLeague = (json['league'] ?? 'Egyéb bajnokság').toString();
    final rawCountry = json['country']?.toString();
    final localizedCountry = HungarianLocalization.localizeCountry(rawCountry, leagueName: rawLeague);
    final localizedLeague = HungarianLocalization.localizeLeague(rawLeague, countryName: localizedCountry);

    final evList = <MatchEvent>[];
    if (json['events'] is List) {
      for (final e in json['events']) {
        if (e is Map) evList.add(MatchEvent.fromJson(e));
      }
    }
    final clipList = <HighlightClip>[];
    if (json['highlights'] is List) {
      for (final c in json['highlights']) {
        if (c is Map) clipList.add(HighlightClip.fromJson(c));
      }
    }
    return MatchData(
      id: (json['id'] ?? '').toString(),
      country: localizedCountry,
      league: localizedLeague,
      homeTeam: homeName,
      awayTeam: awayName,
      homeTeamId: json['homeTeamId']?.toString(),
      awayTeamId: json['awayTeamId']?.toString(),
      homeLogo: json['homeLogo']?.toString(),
      awayLogo: json['awayLogo']?.toString(),
      homeColor: SportsApiService.colorFromName(homeName),
      awayColor: SportsApiService.colorFromName(awayName),
      homeScore: json['homeScore'] as int? ?? 0,
      awayScore: json['awayScore'] as int? ?? 0,
      status: (json['status'] ?? '').toString(),
      isLive: json['isLive'] == true,
      isFinished: json['isFinished'] == true,
      kickoff: json['kickoff'] != null ? DateTime.tryParse(json['kickoff'].toString()) : null,
      isFromApi: true,
      possessionHome: json['possessionHome'] as int? ?? 50,
      shotsHome: json['shotsHome'] as int? ?? 0,
      shotsAway: json['shotsAway'] as int? ?? 0,
      shotsOnTargetHome: json['shotsOnTargetHome'] as int? ?? 0,
      shotsOnTargetAway: json['shotsOnTargetAway'] as int? ?? 0,
      cornersHome: json['cornersHome'] as int? ?? 0,
      cornersAway: json['cornersAway'] as int? ?? 0,
      foulsHome: json['foulsHome'] as int? ?? 0,
      foulsAway: json['foulsAway'] as int? ?? 0,
      events: evList,
      highlights: clipList,
      detailNote: json['detailNote']?.toString(),
    );
  }

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
      country: country,
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

// --- EGYESÍTETT SPORTS API SZOLGÁLTATÁS (HIGHLIGHTLY + STATPAL V2) ---
class SportsApiService {
  static List _asMapList(dynamic input) {
    if (input is List) {
      return input.whereType().toList();
    }
    if (input is Map) {
      return [input];
    }
    return [];
  }

  static dynamic _attr(Map m, List<String> keys) {
    for (final k in keys) {
      if (m.containsKey(k) && m[k] != null) return m[k];
      if (m.containsKey('@$k') && m['@$k'] != null) return m['@$k'];
    }
    return null;
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
      if (a.isLive != b.isLive) return a.isLive ? -1 : 1;
      if (a.isFinished != b.isFinished) return a.isFinished ? 1 : -1;
      if (a.kickoff != null && b.kickoff != null) {
        final cmp = a.kickoff!.compareTo(b.kickoff!);
        if (cmp != 0) return cmp;
      }
      return a.fullCompetitionLabel.compareTo(b.fullCompetitionLabel);
    });
    return sorted;
  }

  // =========================================================================
  // 0. STATPAL HASZNÁLATFIGYELŐ (NEM FOGYASZT KVÓTÁT!)
  // =========================================================================
  static Future<String> fetchStatPalDailyUsage(String rawKey) async {
    final k = rawKey.trim();
    if (k.isEmpty) return 'Nincs megadva StatPal kulcs.';
    final uri = Uri.parse('${ApiConfig.statpalUsageUrl}?access_key=${Uri.encodeComponent(k)}');
    final res = await http.get(uri).timeout(const Duration(seconds: 8));
    if (res.statusCode == 401) return 'Érvénytelen vagy lejárt StatPal kulcs (401).';
    if (res.statusCode != 200) return 'Lekérdezési hiba (${res.statusCode}).';

    final decoded = jsonDecode(res.body);
    if (decoded is Map) {
      final count = decoded['request_count'] ??
          decoded['requests'] ??
          decoded['count'] ??
          decoded['today'] ??
          decoded['data'];
      if (count != null) {
        return 'Mai StatPal API kérések: $count db';
      }
      return 'Válasz: ${res.body}';
    }
    return 'Mai kérések: ${res.body}';
  }

  // =========================================================================
  // 1. NAPI MECCSEK LEKÉRÉSE
  // =========================================================================
  static Future<FetchResult<List<MatchData>>> fetchMatches(
    DateTime date, {
    bool forceRefresh = false,
  }) async {
    if (!ApiConfig.hasValidKey) throw Exception('Nincs megadva API kulcs');

    final dateStr = formatDate(date);
    final todayStr = formatDate(DateTime.now());
    final cacheKey = '${ApiConfig.providerTag}_matches_hu_$dateStr';
    final ttl = dateStr == todayStr
        ? Duration(minutes: ApiCache.cacheMinutes)
        : const Duration(hours: 12);

    if (!forceRefresh) {
      final cachedJson = await ApiCache.get(cacheKey, ttl);
      if (cachedJson != null) {
        final decoded = jsonDecode(cachedJson);
        final list = _asMapList(decoded).map((e) => MatchData.fromCacheMap(e as Map)).toList();
        return FetchResult(data: _sortMatches(list), fromCache: true);
      }
    }

    final matches = ApiConfig.isStatPal
        ? await _fetchStatPalV2Matches(date)
        : await _fetchHighlightlyMatches(dateStr);

    final sorted = _sortMatches(matches);
    if (sorted.isNotEmpty) {
      await ApiCache.put(cacheKey, jsonEncode(sorted.map((m) => m.toCacheMap()).toList()));
    }
    return FetchResult(data: sorted, fromCache: false);
  }

  // --- HIGHLIGHTLY MECCSEK ---
  static Future<List<MatchData>> _fetchHighlightlyMatches(String dateStr) async {
    const int pageSize = 100;
    int offset = 0;
    final allMatches = <MatchData>[];
    final seenIds = <String>{};

    for (int page = 0; page < 10; page++) {
      final uri = Uri.parse(
        '${ApiConfig.highlightlyBaseUrl}/matches?date=$dateStr&timezone=Europe/Budapest&limit=$pageSize&offset=$offset',
      );
      final response = await http
          .get(uri, headers: ApiConfig.highlightlyHeaders)
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('Érvénytelen Highlightly API kulcs (${response.statusCode})');
      }
      if (response.statusCode == 429) {
        if (allMatches.isNotEmpty) break;
        throw Exception('Highlightly API kéréskorlát (429) – várj pár másodpercet');
      }
      if (response.statusCode != 200) {
        if (allMatches.isNotEmpty) break;
        throw Exception('Highlightly API hiba (${response.statusCode})');
      }

      await ApiCache.recordNetworkCall();

      final decoded = jsonDecode(response.body);
      final rawList = decoded is List
          ? decoded
          : (decoded is Map && decoded['data'] is List ? decoded['data'] : []);

      final mapItems = _asMapList(rawList);
      int newlyAdded = 0;
      for (final item in mapItems) {
        final mObj = _parseHighlightlyMatch(item as Map);
        if (!seenIds.contains(mObj.id)) {
          seenIds.add(mObj.id);
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

    return allMatches;
  }

  // --- STATPAL SOCCER V2 MECCSEK ---
  static Future<List<MatchData>> _fetchStatPalV2Matches(DateTime targetDate) async {
    final key = Uri.encodeComponent(ApiConfig.statpalKey.trim());
    final dateStr = formatDate(targetDate);
    final now = DateTime.now();
    final todayOnly = DateTime(now.year, now.month, now.day);
    final targetOnly = DateTime(targetDate.year, targetDate.month, targetDate.day);

    final byId = <String, MatchData>{};

    Future<List<MatchData>> tryFetch(String fullUrl, {required bool filterByDate}) async {
      final res = await http.get(Uri.parse(fullUrl)).timeout(const Duration(seconds: 12));
      if (res.statusCode == 401 || res.statusCode == 403) {
        throw Exception('Érvénytelen vagy lejárt StatPal API kulcs (${res.statusCode})');
      }
      if (res.statusCode == 429) {
        throw Exception('StatPal kéréskorlát (429) – várj 15 másodpercet');
      }
      if (res.statusCode != 200) return [];
      final body = jsonDecode(res.body);
      if (body is Map && body['error'] != null) return [];
      await ApiCache.recordNetworkCall();
      return _parseStatPalAnyPayload(body, targetDate, filterByDate: filterByDate);
    }

    try {
      final v2Daily = await tryFetch(
        '${ApiConfig.statpalV2BaseUrl}/matches?date=$dateStr&access_key=$key',
        filterByDate: false,
      );
      for (final m in v2Daily) {
        byId[m.id] = m;
      }
    } catch (e) {
      if (e.toString().contains('401') || e.toString().contains('403') || e.toString().contains('429')) {
        rethrow;
      }
    }

    if (targetOnly == todayOnly) {
      try {
        final v2Live = await tryFetch(
          '${ApiConfig.statpalV2BaseUrl}/matches/live?access_key=$key',
          filterByDate: false,
        );
        for (final m in v2Live) {
          byId[m.id] = m;
        }
      } catch (e) {
        if (byId.isEmpty) rethrow;
      }
    }

    if (byId.isEmpty) {
      final fallbackPaths = targetOnly == todayOnly
          ? ['livescore', 'upcoming-schedule', 'results']
          : (targetOnly.isAfter(todayOnly) ? ['upcoming-schedule'] : ['results']);
      for (final p in fallbackPaths) {
        try {
          final list = await tryFetch(
            '${ApiConfig.statpalV1BaseUrl}/$p?access_key=$key',
            filterByDate: p != 'livescore',
          );
          for (final m in list) {
            byId.putIfAbsent(m.id, () => m);
          }
        } catch (_) {}
      }
    }

    return byId.values.toList();
  }

  static List<MatchData> _parseStatPalAnyPayload(
    dynamic decoded,
    DateTime targetDate, {
    required bool filterByDate,
  }) {
    final results = <MatchData>[];
    if (decoded == null) return results;

    List? directList;
    if (decoded is List) {
      directList = decoded;
    } else if (decoded is Map) {
      if (decoded['data'] is List) {
        directList = decoded['data'] as List;
      } else if (decoded['matches'] is List) {
        directList = decoded['matches'] as List;
      }
    }

    if (directList != null) {
      for (final item in directList) {
        if (item is Map) {
          final leagueObj = item['league'] ?? item['competition'] ?? item['tournament'];
          final rawLeague = leagueObj is Map
              ? (_attr(leagueObj, ['name', 'title']) ?? 'Egyéb bajnokság').toString()
              : (leagueObj?.toString() ?? 'Egyéb bajnokság');
          final rawCountry = (leagueObj is Map
                  ? (_attr(leagueObj, ['country', 'country_name', 'nation']) ?? '')
                  : '')
              .toString();
          final dateRaw = (_attr(item, ['date', 'match_date', 'kickoff', 'start_time', 'utc_date']) ?? '').toString();
          if (filterByDate && !_statPalMatchesDate(dateRaw, targetDate)) continue;
          results.add(_parseStatPalSingleMatch(item, rawLeague, rawCountry: rawCountry));
        }
      }
      return results;
    }

    if (decoded is! Map) return results;

    final root = decoded['livescore'] ??
        decoded['scores'] ??
        decoded['fixtures'] ??
        decoded['schedule'] ??
        decoded['results'] ??
        decoded['data'] ??
        decoded;

    if (root is! Map) return results;

    final leagues = _asMapList(root['league'] ?? root['leagues'] ?? root['tournament']);
    for (final lItem in leagues) {
      final lMap = lItem as Map;
      final rawLeague = (_attr(lMap, ['name', 'league_name']) ?? 'Egyéb bajnokság').toString();
      final rawCountry = (_attr(lMap, ['country', 'country_name', 'nation']) ?? '').toString();
      final matches = _asMapList(lMap['match'] ?? lMap['matches'] ?? lMap['fixture']);
      for (final mItem in matches) {
        final mMap = mItem as Map;
        final dateRaw = (_attr(mMap, ['date', 'match_date', 'formatted_date']) ?? '').toString();
        if (filterByDate && !_statPalMatchesDate(dateRaw, targetDate)) {
          continue;
        }
        results.add(_parseStatPalSingleMatch(mMap, rawLeague, rawCountry: rawCountry));
      }
    }

    return results;
  }

  static bool _statPalMatchesDate(String dateRaw, DateTime target) {
    if (dateRaw.trim().isEmpty) return true;
    final ymd = formatDate(target);
    final dmyDot =
        '${target.day.toString().padLeft(2, '0')}.${target.month.toString().padLeft(2, '0')}.${target.year}';
    final dmySlash = dmyDot.replaceAll('.', '/');
    return dateRaw.startsWith(ymd) ||
        dateRaw.startsWith(dmyDot) ||
        dateRaw.startsWith(dmySlash);
  }

  static DateTime? _parseStatPalDateTime(String dateRaw, String timeRaw) {
    if (dateRaw.isEmpty) return null;
    if (dateRaw.contains('T')) {
      return DateTime.tryParse(dateRaw)?.toLocal();
    }
    int? y, m, d;
    if (dateRaw.contains('-')) {
      final p = dateRaw.split('-');
      if (p.length >= 3) {
        y = int.tryParse(p[0]);
        m = int.tryParse(p[1]);
        d = int.tryParse(p[2]);
      }
    } else if (dateRaw.contains('.') || dateRaw.contains('/')) {
      final p = dateRaw.split(RegExp(r'[./]'));
      if (p.length >= 3) {
        d = int.tryParse(p[0]);
        m = int.tryParse(p[1]);
        y = int.tryParse(p[2]);
      }
    }
    if (y == null || m == null || d == null) return null;
    int hh = 0, mm = 0;
    if (timeRaw.contains(':')) {
      final tp = timeRaw.split(':');
      hh = int.tryParse(tp[0]) ?? 0;
      mm = int.tryParse(tp[1]) ?? 0;
    }
    return DateTime(y, m, d, hh, mm);
  }

  static MatchData _parseStatPalSingleMatch(Map m, String rawLeagueName, {String rawCountry = ''}) {
    final homeRaw = m['home'] ?? m['localteam'] ?? m['homeTeam'] ?? m['home_team'];
    final awayRaw = m['away'] ?? m['visitorteam'] ?? m['awayTeam'] ?? m['away_team'];

    final homeMap = homeRaw is Map ? homeRaw : {};
    final awayMap = awayRaw is Map ? awayRaw : {};

    final homeName = homeRaw is Map
        ? (_attr(homeMap, ['name', 'team_name', 'short_name']) ?? 'Hazai').toString()
        : (homeRaw?.toString() ?? 'Hazai');
    final awayName = awayRaw is Map
        ? (_attr(awayMap, ['name', 'team_name', 'short_name']) ?? 'Vendég').toString()
        : (awayRaw?.toString() ?? 'Vendég');

    final countryCandidate = rawCountry.isNotEmpty
        ? rawCountry
        : (_attr(m, ['country', 'country_name', 'nation']) ?? '').toString();
    final country = HungarianLocalization.localizeCountry(countryCandidate, leagueName: rawLeagueName);
    final league = HungarianLocalization.localizeLeague(rawLeagueName, countryName: country);

    final homeId = _attr(homeMap, ['id'])?.toString();
    final awayId = _attr(awayMap, ['id'])?.toString();
    final homeLogo = LogoCache.normalizeUrl(
      (_attr(homeMap, ['logo', 'image', 'badge', 'crest', 'icon']) ?? m['home_logo'])?.toString(),
    );
    final awayLogo = LogoCache.normalizeUrl(
      (_attr(awayMap, ['logo', 'image', 'badge', 'crest', 'icon']) ?? m['away_logo'])?.toString(),
    );

    final scoreMap = m['score'] is Map ? m['score'] as Map : {};
    int homeScore = int.tryParse(
          '${_attr(homeMap, ['goals', 'score']) ?? _attr(scoreMap, ['home', 'localteam']) ?? _attr(m, ['home_score', 'homeScore']) ?? ''}',
        ) ??
        0;
    int awayScore = int.tryParse(
          '${_attr(awayMap, ['goals', 'score']) ?? _attr(scoreMap, ['away', 'visitorteam']) ?? _attr(m, ['away_score', 'awayScore']) ?? ''}',
        ) ??
        0;

    final combinedScore = (_attr(m, ['ft_score']) ?? (m['score'] is String ? m['score'] : '')).toString();
    if (homeScore == 0 && awayScore == 0 && combinedScore.contains(RegExp(r'[-:]'))) {
      final parts = combinedScore.replaceAll('[', '').replaceAll(']', '').split(RegExp(r'[-:]'));
      if (parts.length >= 2) {
        homeScore = int.tryParse(parts[0].trim()) ?? 0;
        awayScore = int.tryParse(parts[1].trim()) ?? 0;
      }
    }

    final statusRaw = (_attr(m, ['status', 'state', 'time_status']) ?? '').toString().trim();
    final minuteRaw = (_attr(m, ['minute', 'timer', 'clock', 'elapsed']) ?? '').toString().trim();
    final dateRaw = (_attr(m, ['date', 'match_date', 'formatted_date', 'utc_date']) ?? '').toString().trim();
    final timeRaw = (_attr(m, ['time', 'start_time', 'kickoff']) ?? '').toString().trim();

    final stLower = statusRaw.toLowerCase();
    final isFinished = stLower == 'ft' ||
        stLower == 'aet' ||
        stLower == 'pen' ||
        stLower == 'finished' ||
        stLower.contains('finish') ||
        stLower.contains('ended');

    final isNumericMin = RegExp(r'^\d+(\+\d+)?$').hasMatch(stLower);
    final isLive = !isFinished &&
        (isNumericMin ||
            stLower == 'ht' ||
            stLower == 'live' ||
            stLower == 'in_play' ||
            stLower == 'inplay' ||
            stLower == 'et' ||
            stLower == '1h' ||
            stLower == '2h' ||
            stLower.contains('progress') ||
            stLower.contains('half'));

    final kickoffDt = _parseStatPalDateTime(dateRaw, timeRaw.isNotEmpty ? timeRaw : statusRaw);

    String statusLabel;
    if (isLive) {
      if (stLower == 'ht') {
        statusLabel = 'FÉLIDŐ';
      } else if (minuteRaw.isNotEmpty) {
        statusLabel = minuteRaw.endsWith("'") ? minuteRaw : "$minuteRaw'";
      } else if (isNumericMin) {
        statusLabel = "$statusRaw'";
      } else {
        statusLabel = 'ÉLŐ';
      }
    } else if (isFinished) {
      statusLabel = 'VÉGE';
    } else if (timeRaw.contains(':')) {
      statusLabel = timeRaw.length >= 5 ? timeRaw.substring(0, 5) : timeRaw;
    } else if (statusRaw.contains(':')) {
      statusLabel = statusRaw.length >= 5 ? statusRaw.substring(0, 5) : statusRaw;
    } else if (kickoffDt != null) {
      statusLabel =
          '${kickoffDt.hour.toString().padLeft(2, '0')}:${kickoffDt.minute.toString().padLeft(2, '0')}';
    } else {
      statusLabel = statusRaw.isNotEmpty ? statusRaw : 'Később';
    }

    final events = _parseStatPalEvents(m['events'], homeName);
    final stats = _parseStatPalStats(m['stats'] ?? m['statistics']);

    return MatchData(
      id: (_attr(m, ['id', 'match_id', 'static_id']) ?? '${homeName}_$awayName').toString(),
      country: country,
      league: league,
      homeTeam: homeName,
      awayTeam: awayName,
      homeTeamId: homeId,
      awayTeamId: awayId,
      homeLogo: homeLogo,
      awayLogo: awayLogo,
      homeColor: colorFromName(homeName),
      awayColor: colorFromName(awayName),
      homeScore: homeScore,
      awayScore: awayScore,
      status: statusLabel,
      isLive: isLive,
      isFinished: isFinished,
      kickoff: kickoffDt,
      isFromApi: true,
      possessionHome: stats['poss'] ?? 50,
      shotsHome: stats['shotsH'] ?? 0,
      shotsAway: stats['shotsA'] ?? 0,
      shotsOnTargetHome: stats['sotH'] ?? 0,
      shotsOnTargetAway: stats['sotA'] ?? 0,
      cornersHome: stats['cornH'] ?? 0,
      cornersAway: stats['cornA'] ?? 0,
      foulsHome: stats['foulH'] ?? 0,
      foulsAway: stats['foulA'] ?? 0,
      events: events,
    );
  }

  static List<MatchEvent> _parseStatPalEvents(dynamic eventsNode, String homeTeamName) {
    if (eventsNode == null) return const [];
    final rawList = eventsNode is Map
        ? _asMapList(eventsNode['event'] ?? eventsNode['data'])
        : _asMapList(eventsNode);

    final out = <MatchEvent>[];
    for (final item in rawList) {
      final ev = item as Map;
      final typeRaw = (_attr(ev, ['type', 'event_type']) ?? '').toString().toLowerCase();
      String type = 'goal';
      if (typeRaw.contains('yellow')) {
        type = 'yellow';
      } else if (typeRaw.contains('red')) {
        type = 'red';
      } else if (!typeRaw.contains('goal') && !typeRaw.contains('pen')) {
        continue;
      }

      final teamSide = (_attr(ev, ['team', 'side']) ?? '').toString().toLowerCase();
      final isHome = teamSide == 'home' ||
          teamSide == 'localteam' ||
          teamSide == homeTeamName.toLowerCase();

      final player = (_attr(ev, ['player', 'player_name', 'scorer']) ?? 'Játékos').toString();
      final minute = (_attr(ev, ['minute', 'time']) ?? '').toString();
      out.add(MatchEvent(
        minute: minute.endsWith("'") ? minute : "$minute'",
        player: player,
        type: type,
        isHome: isHome,
      ));
    }
    return out;
  }

  static Map<String, int> _parseStatPalStats(dynamic statsNode) {
    final result = <String, int>{};
    if (statsNode == null) return result;

    int extractInt(dynamic v) =>
        int.tryParse((v ?? '0').toString().replaceAll('%', '').trim()) ?? 0;

    if (statsNode is Map) {
      if (statsNode['home'] is Map && statsNode['away'] is Map) {
        final h = statsNode['home'] as Map;
        final a = statsNode['away'] as Map;
        final poss = extractInt(_attr(h, ['possession', 'ball_possession']));
        if (poss > 0) result['poss'] = poss;
        result['shotsH'] = extractInt(_attr(h, ['shots', 'total_shots', 'shots_total']));
        result['shotsA'] = extractInt(_attr(a, ['shots', 'total_shots', 'shots_total']));
        result['sotH'] = extractInt(_attr(h, ['shots_on_target', 'on_target', 'shots_ongoal']));
        result['sotA'] = extractInt(_attr(a, ['shots_on_target', 'on_target', 'shots_ongoal']));
        result['cornH'] = extractInt(_attr(h, ['corners', 'corner_kicks']));
        result['cornA'] = extractInt(_attr(a, ['corners', 'corner_kicks']));
        result['foulH'] = extractInt(_attr(h, ['fouls', 'fouls_committed']));
        result['foulA'] = extractInt(_attr(a, ['fouls', 'fouls_committed']));
        return result;
      }
    }

    final list = statsNode is List
        ? _asMapList(statsNode)
        : (statsNode is Map ? _asMapList(statsNode['stat'] ?? statsNode['data']) : []);
    for (final item in list) {
      final row = item as Map;
      final name = (_attr(row, ['name', 'title', 'type']) ?? '').toString().toLowerCase();
      final hv = extractInt(_attr(row, ['home', 'localteam', 'home_value']));
      final av = extractInt(_attr(row, ['away', 'visitorteam', 'away_value']));
      if (name.contains('possession')) {
        if (hv > 0) result['poss'] = hv;
      } else if (name.contains('on target') || name.contains('on goal')) {
        result['sotH'] = hv;
        result['sotA'] = av;
      } else if (name.contains('shot')) {
        result['shotsH'] = hv;
        result['shotsA'] = av;
      } else if (name.contains('corner')) {
        result['cornH'] = hv;
        result['cornA'] = av;
      } else if (name.contains('foul')) {
        result['foulH'] = hv;
        result['foulA'] = av;
      }
    }
    return result;
  }

  // --- HIGHLIGHTLY EGYEDI MECCS PARSER ---
  static MatchData _parseHighlightlyMatch(Map m) {
    final homeMap = m['homeTeam'] is Map ? m['homeTeam'] as Map : {};
    final awayMap = m['awayTeam'] is Map ? m['awayTeam'] as Map : {};
    final leagueMap = m['league'] is Map ? m['league'] as Map : {};
    final countryMap = leagueMap['country'] is Map ? leagueMap['country'] as Map : {};
    final stateMap = m['state'] is Map ? m['state'] as Map : {};

    final homeName = (homeMap['name'] ?? m['homeTeam'] ?? 'Hazai').toString();
    final awayName = (awayMap['name'] ?? m['awayTeam'] ?? 'Vendég').toString();
    final homeId = homeMap['id']?.toString();
    final awayId = awayMap['id']?.toString();

    final rawLeague = (leagueMap['name'] ?? m['league'] ?? 'Egyéb bajnokság').toString();
    final rawCountry = (countryMap['name'] ?? leagueMap['country'] ?? m['country'] ?? '').toString();
    final country = HungarianLocalization.localizeCountry(rawCountry, leagueName: rawLeague);
    final league = HungarianLocalization.localizeLeague(rawLeague, countryName: country);

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
        ? _parseHighlightlyEvents(m['events'] as List, homeName, homeId)
        : <MatchEvent>[];

    final statsParsed = m['statistics'] is List
        ? _parseHighlightlyStats(m['statistics'] as List)
        : null;

    return MatchData(
      id: (m['id'] ?? '${homeName}_$awayName').toString(),
      country: country,
      league: league,
      homeTeam: homeName,
      awayTeam: awayName,
      homeTeamId: homeId,
      awayTeamId: awayId,
      homeLogo: LogoCache.normalizeUrl(homeMap['logo']?.toString()),
      awayLogo: LogoCache.normalizeUrl(awayMap['logo']?.toString()),
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

  static Map<String, int>? _parseHighlightlyStats(List list) {
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

  static List<MatchEvent> _parseHighlightlyEvents(
    List list,
    String homeTeamName,
    String? homeTeamId,
  ) {
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
        final player =
            (playerObj['name'] ?? item['player'] ?? item['playerName'] ?? 'Játékos').toString();
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

  // =========================================================================
  // 2. MECCS RÉSZLETEK FRISSÍTÉSE
  // =========================================================================
  static Future<FetchResult<MatchData>> enrichMatchDetails(
    MatchData base, {
    bool forceRefresh = false,
  }) async {
    if (!ApiConfig.hasValidKey || !base.isFromApi) {
      return FetchResult(data: base, fromCache: false);
    }

    final cacheKey = '${ApiConfig.providerTag}_detail_${base.id}';
    final ttl = base.isFinished
        ? const Duration(hours: 12)
        : Duration(seconds: ApiConfig.isStatPal ? 15 : 45);

    if (!forceRefresh) {
      final cachedJson = await ApiCache.get(cacheKey, ttl, savedWeight: 2);
      if (cachedJson != null) {
        final decoded = jsonDecode(cachedJson);
        if (decoded is Map) {
          return FetchResult(fromCache: true, data: MatchData.fromCacheMap(decoded));
        }
      }
    }

    if (ApiConfig.isStatPal) {
      return _enrichStatPalV2Details(base, cacheKey);
    } else {
      return _enrichHighlightlyDetails(base, cacheKey);
    }
  }

  static Future<FetchResult<MatchData>> _enrichStatPalV2Details(
    MatchData base,
    String cacheKey,
  ) async {
    final key = Uri.encodeComponent(ApiConfig.statpalKey.trim());
    MatchData current = base;
    bool rateLimited = false;

    try {
      await ApiCache.recordNetworkCall();
      final res = await http
          .get(Uri.parse('${ApiConfig.statpalV2BaseUrl}/matches/${base.id}?access_key=$key'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 429) {
        rateLimited = true;
      } else if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final obj = body is Map && body['data'] is Map ? body['data'] as Map : body;
        if (obj is Map && obj['error'] == null) {
          final parsed = _parseStatPalSingleMatch(obj, base.league, rawCountry: base.country);
          current = current.copyWith(
            homeScore: parsed.homeScore,
            awayScore: parsed.awayScore,
            status: parsed.status,
            isLive: parsed.isLive,
            isFinished: parsed.isFinished,
            possessionHome: parsed.possessionHome,
            shotsHome: parsed.shotsHome,
            shotsAway: parsed.shotsAway,
            shotsOnTargetHome: parsed.shotsOnTargetHome,
            shotsOnTargetAway: parsed.shotsOnTargetAway,
            cornersHome: parsed.cornersHome,
            cornersAway: parsed.cornersAway,
            foulsHome: parsed.foulsHome,
            foulsAway: parsed.foulsAway,
            events: parsed.events.isNotEmpty ? parsed.events : current.events,
          );
        }
      }
    } catch (_) {}

    if (!rateLimited && !base.isFinished && current.shotsHome == 0 && current.shotsAway == 0) {
      try {
        await ApiCache.recordNetworkCall();
        final liveRes = await http
            .get(Uri.parse('${ApiConfig.statpalV2BaseUrl}/matches/live?access_key=$key'))
            .timeout(const Duration(seconds: 9));
        if (liveRes.statusCode == 200) {
          final list = _parseStatPalAnyPayload(jsonDecode(liveRes.body), DateTime.now(), filterByDate: false);
          for (final m in list) {
            if (m.id == base.id) {
              current = current.copyWith(
                homeScore: m.homeScore,
                awayScore: m.awayScore,
                status: m.status,
                isLive: m.isLive,
                isFinished: m.isFinished,
                possessionHome: m.possessionHome,
                shotsHome: m.shotsHome,
                shotsAway: m.shotsAway,
                shotsOnTargetHome: m.shotsOnTargetHome,
                shotsOnTargetAway: m.shotsOnTargetAway,
                cornersHome: m.cornersHome,
                cornersAway: m.cornersAway,
                foulsHome: m.foulsHome,
                foulsAway: m.foulsAway,
                events: m.events.isNotEmpty ? m.events : current.events,
              );
              break;
            }
          }
        }
      } catch (_) {}
    }

    final note = rateLimited
        ? 'StatPal kéréskorlát (429) – várj 15 másodpercet a következő frissítésig.'
        : 'StatPal V2 élő adatforrás • Helyileg tárolt logókkal.';

    final finalMatch = current.copyWith(detailNote: note);
    if (!rateLimited) {
      await ApiCache.put(cacheKey, jsonEncode(finalMatch.toCacheMap()));
    }
    return FetchResult(data: finalMatch, fromCache: false);
  }

  static Future<FetchResult<MatchData>> _enrichHighlightlyDetails(
    MatchData base,
    String cacheKey,
  ) async {
    MatchData current = base;
    List<HighlightClip> clips = List.of(base.highlights);
    bool rateLimited = false;

    try {
      await ApiCache.recordNetworkCall();
      final matchRes = await http
          .get(
            Uri.parse('${ApiConfig.highlightlyBaseUrl}/matches/${base.id}'),
            headers: ApiConfig.highlightlyHeaders,
          )
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
          final updated = _parseHighlightlyMatch(obj);
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
            .get(
              Uri.parse('${ApiConfig.highlightlyBaseUrl}/match-statistics/${base.id}'),
              headers: ApiConfig.highlightlyHeaders,
            )
            .timeout(const Duration(seconds: 8));
        if (statRes.statusCode == 429) {
          rateLimited = true;
        } else if (statRes.statusCode == 200) {
          final body = jsonDecode(statRes.body);
          final list = body is List ? body : (body is Map && body['data'] is List ? body['data'] : []);
          final parsedStats = _parseHighlightlyStats(list);
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
            .get(
              Uri.parse('${ApiConfig.highlightlyBaseUrl}/live-events/${base.id}'),
              headers: ApiConfig.highlightlyHeaders,
            )
            .timeout(const Duration(seconds: 8));
        if (evRes.statusCode == 429) {
          rateLimited = true;
        } else if (evRes.statusCode == 200) {
          final body = jsonDecode(evRes.body);
          final list = body is List ? body : (body is Map && body['data'] is List ? body['data'] : []);
          final parsedEvents = _parseHighlightlyEvents(list, current.homeTeam, current.homeTeamId);
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
            .get(
              Uri.parse('${ApiConfig.highlightlyBaseUrl}/highlights?matchId=${base.id}'),
              headers: ApiConfig.highlightlyHeaders,
            )
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
      note = 'Ehhez a bajnoksághoz a Highlightly jelenleg csak az élő állást közli.';
    }

    final finalMatch = current.copyWith(highlights: clips, detailNote: note);
    if (!rateLimited) {
      await ApiCache.put(cacheKey, jsonEncode(finalMatch.toCacheMap()));
    }
    return FetchResult(fromCache: false, data: finalMatch);
  }

  // =========================================================================
  // 3. TABELLÁK LEKÉRÉSE
  // =========================================================================
  static const highlightlyLeagueIds = {
    'Premier League': 33973,
    'Bajnokok Ligája': 2486,
    'La Liga': 119924,
    'Bundesliga': 67162,
    'Serie A': 115669,
  };

  static const statpalV2LeagueIds = {
    'Premier League': 3037,
    'Bajnokok Ligája': 1005,
    'La Liga': 1399,
    'Bundesliga': 1229,
    'Serie A': 1269,
  };

  static Future<FetchResult<List<StandingRow>>> fetchStandings(
    String leagueName, {
    bool forceRefresh = false,
  }) async {
    if (!ApiConfig.hasValidKey) throw Exception('Nincs API kulcs');

    final cacheKey = '${ApiConfig.providerTag}_standings_$leagueName';
    if (!forceRefresh) {
      final cachedJson = await ApiCache.get(cacheKey, const Duration(hours: 2));
      if (cachedJson != null) {
        final rows = ApiConfig.isStatPal
            ? _parseStatPalStandingsBody(cachedJson)
            : _parseHighlightlyStandingsBody(cachedJson);
        return FetchResult(data: rows, fromCache: true);
      }
    }

    if (ApiConfig.isStatPal) {
      final id = statpalV2LeagueIds[leagueName];
      if (id == null) throw Exception('Ismeretlen bajnokság');
      final key = Uri.encodeComponent(ApiConfig.statpalKey.trim());
      final uri = Uri.parse('${ApiConfig.statpalV2BaseUrl}/leagues/$id/standings?access_key=$key');
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) throw Exception('StatPal V2 tabella hiba (${res.statusCode})');
      await ApiCache.recordNetworkCall();
      await ApiCache.put(cacheKey, res.body);
      return FetchResult(data: _parseStatPalStandingsBody(res.body), fromCache: false);
    } else {
      final id = highlightlyLeagueIds[leagueName];
      if (id == null) throw Exception('Ismeretlen bajnokság');
      final uri = Uri.parse('${ApiConfig.highlightlyBaseUrl}/standings?leagueId=$id');
      final res = await http
          .get(uri, headers: ApiConfig.highlightlyHeaders)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) throw Exception('Highlightly tabella hiba (${res.statusCode})');
      await ApiCache.recordNetworkCall();
      await ApiCache.put(cacheKey, res.body);
      return FetchResult(data: _parseHighlightlyStandingsBody(res.body), fromCache: false);
    }
  }

  static List<StandingRow> _parseStatPalStandingsBody(String body) {
    final decoded = jsonDecode(body);
    List teams = [];

    if (decoded is List) {
      teams = decoded;
    } else if (decoded is Map) {
      if (decoded['data'] is List) {
        teams = decoded['data'] as List;
      } else {
        final root = decoded['standings'] ?? decoded['data'] ?? decoded;
        if (root is Map) {
          final leagues = _asMapList(root['league']);
          if (leagues.isNotEmpty) {
            final firstLeague = leagues[0] as Map;
            teams = _asMapList(firstLeague['team'] ?? firstLeague['standings']);
          }
        }
      }
    }

    return _asMapList(teams).map((item) {
      final r = item as Map;
      final teamObj = r['team'] is Map ? r['team'] as Map : r;
      final teamName = (_attr(teamObj, ['name', 'team_name']) ?? 'Csapat').toString();
      final pos = int.tryParse('${_attr(r, ['position', 'pos', 'rank']) ?? 0}') ?? 0;
      final overall = r['overall'] is Map ? r['overall'] as Map : r;
      final total = r['total'] is Map ? r['total'] as Map : r;
      final played = int.tryParse('${_attr(overall, ['gp', 'played', 'games', 'matches_played']) ?? 0}') ?? 0;
      final gf = int.tryParse('${_attr(overall, ['gs', 'gf', 'scored', 'goals_for']) ?? 0}') ?? 0;
      final ga = int.tryParse('${_attr(overall, ['ga', 'against', 'received', 'goals_against']) ?? 0}') ?? 0;
      final gd = int.tryParse('${_attr(total, ['gd', 'goal_difference']) ?? (gf - ga)}') ?? (gf - ga);
      final pts = int.tryParse('${_attr(total, ['p', 'pts', 'points']) ?? 0}') ?? 0;

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
        logo: LogoCache.normalizeUrl(_attr(teamObj, ['logo', 'image', 'badge', 'crest'])?.toString()),
        color: colorFromName(teamName),
        played: played,
        gd: gd,
        points: pts,
        zone: zone,
      );
    }).toList();
  }

  static List<StandingRow> _parseHighlightlyStandingsBody(String body) {
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
        logo: LogoCache.normalizeUrl(teamMap['logo']?.toString()),
        color: colorFromName(teamName),
        played: played,
        gd: gd,
        points: pts,
        zone: zone,
      );
    }).toList();
  }
}

// --- DEMO MINTA ADATOK (MAGYAROSÍTVA, ORSZÁGGAL ÉS BAJNOKSÁGGAL) ---
const List<MatchData> sampleMatches = [
  MatchData(
    id: 'm1',
    country: 'Európa',
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
      HighlightClip(title: 'Real Madrid - Liverpool 2-2 | Összefoglaló (Minta)', url: 'https://highlightly.net'),
    ],
  ),
  MatchData(
    id: 'm2',
    country: 'Magyarország',
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
    country: 'Anglia',
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
