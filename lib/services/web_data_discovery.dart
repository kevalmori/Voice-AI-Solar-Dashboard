import 'dart:convert';
import 'webview_controller_service.dart';

/// Discovers available data (plants, sensors, inverters, filter types, nav pages)
/// by scraping the live website at runtime. Results are cached with a TTL.
///
/// This replaces ALL hardcoded lists — the app adapts automatically to whatever
/// data the website currently contains.
class WebDataDiscovery {
  final WebViewControllerService _webView;

  // Cached data
  List<String> _plantNames = [];
  List<String> _sensorNames = [];
  List<String> _sensorTypes = [];
  List<String> _inverterNames = [];
  List<String> _navPages = [];

  // Cache timestamps
  DateTime? _plantsLastFetched;
  DateTime? _sensorsLastFetched;
  DateTime? _sensorTypesLastFetched;
  DateTime? _invertersLastFetched;
  DateTime? _navPagesLastFetched;

  // Cache TTL — 5 minutes
  static const Duration _cacheTtl = Duration(minutes: 5);

  // Track if initial discovery has been done
  bool _initialDiscoveryDone = false;
  bool get isReady => _initialDiscoveryDone;

  WebDataDiscovery(this._webView);

  // ══════════════════════════════════════
  // Public API
  // ══════════════════════════════════════

  /// Get all plant names currently on the website
  Future<List<String>> getPlantNames({bool forceRefresh = false}) async {
    if (!forceRefresh && _isCacheValid(_plantsLastFetched)) {
      return _plantNames;
    }
    await _discoverPlants();
    return _plantNames;
  }

  /// Get all sensor names currently on the website
  Future<List<String>> getSensorNames({bool forceRefresh = false}) async {
    if (!forceRefresh && _isCacheValid(_sensorsLastFetched)) {
      return _sensorNames;
    }
    await _discoverSensors();
    return _sensorNames;
  }

  /// Get all sensor filter types (e.g. All, WMS, MFM, Temperature)
  Future<List<String>> getSensorTypes({bool forceRefresh = false}) async {
    if (!forceRefresh && _isCacheValid(_sensorTypesLastFetched)) {
      return _sensorTypes;
    }
    await _discoverSensorTypes();
    return _sensorTypes;
  }

  /// Get all inverter names currently on the website
  Future<List<String>> getInverterNames({bool forceRefresh = false}) async {
    if (!forceRefresh && _isCacheValid(_invertersLastFetched)) {
      return _inverterNames;
    }
    await _discoverInverters();
    return _inverterNames;
  }

  /// Get all navigation page names from the sidebar
  Future<List<String>> getNavPages({bool forceRefresh = false}) async {
    if (!forceRefresh && _isCacheValid(_navPagesLastFetched)) {
      return _navPages;
    }
    await _discoverNavPages();
    return _navPages;
  }

  /// Run initial discovery — only scrapes data from the CURRENT page.
  /// Does NOT navigate to other pages (that would disrupt the user).
  /// Call this after the WebView has loaded the dashboard.
  Future<void> runInitialDiscovery() async {
    if (_initialDiscoveryDone) return;
    try {
      // Only discover nav pages from the sidebar (visible on every page)
      await _discoverNavPages();
      _initialDiscoveryDone = true;
    } catch (e) {
      _initialDiscoveryDone = true;
    }
  }

  /// Opportunistically discover data from whatever page is currently loaded.
  /// Call this on URL changes — it scrapes the current page WITHOUT navigating.
  Future<void> discoverFromCurrentPage() async {
    final url = _webView.currentUrl.toLowerCase();
    try {
      if (url.contains('/plants')) {
        await _scrapePlantsFromCurrentPage();
      } else if (url.contains('/sensors')) {
        await _scrapeSensorsFromCurrentPage();
        await _scrapeSensorTypesFromCurrentPage();
      } else if (url.contains('/inverters')) {
        await _scrapeInvertersFromCurrentPage();
      }
    } catch (_) {
      // Non-critical
    }
  }

