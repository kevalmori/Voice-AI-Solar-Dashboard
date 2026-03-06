import '../services/webview_controller_service.dart';

class PlantTools {
  final WebViewControllerService webView;

  PlantTools(this.webView);

  /// Helper to safely escape a string for use inside JS
  String _escapeJs(String value) {
    return value
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n');
  }

  /// Get all plants from the plants page
  Future<String> getAllPlants() async {
    final script = '''
      (function() {
        var cards = document.querySelectorAll('.MuiCard-root, .MuiPaper-root');
        var plants = [];
        for (var i = 0; i < cards.length; i++) {
          var cardText = cards[i].innerText.trim();
          if (cardText.length > 5 && (cardText.includes('KWH') || cardText.includes('Active') || cardText.includes('kWh'))) {
            var lines = cardText.split('\\n');
            plants.push({ index: i, name: lines[0].trim() });
          }
        }
        if (plants.length === 0) {
          var allDivs = document.querySelectorAll('div');
          for (var j = 0; j < allDivs.length; j++) {
            var t = allDivs[j].innerText.trim();
            if (t.includes('KWH') && t.length < 500) {
              var firstLine = t.split('\\n')[0].trim();
              if (firstLine.length > 3) {
                plants.push({ index: j, name: firstLine });
              }
            }
          }
        }
        return plants.length > 0 ? JSON.stringify(plants) : 'No plants found on this page';
      })()
    ''';
    return await webView.executeJS(script);
  }

  /// Open (click on) a plant card by searching for name
  Future<String> openPlant(String name) async {
    final safeName = _escapeJs(name.toUpperCase());
    final script = '''
      (function() {
        var searchName = '$safeName';
        
        // The plant cards are MuiCard-root elements with React onClick handlers.
        // We need to simulate a full pointer event sequence for React 18.
        function simulateClick(el) {
          var rect = el.getBoundingClientRect();
          var x = rect.left + rect.width / 2;
          var y = rect.top + rect.height / 2;
          var opts = {bubbles: true, cancelable: true, view: window, clientX: x, clientY: y};
          el.dispatchEvent(new PointerEvent('pointerdown', opts));
          el.dispatchEvent(new MouseEvent('mousedown', opts));
          el.dispatchEvent(new PointerEvent('pointerup', opts));
          el.dispatchEvent(new MouseEvent('mouseup', opts));
          el.dispatchEvent(new MouseEvent('click', opts));
        }
        
        // Strategy 1: Find MuiCard containing the search name
        var cards = document.querySelectorAll('.MuiCard-root');
        for (var i = 0; i < cards.length; i++) {
          if (cards[i].innerText && cards[i].innerText.toUpperCase().includes(searchName)) {
            simulateClick(cards[i]);
            return 'Clicked plant card: ' + searchName;
          }
        }
        
        // Strategy 2: Find any MuiPaper containing the search name
        var papers = document.querySelectorAll('.MuiPaper-root');
        for (var i = 0; i < papers.length; i++) {
          if (papers[i].innerText && papers[i].innerText.toUpperCase().includes(searchName)) {
            simulateClick(papers[i]);
            return 'Clicked paper card: ' + searchName;
          }
        }
        
        // Strategy 3: Find any element with short text containing the name
        var allEls = document.querySelectorAll('h5, h4, h3, h2, h1, div');
        for (var i = 0; i < allEls.length; i++) {
          var el = allEls[i];
          if (el.innerText && el.innerText.toUpperCase().includes(searchName) && el.innerText.length < 100) {
            // Click the closest card-like parent or the element itself
            var target = el.closest('.MuiCard-root') || el.closest('.MuiPaper-root') || el;
            simulateClick(target);
            return 'Clicked element for: ' + searchName;
          }
        }
        
        return 'Plant ' + searchName + ' not found on this page';
      })()
    ''';
    final result = await webView.executeJS(script);
    // Wait for page transition
    await Future.delayed(const Duration(milliseconds: 3000));
    return result;
  }

  /// Read the plant summary info from the plant detail page
  Future<String> getPlantInfo() async {
    final script = '''
      (function() {
        var info = {};
        var h2 = document.querySelector('h2, h1, .MuiTypography-h2, .MuiTypography-h4');
        info.name = h2 ? h2.innerText.trim() : 'Unknown';
        
        var cards = document.querySelectorAll('.MuiCard-root, .MuiPaper-root');
        var stats = [];
        for (var i = 0; i < cards.length; i++) {
          var cardText = cards[i].innerText.trim();
          if (cardText.length > 2 && cardText.length < 200) {
            stats.push(cardText.replace(/\\n/g, ' | '));
          }
        }
        info.stats = stats;
        return JSON.stringify(info);
      })()
    ''';
    return await webView.executeJS(script);
  }
}
