import 'navigation_tools.dart';
import 'sensor_tools.dart';
import 'sensor_detail_tools.dart';
import 'plant_tools.dart';
import 'page_interaction_tools.dart';
import '../services/webview_controller_service.dart';

class ToolRegistry {
  late final NavigationTools _navTools;
  late final SensorTools _sensorTools;
  late final SensorDetailTools _detailTools;
  late final PlantTools _plantTools;
  late final PageInteractionTools _pageTools;

  ToolRegistry(WebViewControllerService webView) {
    _navTools = NavigationTools(webView);
    _sensorTools = SensorTools(webView);
    _detailTools = SensorDetailTools(webView);
    _plantTools = PlantTools(webView);
    _pageTools = PageInteractionTools(webView);
  }

  /// Execute a tool by name with given arguments
  Future<String> executeTool(String name, Map<String, dynamic> args) async {
    switch (name) {
      // ── Navigation ──
      case 'open_dashboard':
        return await _navTools.openDashboard();
      case 'open_plants':
        return await _navTools.openPlants();
      case 'open_inverters':
        return await _navTools.openInverters();
      case 'open_slms':
        return await _navTools.openSlms();
      case 'open_sensors':
        return await _navTools.openSensors();

      // ── Combined Plant tools (single-call, handles chaining) ──
      case 'open_plant_by_name':
        return await _openPlantByName(args['name'] ?? '');
      case 'show_plant_energy':
        return await _showPlantData(
          args['name'] ?? '',
          'Energy',
          args['period'],
        );
      case 'show_plant_revenue':
        return await _showPlantData(
          args['name'] ?? '',
          'Revenue',
          args['period'],
        );

      // ── Combined Sensor tools (single-call, handles chaining) ──
      case 'open_sensor_by_name':
        return await _openSensorByName(args['name'] ?? '');
      case 'filter_sensors_by_type':
        return await _filterSensorsByType(args['type'] ?? '');

      // ── Combined Inverter tools ──
      case 'open_inverter_by_name':
        return await _openInverterByName(args['name'] ?? '');

      // ── Sensor Detail ──
      case 'get_sensor_value':
        return await _detailTools.getSensorValue();
      case 'get_sensor_name':
        return await _detailTools.getSensorName();
      case 'get_sensor_category':
        return await _detailTools.getSensorCategory();
      case 'get_sensor_last_update':
        return await _detailTools.getSensorLastUpdate();
      case 'set_graph_date':
        return await _detailTools.setGraphDate(args['date'] ?? '');
      case 'change_graph_mode':
        return await _detailTools.changeGraphMode(args['mode'] ?? '');

      // ── Dashboard tabs ──
      case 'switch_dashboard_tab':
        return await _switchDashboardTab(
          args['tab'] ?? '',
          args['period'],
        );

      // ── Generic (work on ANY page) ──
      case 'click_by_text':
        return await _pageTools.clickByText(args['text'] ?? '');
      case 'read_page_content':
        return await _pageTools.readPageContent();
      case 'go_back':
        return await _pageTools.goBack();
      case 'scroll_page':
        return await _pageTools.scrollPage(args['direction'] ?? 'down');
      case 'search_on_page':
        return await _pageTools.searchOnPage(args['query'] ?? '');
      case 'get_page_actions':
        return await _pageTools.getPageActions();
      case 'get_current_page':
        return await _pageTools.getCurrentPage();
      case 'select_dropdown':
        return await _pageTools.selectDropdownValue(
            args['label'] ?? '', args['value'] ?? '');
      case 'click_table_row':
        return await _pageTools.clickTableRow(args['text'] ?? '');
      case 'click_navigation_arrow':
        return await _pageTools.clickNavigationArrow(args['direction'] ?? 'next');

      // Legacy tools (kept for backward compat)
      case 'open_plant':
        return await _plantTools.openPlant(args['name'] ?? '');
      case 'get_plant_info':
        return await _plantTools.getPlantInfo();
      case 'open_sensor':
        return await _sensorTools.openSensor(args['name'] ?? '');
      case 'filter_sensors':
        return await _sensorTools.filterSensors(args['type'] ?? '');

      default:
        return 'Unknown tool: $name';
    }
  }

  // ══════════════════════════════════════════
  // Combined / chained tool implementations
  // ══════════════════════════════════════════

  /// Wait for plant cards to appear on the page (up to 8s)
  Future<void> _waitForPlantCards() async {
    for (int i = 0; i < 16; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      final check = await _pageTools.readPageContent();
      if (check.toUpperCase().contains('KWH') ||
          check.toUpperCase().contains('GOA') ||
          check.toUpperCase().contains('SHIPYARD')) {
        return;
      }
    }
  }

