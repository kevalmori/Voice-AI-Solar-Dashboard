import '../tools/tool_registry.dart';
import '../models/chat_message.dart';
import '../services/web_data_discovery.dart';

/// A command result from the local router
class CommandResult {
  final String response;
  final List<ToolCallInfo> toolCalls;
  final List<String> suggestions;
  final bool matched;

  CommandResult({
    required this.response,
    this.toolCalls = const [],
    this.suggestions = const [],
    this.matched = true,
  });
}

/// Locally matches user input to tool functions using keyword/pattern matching.
/// No API calls — everything runs on-device.
///
/// ALL data (plants, sensors, inverters, types) is discovered dynamically from
/// the website at runtime via [WebDataDiscovery]. Nothing is hardcoded.
class CommandRouter {
  final ToolRegistry _toolRegistry;
  final WebDataDiscovery _discovery;

  /// Fixed sensor filter types
  static const List<String> sensorTypes = ['All', 'WMS', 'MFM', 'Temperature'];

  CommandRouter(this._toolRegistry, this._discovery);

  /// Try to match user input to a known command.
  Future<CommandResult> processMessage(String input) async {
    // Normalize: strip apostrophes so voice "can't" matches keyword "cant"
    // Also map common mispronunciation "early" to "yearly"
    final text = input.toLowerCase().trim()
        .replaceAll("'", '')
        .replaceAll("\u2019", '')
        .replaceAll(RegExp(r'\bearly\b'), 'yearly');
    final tools = <ToolCallInfo>[];

    try {
      // ── Navigation commands (highest priority) ──
      if (_matches(text, ['dashboard', 'home']) && !_containsAny(text, ['energy', 'revenue', 'month', 'year'])) {
        tools.add(_tool('open_dashboard', {}));
        await _toolRegistry.executeTool('open_dashboard', {});
        return CommandResult(
          response: 'Opened the dashboard.',
          toolCalls: _markDone(tools),
          suggestions: ['Show energy', 'Show revenue', 'Open plants', 'Open sensors'],
        );
      }

      // ── Plant commands ──
      if (_matches(text, ['plant']) &&
          !_containsAny(text, ['sensor', 'inverter', 'dashboard'])) {
        final plantName = _extractEntityName(text, ['plant', 'plants']);

        if (plantName != null) {
          // Energy request for a specific plant
          if (_containsAny(text, ['energy'])) {
            final period = _extractPeriod(text);
            tools.add(_tool('show_plant_energy', {'name': plantName, 'period': period}));
            await _toolRegistry.executeTool(
                'show_plant_energy', {'name': plantName, 'period': period});
            return CommandResult(
              response: 'Showing ${period ?? "monthly"} energy for $plantName plant.',
              toolCalls: _markDone(tools),
              suggestions: ['Show revenue', 'Yearly', 'Monthly', 'Go back'],
            );
          }

          // Revenue request for a specific plant
          if (_containsAny(text, ['revenue', 'income', 'earning'])) {
            final period = _extractPeriod(text);
            tools.add(_tool('show_plant_revenue', {'name': plantName, 'period': period}));
            await _toolRegistry.executeTool(
                'show_plant_revenue', {'name': plantName, 'period': period});
            return CommandResult(
              response: 'Showing ${period ?? "monthly"} revenue for $plantName plant.',
              toolCalls: _markDone(tools),
              suggestions: ['Show energy', 'Yearly', 'Monthly', 'Go back'],
            );
          }

          // Just open the plant
          tools.add(_tool('open_plant_by_name', {'name': plantName}));
          await _toolRegistry.executeTool(
              'open_plant_by_name', {'name': plantName});
          return CommandResult(
            response: 'Opened $plantName plant details.',
            toolCalls: _markDone(tools),
            suggestions: ['Show energy data', 'Show revenue data', 'Go back'],
          );
        }

        // No specific plant → open plants list
        tools.add(_tool('open_plants', {}));
        await _toolRegistry.executeTool('open_plants', {});
        return CommandResult(
          response: 'Opened the plants page.',
          toolCalls: _markDone(tools),
          suggestions: _plantListSuggestions(),
        );
      }

      // ── Sensor type filter commands (e.g. "open temperature sensor", "show wms sensors") ──
      // Must be checked BEFORE generic sensor commands
      final sensorTypeMatch = _matchSensorTypeFromText(text);
      if (sensorTypeMatch != null &&
          _containsAny(text, ['sensor', 'sensors', 'filter', 'type', 'show', 'open',
            'temperature', 'temp', 'wms', 'mfm'])) {
        tools.add(_tool('filter_sensors_by_type', {'type': sensorTypeMatch}));
        await _toolRegistry.executeTool(
            'filter_sensors_by_type', {'type': sensorTypeMatch});
        return CommandResult(
          response: 'Showing $sensorTypeMatch sensors.',
          toolCalls: _markDone(tools),
          suggestions: _sensorFilteredSuggestions(sensorTypeMatch),
        );
      }

      // ── Sensor commands ──
      if (_containsAny(text, ['sensor', 'sensors']) ||
          (_discovery.textContainsSensorKeyword(text) &&
           !_containsAny(text, ['inverter', 'plant']))) {
        // Check for sensor type filter
        final filterType = _discovery.matchSensorType(text);
        if (filterType != null && !_hasSpecificItemIdentifier(text)) {
          tools.add(_tool('filter_sensors_by_type', {'type': filterType}));
          await _toolRegistry.executeTool(
              'filter_sensors_by_type', {'type': filterType});
          return CommandResult(
            response: 'Showing $filterType sensors.',
            toolCalls: _markDone(tools),
            suggestions: _sensorFilteredSuggestions(filterType),
          );
        }

        final sensorName = _extractEntityName(text, ['sensor', 'sensors']);
        if (sensorName != null) {
          tools.add(_tool('open_sensor_by_name', {'name': sensorName}));
          await _toolRegistry.executeTool(
              'open_sensor_by_name', {'name': sensorName});
          return CommandResult(
            response: 'Opened sensor $sensorName.',
            toolCalls: _markDone(tools),
            suggestions: ['Get sensor value', 'Go back', 'Open dashboard'],
          );
        }

        tools.add(_tool('open_sensors', {}));
        await _toolRegistry.executeTool('open_sensors', {});
        return CommandResult(
          response: 'Opened the sensors page.',
          toolCalls: _markDone(tools),
          suggestions: _sensorListSuggestions(),
        );
      }

      // ── Inverter commands ──
      if (_containsAny(text, ['inverter'])) {
        final inverterName = _extractEntityName(text, ['inverter', 'inverters']);
        if (inverterName != null) {
          tools.add(_tool('open_inverter_by_name', {'name': inverterName}));
          await _toolRegistry.executeTool(
              'open_inverter_by_name', {'name': inverterName});
          return CommandResult(
            response: 'Opened inverter $inverterName.',
            toolCalls: _markDone(tools),
            suggestions: ['Go back', 'Open dashboard', 'Open sensors'],
          );
        }

        tools.add(_tool('open_inverters', {}));
        await _toolRegistry.executeTool('open_inverters', {});
        return CommandResult(
          response: 'Opened the inverters page.',
          toolCalls: _markDone(tools),
          suggestions: _inverterListSuggestions(),
        );
      }

      // ── SLM commands ──
      if (_containsAny(text, ['slm'])) {
        tools.add(_tool('open_slms', {}));
        await _toolRegistry.executeTool('open_slms', {});
        return CommandResult(
          response: 'Opened the SLMs page.',
          toolCalls: _markDone(tools),
          suggestions: ['Open dashboard', 'Open sensors', 'Open plants'],
        );
      }

      // ── Dashboard tab/period commands (energy/revenue) ──
      if (_containsAny(text, ['energy', 'revenue'])) {
        final tab = _containsAny(text, ['revenue']) ? 'Revenue' : 'Energy';
        final otherTab = tab == 'Energy' ? 'Revenue' : 'Energy';
        final period = _extractPeriod(text);
        tools.add(_tool('switch_dashboard_tab', {'tab': tab, 'period': period}));
        await _toolRegistry.executeTool(
            'switch_dashboard_tab', {'tab': tab, 'period': period});

        // If user also specified a year (e.g. "yearly revenue for 2022"), navigate to that year
        final year = _extractYear(text);
        String yearResponse = '';
        if (year != null) {
          tools.add(_tool('change_year', {'year': year}));
          final yearResult = await _toolRegistry.executeTool('change_year', {'year': year});
          yearResponse = ' $yearResult';
        }

        // If user also specified a month (e.g. "show monthly revenue of december"),
        // navigate to that month after switching the tab
        final month = _extractMonth(text);
        String monthResponse = '';
        if (month != null) {
          // Wait for Monthly view to fully render with month arrows
          await Future.delayed(const Duration(milliseconds: 2000));
          tools.add(_tool('change_month', {'month': month}));
          final monthResult = await _toolRegistry.executeTool('change_month', {'month': month});
          monthResponse = ' $monthResult';
        }

        return CommandResult(
          response: 'Switched to $tab${period != null ? " ($period)" : ""} view.$yearResponse$monthResponse',
          toolCalls: _markDone(tools),
          suggestions: ['Show $otherTab', 'Yearly', 'Monthly', 'Open plants'],
        );
      }

      // ── Month navigation commands ──
      if (_containsAny(text, ['month'])) {
        if (_containsAny(text, ['next', 'forward', 'ahead'])) {
          tools.add(_tool('click_navigation_arrow', {'direction': 'next'}));
          await _toolRegistry.executeTool('click_navigation_arrow', {'direction': 'next'});
          return CommandResult(
            response: 'Moved to the next month.',
            toolCalls: _markDone(tools),
            suggestions: ['Next month', 'Previous month', 'Show energy', 'Show revenue'],
          );
        }

        if (_containsAny(text, ['previous', 'prev', 'last', 'back', 'before'])) {
          tools.add(_tool('click_navigation_arrow', {'direction': 'prev'}));
          await _toolRegistry.executeTool('click_navigation_arrow', {'direction': 'prev'});
          return CommandResult(
            response: 'Moved to the previous month.',
            toolCalls: _markDone(tools),
            suggestions: ['Previous month', 'Next month', 'Show energy', 'Show revenue'],
          );
        }

        final month = _extractMonth(text);
        if (month != null) {
          tools.add(_tool('change_month', {'month': month}));
          await _toolRegistry.executeTool('change_month', {'month': month});
          return CommandResult(
            response: 'Changed to $month.',
            toolCalls: _markDone(tools),
            suggestions: ['Next month', 'Previous month', 'Show energy', 'Show revenue'],
          );
        }
      }

      // ── Specific month without "month" keyword (e.g. "change to april", "for january") ──
      final monthDirect = _extractMonth(text);
      if (monthDirect != null && _containsAny(text, ['change', 'go to', 'select', 'switch', 'set', 'for'])) {
        tools.add(_tool('change_month', {'month': monthDirect}));
        await _toolRegistry.executeTool('change_month', {'month': monthDirect});
        return CommandResult(
          response: 'Changed to $monthDirect.',
          toolCalls: _markDone(tools),
          suggestions: ['Next month', 'Previous month', 'Show energy', 'Show revenue'],
        );
      }

      // ── Year navigation (e.g. "year 2022", "change year to 2023") ──
      final year = _extractYear(text);
      if (year != null && _containsAny(text, ['year', 'change', 'go to', 'select', 'switch', 'set', 'for'])) {
        tools.add(_tool('change_year', {'year': year}));
        await _toolRegistry.executeTool('change_year', {'year': year});
        return CommandResult(
          response: 'Changed to year $year.',
          toolCalls: _markDone(tools),
          suggestions: ['Show energy', 'Show revenue', 'Open plants'],
        );
      }

      // ── Sensor detail commands (only when on sensor page) ──
      if (_containsAny(text, ['value', 'reading']) &&
          !_containsAny(text, ['energy', 'revenue', 'month', 'year', 'plant', 'sensor list'])) {
        tools.add(_tool('get_sensor_value', {}));
        final value = await _toolRegistry.executeTool('get_sensor_value', {});
        return CommandResult(
          response: 'Current sensor value: $value',
          toolCalls: _markDone(tools),
          suggestions: ['Go back', 'Open sensors', 'Open dashboard'],
        );
      }

      // ── Go back ──
      if (_containsAny(text, ['back', 'previous', 'return'])) {
        tools.add(_tool('go_back', {}));
        await _toolRegistry.executeTool('go_back', {});
        return CommandResult(
          response: 'Went back to the previous page.',
          toolCalls: _markDone(tools),
          suggestions: ['Open dashboard', 'Open plants', 'Show sensors'],
        );
      }

      // ── Scroll ──
      if (_containsAny(text, ['scroll'])) {
        final direction = _containsAny(text, ['up']) ? 'up' : 'down';
        final otherDir = direction == 'up' ? 'down' : 'up';
        tools.add(_tool('scroll_page', {'direction': direction}));
        await _toolRegistry.executeTool('scroll_page', {'direction': direction});
        return CommandResult(
          response: 'Scrolled $direction.',
          toolCalls: _markDone(tools),
          suggestions: ['Scroll $otherDir', 'Go back', 'Open dashboard'],
        );
      }

      // ── Alert commands ──
      if (_containsAny(text, ['alert', 'notification'])) {
        tools.add(_tool('click_by_text', {'text': 'Alerts'}));
        await _toolRegistry.executeTool('click_by_text', {'text': 'Alerts'});
        return CommandResult(
          response: 'Opened alerts.',
          toolCalls: _markDone(tools),
          suggestions: ['Open dashboard', 'Go back'],
        );
      }

      // ── Period-only commands (Monthly/Yearly/LifeTime) ──
      final periodOnly = _extractPeriod(text);
      if (periodOnly != null && text.split(' ').length <= 3) {
        tools.add(_tool('click_by_text', {'text': periodOnly}));
        await _toolRegistry.executeTool('click_by_text', {'text': periodOnly});
        return CommandResult(
          response: 'Selected $periodOnly view.',
          toolCalls: _markDone(tools),
          suggestions: ['Show energy', 'Show revenue', 'Open plants'],
        );
      }

      // ── Read page ──
      if (_containsAny(text, ['read page', 'whats on the page', 'page content', 'read content']) &&
          !_containsAny(text, ['energy', 'revenue', 'plant', 'sensor', 'inverter', 'month', 'year'])) {
        tools.add(_tool('read_page_content', {}));
        await _toolRegistry.executeTool('read_page_content', {});
        return CommandResult(
          response: 'I\'ve read the current page for you.',
          toolCalls: _markDone(tools),
          suggestions: ['Open dashboard', 'Open plants', 'Show sensors'],
        );
      }

      // ── No match ──
      return CommandResult(
        response: 'Sorry, I didn\'t understand that command. Try tapping a suggestion below or say something like "open plants" or "show sensors".',
        suggestions: _defaultSuggestions(),
      );

    } catch (e) {
      return CommandResult(
        response: 'Sorry, something went wrong. Please try again.',
        suggestions: _defaultSuggestions(),
      );
    }
  }

