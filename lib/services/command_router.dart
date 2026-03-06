import '../tools/tool_registry.dart';
import '../models/chat_message.dart';

/// A command result from the local router
class CommandResult {
  final String response;
  final List<ToolCallInfo> toolCalls;
  final bool matched;

  CommandResult({required this.response, this.toolCalls = const [], this.matched = true});
}

/// Locally matches user input to tool functions using keyword/pattern matching.
/// No API calls — everything runs on-device.
class CommandRouter {
  final ToolRegistry _toolRegistry;

  CommandRouter(this._toolRegistry);

  /// Try to match user input to a known command. Returns null if no match.
  Future<CommandResult> processMessage(String input) async {
    final text = input.toLowerCase().trim();
    final tools = <ToolCallInfo>[];

    // ── Navigation commands ──
    if (_matches(text, ['dashboard', 'home'])) {
      tools.add(_tool('open_dashboard', {}));
      await _toolRegistry.executeTool('open_dashboard', {});
      return CommandResult(
        response: 'Opened the dashboard.\n\nWhat would you like to do next?\n1. Show energy data\n2. Show revenue data\n3. Open plants',
        toolCalls: _markDone(tools),
      );
    }

    if (_matches(text, ['plant']) && !_containsAny(text, ['sensor', 'inverter', 'dashboard'])) {
      // Check if a specific plant name is mentioned
      final plantName = _extractPlantName(text);
      
      if (plantName != null) {
        // Check for energy/revenue request
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
      return CommandResult(
        response: 'Opened the plants page.\n\nAvailable plants: GOA (M/S. GOA SHIPYARD LIMITED)\n\nWhat would you like to do?\n1. Open GOA plant\n2. Show GOA energy\n3. Show GOA revenue',
        toolCalls: _markDone(tools),
      );
    }

    // ── Sensor commands ──
    if (_containsAny(text, ['sensor'])) {
      // Check for specific sensor name
      final sensorName = _extractSensorName(text);

      if (sensorName != null) {
        tools.add(_tool('open_sensor_by_name', {'name': sensorName}));
        await _toolRegistry.executeTool(
            'open_sensor_by_name', {'name': sensorName});
        return CommandResult(
          response: 'Opened sensor $sensorName.\n\nWhat would you like to do?\n1. Get sensor value\n2. Get sensor category\n3. Go back to sensors',
          toolCalls: _markDone(tools),
        );
      }

      // Filter by type?
      final filterType = _extractSensorType(text);
      if (filterType != null) {
        tools.add(_tool('filter_sensors_by_type', {'type': filterType}));
        await _toolRegistry.executeTool(
            'filter_sensors_by_type', {'type': filterType});
        return CommandResult(
          response: 'Showing $filterType sensors.\n\nWhat next?\n1. Open a specific sensor\n2. Show all sensors\n3. Go back to dashboard',
          toolCalls: _markDone(tools),
        );
      }

      // Just open sensors list
      tools.add(_tool('open_sensors', {}));
      await _toolRegistry.executeTool('open_sensors', {});
      return CommandResult(
        response: 'Opened the sensors page.\n\nAvailable sensors: CANT_RADIATION_1, CANT_TEMP_1, CANT_MFM_1, MOULD_MFM_2, SPS_MFM_3\n\nWhat would you like to do?\n1. Open a specific sensor\n2. Filter by type (WMS, MFM, Temperature)\n3. Go back to dashboard',
        toolCalls: _markDone(tools),
      );
    }

    // ── Inverter commands ──
    if (_containsAny(text, ['inverter'])) {
      final inverterName = _extractInverterName(text);
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
      return CommandResult(
        response: 'Opened the inverters page.\n\nWhat would you like to do?\n1. Search for a specific inverter\n2. Go back to dashboard',
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

    // ── Dashboard tab/period commands ──
    if (_containsAny(text, ['energy', 'revenue']) && !_containsAny(text, ['plant', 'goa'])) {
      final tab = _containsAny(text, ['revenue']) ? 'Revenue' : 'Energy';
      final period = _extractPeriod(text);
      tools.add(_tool('switch_dashboard_tab', {'tab': tab, 'period': period}));
      await _toolRegistry.executeTool(
          'switch_dashboard_tab', {'tab': tab, 'period': period});
      return CommandResult(
        response: 'Switched to $tab${period != null ? " ($period)" : ""} view.\n\nWhat next?\n1. Switch to ${tab == "Energy" ? "Revenue" : "Energy"}\n2. Change period\n3. Open plants',
        toolCalls: _markDone(tools),
      );
    }

    // ── Sensor detail commands (when already on sensor page) ──
    if (_containsAny(text, ['value', 'reading', 'current'])) {
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

    // ── Read page ──
    if (_containsAny(text, ['read', 'what is', 'what\'s on', 'show me', 'content'])) {
      tools.add(_tool('read_page_content', {}));
      final content = await _toolRegistry.executeTool('read_page_content', {});
      return CommandResult(
        response: 'Page content:\n$content',
        toolCalls: _markDone(tools),
      );
    }

    // ── Scroll ──
    if (_containsAny(text, ['scroll'])) {
      final direction = _containsAny(text, ['up']) ? 'up' : 'down';
      tools.add(_tool('scroll_page', {'direction': direction}));
      await _toolRegistry.executeTool(
          'scroll_page', {'direction': direction});
      return CommandResult(
        response: 'Scrolled $direction.',
        toolCalls: _markDone(tools),
      );
    }

    // ── Alert commands ──
    if (_containsAny(text, ['alert', 'notification'])) {
      tools.add(_tool('click_by_text', {'text': 'Alerts'}));
      await _toolRegistry.executeTool(
          'click_by_text', {'text': 'Alerts'});
      return CommandResult(
        response: 'Opened alerts.',
        toolCalls: _markDone(tools),
      );
    }

    // ── Period-only commands (Monthly/Yearly/LifeTime) ──
    final periodOnly = _extractPeriod(text);
    if (periodOnly != null && text.split(' ').length <= 3) {
      tools.add(_tool('click_by_text', {'text': periodOnly}));
      await _toolRegistry.executeTool(
          'click_by_text', {'text': periodOnly});
      return CommandResult(
        response: 'Selected $periodOnly view.',
        toolCalls: _markDone(tools),
      );
    }

    // ── Generic click (last resort for simple commands) ──
    if (_containsAny(text, ['click', 'tap', 'press', 'open', 'show'])) {
      // Try to extract what to click from the text
      final clickTarget = text
          .replaceAll(RegExp(r'\b(click|tap|press|open|show|on|the|please|can you|me)\b'), '')
          .trim();
      if (clickTarget.isNotEmpty) {
        tools.add(_tool('click_by_text', {'text': clickTarget}));
        final result = await _toolRegistry.executeTool(
            'click_by_text', {'text': clickTarget});
        return CommandResult(
          response: result,
          toolCalls: _markDone(tools),
        );
      }
    }

    // ── No match → let home_screen fall back to LLM ──
    return CommandResult(
      matched: false,
      response: '',
    );
  }

  // ════════════════════════════════
  // Helper methods
  // ════════════════════════════════

  /// Check if text matches any of the given keywords
  bool _matches(String text, List<String> keywords) {
    return keywords.any((k) => text.contains(k));
  }

  /// Check if text contains any of the given words
  bool _containsAny(String text, List<String> words) {
    return words.any((w) => text.contains(w));
  }

  /// Extract plant name from text
  String? _extractPlantName(String text) {
    // Known plants
    if (text.contains('goa') || text.contains('shipyard')) return 'GOA';
    // Add more plants here as they become available
    return null;
  }

  /// Extract sensor search query from text.
  /// Returns a search string that will be fuzzy-matched against actual page items.
  String? _extractSensorName(String text) {
    // Remove filler words to get the meaningful search query
    final cleaned = text
        .replaceAll(RegExp(r'\b(open|show|go to|navigate|sensor|sensors|the|a|an|please|can you|me)\b'), '')
        .trim();

    // If there's something left after cleaning, use it as search
    if (cleaned.isNotEmpty && cleaned != text) {
      return cleaned;
    }

    // Check for known keywords that identify a specific sensor
    final keywords = ['radiation', 'temp', 'temperature', 'mfm', 'cant', 'mould', 'sps'];
    for (final k in keywords) {
      if (text.contains(k)) {
        // Build search string from all matching keywords
        final parts = keywords.where((w) => text.contains(w)).toList();
        // Add any number found
        final numMatch = RegExp(r'(\d+)').firstMatch(text);
        if (numMatch != null) parts.add(numMatch.group(1)!);
        return parts.join(' ');
      }
    }

    // If user said a number (e.g. "sensor 3"), pass it
    final numMatch = RegExp(r'(\d+)').firstMatch(text);
    if (numMatch != null) return numMatch.group(1)!;

    return null;
  }

  /// Extract sensor filter type from text
  String? _extractSensorType(String text) {
    if (text.contains('wms')) return 'WMS';
    if (text.contains('mfm')) return 'MFM';
    if (text.contains('temperature') || text.contains('temp')) return 'Temperature';
    if (text.contains('all')) return 'All';
    return null;
  }

  /// Extract inverter search query from text.
  /// Returns a search string that will be fuzzy-matched against actual page items at runtime.
  /// No hardcoded inverter names — the matching happens in the WebView JS.
  String? _extractInverterName(String text) {
    // Build a search string from user keywords + number
    final parts = <String>[];

    // Add prefix hint if user mentioned one
    if (text.contains('grp')) parts.add('grp');
    if (text.contains('mould') || text.contains('moduld') || text.contains('module')) parts.add('mould');
    if (text.contains('cant')) parts.add('cant');
    if (text.contains('sps')) parts.add('sps');

    // Always include "inverter" keyword for matching
    parts.add('inverter');

    // Extract number (e.g. "inverter 4" → "4")
    final numMatch = RegExp(r'(\d+)').firstMatch(text);
    if (numMatch != null) {
      parts.add(numMatch.group(1)!);
    }

    // If we have at least the word "inverter" + something else, return it
    if (parts.length > 1) {
      return parts.join(' ');
    }

    // If user just said "inverter" with nothing else, return null (will open list)
    return null;
  }

  /// Extract period (Monthly/Yearly/LifeTime) from text
  String? _extractPeriod(String text) {
    if (text.contains('lifetime') || text.contains('life time') || text.contains('all time') || text.contains('total')) {
      return 'LifeTime';
    }
    if (text.contains('yearly') || text.contains('year') || text.contains('annual')) {
      return 'Yearly';
    }
    if (text.contains('monthly') || text.contains('month')) {
      return 'Monthly';
    }
    return null;
  }

  /// Create a ToolCallInfo in executing state
  ToolCallInfo _tool(String name, Map<String, dynamic> args) {
    return ToolCallInfo(name: name, arguments: args, isExecuting: true);
  }

  /// Mark all tools as done
  List<ToolCallInfo> _markDone(List<ToolCallInfo> tools) {
    return tools
        .map((t) => t.copyWith(isExecuting: false, result: 'done'))
        .toList();
  }
}