  /// Navigate to plants page, then click a plant card by name
  Future<String> _openPlantByName(String name) async {
    final nav = await _navTools.openPlants();
    await _waitForPlantCards();
    final click = await _plantTools.openPlant(name);
    return '$nav → $click';
  }

  /// Navigate to plants → open plant → click tab → select period
  Future<String> _showPlantData(
      String name, String tab, String? period) async {
    final nav = await _navTools.openPlants();
    await _waitForPlantCards();
    final click = await _plantTools.openPlant(name);
    await Future.delayed(const Duration(milliseconds: 3000));
    final tabResult = await _pageTools.clickByText(tab);
    String result = '$nav → $click → $tabResult';
    if (period != null && period.isNotEmpty) {
      await Future.delayed(const Duration(milliseconds: 1000));
      final periodResult = await _pageTools.clickByText(period);
      result += ' → $periodResult';
    }
    return result;
  }

  /// Navigate to sensors page, then click a sensor row by name (fuzzy)
  Future<String> _openSensorByName(String name) async {
    final nav = await _navTools.openSensors();
    await Future.delayed(const Duration(milliseconds: 2000));
    // Use fuzzy matching to find the best sensor match at runtime
    final click = await _pageTools.clickBestMatch(name);
    return '$nav → $click';
  }

  /// Navigate to sensors page, then click a filter tab
  Future<String> _filterSensorsByType(String type) async {
    final nav = await _navTools.openSensors();
    await Future.delayed(const Duration(milliseconds: 2000));
    final filter = await _sensorTools.filterSensors(type);
    return '$nav → $filter';
  }

  /// Navigate to inverters page, then fuzzy-match & click inverter by name
  Future<String> _openInverterByName(String name) async {
    final nav = await _navTools.openInverters();
    // Wait for the inverter table to load
    for (int i = 0; i < 12; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      final check = await _pageTools.readPageContent();
      if (check.toUpperCase().contains('INVERTER') ||
          check.toUpperCase().contains('DEVICE NAME')) {
        break;
      }
    }
    // Use fuzzy matching to find the best inverter match at runtime
    final click = await _pageTools.clickBestMatch(name);
    return '$nav → $click';
  }

  /// Switch dashboard Energy/Revenue tab and optionally select period
  Future<String> _switchDashboardTab(String tab, String? period) async {
    final tabResult = await _pageTools.clickByText(tab);
    String result = tabResult;
    if (period != null && period.isNotEmpty) {
      await Future.delayed(const Duration(milliseconds: 1000));
      final periodResult = await _pageTools.clickByText(period);
      result += ' → $periodResult';
    }
    return result;
  }