  // ════════════════════════════════════
  // Dynamic suggestion builders
  // ════════════════════════════════════

  /// Default suggestions for fallback/error
  List<String> _defaultSuggestions() {
    return ['Open dashboard', 'Open plants', 'Show sensors', 'Show inverters'];
  }

  /// Suggestions after opening the plants list
  List<String> _plantListSuggestions() {
    final plants = _discovery.getPlantSuggestions(max: 2);
    if (plants.contains('(run')) {
      // Discovery hasn't run yet — show generic
      return ['Open dashboard', 'Show sensors', 'Show inverters'];
    }
    // Show discovered plant names as actionable commands
    final names = plants.split(', ').take(2).toList();
    final suggestions = <String>[];
    for (final name in names) {
      if (name.isNotEmpty && !name.startsWith('(') && name.length < 25) {
        suggestions.add('Open $name plant');
      }
    }
    suggestions.add('Open dashboard');
    return suggestions.take(4).toList();
  }

  /// Suggestions after opening the sensors list
  List<String> _sensorListSuggestions() {
    return ['Filter WMS', 'Filter MFM', 'Filter Temperature', 'Open dashboard'];
  }

  /// Suggestions after filtering sensors by type
  List<String> _sensorFilteredSuggestions(String currentType) {
    final suggestions = <String>[];
    // Suggest other filter types
    for (final type in sensorTypes) {
      if (type.toLowerCase() != currentType.toLowerCase() && type != 'All') {
        suggestions.add('Filter $type');
      }
    }
    suggestions.add('Show all sensors');
    suggestions.add('Go back');
    return suggestions.take(4).toList();
  }

