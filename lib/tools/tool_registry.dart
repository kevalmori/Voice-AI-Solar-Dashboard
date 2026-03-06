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
      case 'change_month':
        return await _pageTools.changeMonth(args['month'] ?? '');
      case 'change_year':
        return await _pageTools.changeYear(args['year'] ?? '');

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
      final upper = check.toUpperCase();
      if (upper.contains('KWH') ||
          upper.contains('KWP') ||
          upper.contains('ACTIVE') ||
          upper.contains('PLANT')) {
        return;
      }
    }
  }

  /// Navigate to plants page, then fuzzy-match & click plant by name
  Future<String> _openPlantByName(String name) async {
    final nav = await _navTools.openPlants();
    await _waitForPlantCards();
    final click = await _pageTools.clickBestMatch(name);
    return '$nav → $click';
  }

  /// Navigate to plants → open plant → click tab → select period
  Future<String> _showPlantData(
      String name, String tab, String? period) async {
    final nav = await _navTools.openPlants();
    await _waitForPlantCards();
    final click = await _pageTools.clickBestMatch(name);
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
    // Wait for the sensor table to load (same approach as inverter)
    for (int i = 0; i < 12; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      final check = await _pageTools.readPageContent();
      if (check.toUpperCase().contains('DEVICE NAME') ||
          check.toUpperCase().contains('CANT') ||
          check.toUpperCase().contains('RADIATION') ||
          check.toUpperCase().contains('MFM')) {
        break;
      }
    }
    // Use fuzzy matching to find the best sensor match at runtime
    final click = await _pageTools.clickBestMatch(name);
    return '$nav → $click';
  }

  /// Navigate to sensors page, then click a filter tab
  Future<String> _filterSensorsByType(String type) async {
    final nav = await _navTools.openSensors();
    // Wait for the sensor page to load
    for (int i = 0; i < 12; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      final check = await _pageTools.readPageContent();
      if (check.toUpperCase().contains('DEVICE NAME') ||
          check.toUpperCase().contains('CANT') ||
          check.toUpperCase().contains('MFM')) {
        break;
      }
    }
    // Use clickByText which has broader selectors than role="tab"
    final filter = await _pageTools.clickByText(type);
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

}

