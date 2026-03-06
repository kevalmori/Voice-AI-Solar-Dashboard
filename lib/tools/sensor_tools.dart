import '../services/webview_controller_service.dart';

class SensorTools {
  final WebViewControllerService webView;

  SensorTools(this.webView);

  /// Search for a sensor by name in the search input
  Future<String> searchSensor(String name) async {
    // First clear then type into the search input
    final result = await webView.typeIntoInput(
      'input[placeholder="Search inverters..."]',
      name,
    );
    await Future.delayed(const Duration(milliseconds: 500));
    return 'Searched for sensor: $name. $result';
  }

  /// Open a sensor by clicking on its row in the table
  Future<String> openSensor(String name) async {
    final script = '''
      (function() {
        var rows = document.querySelectorAll("tbody tr");
        for (var i = 0; i < rows.length; i++) {
          if (rows[i].innerText.includes("$name")) {
            rows[i].click();
            return "Opened sensor: $name";
          }
        }
        return "Sensor $name not found in table";
      })()
    ''';
    return await webView.executeJS(script);
  }

  /// Open a sensor by its index in the table
  Future<String> openSensorByIndex(int index) async {
    final script = '''
      (function() {
        var rows = document.querySelectorAll("tbody tr");
        if ($index < rows.length) {
          rows[$index].click();
          return "Opened sensor at index $index";
        }
        return "Index $index out of range. Found " + rows.length + " sensors.";
      })()
    ''';
    return await webView.executeJS(script);
  }

  /// Filter sensors by clicking a tab (All, WMS, Temperature, MFM)
  Future<String> filterSensors(String type) async {
    final script = '''
      (function() {
        var tabs = document.querySelectorAll('[role="tab"]');
        for (var i = 0; i < tabs.length; i++) {
          if (tabs[i].innerText.toLowerCase().includes("${type.toLowerCase()}")) {
            tabs[i].click();
            return "Filtered sensors by: $type";
          }
        }
        return "Filter tab '$type' not found. Available tabs: " + 
          Array.from(tabs).map(t => t.innerText).join(", ");
      })()
    ''';
    return await webView.executeJS(script);
  }

  /// Get all sensors from the table
  Future<String> getAllSensors() async {
    final script = '''
      (function() {
        var rows = document.querySelectorAll("tbody tr");
        var sensors = [];
        for (var i = 0; i < rows.length; i++) {
          var cells = rows[i].querySelectorAll("td");
          if (cells.length >= 2) {
            sensors.push({
              name: cells[0].innerText.trim(),
              category: cells[1].innerText.trim()
            });
          }
        }
        return JSON.stringify(sensors);
      })()
    ''';
    return await webView.executeJS(script);
  }
}
