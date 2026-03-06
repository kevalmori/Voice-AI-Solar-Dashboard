import '../services/webview_controller_service.dart';

class SensorDetailTools {
  final WebViewControllerService webView;

  SensorDetailTools(this.webView);

  /// Get the sensor name from the detail page
  Future<String> getSensorName() async {
    return await webView.executeJS(
      '(function(){ var el = document.querySelector("h2.MuiTypography-h2"); return el ? el.innerText : "Sensor name not found"; })()',
    );
  }

  /// Get the sensor category
  Future<String> getSensorCategory() async {
    return await webView.executeJS(
      '(function(){ var el = document.querySelector("h6.MuiTypography-h6"); return el ? el.innerText : "Category not found"; })()',
    );
  }

  /// Get the current sensor value
  Future<String> getSensorValue() async {
    return await webView.executeJS(
      '(function(){ var el = document.querySelector("h5.MuiTypography-h5"); return el ? el.innerText : "Value not found"; })()',
    );
  }

  /// Get the last update time
  Future<String> getSensorLastUpdate() async {
    return await webView.executeJS(
      '''(function(){ 
        var els = document.querySelectorAll("p.MuiTypography-root");
        for (var i = 0; i < els.length; i++) {
          if (els[i].innerText.includes(":") && els[i].innerText.includes("/")) {
            return els[i].innerText;
          }
        }
        var el = document.querySelector(".css-1idzl3r");
        return el ? el.innerText : "Last update time not found";
      })()''',
    );
  }

  /// Change the graph date
  Future<String> setGraphDate(String date) async {
    final result = await webView.typeIntoInput('.datepicker-input', date);
    await Future.delayed(const Duration(milliseconds: 1000));
    // Press enter to confirm
    await webView.executeJS('''
      (function() {
        var el = document.querySelector('.datepicker-input');
        if (el) {
          el.dispatchEvent(new KeyboardEvent('keydown', {key: 'Enter', bubbles: true}));
        }
      })()
    ''');
    return 'Graph date set to: $date. $result';
  }

  /// Change graph display mode
  Future<String> changeGraphMode(String mode) async {
    final script = '''
      (function() {
        var buttons = document.querySelectorAll("button");
        for (var i = 0; i < buttons.length; i++) {
          if (buttons[i].innerText.toLowerCase().includes("${mode.toLowerCase()}")) {
            buttons[i].click();
            return "Changed graph mode to: $mode";
          }
        }
        return "Graph mode '$mode' not found";
      })()
    ''';
    return await webView.executeJS(script);
  }
}