  /// Build a dynamic system prompt using the currently cached data
  String buildDynamicSystemPrompt() {
    final plants = _plantNames.isNotEmpty
        ? _plantNames.join(', ')
        : '(none discovered yet)';
    final sensors = _sensorNames.isNotEmpty
        ? _sensorNames.join(', ')
        : '(none discovered yet)';
    final sensorTypes = _sensorTypes.isNotEmpty
        ? _sensorTypes.join(', ')
        : '(none discovered yet)';
    final inverters = _inverterNames.isNotEmpty
        ? _inverterNames.join(', ')
        : '(none discovered yet)';
    final pages = _navPages.isNotEmpty
        ? _navPages.join(', ')
        : '/dashboard, /plants, /inverters, /slmsDevices, /sensors';

    return '''
You are a smart assistant controlling the aALoK solar monitoring dashboard. You help users navigate and interact with the website using tool calls.

IMPORTANT: Use combined tools that handle ALL steps automatically. Do NOT chain multiple tools — use the single combined tool instead.

Available pages: $pages

TOOL USAGE GUIDE:
- User wants to see a plant → use open_plant_by_name(name)
- User wants plant energy data → use show_plant_energy(name, period)
- User wants plant revenue data → use show_plant_revenue(name, period)
- User wants to see a sensor → use open_sensor_by_name(name)
- User wants to filter sensors → use filter_sensors_by_type(type)
- User wants to open an inverter → use open_inverter_by_name(name)
- User wants dashboard energy/revenue → use switch_dashboard_tab(tab, period)
- User wants to read the page → use read_page_content()
- User wants to go back → use go_back()

Known plants: $plants
Known sensors: $sensors
Known inverters: $inverters
Sensor types: $sensorTypes
Periods: Monthly, Yearly, LifeTime
Dashboard tabs: Energy, Revenue

Always call exactly ONE tool per step. After completing, briefly summarize what was done and suggest 2-3 next actions as a numbered list.
''';
  }

  /// Check if the user input contains any token that fuzzy-matches a known sensor name.
  /// Returns true if any sensor keyword is found in the text.
  bool textContainsSensorKeyword(String text) {
    final normalized = _normalize(text);
    for (final sensor in _sensorNames) {
      final sensorNorm = _normalize(sensor);
      // Check if any significant token from the sensor name appears in the text
      final tokens = sensorNorm.split(' ').where((t) => t.length >= 3).toList();
      for (final token in tokens) {
        if (normalized.contains(token)) return true;
      }
    }
    return false;
  }

  /// Check if the user input mentions a sensor type.
  /// Returns the matched type or null.
  String? matchSensorType(String text) {
    final normalized = _normalize(text);
    for (final type in _sensorTypes) {
      if (type.toLowerCase() == 'all') continue; // Skip 'All' — too generic
      if (normalized.contains(type.toLowerCase())) return type;
    }
    // Also check common aliases
    if (normalized.contains('temp') && _sensorTypes.any((t) => t.toLowerCase() == 'temperature')) {
      return 'Temperature';
    }
    if (normalized.contains('all') && !normalized.contains('install')) {
      return 'All';
    }
    return null;
  }

  /// Find the best matching sensor name for the given user input.
  /// Returns null if no match is found.
  String? findBestSensorMatch(String text) {
    return _findBestMatch(text, _sensorNames);
  }

  /// Find the best matching plant name for the given user input.
  /// Returns null if no match is found.
  String? findBestPlantMatch(String text) {
    return _findBestMatch(text, _plantNames);
  }

  /// Find the best matching inverter name for the given user input.
  /// Returns null if no match is found.
  String? findBestInverterMatch(String text) {
    return _findBestMatch(text, _inverterNames);
  }

  /// Get a suggestion list string (first N items) for response messages
  String getSensorSuggestions({int max = 5}) {
    if (_sensorNames.isEmpty) return '(run "show sensors" to discover available sensors)';
    final items = _sensorNames.take(max).toList();
    return items.join(', ') + (_sensorNames.length > max ? ', ...' : '');
  }

  String getPlantSuggestions({int max = 5}) {
    if (_plantNames.isEmpty) return '(run "open plants" to discover available plants)';
    final items = _plantNames.take(max).toList();
    return items.join(', ') + (_plantNames.length > max ? ', ...' : '');
  }

