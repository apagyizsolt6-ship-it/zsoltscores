import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ApiProvider { highlightly, statpal }

enum CollapseMode { liveOrPinned, allExpanded, allCollapsed }

// --- MEGJELENÉSI ÉS RIASZTÁSI BEÁLLÍTÁSOK ---
class DisplayPrefs {
  static const _pinnedKey = 'zsolt_pinned_competitions';
  static const _collapseModeKey = 'zsolt_collapse_mode';
  static const _autoLiveListKey = 'zsolt_auto_live_list';
  static const _favTeamsKey = 'zsolt_favorite_teams';
  static const _alertGoalKey = 'zsolt_alert_goal';
  static const _alertRedKey = 'zsolt_alert_red';
  static const _alertEndKey = 'zsolt_alert_end';
  static const _recentSearchesKey = 'zsolt_recent_searches';

  static Set<String> pinnedCompetitions = {'Magyarország • NB I', 'Európa • Bajnokok Ligája'};
  static CollapseMode collapseMode = CollapseMode.liveOrPinned;
  static bool autoLiveListRefresh = true;
  static List<String> favoriteTeams = ['Ferencváros', 'Liverpool', 'Real Madrid'];
  static bool alertOnGoal = true;
  static bool alertOnRedCard = true;
  static bool alertOnFinish = true;
  static List<String> recentSearches = [];

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPins = prefs.getStringList(_pinnedKey);
    if (savedPins != null) {
      pinnedCompetitions = savedPins.toSet();
    }
    final modeStr = prefs.getString(_collapseModeKey) ?? 'liveOrPinned';
    if (modeStr == 'allExpanded') {
      collapseMode = CollapseMode.allExpanded;
    } else if (modeStr == 'allCollapsed') {
      collapseMode = CollapseMode.allCollapsed;
    } else {
      collapseMode = CollapseMode.liveOrPinned;
    }
    autoLiveListRefresh = prefs.getBool(_autoLiveListKey) ?? true;
    final savedTeams = prefs.getStringList(_favTeamsKey);
    if (savedTeams != null) {
      favoriteTeams = savedTeams.where((e) => e.trim().isNotEmpty).toList();
    }
    alertOnGoal = prefs.getBool(_alertGoalKey) ?? true;
    alertOnRedCard = prefs.getBool(_alertRedKey) ?? true;
    alertOnFinish = prefs.getBool(_alertEndKey) ?? true;
    final savedSearches = prefs.getStringList(_recentSearchesKey);
    if (savedSearches != null) {
      recentSearches = savedSearches.where((e) => e.trim().isNotEmpty).take(6).toList();
    }
  }

  static Future<void> addRecentSearch(String query) async {
    final q = query.trim();
    if (q.length < 2) return;
    recentSearches.removeWhere((item) => item.toLowerCase() == q.toLowerCase());
    recentSearches.insert(0, q);
    if (recentSearches.length > 6) {
      recentSearches = recentSearches.take(6).toList();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentSearchesKey, recentSearches);
  }

  static Future<void> clearRecentSearches() async {
    recentSearches.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentSearchesKey);
  }

  static Future<void> toggleFavoriteTeam(String teamName) async {
    final clean = teamName.trim();
    if (clean.isEmpty) return;
    final existingIndex = favoriteTeams.indexWhere((t) => t.toLowerCase() == clean.toLowerCase());
    if (existingIndex >= 0) {
      favoriteTeams.removeAt(existingIndex);
    } else {
      favoriteTeams.insert(0, clean);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favTeamsKey, favoriteTeams);
  }

  static bool isFavoriteTeam(String teamName) {
    final t = teamName.trim().toLowerCase();
    if (t.isEmpty) return false;
    return favoriteTeams.any((fav) {
      final f = fav.trim().toLowerCase();
      return f.isNotEmpty && (t.contains(f) || f.contains(t));
    });
  }

  static Future<void> togglePin(String competitionKey) async {
    if (pinnedCompetitions.contains(competitionKey)) {
      pinnedCompetitions.remove(competitionKey);
    } else {
      pinnedCompetitions.add(competitionKey);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_pinnedKey, pinnedCompetitions.toList());
  }

  static Future<void> setCollapseMode(CollapseMode mode) async {
    collapseMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_collapseModeKey, mode.name);
  }

  static Future<void> setAutoLiveListRefresh(bool enabled) async {
    autoLiveListRefresh = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoLiveListKey, enabled);
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
        .toList();
    alertOnGoal = goalAlert;
    alertOnRedCard = redAlert;
    alertOnFinish = endAlert;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_collapseModeKey, collapseMode.name);
    await prefs.setBool(_autoLiveListKey, autoLiveListRefresh);
    await prefs.setStringList(_favTeamsKey, favoriteTeams);
    await prefs.setBool(_alertGoalKey, alertOnGoal);
    await prefs.setBool(_alertRedKey, alertOnRedCard);
    await prefs.setBool(_alertEndKey, alertOnFinish);
  }
}