  /// Suggestions after opening the inverters list
  List<String> _inverterListSuggestions() {
    final inverters = _discovery.getInverterSuggestions(max: 2);
    if (inverters.contains('(run')) {
      return ['Open dashboard', 'Show sensors', 'Open plants'];
    }
    final names = inverters.split(', ').take(2).toList();
    final suggestions = <String>[];
    for (final name in names) {
      if (name.isNotEmpty && !name.startsWith('(') && name.length < 25) {
        suggestions.add('Open inverter $name');
      }
    }
    suggestions.add('Open dashboard');
    return suggestions.take(4).toList();
  }

  // ════════════════════════════════════
  // Sensor type matching
  // ════════════════════════════════════

  /// Match sensor type keywords from user text
  /// Handles: "temperature sensor", "wms sensors", "mfm sensor", "all sensors"
  String? _matchSensorTypeFromText(String text) {
    if (text.contains('temperature') || text.contains('temp')) return 'Temperature';
    if (text.contains('wms')) return 'WMS';
    if (text.contains('mfm')) return 'MFM';
    // "all sensors" — only if it's clearly about showing all
    if (RegExp(r'\ball\b').hasMatch(text) &&
        _containsAny(text, ['sensor', 'sensors']) &&
        !text.contains('install')) {
      return 'All';
    }
    return null;
  }