  String getInverterSuggestions({int max = 5}) {
    if (_inverterNames.isEmpty) return '(run "open inverters" to discover available inverters)';
    final items = _inverterNames.take(max).toList();
    return items.join(', ') + (_inverterNames.length > max ? ', ...' : '');
  }

  String getSensorTypeSuggestions() {
    if (_sensorTypes.isEmpty) return '(discover sensor types first)';
    return _sensorTypes.join(', ');
  }

  // ══════════════════════════════════════
  // Private scraping methods (NO navigation — scrape current page only)
  // ══════════════════════════════════════

  /// Scrape plant names from the CURRENT page (must already be on /plants)
  Future<void> _scrapePlantsFromCurrentPage() async {
    final result = await _webView.executeJS('''
      (function() {
        var plants = [];
        var cards = document.querySelectorAll('.MuiCard-root, .MuiPaper-root');
        for (var i = 0; i < cards.length; i++) {
          var cardText = cards[i].innerText.trim();
          if (cardText.length > 5 && (cardText.toUpperCase().includes('KWH') || cardText.toUpperCase().includes('ACTIVE') || cardText.toUpperCase().includes('KWP'))) {
            var lines = cardText.split('\\n');
            var name = lines[0].trim();
            if (name.length > 2 && plants.indexOf(name) === -1) {
              plants.push(name);
            }
          }
        }
        if (plants.length === 0) {
          var allDivs = document.querySelectorAll('h2, h3, h4, h5, div');
          for (var j = 0; j < allDivs.length; j++) {
            var t = allDivs[j].innerText.trim();
            if (t.toUpperCase().includes('KWH') && t.length < 500) {
              var firstLine = t.split('\\n')[0].trim();
              if (firstLine.length > 3 && plants.indexOf(firstLine) === -1) {
                plants.push(firstLine);
              }
            }
          }
        }
        return JSON.stringify(plants);
      })()
    ''');
    final parsed = _parseJsonList(result);
    if (parsed.isNotEmpty) {
      _plantNames = parsed;
      _plantsLastFetched = DateTime.now();
    }
  }

  /// Scrape sensor names from the CURRENT page (must already be on /sensors)
  Future<void> _scrapeSensorsFromCurrentPage() async {
    final result = await _webView.executeJS('''
      (function() {
        var sensors = [];
        var rows = document.querySelectorAll('tbody tr');
        for (var i = 0; i < rows.length; i++) {
          var cells = rows[i].querySelectorAll('td');
          if (cells.length > 0) {
            var name = cells[0].innerText.trim();
            if (name.length > 0 && sensors.indexOf(name) === -1) {
              sensors.push(name);
            }
          }
        }
        return JSON.stringify(sensors);
      })()
    ''');
    final parsed = _parseJsonList(result);
    if (parsed.isNotEmpty) {
      _sensorNames = parsed;
      _sensorsLastFetched = DateTime.now();
    }
  }

  /// Scrape sensor type tabs from the CURRENT page (must already be on /sensors)
  Future<void> _scrapeSensorTypesFromCurrentPage() async {
    final result = await _webView.executeJS('''
      (function() {
        var types = [];
        var tabs = document.querySelectorAll('[role="tab"], button.MuiTab-root, .MuiTab-root, .MuiToggleButton-root');
        for (var i = 0; i < tabs.length; i++) {
          var txt = tabs[i].innerText.trim();
          if (txt.length > 0 && txt.length < 30 && types.indexOf(txt) === -1) {
            types.push(txt);
          }
        }
        return JSON.stringify(types);
      })()
    ''');
    final parsed = _parseJsonList(result);
    if (parsed.isNotEmpty) {
      _sensorTypes = parsed;
      _sensorTypesLastFetched = DateTime.now();
    }
  }