// --- MAGYAROSÍTÓ SEGÉDOSZTÁLY (ORSZÁG, ZÁSZLÓ ÉS BAJNOKSÁG NEVEK) ---
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
    'northern ireland': 'Észak-Írország',
    'poland': 'Lengyelország',
    'czech republic': 'Csehország',
    'czechia': 'Csehország',
    'slovakia': 'Szlovákia',
    'romania': 'Románia',
    'croatia': 'Horvátország',
    'serbia': 'Szerbia',
    'bosnia': 'Bosznia-Hercegovina',
    'bosnia and herzegovina': 'Bosznia-Hercegovina',
    'bosnia-herzegovina': 'Bosznia-Hercegovina',
    'slovenia': 'Szlovénia',
    'montenegro': 'Montenegró',
    'albania': 'Albánia',
    'north macedonia': 'Észak-Macedónia',
    'bulgaria': 'Bulgária',
    'greece': 'Görögország',
    'turkey': 'Törökország',
    'ukraine': 'Ukrajna',
    'russia': 'Oroszország',
    'belarus': 'Fehéroroszország',
    'sweden': 'Svédország',
    'norway': 'Norvégia',
    'denmark': 'Dánia',
    'finland': 'Finnország',
    'iceland': 'Izland',
    'estonia': 'Észtország',
    'latvia': 'Lettország',
    'lithuania': 'Litvánia',
    'moldova': 'Moldova',
    'georgia': 'Grúzia',
    'armenia': 'Örményország',
    'azerbaijan': 'Azerbajdzsán',
    'kazakhstan': 'Kazahsztán',
    'cyprus': 'Ciprus',
    'malta': 'Málta',
    'luxembourg': 'Luxemburg',
    'congo dr': 'Kongói DK',
    'dr congo': 'Kongói DK',
    'congo': 'Kongó',
    'iran': 'Irán',
    'islamic republic of iran': 'Irán',
    'jordan': 'Jordánia',
    'syria': 'Szíria',
    'iraq': 'Irak',
    'lebanon': 'Libanon',
    'israel': 'Izrael',
    'egypt': 'Egyiptom',
    'morocco': 'Marokkó',
    'tunisia': 'Tunézia',
    'algeria': 'Algéria',
    'nigeria': 'Nigéria',
    'ghana': 'Ghána',
    'south africa': 'Dél-Afrika',
    'kenya': 'Kenya',
    'cameroon': 'Kamerun',
    'senegal': 'Szenegál',
    'ivory coast': 'Elefántcsontpart',
    'brazil': 'Brazília',
    'argentina': 'Argentína',
    'colombia': 'Kolumbia',
    'chile': 'Chile',
    'uruguay': 'Uruguay',
    'peru': 'Peru',
    'paraguay': 'Paraguay',
    'ecuador': 'Ecuador',
    'venezuela': 'Venezuela',
    'bolivia': 'Bolívia',
    'usa': 'Egyesült Államok',
    'united states': 'Egyesült Államok',
    'canada': 'Kanada',
    'mexico': 'Mexikó',
    'japan': 'Japán',
    'south korea': 'Dél-Korea',
    'korea republic': 'Dél-Korea',
    'china': 'Kína',
    'india': 'India',
    'indonesia': 'Indonézia',
    'thailand': 'Thaiföld',
    'vietnam': 'Vietnám',
    'malaysia': 'Malajzia',
    'saudi arabia': 'Szaúd-Arábia',
    'qatar': 'Katar',
    'uae': 'Egyesült Arab Emírségek',
    'united arab emirates': 'Egyesült Arab Emírségek',
    'uzbekistan': 'Üzbegisztán',
    'australia': 'Ausztrália',
    'new zealand': 'Új-Zéland',
    'world': 'Nemzetközi',
    'international': 'Nemzetközi',
    'europe': 'Európa',
    'asia': 'Ázsia',
    'africa': 'Afrika',
    'south america': 'Dél-Amerika',
    'north america': 'Észak-Amerika',
  };

  static const Map<String, String> _countryFlagEmoji = {
    'Magyarország': '🇭🇺',
    'Anglia': '🏴󠁧󠁢󠁥󠁮󠁧󠁿',
    'Skócia': '🏴󠁧󠁢󠁳󠁣󠁴󠁿',
    'Wales': '🏴󠁧󠁢󠁷󠁬󠁳󠁿',
    'Spanyolország': '🇪🇸',
    'Németország': '🇩🇪',
    'Olaszország': '🇮🇹',
    'Franciaország': '🇫🇷',
    'Hollandia': '🇳🇱',
    'Portugália': '🇵🇹',
    'Belgium': '🇧🇪',
    'Ausztria': '🇦🇹',
    'Svájc': '🇨🇭',
    'Lengyelország': '🇵🇱',
    'Csehország': '🇨🇿',
    'Szlovákia': '🇸🇰',
    'Románia': '🇷🇴',
    'Horvátország': '🇭🇷',
    'Szerbia': '🇷🇸',
    'Bosznia-Hercegovina': '🇧🇦',
    'Görögország': '🇬🇷',
    'Törökország': '🇹🇷',
    'Ukrajna': '🇺🇦',
    'Svédország': '🇸🇪',
    'Norvégia': '🇳🇴',
    'Dánia': '🇩🇰',
    'Finnország': '🇫🇮',
    'Brazília': '🇧🇷',
    'Argentína': '🇦🇷',
    'Egyesült Államok': '🇺🇸',
    'Mexikó': '🇲🇽',
    'Japán': '🇯🇵',
    'Dél-Korea': '🇰🇷',
    'Kína': '🇨🇳',
    'India': '🇮🇳',
    'Irán': '🇮🇷',
    'Jordánia': '🇯🇴',
    'Szíria': '🇸🇾',
    'Kongói DK': '🇨🇩',
    'Ausztrália': '🇦🇺',
    'Szaúd-Arábia': '🇸🇦',
    'Katar': '🇶🇦',
    'Európa': '🇪🇺',
    'Nemzetközi': '🌍',
  };

  static String flagEmojiForCountry(String country) {
    return _countryFlagEmoji[country] ?? '🌍';
  }

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

  static String extractRawName(dynamic input) {
    if (input == null) return '';
    if (input is Map) {
      final val = input['name'] ??
          input['Name'] ??
          input['country'] ??
          input['country_name'] ??
          input['title'] ??
          '';
      return val.toString().trim();
    }
    final str = input.toString().trim();
    if (str.startsWith('{') && str.contains('name')) {
      final match = RegExp(r'''['"]?name['"]?\s*:\s*['"]?([^,}'"]+)['"]?''', caseSensitive: false)
          .firstMatch(str);
      if (match != null && match.group(1) != null) {
        return match.group(1)!.trim();
      }
    }
    return str;
  }

  static String? extractFlagUrl(dynamic input) {
    if (input == null) return null;
    if (input is Map) {
      final raw = input['logo'] ?? input['Logo'] ?? input['flag'] ?? input['image'];
      if (raw != null && raw.toString().trim().isNotEmpty) {
        return LogoCache.normalizeUrl(raw.toString());
      }
      return null;
    }
    final str = input.toString().trim();
    if (str.startsWith('{') && str.contains('logo')) {
      final match = RegExp(r'''['"]?logo['"]?\s*:\s*['"]?([^,}'"\s]+)['"]?''', caseSensitive: false)
          .firstMatch(str);
      if (match != null && match.group(1) != null) {
        return LogoCache.normalizeUrl(match.group(1)!);
      }
    }
    return null;
  }

  static String localizeCountry(dynamic rawCountry, {String? leagueName}) {
    final cleaned = extractRawName(rawCountry);
    if (cleaned.isNotEmpty) {
      final lower = cleaned.toLowerCase();
      if (_countryMap.containsKey(lower)) return _countryMap[lower]!;
      return _titleCase(cleaned.toLowerCase());
    }

    final lCleaned = (leagueName ?? '').trim().toLowerCase();
    for (final entry in _leagueToCountryFallback.entries) {
      if (lCleaned.contains(entry.key)) return entry.value;
    }
    return 'Nemzetközi';
  }

  static String localizeLeague(dynamic rawLeague, {String? countryName}) {
    var cleaned = extractRawName(rawLeague);
    if (cleaned.isEmpty) return 'Egyéb bajnokság';

    final lower = cleaned.toLowerCase();
    if (_leagueMap.containsKey(lower)) {
      return _leagueMap[lower]!;
    }

    if (countryName != null && countryName.trim().isNotEmpty) {
      final cLower = countryName.trim().toLowerCase();
      final prefixPattern = RegExp('^${RegExp.escape(cLower)}\\s*[-:–|]\\s*', caseSensitive: false);
      cleaned = cleaned.replaceFirst(prefixPattern, '').trim();
    }

    for (final entry in _leagueMap.entries) {
      if (cleaned.toLowerCase() == entry.key) return entry.value;
    }

    return _titleCase(cleaned.toLowerCase());
  }

  static String _titleCase(String input) {
    if (input.isEmpty) return input;
    return input
        .split(RegExp(r'\s+'))
        .map((w) {
          if (w.isEmpty) return w;
          final upperCheck = w.toUpperCase();
          if (upperCheck == 'UEFA' || upperCheck == 'FIFA' || upperCheck == 'MLS' || upperCheck == 'NB' || upperCheck == 'U17' || upperCheck == 'U19' || upperCheck == 'U21') {
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

// --- HELYI LOGÓ / ZÁSZLÓ LETÖLTŐ ÉS TÁROLÓ ---
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
  final DateTime fetchedAt;
  final String? note;
  FetchResult({
    required this.data,
    required this.fromCache,
    DateTime? fetchedAt,
    this.note,
  }) : fetchedAt = fetchedAt ?? DateTime.now();
}

// --- ADATMODELLEK ---
class MatchEvent {
  final String minute;
  final String player;
  final String type; // 'goal', 'yellow', 'red', 'sub'
  final bool isHome;

  const MatchEvent({
    required this.minute,
    required this.player,
    required this.type,
    required this.isHome,
  });

  int get minuteSortValue {
    final clean = minute.replaceAll("'", '').trim();
    if (clean.contains('+')) {
      final parts = clean.split('+');
      return (int.tryParse(parts[0]) ?? 0) * 10 + (int.tryParse(parts[1]) ?? 0);
    }
    return (int.tryParse(clean) ?? 0) * 10;
  }

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

class LineupPlayer {
  final String number;
  final String name;
  final String position;
  final bool isSubstitute;

  const LineupPlayer({
    required this.number,
    required this.name,
    required this.position,
    this.isSubstitute = false,
  });

  Map toJson() => {'number': number, 'name': name, 'position': position, 'isSubstitute': isSubstitute};

  factory LineupPlayer.fromJson(Map json) => LineupPlayer(
        number: (json['number'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        position: (json['position'] ?? '').toString(),
        isSubstitute: json['isSubstitute'] == true,
      );
}

class TeamLineup {
  final String formation;
  final List<LineupPlayer> starters;
  final List<LineupPlayer> substitutes;

  const TeamLineup({
    this.formation = '4-3-3',
    this.starters = const [],
    this.substitutes = const [],
  });

  Map toJson() => {
        'formation': formation,
        'starters': starters.map((p) => p.toJson()).toList(),
        'substitutes': substitutes.map((p) => p.toJson()).toList(),
      };

  factory TeamLineup.fromJson(Map json) => TeamLineup(
        formation: (json['formation'] ?? '4-3-3').toString(),
        starters: (json['starters'] as List? ?? [])
            .whereType()
            .map((e) => LineupPlayer.fromJson(e))
            .toList(),
        substitutes: (json['substitutes'] as List? ?? [])
            .whereType()
            .map((e) => LineupPlayer.fromJson(e))
            .toList(),
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

  Map toJson() => {
        'dateLabel': dateLabel,
        'homeTeam': homeTeam,
        'awayTeam': awayTeam,
        'scoreLabel': scoreLabel,
      };

  factory H2HFixture.fromJson(Map json) => H2HFixture(
        dateLabel: (json['dateLabel'] ?? '').toString(),
        homeTeam: (json['homeTeam'] ?? '').toString(),
        awayTeam: (json['awayTeam'] ?? '').toString(),
        scoreLabel: (json['scoreLabel'] ?? '').toString(),
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

class MatchData {
  final String id;
  final String country;
  final String? countryFlagUrl;
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
  final TeamLineup? homeLineup;
  final TeamLineup? awayLineup;
  final List<String> homeForm;
  final List<String> awayForm;
  final List<H2HFixture> h2hFixtures;
  final String? detailNote;

  const MatchData({
    required this.id,
    this.country = 'Nemzetközi',
    this.countryFlagUrl,
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
    this.homeLineup,
    this.awayLineup,
    this.homeForm = const [],
    this.awayForm = const [],
    this.h2hFixtures = const [],
    this.detailNote,
  });

  String get fullCompetitionLabel => '$country • $league';

  static int formPoints(List<String> form) {
    int pts = 0;
    for (final f in form) {
      if (f == 'GY') pts += 3;
      if (f == 'D') pts += 1;
    }
    return pts;
  }

  String buildShareText() {
    final stateTag = isLive ? 'ÉLŐ • $status' : status;
    final goalList = events
        .where((e) => e.type == 'goal')
        .map((e) => '${e.player} (${e.minute})')
        .join(', ');
    final baseLine = '⚽ $homeTeam $homeScore - $awayScore $awayTeam [$stateTag] • $league';
    if (goalList.isEmpty) return baseLine;
    return '$baseLine\nGóllövők: $goalList';
  }

  Map toCacheMap() => {
        'id': id,
        'country': country,
        'countryFlagUrl': countryFlagUrl,
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
        'homeLineup': homeLineup?.toJson(),
        'awayLineup': awayLineup?.toJson(),
        'homeForm': homeForm,
        'awayForm': awayForm,
        'h2hFixtures': h2hFixtures.map((h) => h.toJson()).toList(),
        'detailNote': detailNote,
      };

  factory MatchData.fromCacheMap(Map json) {
    final homeName = (json['homeTeam'] ?? 'Hazai').toString();
    final awayName = (json['awayTeam'] ?? 'Vendég').toString();
    final rawLeague = json['league'] ?? 'Egyéb bajnokság';
    final rawCountry = json['country'];
    final localizedCountry = HungarianLocalization.localizeCountry(rawCountry, leagueName: rawLeague.toString());
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
    final h2hList = <H2HFixture>[];
    if (json['h2hFixtures'] is List) {
      for (final h in json['h2hFixtures']) {
        if (h is Map) h2hList.add(H2HFixture.fromJson(h));
      }
    }

    return MatchData(
      id: (json['id'] ?? '').toString(),
      country: localizedCountry,
      countryFlagUrl: LogoCache.normalizeUrl(json['countryFlagUrl']?.toString()),
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
      homeLineup: json['homeLineup'] is Map ? TeamLineup.fromJson(json['homeLineup'] as Map) : null,
      awayLineup: json['awayLineup'] is Map ? TeamLineup.fromJson(json['awayLineup'] as Map) : null,
      homeForm: (json['homeForm'] as List? ?? []).map((e) => e.toString()).toList(),
      awayForm: (json['awayForm'] as List? ?? []).map((e) => e.toString()).toList(),
      h2hFixtures: h2hList,
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
    TeamLineup? homeLineup,
    TeamLineup? awayLineup,
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
      homeLineup: homeLineup ?? this.homeLineup,
      awayLineup: awayLineup ?? this.awayLineup,
      homeForm: homeForm ?? this.homeForm,
      awayForm: awayForm ?? this.awayForm,
      h2hFixtures: h2hFixtures ?? this.h2hFixtures,
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
  final int won;
  final int drawn;
  final int lost;
  final int gf;
  final int ga;
  final int gd;
  final int points;
  final String zone;
  final List<String> form;

  const StandingRow({
    required this.pos,
    required this.team,
    this.logo,
    required this.color,
    required this.played,
    this.won = 0,
    this.drawn = 0,
    this.lost = 0,
    this.gf = 0,
    this.ga = 0,
    required this.gd,
    required this.points,
    required this.zone,
    this.form = const [],
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

  static String formatClock(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$h:$min';
  }

  static List<String> _normalizeFormList(dynamic raw) {
    if (raw == null) return const [];
    final tokens = <String>[];
    if (raw is List) {
      for (final item in raw) {
        tokens.add(item.toString().trim().toUpperCase());
      }
    } else {
      final str = raw.toString().trim().toUpperCase();
      if (str.contains(',') || str.contains('-')) {
        tokens.addAll(str.split(RegExp(r'[,\-\s]+')).where((s) => s.isNotEmpty));
      } else {
        for (int i = 0; i < str.length; i++) {
          tokens.add(str[i]);
        }
      }
    }
    return tokens.take(5).map((t) {
      if (t == 'W' || t == 'GY' || t == '1') return 'GY';
      if (t == 'D' || t == 'X') return 'D';
      if (t == 'L' || t == 'V' || t == '2') return 'V';
      return t;
    }).where((t) => t == 'GY' || t == 'D' || t == 'V').toList();
  }

  static List<MatchData> _sortMatches(List<MatchData> list) {
    final sorted = List<MatchData>.of(list);
    sorted.sort((a, b) {
      final favTeamA = DisplayPrefs.isFavoriteTeam(a.homeTeam) || DisplayPrefs.isFavoriteTeam(a.awayTeam);
      final favTeamB = DisplayPrefs.isFavoriteTeam(b.homeTeam) || DisplayPrefs.isFavoriteTeam(b.awayTeam);
      if (favTeamA != favTeamB) return favTeamA ? -1 : 1;
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

  static Future<FetchResult<List<MatchData>>> fetchMatches(
    DateTime date, {
    bool forceRefresh = false,
  }) async {
    if (!ApiConfig.hasValidKey) throw Exception('Nincs megadva API kulcs');

    final dateStr = formatDate(date);
    final todayStr = formatDate(DateTime.now());
    final cacheKey = '${ApiConfig.providerTag}_matches_hu_v4_$dateStr';
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
              ? (_attr(leagueObj, ['name', 'title']) ?? 'Egyéb bajnokság')
              : (leagueObj ?? 'Egyéb bajnokság');
          final rawCountry = leagueObj is Map
              ? (_attr(leagueObj, ['country', 'country_name', 'nation']) ?? '')
              : '';
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
      final rawLeague = _attr(lMap, ['name', 'league_name']) ?? 'Egyéb bajnokság';
      final rawCountry = _attr(lMap, ['country', 'country_name', 'nation']) ?? '';
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

  static MatchData _parseStatPalSingleMatch(Map m, dynamic rawLeagueName, {dynamic rawCountry = ''}) {
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

    final rawLeagueStr = HungarianLocalization.extractRawName(rawLeagueName);
    final countryCandidate = HungarianLocalization.extractRawName(rawCountry).isNotEmpty
        ? rawCountry
        : (_attr(m, ['country', 'country_name', 'nation']) ?? '');
    final country = HungarianLocalization.localizeCountry(countryCandidate, leagueName: rawLeagueStr);
    final flagUrl = HungarianLocalization.extractFlagUrl(countryCandidate);
    final league = HungarianLocalization.localizeLeague(rawLeagueStr, countryName: country);

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
      countryFlagUrl: flagUrl,
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
      } else if (typeRaw.contains('sub')) {
        type = 'sub';
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

  static MatchData _parseHighlightlyMatch(Map m) {
    final homeMap = m['homeTeam'] is Map ? m['homeTeam'] as Map : {};
    final awayMap = m['awayTeam'] is Map ? m['awayTeam'] as Map : {};
    final leagueMap = m['league'] is Map ? m['league'] as Map : {};
    final stateMap = m['state'] is Map ? m['state'] as Map : {};

    final homeName = (homeMap['name'] ?? m['homeTeam'] ?? 'Hazai').toString();
    final awayName = (awayMap['name'] ?? m['awayTeam'] ?? 'Vendég').toString();
    final homeId = homeMap['id']?.toString();
    final awayId = awayMap['id']?.toString();

    final rawLeague = HungarianLocalization.extractRawName(leagueMap['name'] ?? m['league'] ?? 'Egyéb bajnokság');
    final countrySource = leagueMap['country'] ?? m['country'] ?? '';
    final rawCountry = HungarianLocalization.extractRawName(countrySource);
    final flagUrl = HungarianLocalization.extractFlagUrl(countrySource);
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

    final lineupsParsed = _parseLineups(m['lineups'] ?? m['lineup'], homeName, awayName);
    final h2hParsed = _parseH2H(m['h2h'] ?? m['headToHead']);

    return MatchData(
      id: (m['id'] ?? '${homeName}_$awayName').toString(),
      country: country,
      countryFlagUrl: flagUrl,
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
      homeLineup: lineupsParsed['home'],
      awayLineup: lineupsParsed['away'],
      h2hFixtures: h2hParsed,
    );
  }

  static Map<String, TeamLineup?> _parseLineups(dynamic node, String homeName, String awayName) {
    if (node == null) return {'home': null, 'away': null};
    TeamLineup? parseSide(dynamic sideMap) {
      if (sideMap is! Map) return null;
      final formation = (sideMap['formation'] ?? sideMap['system'] ?? '4-3-3').toString();
      final rawStarters = sideMap['startXI'] ?? sideMap['starters'] ?? sideMap['players'] ?? [];
      final rawSubs = sideMap['substitutes'] ?? sideMap['bench'] ?? sideMap['subs'] ?? [];

      List<LineupPlayer> mapPlayers(dynamic list, bool isSub) {
        return _asMapList(list).map((p) {
          final pl = p['player'] is Map ? p['player'] as Map : p;
          return LineupPlayer(
            number: (pl['number'] ?? pl['shirtNumber'] ?? p['number'] ?? '').toString(),
            name: (pl['name'] ?? p['name'] ?? 'Játékos').toString(),
            position: (pl['position'] ?? pl['pos'] ?? p['position'] ?? '').toString(),
            isSubstitute: isSub,
          );
        }).toList();
      }

      return TeamLineup(
        formation: formation,
        starters: mapPlayers(rawStarters, false),
        substitutes: mapPlayers(rawSubs, true),
      );
    }

    if (node is Map) {
      return {
        'home': parseSide(node['home'] ?? node['homeTeam']),
        'away': parseSide(node['away'] ?? node['awayTeam']),
      };
    }
    if (node is List && node.length >= 2) {
      return {
        'home': parseSide(node[0]),
        'away': parseSide(node[1]),
      };
    }
    return {'home': null, 'away': null};
  }

  static List<H2HFixture> _parseH2H(dynamic node) {
    if (node == null) return const [];
    final list = node is Map ? _asMapList(node['matches'] ?? node['data']) : _asMapList(node);
    return list.take(6).map((item) {
      final hMap = item['homeTeam'] is Map ? item['homeTeam'] as Map : {};
      final aMap = item['awayTeam'] is Map ? item['awayTeam'] as Map : {};
      final hName = (hMap['name'] ?? item['homeTeam'] ?? 'Hazai').toString();
      final aName = (aMap['name'] ?? item['awayTeam'] ?? 'Vendég').toString();
      final dateStr = (item['date'] ?? '').toString();
      final shortDate = dateStr.length >= 10 ? dateStr.substring(0, 10) : dateStr;
      final score = item['score'] is Map
          ? (item['score']['current'] ?? '').toString()
          : '${item['homeScore'] ?? '-'} - ${item['awayScore'] ?? '-'}';
      return H2HFixture(
        dateLabel: shortDate,
        homeTeam: hName,
        awayTeam: aName,
        scoreLabel: score,
      );
    }).toList();
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
        } else if (rawType.contains('sub')) {
          type = 'sub';
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

  static Future<FetchResult<MatchData>> enrichMatchDetails(
    MatchData base, {
    bool forceRefresh = false,
  }) async {
    if (!ApiConfig.hasValidKey || !base.isFromApi) {
      return FetchResult(data: _ensureFallbackFormAndLineup(base), fromCache: false);
    }

    final cacheKey = '${ApiConfig.providerTag}_detail_v2_${base.id}';
    final ttl = base.isFinished
        ? const Duration(hours: 12)
        : Duration(seconds: ApiConfig.isStatPal ? 15 : 45);

    if (!forceRefresh) {
      final cachedJson = await ApiCache.get(cacheKey, ttl, savedWeight: 2);
      if (cachedJson != null) {
        final decoded = jsonDecode(cachedJson);
        if (decoded is Map) {
          return FetchResult(fromCache: true, data: _ensureFallbackFormAndLineup(MatchData.fromCacheMap(decoded)));
        }
      }
    }

    if (ApiConfig.isStatPal) {
      return _enrichStatPalV2Details(base, cacheKey);
    } else {
      return _enrichHighlightlyDetails(base, cacheKey);
    }
  }

  static MatchData _ensureFallbackFormAndLineup(MatchData m) {
    final hForm = m.homeForm.isNotEmpty ? m.homeForm : _defaultFormFor(m.homeTeam);
    final aForm = m.awayForm.isNotEmpty ? m.awayForm : _defaultFormFor(m.awayTeam);
    final hLineup = m.homeLineup ?? _defaultLineupFor(m.homeTeam, '4-3-3');
    final aLineup = m.awayLineup ?? _defaultLineupFor(m.awayTeam, '4-2-3-1');
    final h2h = m.h2hFixtures.isNotEmpty
        ? m.h2hFixtures
        : [
            H2HFixture(
              dateLabel: 'Korábbi meccs',
              homeTeam: m.homeTeam,
              awayTeam: m.awayTeam,
              scoreLabel: '${m.homeScore} - ${m.awayScore}',
            ),
          ];
    return m.copyWith(
      homeForm: hForm,
      awayForm: aForm,
      homeLineup: hLineup,
      awayLineup: aLineup,
      h2hFixtures: h2h,
    );
  }

  static List<String> _defaultFormFor(String team) {
    const outcomes = ['GY', 'D', 'GY', 'V', 'GY'];
    final shift = team.codeUnits.fold<int>(0, (a, b) => a + b) % outcomes.length;
    return List.generate(5, (i) => outcomes[(i + shift) % outcomes.length]);
  }

  static TeamLineup _defaultLineupFor(String team, String formation) {
    return TeamLineup(
      formation: formation,
      starters: [
        LineupPlayer(number: '1', name: 'Kapus ($team)', position: 'GK'),
        LineupPlayer(number: '4', name: 'Középhátvéd J.', position: 'DEF'),
        LineupPlayer(number: '5', name: 'Középhátvéd K.', position: 'DEF'),
        LineupPlayer(number: '2', name: 'Jobbhátvéd', position: 'DEF'),
        LineupPlayer(number: '3', name: 'Balhátvéd', position: 'DEF'),
        LineupPlayer(number: '6', name: 'Védekező kp.', position: 'MID'),
        LineupPlayer(number: '8', name: 'Középpályás', position: 'MID'),
        LineupPlayer(number: '10', name: 'Irányító', position: 'MID'),
        LineupPlayer(number: '7', name: 'Jobbszélső', position: 'FWD'),
        LineupPlayer(number: '9', name: 'Középcsatár', position: 'FWD'),
        LineupPlayer(number: '11', name: 'Balszélső', position: 'FWD'),
      ],
      substitutes: const [
        LineupPlayer(number: '12', name: 'Csere játékos 1', position: 'MID', isSubstitute: true),
        LineupPlayer(number: '14', name: 'Csere csatár 2', position: 'FWD', isSubstitute: true),
        LineupPlayer(number: '16', name: 'Csere védő 3', position: 'DEF', isSubstitute: true),
      ],
    );
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
          final lu = _parseLineups(obj['lineups'] ?? obj['lineup'], base.homeTeam, base.awayTeam);
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
            homeLineup: lu['home'] ?? current.homeLineup,
            awayLineup: lu['away'] ?? current.awayLineup,
          );
        }
      }
    } catch (_) {}

    final enriched = _ensureFallbackFormAndLineup(current).copyWith(
      detailNote: rateLimited
          ? 'StatPal kéréskorlát (429) – várj 15 másodpercet a következő frissítésig.'
          : 'StatPal V2 élő adatforrás • Idővonal, 2D felállás és bővített statisztika.',
    );
    if (!rateLimited) {
      await ApiCache.put(cacheKey, jsonEncode(enriched.toCacheMap()));
    }
    return FetchResult(data: enriched, fromCache: false);
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
            homeLineup: updated.homeLineup ?? current.homeLineup,
            awayLineup: updated.awayLineup ?? current.awayLineup,
            h2hFixtures: updated.h2hFixtures.isNotEmpty ? updated.h2hFixtures : current.h2hFixtures,
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
    }

    final finalMatch = _ensureFallbackFormAndLineup(current).copyWith(highlights: clips, detailNote: note);
    if (!rateLimited) {
      await ApiCache.put(cacheKey, jsonEncode(finalMatch.toCacheMap()));
    }
    return FetchResult(fromCache: false, data: finalMatch);
  }

  static const highlightlyLeagueIds = {
    'Premier League': 33973,
    'Bajnokok Ligája': 2486,
    'Európa Liga': 33995,
    'Konferencia Liga': 34001,
    'La Liga': 119924,
    'Bundesliga': 67162,
    'Serie A': 115669,
    'NB I': 34284,
  };

  static const statpalV2LeagueIds = {
    'Premier League': 3037,
    'Bajnokok Ligája': 1005,
    'Európa Liga': 1007,
    'Konferencia Liga': 1009,
    'La Liga': 1399,
    'Bundesliga': 1229,
    'Serie A': 1269,
    'NB I': 1255,
  };

  static Future<int?> _resolveHighlightlyCurrentLeagueId(String leagueName) async {
    final cacheKey = 'hl_league_map_v1';
    final cached = await ApiCache.get(cacheKey, const Duration(hours: 24));
    Map<String, int> discovered = {};
    if (cached != null) {
      final d = jsonDecode(cached);
      if (d is Map) {
        d.forEach((k, v) {
          final parsed = int.tryParse('$v');
          if (parsed != null) discovered[k.toString()] = parsed;
        });
      }
    }

    if (discovered.isEmpty) {
      try {
        final uri = Uri.parse('${ApiConfig.highlightlyBaseUrl}/leagues?limit=100');
        final res = await http.get(uri, headers: ApiConfig.highlightlyHeaders).timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) {
          await ApiCache.recordNetworkCall();
          final body = jsonDecode(res.body);
          final list = body is List ? body : (body is Map && body['data'] is List ? body['data'] : []);
          for (final item in list) {
            if (item is Map) {
              final id = int.tryParse('${item['id'] ?? ''}');
              final rawName = HungarianLocalization.extractRawName(item['name'] ?? '');
              final country = HungarianLocalization.localizeCountry(item['country'] ?? '', leagueName: rawName);
              final locName = HungarianLocalization.localizeLeague(rawName, countryName: country);
              if (id != null) {
                for (final key in highlightlyLeagueIds.keys) {
                  if (locName.toLowerCase() == key.toLowerCase() ||
                      rawName.toLowerCase().contains(key.toLowerCase())) {
                    discovered[key] = id;
                  }
                }
              }
            }
          }
          if (discovered.isNotEmpty) {
            await ApiCache.put(cacheKey, jsonEncode(discovered));
          }
        }
      } catch (_) {}
    }

    return discovered[leagueName] ?? highlightlyLeagueIds[leagueName];
  }

  static Future<FetchResult<List<StandingRow>>> fetchStandings(
    String leagueName, {
    String venueFilter = 'all',
    bool forceRefresh = false,
  }) async {
    if (!ApiConfig.hasValidKey) {
      throw Exception('Nincs API kulcs beállítva');
    }

    final cacheKey = '${ApiConfig.providerTag}_standings_v4_${leagueName}_$venueFilter';
    if (!forceRefresh) {
      final cachedJson = await ApiCache.get(cacheKey, const Duration(minutes: 30));
      if (cachedJson != null) {
        final rows = ApiConfig.isStatPal
            ? _parseStatPalStandingsBody(cachedJson, venueFilter: venueFilter)
            : _parseHighlightlyStandingsBody(cachedJson, venueFilter: venueFilter);
        if (rows.isNotEmpty) {
          return FetchResult(
            data: rows,
            fromCache: true,
            note: 'Gyorsítótár (${ApiConfig.providerName}) • ${rows.length} csapat',
          );
        }
      }
    }

    if (ApiConfig.isStatPal) {
      final id = statpalV2LeagueIds[leagueName];
      if (id == null) throw Exception('Ismeretlen bajnokság: $leagueName');
      final key = Uri.encodeComponent(ApiConfig.statpalKey.trim());
      final candidateUrls = [
        '${ApiConfig.statpalV2BaseUrl}/leagues/$id/standings?access_key=$key',
        '${ApiConfig.statpalV2BaseUrl}/standings?league_id=$id&access_key=$key',
        '${ApiConfig.statpalV1BaseUrl}/standings?league=$id&access_key=$key',
      ];

      String lastErr = 'Nem sikerült tabellát lekérni';
      for (final url in candidateUrls) {
        try {
          final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
          if (res.statusCode == 200) {
            await ApiCache.recordNetworkCall();
            final rows = _parseStatPalStandingsBody(res.body, venueFilter: venueFilter);
            if (rows.isNotEmpty) {
              await ApiCache.put(cacheKey, res.body);
              return FetchResult(
                data: rows,
                fromCache: false,
                note: 'StatPal V2 élő tabella • ${rows.length} csapat',
              );
            }
            lastErr = 'StatPal üres tabellát adott (200)';
          } else {
            lastErr = 'StatPal HTTP ${res.statusCode}';
          }
        } catch (e) {
          lastErr = '$e';
        }
      }
      throw Exception(lastErr);
    } else {
      final resolvedId = await _resolveHighlightlyCurrentLeagueId(leagueName);
      if (resolvedId == null) throw Exception('Ismeretlen bajnokság: $leagueName');

      final now = DateTime.now();
      final seasonYear = now.month >= 7 ? now.year : now.year - 1;
      final candidateUrls = [
        '${ApiConfig.highlightlyBaseUrl}/standings?leagueId=$resolvedId&season=$seasonYear',
        '${ApiConfig.highlightlyBaseUrl}/standings?leagueId=$resolvedId',
        '${ApiConfig.highlightlyBaseUrl}/leagues/$resolvedId/standings',
      ];

      String lastErr = 'Nem sikerült Highlightly tabellát lekérni';
      for (final url in candidateUrls) {
        try {
          final res = await http
              .get(Uri.parse(url), headers: ApiConfig.highlightlyHeaders)
              .timeout(const Duration(seconds: 10));
          if (res.statusCode == 200) {
            await ApiCache.recordNetworkCall();
            final rows = _parseHighlightlyStandingsBody(res.body, venueFilter: venueFilter);
            if (rows.isNotEmpty) {
              await ApiCache.put(cacheKey, res.body);
              return FetchResult(
                data: rows,
                fromCache: false,
                note: 'Highlightly élő tabella (ID: $resolvedId) • ${rows.length} csapat',
              );
            }
            lastErr = 'Highlightly üres tabellát adott (ID: $resolvedId)';
          } else {
            lastErr = 'Highlightly HTTP ${res.statusCode} (ID: $resolvedId)';
          }
        } catch (e) {
          lastErr = '$e';
        }
      }
      throw Exception(lastErr);
    }
  }

  static List<StandingRow> _parseStatPalStandingsBody(String body, {String venueFilter = 'all'}) {
    final decoded = jsonDecode(body);
    List teams = [];

    if (decoded is List) {
      teams = decoded;
    } else if (decoded is Map) {
      if (decoded['data'] is List) {
        teams = decoded['data'] as List;
      } else if (decoded['data'] is Map) {
        final dMap = decoded['data'] as Map;
        teams = _asMapList(dMap['standings'] ?? dMap['table'] ?? dMap['rows'] ?? dMap['team']);
      } else {
        final root = decoded['standings'] ?? decoded['table'] ?? decoded['data'] ?? decoded;
        if (root is Map) {
          final leagues = _asMapList(root['league'] ?? root['leagues']);
          if (leagues.isNotEmpty) {
            final firstLeague = leagues[0] as Map;
            teams = _asMapList(firstLeague['team'] ?? firstLeague['standings'] ?? firstLeague['rows']);
          } else {
            teams = _asMapList(root['team'] ?? root['rows'] ?? root['entries']);
          }
        } else if (root is List) {
          teams = root;
        }
      }
    }

    final rows = _asMapList(teams).map((item) {
      final r = item as Map;
      final teamObj = r['team'] is Map ? r['team'] as Map : r;
      final teamName = (_attr(teamObj, ['name', 'team_name', 'title']) ?? 'Csapat').toString();
      final pos = int.tryParse('${_attr(r, ['position', 'pos', 'rank']) ?? 0}') ?? 0;
      final splitMap = venueFilter == 'home'
          ? (r['home'] is Map ? r['home'] as Map : (r['overall'] is Map ? r['overall'] as Map : r))
          : (venueFilter == 'away'
              ? (r['away'] is Map ? r['away'] as Map : (r['overall'] is Map ? r['overall'] as Map : r))
              : (r['overall'] is Map ? r['overall'] as Map : r));
      final total = venueFilter == 'all'
          ? (r['total'] is Map ? r['total'] as Map : r)
          : splitMap;

      final played = int.tryParse('${_attr(splitMap, ['gp', 'played', 'games', 'matches_played']) ?? 0}') ?? 0;
      final won = int.tryParse('${_attr(splitMap, ['w', 'won', 'wins']) ?? 0}') ?? 0;
      final drawn = int.tryParse('${_attr(splitMap, ['d', 'drawn', 'draws']) ?? 0}') ?? 0;
      final lost = int.tryParse('${_attr(splitMap, ['l', 'lost', 'losses']) ?? 0}') ?? 0;
      final gf = int.tryParse('${_attr(splitMap, ['gs', 'gf', 'scored', 'goals_for']) ?? 0}') ?? 0;
      final ga = int.tryParse('${_attr(splitMap, ['ga', 'against', 'received', 'goals_against']) ?? 0}') ?? 0;
      final gd = int.tryParse('${_attr(total, ['gd', 'goal_difference']) ?? (gf - ga)}') ?? (gf - ga);
      final pts = int.tryParse('${_attr(total, ['p', 'pts', 'points']) ?? 0}') ?? 0;
      final formList = _normalizeFormList(_attr(r, ['form', 'recent_form']) ?? _attr(splitMap, ['form']));

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
        won: won,
        drawn: drawn,
        lost: lost,
        gf: gf,
        ga: ga,
        gd: gd,
        points: pts,
        zone: zone,
        form: formList,
      );
    }).toList();

    if (venueFilter != 'all' && rows.isNotEmpty) {
      rows.sort((a, b) {
        final pCmp = b.points.compareTo(a.points);
        if (pCmp != 0) return pCmp;
        return b.gd.compareTo(a.gd);
      });
      return List.generate(
        rows.length,
        (i) => StandingRow(
          pos: i + 1,
          team: rows[i].team,
          logo: rows[i].logo,
          color: rows[i].color,
          played: rows[i].played,
          won: rows[i].won,
          drawn: rows[i].drawn,
          lost: rows[i].lost,
          gf: rows[i].gf,
          ga: rows[i].ga,
          gd: rows[i].gd,
          points: rows[i].points,
          zone: i < 4 ? 'ucl' : (i < 6 ? 'uel' : 'none'),
          form: rows[i].form,
        ),
      );
    }
    return rows;
  }

  static List<StandingRow> _parseHighlightlyStandingsBody(String body, {String venueFilter = 'all'}) {
    final decoded = jsonDecode(body);
    List rows = [];

    if (decoded is Map) {
      if (decoded['groups'] is List && (decoded['groups'] as List).isNotEmpty) {
        final firstGroup = decoded['groups'][0];
        if (firstGroup is Map) {
          rows = (firstGroup['standings'] ?? firstGroup['rows'] ?? firstGroup['table'] ?? []) as List;
        }
      } else if (decoded['standings'] is List) {
        rows = decoded['standings'] as List;
      } else if (decoded['data'] is List) {
        rows = decoded['data'] as List;
      } else if (decoded['data'] is Map) {
        final dMap = decoded['data'] as Map;
        if (dMap['groups'] is List && (dMap['groups'] as List).isNotEmpty && dMap['groups'][0] is Map) {
          rows = (dMap['groups'][0]['standings'] ?? []) as List;
        } else {
          rows = (dMap['standings'] ?? dMap['table'] ?? dMap['rows'] ?? []) as List;
        }
      }
    } else if (decoded is List) {
      rows = decoded;
    }

    final parsed = _asMapList(rows).map((item) {
      final r = item as Map;
      final teamMap = r['team'] is Map ? r['team'] as Map : r;
      final totalMap = r['total'] is Map ? r['total'] as Map : r;
      final teamName = (teamMap['name'] ?? r['teamName'] ?? 'Csapat').toString();
      final pos = int.tryParse('${r['position'] ?? r['pos'] ?? r['rank'] ?? 0}') ?? 0;

      final splitSource = venueFilter == 'home'
          ? (r['home'] is Map ? r['home'] as Map : totalMap)
          : (venueFilter == 'away'
              ? (r['away'] is Map ? r['away'] as Map : totalMap)
              : totalMap);

      final played = int.tryParse('${splitSource['games'] ?? splitSource['played'] ?? splitSource['matchesPlayed'] ?? 0}') ?? 0;
      final won = int.tryParse('${splitSource['wins'] ?? splitSource['won'] ?? 0}') ?? 0;
      final drawn = int.tryParse('${splitSource['draws'] ?? splitSource['drawn'] ?? 0}') ?? 0;
      final lost = int.tryParse('${splitSource['losses'] ?? splitSource['lost'] ?? 0}') ?? 0;
      final gf = int.tryParse('${splitSource['scoredGoals'] ?? splitSource['goalsFor'] ?? splitSource['gf'] ?? 0}') ?? 0;
      final ga = int.tryParse('${splitSource['receivedGoals'] ?? splitSource['goalsAgainst'] ?? splitSource['ga'] ?? 0}') ?? 0;
      final gd = venueFilter == 'all'
          ? (int.tryParse('${r['goalDifference'] ?? r['gd'] ?? (gf - ga)}') ?? (gf - ga))
          : (gf - ga);
      final pts = venueFilter == 'all'
          ? (int.tryParse('${r['points'] ?? r['pts'] ?? 0}') ?? 0)
          : (int.tryParse('${splitSource['points'] ?? splitSource['pts'] ?? 0}') ?? 0);
      final formList = _normalizeFormList(r['form'] ?? splitSource['form']);

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
        won: won,
        drawn: drawn,
        lost: lost,
        gf: gf,
        ga: ga,
        gd: gd,
        points: pts,
        zone: zone,
        form: formList,
      );
    }).toList();

    if (venueFilter != 'all' && parsed.isNotEmpty) {
      parsed.sort((a, b) {
        final pCmp = b.points.compareTo(a.points);
        if (pCmp != 0) return pCmp;
        return b.gd.compareTo(a.gd);
      });
      return List.generate(
        parsed.length,
        (i) => StandingRow(
          pos: i + 1,
          team: parsed[i].team,
          logo: parsed[i].logo,
          color: parsed[i].color,
          played: parsed[i].played,
          won: parsed[i].won,
          drawn: parsed[i].drawn,
          lost: parsed[i].lost,
          gf: parsed[i].gf,
          ga: parsed[i].ga,
          gd: parsed[i].gd,
          points: parsed[i].points,
          zone: i < 4 ? 'ucl' : (i < 6 ? 'uel' : 'none'),
          form: parsed[i].form,
        ),
      );
    }
    return parsed;
  }
}

// --- DEMO MINTA ADATOK (CSAK HA NINCS API KULCS) ---
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
    homeForm: ['GY', 'GY', 'D', 'GY', 'GY'],
    awayForm: ['GY', 'GY', 'GY', 'D', 'GY'],
    events: [
      MatchEvent(minute: "14'", player: 'Szoboszlai D.', type: 'goal', isHome: false),
      MatchEvent(minute: "39'", player: 'Vinícius Jr.', type: 'goal', isHome: true),
      MatchEvent(minute: "52'", player: 'Salah', type: 'goal', isHome: false),
      MatchEvent(minute: "69'", player: 'Bellingham', type: 'goal', isHome: true),
    ],
  ),
];

const Map<String, List<StandingRow>> sampleStandings = {
  'Premier League': [
    StandingRow(pos: 1, team: 'Minta Liverpool (nincs API adat)', color: Color(0xFFFF1744), played: 10, won: 8, drawn: 1, lost: 1, gf: 22, ga: 8, gd: 14, points: 25, zone: 'ucl', form: ['GY', 'GY', 'D', 'GY', 'GY']),
    StandingRow(pos: 2, team: 'Minta Man. City (nincs API adat)', color: Color(0xFF00B0FF), played: 10, won: 7, drawn: 2, lost: 1, gf: 20, ga: 10, gd: 10, points: 23, zone: 'ucl', form: ['GY', 'D', 'GY', 'GY', 'V']),
  ],
  'La Liga': [
    StandingRow(pos: 1, team: 'Minta Barcelona (nincs API adat)', color: Color(0xFF2979FF), played: 10, won: 8, drawn: 1, lost: 1, gf: 28, ga: 9, gd: 19, points: 25, zone: 'ucl', form: ['GY', 'GY', 'GY', 'D', 'GY']),
    StandingRow(pos: 2, team: 'Minta Real Madrid (nincs API adat)', color: Color(0xFF7C4DFF), played: 10, won: 7, drawn: 2, lost: 1, gf: 21, ga: 8, gd: 13, points: 23, zone: 'ucl', form: ['GY', 'D', 'GY', 'GY', 'GY']),
  ],
};

const sampleTopScorers = {
  'Premier League': [
    TopScorerRow(rank: 1, player: 'Erling Haaland', team: 'Man. City', goals: 12, assists: 1),
    TopScorerRow(rank: 2, player: 'Mohamed Salah', team: 'Liverpool', goals: 10, assists: 6),
  ],
  'NB I': [
    TopScorerRow(rank: 1, player: 'Varga Barnabás', team: 'Ferencváros', goals: 8, assists: 3),
  ],
};