  // ════════════════════════════════════
  // Helper methods
  // ════════════════════════════════════

  bool _matches(String text, List<String> keywords) {
    return keywords.any((k) => text.contains(k));
  }

  bool _containsAny(String text, List<String> words) {
    return words.any((w) => text.contains(w));
  }

  /// Check if the text contains a specific item identifier (number or known name fragment)
  bool _hasSpecificItemIdentifier(String text) {
    if (RegExp(r'\d').hasMatch(text)) return true;
    final stripped = text
        .replaceAll(RegExp(r'\b(show|open|filter|sensors?|by|type|the|all|a|an)\b'), '')
        .trim();
    return stripped.length > 3;
  }

  /// Extract an entity name from text by removing filler/command words.
  String? _extractEntityName(String text, List<String> entityKeywords) {
    final fillers = [
      'open', 'show', 'go', 'to', 'navigate', 'the', 'a', 'an',
      'please', 'can', 'you', 'me', 'display',
      'energy', 'revenue', 'income', 'earning', 'earnings',
      'monthly', 'yearly', 'lifetime', 'month', 'year',
      'for', 'of', 'from', 'in', 'on', 'at', 'with',
      'details', 'detail', 'data', 'info', 'information',
      'check', 'get', 'find', 'select', 'switch', 'change',
      ...entityKeywords,
    ];
    final words = text.split(RegExp(r'\s+'));
    final remaining = words
        .where((w) => w.isNotEmpty && !fillers.contains(w))
        .join(' ')
        .trim();
    if (remaining.isNotEmpty) return remaining;
    return null;
  }

