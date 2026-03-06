import '../tools/tool_registry.dart';
import '../models/chat_message.dart';
import '../services/web_data_discovery.dart';

/// A command result from the local router
class CommandResult {
  final String response;
  final List<ToolCallInfo> toolCalls;
  final bool matched;

  CommandResult({required this.response, this.toolCalls = const [], this.matched = true});
}

/// Locally matches user input to tool functions using keyword/pattern matching.
/// No API calls — everything runs on-device.
///
/// ALL data (plants, sensors, inverters, types) is discovered dynamically from
/// the website at runtime via [WebDataDiscovery]. Nothing is hardcoded.
class CommandRouter {
  final ToolRegistry _toolRegistry;
  final WebDataDiscovery _discovery;

  CommandRouter(this._toolRegistry, this._discovery);

  /// Try to match user input to a known command.
  Future<CommandResult> processMessage(String input) async {
    // Normalize: strip apostrophes so voice "can't" matches keyword "cant"
    final text = input.toLowerCase().trim().replaceAll("'", '').replaceAll("\u2019", '');
    final tools = <ToolCallInfo>[];

    try {
      // ── Navigation commands (highest priority) ──
      if (_matches(text, ['dashboard', 'home']) && !_containsAny(text, ['energy', 'revenue', 'month', 'year'])) {
        tools.add(_tool('open_dashboard', {}));
        await _toolRegistry.executeTool('open_dashboard', {});
        return CommandResult(
          response: 'Opened the dashboard.\n\nWhat would you like to do next?\n1. Show energy data\n2. Show revenue data\n3. Open plants',
          toolCalls: _markDone(tools),
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
              response: 'Showing ${period ?? "monthly"} energy for $plantName plant.\n\nWhat next?\n1. Show revenue instead\n2. Change period\n3. Go back to plants',
              toolCalls: _markDone(tools),
            );
          }

          // Revenue request for a specific plant
          if (_containsAny(text, ['revenue', 'income', 'earning'])) {
            final period = _extractPeriod(text);
            tools.add(_tool('show_plant_revenue', {'name': plantName, 'period': period}));
            await _toolRegistry.executeTool(
                'show_plant_revenue', {'name': plantName, 'period': period});
            return CommandResult(
              response: 'Showing ${period ?? "monthly"} revenue for $plantName plant.\n\nWhat next?\n1. Show energy instead\n2. Change period\n3. Go back to plants',
              toolCalls: _markDone(tools),
            );
          }

          // Just open the plant
          tools.add(_tool('open_plant_by_name', {'name': plantName}));
          await _toolRegistry.executeTool(
              'open_plant_by_name', {'name': plantName});
          return CommandResult(
            response: 'Opened $plantName plant details.\n\nWhat would you like to see?\n1. Show energy data\n2. Show revenue data\n3. Go back to plants list',
            toolCalls: _markDone(tools),
          );
        }

        // No specific plant → open plants list
        tools.add(_tool('open_plants', {}));
        await _toolRegistry.executeTool('open_plants', {});
        final plantSuggestions = _discovery.getPlantSuggestions();
        return CommandResult(
          response: 'Opened the plants page.\n\nKnown plants: $plantSuggestions\n\nWhat would you like to do?\n1. Open a specific plant by name\n2. Show plant energy\n3. Show plant revenue',
          toolCalls: _markDone(tools),
        );
      }