  /// Scrape inverter names from the CURRENT page (must already be on /inverters)
  Future<void> _scrapeInvertersFromCurrentPage() async {
    final result = await _webView.executeJS('''
      (function() {
        var inverters = [];
        var rows = document.querySelectorAll('tbody tr');
        for (var i = 0; i < rows.length; i++) {
          var cells = rows[i].querySelectorAll('td');
          if (cells.length > 0) {
            var name = cells[0].innerText.trim();
            if (name.length > 0 && inverters.indexOf(name) === -1) {
              inverters.push(name);
            }
          }
        }
        if (inverters.length === 0) {
          var cards = document.querySelectorAll('.MuiCard-root, .MuiListItem-root');
          for (var i = 0; i < cards.length; i++) {
            var txt = cards[i].innerText.trim().split('\\n')[0].trim();
            if (txt.length > 2 && inverters.indexOf(txt) === -1) {
              inverters.push(txt);
            }
          }
        }
        return JSON.stringify(inverters);
      })()
    ''');
    final parsed = _parseJsonList(result);
    if (parsed.isNotEmpty) {
      _inverterNames = parsed;
      _invertersLastFetched = DateTime.now();
    }
  }

  /// Discover nav links from the sidebar (visible on every page, no navigation needed)
  Future<void> _discoverNavPages() async {
    final result = await _webView.executeJS('''
      (function() {
        var pages = [];
        var links = document.querySelectorAll('a[href], .MuiListItemButton-root, [role="menuitem"]');
        for (var i = 0; i < links.length; i++) {
          var href = links[i].getAttribute('href') || '';
          var text = links[i].innerText.trim();
          if (href.startsWith('/') && href.length > 1 && text.length > 0 && text.length < 30) {
            var entry = href + '|' + text;
            if (pages.indexOf(entry) === -1) {
              pages.push(entry);
            }
          }
        }
        return JSON.stringify(pages);
      })()
    ''');
    final rawList = _parseJsonList(result);
    _navPages = rawList.map((entry) {
      final parts = entry.split('|');
      return parts.length >= 2 ? parts[0] : entry;
    }).toList();
    _navPagesLastFetched = DateTime.now();
  }

  // ══════════════════════════════════════
  // Helpers
  // ══════════════════════════════════════

  bool _isCacheValid(DateTime? lastFetched) {
    if (lastFetched == null) return false;
    return DateTime.now().difference(lastFetched) < _cacheTtl;
  }

