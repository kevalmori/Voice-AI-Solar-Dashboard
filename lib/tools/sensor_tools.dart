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

  /// Open a sensor by clicking on its row in the table (fuzzy match)
  Future<String> openSensor(String name) async {
    final safeName = name
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n')
        .toLowerCase()
        .trim();
    final script = '''
      (function() {
        var rawInput = '$safeName';

        function normalize(str) {
          return str.toLowerCase().replace(/['\u2019]/g, '').replace(/[_\\\\-]+/g, ' ').replace(/\\\\s+/g, ' ').trim();
        }
        function tokenize(str) {
          return normalize(str).split(' ').filter(function(w) { return w.length > 0; });
        }
        function editDistance(a, b) {
          if (a.length === 0) return b.length;
          if (b.length === 0) return a.length;
          var matrix = [];
          for (var i = 0; i <= b.length; i++) matrix[i] = [i];
          for (var j = 0; j <= a.length; j++) matrix[0][j] = j;
          for (var i = 1; i <= b.length; i++) {
            for (var j = 1; j <= a.length; j++) {
              if (b[i-1] === a[j-1]) matrix[i][j] = matrix[i-1][j-1];
              else matrix[i][j] = Math.min(matrix[i-1][j-1]+1, matrix[i][j-1]+1, matrix[i-1][j]+1);
            }
          }
          return matrix[b.length][a.length];
        }

        var fillers = ['open','show','the','a','an','go','to','me','please','can','you','click','select','find','details','detail','of','for'];
        var userNorm = normalize(rawInput);
        var userTokens = tokenize(rawInput).filter(function(w) { return fillers.indexOf(w) === -1; });
        if (userTokens.length === 0) userTokens = tokenize(rawInput);

        var rows = document.querySelectorAll("tbody tr");
        var bestScore = -1;
        var bestRow = null;
        var bestName = '';

        for (var i = 0; i < rows.length; i++) {
          var cells = rows[i].querySelectorAll("td");
          var cellName = cells.length > 0 ? cells[0].innerText.trim() : rows[i].innerText.trim().split('\\n')[0].trim();
          if (!cellName) continue;

          var deviceNorm = normalize(cellName);
          var deviceTokens = tokenize(cellName);
          var score = 0;

          if (deviceNorm === userNorm) { score += 1000; }
          else if (deviceNorm.includes(userNorm)) { score += 500; }
          else if (userNorm.includes(deviceNorm)) { score += 400; }

          var matched = 0;
          for (var j = 0; j < userTokens.length; j++) {
            var ut = userTokens[j];
            for (var k = 0; k < deviceTokens.length; k++) {
              var dt = deviceTokens[k];
              if (ut === dt) { score += 30; matched++; break; }
              else if (dt.indexOf(ut) === 0 || ut.indexOf(dt) === 0) { score += 20; matched++; break; }
              else if (dt.includes(ut) || ut.includes(dt)) { score += 10; matched++; break; }
              else if (ut.length >= 3 && dt.length >= 3 && dt.substring(0,3) === ut.substring(0,3)) { score += 8; matched++; break; }
              else if (ut.length >= 3 && dt.length >= 3) {
                var maxLen = Math.max(ut.length, dt.length);
                var dist = editDistance(ut, dt);
                if (dist <= Math.ceil(maxLen * 0.3)) { score += Math.round(15 * (1 - dist / maxLen)); matched++; break; }
              }
            }
          }

          if (userTokens.length > 0 && matched === userTokens.length) score += 100;

          if (score > bestScore) {
            bestScore = score;
            bestRow = rows[i];
            bestName = cellName;
          }
        }

        if (bestRow && bestScore > 0) {
          bestRow.click();
          return "Opened sensor: " + bestName;
        }
        return "Sensor not found for: " + rawInput;
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
        var tabs = document.querySelectorAll('[role="tab"], button.MuiTab-root, .MuiTab-root, .MuiToggleButton-root, button');
        var matchedTabs = [];
        for (var i = 0; i < tabs.length; i++) {
          var txt = tabs[i].innerText.trim().toLowerCase();
          if (txt.includes("${type.toLowerCase()}")) {
            matchedTabs.push(tabs[i]);
          }
        }
        if (matchedTabs.length > 0) {
          matchedTabs[0].click();
          return "Filtered sensors by: $type";
        }
        var available = Array.from(tabs).map(function(t) { return t.innerText.trim(); }).filter(function(t) { return t.length > 0 && t.length < 30; });
        var unique = available.filter(function(v, i, a) { return a.indexOf(v) === i; });
        return "Filter tab '$type' not found. Available: " + unique.join(", ");
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