  /// Extract month name from text.
  /// Full names are checked BEFORE abbreviations so that e.g. 'december'
  /// matches 'December' and not the shorter 'dec' → 'Dec'.
  String? _extractMonth(String text) {
    // Full names first (longest match wins)
    const fullMonths = [
      ['january', 'January'],
      ['february', 'February'],
      ['march', 'March'],
      ['april', 'April'],
      ['may', 'May'],
      ['june', 'June'],
      ['july', 'July'],
      ['august', 'August'],
      ['september', 'September'],
      ['october', 'October'],
      ['november', 'November'],
      ['december', 'December'],
    ];
    for (final pair in fullMonths) {
      if (text.contains(pair[0])) return pair[1];
    }
    // Then abbreviations
    const shortMonths = [
      ['sept', 'September'],
      ['jan', 'January'],
      ['feb', 'February'],
      ['mar', 'March'],
      ['apr', 'April'],
      ['jun', 'June'],
      ['jul', 'July'],
      ['aug', 'August'],
      ['sep', 'September'],
      ['oct', 'October'],
      ['nov', 'November'],
      ['dec', 'December'],
    ];
    for (final pair in shortMonths) {
      if (text.contains(pair[0])) return pair[1];
    }
    return null;
  }

  /// Extract a 4-digit year from text
  String? _extractYear(String text) {
    final match = RegExp(r'\b(20\d{2})\b').firstMatch(text);
    return match?.group(1);
  }

  /// Extract period (Monthly/Yearly/LifeTime) from text
  String? _extractPeriod(String text) {
    if (text.contains('lifetime') || text.contains('life time') || text.contains('all time') || text.contains('total')) {
      return 'LifeTime';
    }
    if (text.contains('yearly') || text.contains('year') || text.contains('annual')) {
      return 'Yearly';
    }
    if (text.contains('monthly')) {
      return 'Monthly';
    }
    if (text.contains('month') && _extractMonth(text) == null) {
      return 'Monthly';
    }
    return null;
  }

  ToolCallInfo _tool(String name, Map<String, dynamic> args) {
    return ToolCallInfo(name: name, arguments: args, isExecuting: true);
  }

  List<ToolCallInfo> _markDone(List<ToolCallInfo> tools) {
    return tools
        .map((t) => t.copyWith(isExecuting: false, result: 'done'))
        .toList();
  }
}