  /// Parse a JSON string into a list of strings, handling edge cases gracefully
  List<String> _parseJsonList(String raw) {
    try {
      // Remove surrounding quotes if the JS bridge wrapped it
      var cleaned = raw.trim();
      if (cleaned.startsWith('"') && cleaned.endsWith('"')) {
        cleaned = cleaned.substring(1, cleaned.length - 1);
        // Unescape inner quotes
        cleaned = cleaned.replaceAll('\\"', '"');
      }
      if (!cleaned.startsWith('[')) return [];
      final decoded = _jsonDecode(cleaned);
      if (decoded is List) {
        return decoded
            .whereType<String>()
            .where((s) => s.trim().isNotEmpty)
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Decode a JSON string
  dynamic _jsonDecode(String source) {
    return jsonDecode(source);
  }

  /// Navigate to /plants, scrape, then return to the original page
  Future<void> _discoverPlants() async {
    final originalUrl = _webView.currentUrl;
    final isAlreadyOnPlants = originalUrl.toLowerCase().contains('/plants');
    if (isAlreadyOnPlants) {
      await _scrapePlantsFromCurrentPage();
      return;
    }
    // Navigate to /plants, scrape, navigate back
    await _webView.navigateTo('/plants');
    await Future.delayed(const Duration(seconds: 2));
    await _scrapePlantsFromCurrentPage();
    // Return to original page
    if (originalUrl.isNotEmpty) {
      _webView.controller?.goBack();
    }
  }

  /// Navigate to /sensors, scrape sensor names, then return
  Future<void> _discoverSensors() async {
    final originalUrl = _webView.currentUrl;
    final isAlreadyOnSensors = originalUrl.toLowerCase().contains('/sensors');
    if (isAlreadyOnSensors) {
      await _scrapeSensorsFromCurrentPage();
      return;
    }
    await _webView.navigateTo('/sensors');
    await Future.delayed(const Duration(seconds: 2));
    await _scrapeSensorsFromCurrentPage();
    if (originalUrl.isNotEmpty) {
      _webView.controller?.goBack();
    }
  }

  /// Navigate to /sensors, scrape sensor types, then return
  Future<void> _discoverSensorTypes() async {
    final originalUrl = _webView.currentUrl;
    final isAlreadyOnSensors = originalUrl.toLowerCase().contains('/sensors');
    if (isAlreadyOnSensors) {
      await _scrapeSensorTypesFromCurrentPage();
      return;
    }
    await _webView.navigateTo('/sensors');
    await Future.delayed(const Duration(seconds: 2));
    await _scrapeSensorTypesFromCurrentPage();
    if (originalUrl.isNotEmpty) {
      _webView.controller?.goBack();
    }
  }

  /// Navigate to /inverters, scrape inverter names, then return
  Future<void> _discoverInverters() async {
    final originalUrl = _webView.currentUrl;
    final isAlreadyOnInverters = originalUrl.toLowerCase().contains('/inverters');
    if (isAlreadyOnInverters) {
      await _scrapeInvertersFromCurrentPage();
      return;
    }
    await _webView.navigateTo('/inverters');
    await Future.delayed(const Duration(seconds: 2));
    await _scrapeInvertersFromCurrentPage();
    if (originalUrl.isNotEmpty) {
      _webView.controller?.goBack();
    }
  }


  String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r"[''']"), '')
        .replaceAll(RegExp(r'[_\-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Generic fuzzy matcher: find the best matching name from a list
  String? _findBestMatch(String text, List<String> candidates) {
    if (candidates.isEmpty) return null;

    // Remove command filler words from input
    final fillers = [
      'open', 'show', 'go', 'to', 'navigate', 'the', 'a', 'an',
      'plant', 'plants', 'please', 'can', 'you', 'me', 'display',
      'energy', 'revenue', 'income', 'earning', 'earnings',
      'monthly', 'yearly', 'lifetime', 'month', 'year',
      'for', 'of', 'from', 'in', 'on', 'at', 'with',
      'details', 'detail', 'data', 'info', 'information',
      'check', 'get', 'find', 'select', 'switch', 'change',
      'sensor', 'sensors', 'inverter', 'inverters',
    ];

    final inputNorm = _normalize(text);
    final inputTokens = inputNorm
        .split(' ')
        .where((w) => w.isNotEmpty && !fillers.contains(w))
        .toList();

    if (inputTokens.isEmpty) return null;

    String? bestMatch;
    int bestScore = 0;

    for (final candidate in candidates) {
      final candNorm = _normalize(candidate);
      final candTokens = candNorm.split(' ').where((w) => w.isNotEmpty).toList();
      int score = 0;

      // Exact normalized match
      if (candNorm == inputNorm) {
        score += 1000;
      } else if (candNorm.contains(inputTokens.join(' '))) {
        score += 500;
      } else if (inputNorm.contains(candNorm)) {
        score += 400;
      }

      // Token matching
      int matched = 0;
      for (final it in inputTokens) {
        for (final ct in candTokens) {
          if (it == ct) {
            score += 30;
            matched++;
            break;
          } else if (ct.startsWith(it) || it.startsWith(ct)) {
            score += 20;
            matched++;
            break;
          } else if (ct.contains(it) || it.contains(ct)) {
            score += 10;
            matched++;
            break;
          }
        }
      }

      if (inputTokens.isNotEmpty && matched == inputTokens.length) {
        score += 100;
      }

      // Number matching — critical for "inverter 4" → "MODULE_INVERTER_4"
      final inputNumbers = RegExp(r'\d+').allMatches(inputNorm).map((m) => m.group(0)!).toList();
      final candNumbers = RegExp(r'\d+').allMatches(candNorm).map((m) => m.group(0)!).toList();
      for (final num in inputNumbers) {
        if (candNumbers.contains(num)) score += 50;
      }

      if (score > bestScore) {
        bestScore = score;
        bestMatch = candidate;
      }
    }

    return bestScore > 0 ? bestMatch : null;
  }
}