      // ── Sensor commands ──
      // Dynamically check if any sensor keyword appears in the text
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
            response: 'Showing $filterType sensors.\n\nWhat next?\n1. Open a specific sensor\n2. Show all sensors\n3. Go back to dashboard',
            toolCalls: _markDone(tools),
          );
        }

        final sensorName = _extractEntityName(text, ['sensor', 'sensors']);
        if (sensorName != null) {
          tools.add(_tool('open_sensor_by_name', {'name': sensorName}));
          await _toolRegistry.executeTool(
              'open_sensor_by_name', {'name': sensorName});
          return CommandResult(
            response: 'Opened sensor $sensorName.\n\nWhat would you like to do?\n1. Get sensor value\n2. Get sensor category\n3. Go back to sensors',
            toolCalls: _markDone(tools),
          );
        }

        tools.add(_tool('open_sensors', {}));
        await _toolRegistry.executeTool('open_sensors', {});
        final sensorSuggestions = _discovery.getSensorSuggestions();
        final typeSuggestions = _discovery.getSensorTypeSuggestions();
        return CommandResult(
          response: 'Opened the sensors page.\n\nAvailable sensors: $sensorSuggestions\n\nWhat would you like to do?\n1. Open a specific sensor\n2. Filter by type ($typeSuggestions)\n3. Go back to dashboard',
          toolCalls: _markDone(tools),
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
            response: 'Opened inverter $inverterName.\n\nWhat next?\n1. Go back to inverters\n2. Open dashboard',
            toolCalls: _markDone(tools),
          );
        }

        tools.add(_tool('open_inverters', {}));
        await _toolRegistry.executeTool('open_inverters', {});
        final inverterSuggestions = _discovery.getInverterSuggestions();
        return CommandResult(
          response: 'Opened the inverters page.\n\nKnown inverters: $inverterSuggestions\n\nWhat would you like to do?\n1. Search for a specific inverter\n2. Go back to dashboard',
          toolCalls: _markDone(tools),
        );
      }

      // ── SLM commands ──
      if (_containsAny(text, ['slm'])) {
        tools.add(_tool('open_slms', {}));
        await _toolRegistry.executeTool('open_slms', {});
        return CommandResult(
          response: 'Opened the SLMs page.\n\nWhat next?\n1. Open dashboard\n2. Open sensors',
          toolCalls: _markDone(tools),
        );
      }

      // ── Dashboard tab/period commands (energy/revenue) ──
      if (_containsAny(text, ['energy', 'revenue'])) {
        final tab = _containsAny(text, ['revenue']) ? 'Revenue' : 'Energy';
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
          yearResponse = '\n$yearResult';
        }

        return CommandResult(
          response: 'Switched to $tab${period != null ? " ($period)" : ""} view.$yearResponse\n\nWhat next?\n1. Switch to ${tab == "Energy" ? "Revenue" : "Energy"}\n2. Change period\n3. Open plants',
          toolCalls: _markDone(tools),
        );
      }

      // ── Month navigation commands ──
      if (_containsAny(text, ['month'])) {
        if (_containsAny(text, ['next', 'forward', 'ahead'])) {
          tools.add(_tool('click_navigation_arrow', {'direction': 'next'}));
          await _toolRegistry.executeTool('click_navigation_arrow', {'direction': 'next'});
          return CommandResult(
            response: 'Moved to the next month.\n\nWhat next?\n1. Next month\n2. Previous month\n3. Show energy',
            toolCalls: _markDone(tools),
          );
        }

        if (_containsAny(text, ['previous', 'prev', 'last', 'back', 'before'])) {
          tools.add(_tool('click_navigation_arrow', {'direction': 'prev'}));
          await _toolRegistry.executeTool('click_navigation_arrow', {'direction': 'prev'});
          return CommandResult(
            response: 'Moved to the previous month.\n\nWhat next?\n1. Previous month\n2. Next month\n3. Show energy',
            toolCalls: _markDone(tools),
          );
        }

        final month = _extractMonth(text);
        if (month != null) {
          tools.add(_tool('change_month', {'month': month}));
          await _toolRegistry.executeTool('change_month', {'month': month});
          return CommandResult(
            response: 'Changed to $month.\n\nWhat next?\n1. Next month\n2. Previous month\n3. Show energy',
            toolCalls: _markDone(tools),
          );
        }
      }

      // ── Specific month without "month" keyword (e.g. "change to april", "for january") ──
      final monthDirect = _extractMonth(text);
      if (monthDirect != null && _containsAny(text, ['change', 'go to', 'select', 'switch', 'set', 'for'])) {
        tools.add(_tool('change_month', {'month': monthDirect}));
        await _toolRegistry.executeTool('change_month', {'month': monthDirect});
        return CommandResult(
          response: 'Changed to $monthDirect.\n\nWhat next?\n1. Next month\n2. Previous month\n3. Show energy',
          toolCalls: _markDone(tools),
        );
      }

      // ── Year navigation (e.g. "year 2022", "change year to 2023") ──
      final year = _extractYear(text);
      if (year != null && _containsAny(text, ['year', 'change', 'go to', 'select', 'switch', 'set', 'for'])) {
        tools.add(_tool('change_year', {'year': year}));
        await _toolRegistry.executeTool('change_year', {'year': year});
        return CommandResult(
          response: 'Changed to year $year.\n\nWhat next?\n1. Show energy\n2. Show revenue\n3. Open plants',
          toolCalls: _markDone(tools),
        );
      }

      // ── Sensor detail commands (only when on sensor page, more specific matching) ──
      if (_containsAny(text, ['value', 'reading']) &&
          !_containsAny(text, ['energy', 'revenue', 'month', 'year', 'plant', 'sensor list'])) {
        tools.add(_tool('get_sensor_value', {}));
        final value = await _toolRegistry.executeTool('get_sensor_value', {});
        return CommandResult(
          response: 'Current sensor value: $value\n\nWhat next?\n1. Get sensor name\n2. Change date\n3. Go back',
          toolCalls: _markDone(tools),
        );
      }

      // ── Go back ──
      if (_containsAny(text, ['back', 'previous', 'return'])) {
        tools.add(_tool('go_back', {}));
        await _toolRegistry.executeTool('go_back', {});
        return CommandResult(
          response: 'Went back to the previous page.',
          toolCalls: _markDone(tools),
        );
      }

      // ── Scroll ──
      if (_containsAny(text, ['scroll'])) {
        final direction = _containsAny(text, ['up']) ? 'up' : 'down';
        tools.add(_tool('scroll_page', {'direction': direction}));
        await _toolRegistry.executeTool('scroll_page', {'direction': direction});
        return CommandResult(
          response: 'Scrolled $direction.',
          toolCalls: _markDone(tools),
        );
      }

      // ── Alert commands ──
      if (_containsAny(text, ['alert', 'notification'])) {
        tools.add(_tool('click_by_text', {'text': 'Alerts'}));
        await _toolRegistry.executeTool('click_by_text', {'text': 'Alerts'});
        return CommandResult(
          response: 'Opened alerts.',
          toolCalls: _markDone(tools),
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
        );
      }

      // ── Read page (only if clearly asking to read, not combined with action keywords) ──
      if (_containsAny(text, ['read page', 'whats on the page', 'page content', 'read content']) &&
          !_containsAny(text, ['energy', 'revenue', 'plant', 'sensor', 'inverter', 'month', 'year'])) {
        tools.add(_tool('read_page_content', {}));
        await _toolRegistry.executeTool('read_page_content', {});
        return CommandResult(
          response: 'I\'ve read the current page for you.',
          toolCalls: _markDone(tools),
        );
      }

      // ── No match — provide helpful fallback with dynamic suggestions ──
      final plantHint = _discovery.getPlantSuggestions(max: 2);
      return CommandResult(
        matched: true,
        response: 'Sorry, I didn\'t understand that command.\n\n'
            'Here are some things you can try:\n'
            '1. Open a plant (e.g. $plantHint)\n'
            '2. Show sensors\n'
            '3. Show energy / revenue\n'
            '4. Change month to April\n'
            '5. Yearly revenue for 2022',
      );

    } catch (e) {
      // ── Global error handler — never show raw errors ──
      return CommandResult(
        matched: true,
        response: 'Sorry, something went wrong while processing your command. Please try again.\n\n'
            'You can try:\n'
            '1. Open dashboard\n'
            '2. Show sensors\n'
            '3. Open plants',
      );
    }
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
    // If there's a number, it's likely a specific item (e.g. "sensor 1")
    if (RegExp(r'\d').hasMatch(text)) return true;
    // If the text is long enough beyond the command words, it likely has a name
    final stripped = text
        .replaceAll(RegExp(r'\b(show|open|filter|sensors?|by|type|the|all|a|an)\b'), '')
        .trim();
    return stripped.length > 3;
  }

  /// Extract an entity name from text by removing filler/command words.
  /// [entityKeywords] are additional domain words to strip (e.g. ['plant', 'plants']).
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

  /// Extract month name from text
  String? _extractMonth(String text) {
    final months = {
      'january': 'January', 'jan': 'Jan',
      'february': 'February', 'feb': 'Feb',
      'march': 'March', 'mar': 'Mar',
      'april': 'April', 'apr': 'Apr',
      'may': 'May',
      'june': 'June', 'jun': 'Jun',
      'july': 'July', 'jul': 'Jul',
      'august': 'August', 'aug': 'Aug',
      'september': 'September', 'sep': 'Sep', 'sept': 'Sep',
      'october': 'October', 'oct': 'Oct',
      'november': 'November', 'nov': 'Nov',
      'december': 'December', 'dec': 'Dec',
    };
    // Check full names first (longer match takes priority)
    for (final entry in months.entries) {
      if (text.contains(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  /// Extract a 4-digit year from text (e.g. "2022", "2023")
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