  /// Gemini tool declarations — combined high-level tools
  static List<Map<String, dynamic>> get toolDeclarations => [
        // ── Navigation (simple, no params) ──
        _t('open_dashboard', 'Navigate to the main dashboard page', {}),
        _t('open_plants', 'Navigate to the plants list page', {}),
        _t('open_inverters', 'Navigate to the inverters page', {}),
        _t('open_slms', 'Navigate to the SLMs page', {}),
        _t('open_sensors', 'Navigate to the sensors list page', {}),
        _t('go_back', 'Go back to the previous page', {}),

        // ── Combined Plant tools ──
        _t('open_plant_by_name',
            'Open a specific plant by name. Automatically navigates to plants page first, then clicks the plant card. Use this when user asks to see a specific plant.',
            {
              'name': {
                'type': 'STRING',
                'description':
                    'Plant name to open, e.g. GOA, GOA SHIPYARD, etc.'
              },
            }),
        _t('show_plant_energy',
            'Show energy data for a specific plant. Chains: open plants → click plant → click Energy tab → optionally select period. Use for requests like "show goa energy" or "goa monthly energy".',
            {
              'name': {
                'type': 'STRING',
                'description': 'Plant name, e.g. GOA'
              },
              'period': {
                'type': 'STRING',
                'description':
                    'Optional period: Monthly, Yearly, or LifeTime. Leave empty for default.'
              },
            }),
        _t('show_plant_revenue',
            'Show revenue data for a specific plant. Chains: open plants → click plant → click Revenue tab → optionally select period. Use for requests like "goa yearly revenue".',
            {
              'name': {
                'type': 'STRING',
                'description': 'Plant name, e.g. GOA'
              },
              'period': {
                'type': 'STRING',
                'description':
                    'Optional period: Monthly, Yearly, or LifeTime. Leave empty for default.'
              },
            }),
        _t('get_plant_info',
            'Read the current plant detail info (name, stats) from the plant detail page. Use when already on a plant detail page.',
            {}),

        // ── Combined Sensor tools ──
        _t('open_sensor_by_name',
            'Open a specific sensor by name. Automatically navigates to sensors page first, then clicks the sensor row. Sensors include: CANT_RADIATION_1, CANT_TEMP_1, CANT_MFM_1, MOULD_MFM_2, SPS_MFM_3.',
            {
              'name': {
                'type': 'STRING',
                'description':
                    'Sensor name, e.g. CANT_RADIATION_1 or CANT_TEMP_1'
              },
            }),
        _t('filter_sensors_by_type',
            'Navigate to sensors page and filter by type. Available types: All, WMS, MFM, Temperature.',
            {
              'type': {
                'type': 'STRING',
                'description':
                    'Sensor type to filter: All, WMS, MFM, or Temperature'
              },
            }),

        // ── Sensor detail ──
        _t('get_sensor_value',
            'Get the current live value of the sensor (when on sensor detail page)',
            {}),
        _t('get_sensor_name',
            'Get the name of the current sensor (when on sensor detail page)',
            {}),
        _t('get_sensor_category',
            'Get the category of the current sensor (when on sensor detail page)',
            {}),
        _t('get_sensor_last_update',
            'Get the last update time of the current sensor (when on sensor detail page)',
            {}),
        _t('set_graph_date',
            'Set the graph date on the sensor detail page', {
          'date': {
            'type': 'STRING',
            'description': 'Date in DD/MM/YYYY format'
          },
        }),
        _t('change_graph_mode',
            'Change the display mode of the graph on sensor detail page', {
          'mode': {
            'type': 'STRING',
            'description': 'Graph display mode to switch to'
          },
        }),

        // ── Combined Inverter tools ──
        _t('open_inverter_by_name',
            'Open a specific inverter by name. Automatically navigates to inverters page first, then clicks the inverter.',
            {
              'name': {
                'type': 'STRING',
                'description':
                    'Inverter name, e.g. GRP_INNVERTER_8 or MOULD_INVERTER_10'
              },
            }),

        // ── Dashboard controls ──
        _t('switch_dashboard_tab',
            'Switch between Energy/Revenue tabs on dashboard and optionally select a period (Monthly/Yearly/LifeTime).',
            {
              'tab': {
                'type': 'STRING',
                'description': 'Tab to switch to: Energy or Revenue'
              },
              'period': {
                'type': 'STRING',
                'description':
                    'Optional period: Monthly, Yearly, or LifeTime'
              },
            }),

        // ── Generic page interaction ──
        _t('click_by_text',
            'Click any visible button, tab, or link by its text. Use as a fallback when no specific tool matches.',
            {
              'text': {
                'type': 'STRING',
                'description': 'The visible text of the element to click'
              },
            }),
        _t('read_page_content',
            'Read the visible text content of the current page', {}),
        _t('scroll_page', 'Scroll the current page up or down', {
          'direction': {
            'type': 'STRING',
            'description': 'Scroll direction: up or down'
          },
        }),
        _t('search_on_page',
            'Type into a search input on the current page', {
          'query': {
            'type': 'STRING',
            'description': 'Search text to type'
          },
        }),
        _t('get_page_actions',
            'Get all clickable elements (buttons, tabs, links) visible on the current page. Useful to discover what actions are available.',
            {}),
        _t('get_current_page',
            'Get the current page URL, path, and title',
            {}),
        _t('select_dropdown',
            'Select a value from a dropdown/select element on the page', {
          'label': {
            'type': 'STRING',
            'description': 'Label or name of the dropdown'
          },
          'value': {
            'type': 'STRING',
            'description': 'Value to select from the dropdown'
          },
        }),
        _t('click_table_row',
            'Click on a table row by matching its text content', {
          'text': {
            'type': 'STRING',
            'description': 'Text to find in the table row'
          },
        }),
        _t('click_navigation_arrow',
            'Click a navigation arrow (prev/next) for date/period navigation', {
          'direction': {
            'type': 'STRING',
            'description': 'Direction: next or prev'
          },
        }),
      ];

  static Map<String, dynamic> _t(
      String name, String desc, Map<String, dynamic> props) {
    final params = <String, dynamic>{
      'type': 'OBJECT',
      'properties': props,
    };
    if (props.isNotEmpty) {
      // Only mark truly required params (not optional ones like 'period')
      final required = props.keys
          .where((k) => k != 'period')
          .toList();
      if (required.isNotEmpty) {
        params['required'] = required;
      }
    }
    return {
      'name': name,
      'description': desc,
      'parameters': params,
    };
  }
}
