import '../services/webview_controller_service.dart';

/// Generic tools that work on ANY page of the website.
/// These allow the AI to interact with buttons, tabs, dropdowns,
/// and read content from any page without page-specific code.
class PageInteractionTools {
  final WebViewControllerService webView;

  PageInteractionTools(this.webView);

  /// Helper to safely escape a string for use inside JS
  String _escapeJs(String value) {
    return value
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n');
  }

  /// Click a button, tab, or link by its visible text
  Future<String> clickByText(String text) async {
    final safeText = _escapeJs(text.toLowerCase());
    final script = '''
      (function() {
        var textLower = '$safeText';
        var elements = document.querySelectorAll('button, a, [role="tab"], [role="button"], .MuiTab-root, .MuiButton-root, .MuiListItemButton-root, .MuiToggleButton-root');
        
        // First try exact match
        for (var i = 0; i < elements.length; i++) {
          if (elements[i].innerText.trim().toLowerCase() === textLower) {
            elements[i].click();
            return "Clicked: " + elements[i].innerText.trim();
          }
        }
        
        // Then try partial match
        for (var i = 0; i < elements.length; i++) {
          if (elements[i].innerText.trim().toLowerCase().includes(textLower)) {
            elements[i].click();
            return "Clicked: " + elements[i].innerText.trim();
          }
        }
        
        // Last resort: search ALL leaf elements
        var all = document.querySelectorAll('*');
        for (var i = 0; i < all.length; i++) {
          var el = all[i];
          if (el.children.length === 0 && el.innerText && el.innerText.trim().toLowerCase().includes(textLower)) {
            el.click();
            return "Clicked element containing: " + textLower;
          }
        }
        
        return "No clickable element found with text: " + textLower;
      })()
    ''';
    final result = await webView.executeJS(script);
    // Wait for any UI reaction
    await Future.delayed(const Duration(milliseconds: 1500));
    return result;
  }

  /// Get all clickable elements (buttons, tabs, links) visible on the current page
  Future<String> getPageActions() async {
    final script = '''
      (function() {
        var elements = document.querySelectorAll('button, a, [role="tab"], [role="button"], .MuiTab-root, .MuiButton-root, .MuiToggleButton-root');
        var actions = [];
        var seen = {};
        for (var i = 0; i < elements.length; i++) {
          var txt = elements[i].innerText.trim();
          if (txt.length > 0 && txt.length < 50 && !seen[txt]) {
            seen[txt] = true;
            actions.push(txt);
          }
        }
        return JSON.stringify(actions);
      })()
    ''';
    return await webView.executeJS(script);
  }

  /// Read the main content/text of the current page
  Future<String> readPageContent() async {
    final script = '''
      (function() {
        var main = document.querySelector('main') || document.querySelector('.MuiContainer-root') || document.body;
        var content = main.innerText;
        if (content.length > 2000) {
          content = content.substring(0, 2000) + '... (truncated)';
        }
        return content;
      })()
    ''';
    return await webView.executeJS(script);
  }

  /// Get the current page URL and title
  Future<String> getCurrentPage() async {
    final script = '''
      (function() {
        return JSON.stringify({
          url: window.location.href,
          path: window.location.pathname,
          title: document.title
        });
      })()
    ''';
    return await webView.executeJS(script);
  }

  /// Select a value from a dropdown/select element
  Future<String> selectDropdownValue(String label, String value) async {
    final safeLabel = _escapeJs(label.toLowerCase());
    final safeValue = _escapeJs(value.toLowerCase());
    final script = '''
      (function() {
        var selects = document.querySelectorAll('[role="combobox"], select, .MuiSelect-root');
        for (var i = 0; i < selects.length; i++) {
          var selectEl = selects[i];
          var labelEl = selectEl.closest('.MuiFormControl-root');
          var labelText = labelEl ? labelEl.innerText.toLowerCase() : '';
          var ariaLabel = (selectEl.getAttribute('aria-label') || '').toLowerCase();
          if (labelText.includes('$safeLabel') || ariaLabel.includes('$safeLabel')) {
            selectEl.click();
            setTimeout(function() {
              var options = document.querySelectorAll('[role="option"], .MuiMenuItem-root, li');
              for (var j = 0; j < options.length; j++) {
                if (options[j].innerText.trim().toLowerCase().includes('$safeValue')) {
                  options[j].click();
                  break;
                }
              }
            }, 500);
            return 'Selected $value from $label';
          }
        }
        return 'Dropdown $label not found';
      })()
    ''';
    final result = await webView.executeJS(script);
    await Future.delayed(const Duration(milliseconds: 1500));
    return result;
  }

  /// Scroll the page in a direction
  Future<String> scrollPage(String direction) async {
    final pixels = direction.toLowerCase() == 'up' ? -500 : 500;
    final script = 'window.scrollBy(0, $pixels); "Scrolled $direction"';
    return await webView.executeJS(script);
  }

  /// Click the browser back button
  Future<String> goBack() async {
    await webView.executeJS('window.history.back()');
    await Future.delayed(const Duration(milliseconds: 1500));
    return 'Navigated back';
  }

  /// Click navigation arrows (prev/next) for date/period navigation
  Future<String> clickNavigationArrow(String direction) async {
    final isNext = direction.toLowerCase() == 'next' || direction.toLowerCase() == 'right';
    final script = '''
      (function() {
        var buttons = document.querySelectorAll('button, [role="button"], .MuiIconButton-root');
        for (var i = 0; i < buttons.length; i++) {
          var btn = buttons[i];
          var btnText = btn.innerText.trim();
          var ariaLabel = (btn.getAttribute('aria-label') || '').toLowerCase();
          
          if (${isNext ? 'true' : 'false'}) {
            if (btnText === ">" || btnText === "›" || btnText === "→" || ariaLabel.includes('next') || ariaLabel.includes('forward')) {
              btn.click();
              return "Clicked next arrow";
            }
          } else {
            if (btnText === "<" || btnText === "‹" || btnText === "←" || ariaLabel.includes('prev') || ariaLabel.includes('back')) {
              btn.click();
              return "Clicked previous arrow";
            }
          }
        }
        
        // Fallback: look for SVG chevron/arrow icons in buttons
        var allBtns = document.querySelectorAll('button svg, [role="button"] svg');
        for (var j = 0; j < allBtns.length; j++) {
          var parent = allBtns[j].closest('button') || allBtns[j].closest('[role="button"]');
          if (parent && parent.innerText.trim().length === 0) {
            // Icon-only button — use position heuristic
            parent.click();
            return "Clicked navigation arrow";
          }
        }
        
        return "Navigation arrow not found";
      })()
    ''';
    final result = await webView.executeJS(script);
    await Future.delayed(const Duration(milliseconds: 1000));
    return result;
  }

  /// Search for text in a search input on the current page
  Future<String> searchOnPage(String query) async {
    final safeQuery = _escapeJs(query);
    return await webView.typeIntoInput(
      'input[type="text"], input[type="search"], input[placeholder*="Search"], input[placeholder*="search"]',
      safeQuery,
    );
  }

  /// Click on a table row by matching text content
  Future<String> clickTableRow(String text) async {
    final safeText = _escapeJs(text.toLowerCase());
    final script = '''
      (function() {
        var rows = document.querySelectorAll('tbody tr, .MuiTableRow-root');
        for (var i = 0; i < rows.length; i++) {
          if (rows[i].innerText.toLowerCase().includes('$safeText')) {
            rows[i].click();
            return "Clicked row containing: $text";
          }
        }
        return "No table row found containing: $text";
      })()
    ''';
    final result = await webView.executeJS(script);
    await Future.delayed(const Duration(milliseconds: 1500));
    return result;
  }

  /// Fuzzy-match user input against visible page items and click the best match.
  /// All logic runs in JavaScript in the WebView — no API calls, no hardcoded names.
  ///
  /// Strategy:
  ///  1. Normalize names: underscores → spaces, lowercase, trim
  ///  2. Tokenize both user input and each candidate name
  ///  3. Score by token overlap: exact(30), prefix(10), substring(5)
  ///  4. Bonus for full-match ratio and exact string match
  ///  5. Works with or without numbers in the name
  Future<String> clickBestMatch(String userInput) async {
    final safeInput = _escapeJs(userInput.toLowerCase().trim());
    final script = '''
      (function() {
        var rawInput = '$safeInput';
        var candidates = [];

        // ── Collect table rows: use FIRST CELL text as the match target ──
        var rows = document.querySelectorAll('tbody tr');
        if (rows.length === 0) {
          rows = document.querySelectorAll('.MuiTableRow-root');
        }
        for (var i = 0; i < rows.length; i++) {
          var cells = rows[i].querySelectorAll('td');
          var name = '';
          if (cells.length > 0) {
            name = cells[0].innerText.trim();
          }
          if (!name) {
            name = rows[i].innerText.trim().split('\\n')[0].trim();
          }
          if (name.length > 0) {
            candidates.push({ el: rows[i], name: name, index: i });
          }
        }

        // Also check cards and list items (non-table pages)
        if (candidates.length === 0) {
          var cards = document.querySelectorAll('.MuiCard-root, .MuiListItem-root, .MuiListItemButton-root, [role="listitem"]');
          for (var i = 0; i < cards.length; i++) {
            var txt = cards[i].innerText.trim().split('\\n')[0].trim();
            if (txt.length > 0) {
              candidates.push({ el: cards[i], name: txt, index: i });
            }
          }
        }

        if (candidates.length === 0) {
          return "No items found on the page to match against";
        }

        // ── Normalize: underscores/hyphens → spaces, lowercase, collapse spaces ──
        function normalize(str) {
          return str.toLowerCase().replace(/[_\\-]+/g, ' ').replace(/\\s+/g, ' ').trim();
        }

        // ── Tokenize: split into individual word tokens ──
        function tokenize(str) {
          return normalize(str).split(' ').filter(function(w) { return w.length > 0; });
        }

        // Only strip true command-filler words — keep ALL domain keywords
        var fillers = ['open','show','the','a','an','go','to','me','please','can','you',
                       'click','select','find','details','detail','of','for','check','get','what','is'];
        var userNorm = normalize(rawInput);
        var userTokens = tokenize(rawInput).filter(function(w) {
          return fillers.indexOf(w) === -1;
        });

        // If all tokens got filtered out, fall back to the full normalized input
        if (userTokens.length === 0) {
          userTokens = tokenize(rawInput);
        }

        var bestScore = -1;
        var bestCandidate = null;

        for (var i = 0; i < candidates.length; i++) {
          var deviceRaw = candidates[i].name;
          var deviceNorm = normalize(deviceRaw);
          var deviceTokens = tokenize(deviceRaw);
          var score = 0;

          // ── 1. Exact normalized string match ──
          if (deviceNorm === userNorm) {
            score += 1000;
          }
          // ── 2. One contains the other fully ──
          else if (deviceNorm.includes(userNorm)) {
            score += 500;
          }
          else if (userNorm.includes(deviceNorm)) {
            score += 400;
          }

          // ── 3. Token-by-token matching ──
          var matchedTokens = 0;
          for (var j = 0; j < userTokens.length; j++) {
            var ut = userTokens[j];
            var tokenMatched = false;

            for (var k = 0; k < deviceTokens.length; k++) {
              var dt = deviceTokens[k];

              if (ut === dt) {
                // Exact token match
                score += 30;
                tokenMatched = true;
                break;
              } else if (dt.indexOf(ut) === 0 || ut.indexOf(dt) === 0) {
                // One is a prefix of the other (handles typos like INNVERTER vs INVERTER)
                score += 20;
                tokenMatched = true;
                break;
              } else if (dt.includes(ut) || ut.includes(dt)) {
                // Substring match
                score += 10;
                tokenMatched = true;
                break;
              } else if (ut.length >= 3 && dt.length >= 3) {
                // Check if first 3 chars match (handles misspellings)
                if (dt.substring(0, 3) === ut.substring(0, 3)) {
                  score += 8;
                  tokenMatched = true;
                  break;
                }
              }
            }

            if (tokenMatched) {
              matchedTokens++;
            }
          }

          // ── 4. Bonus for match completeness ──
          if (userTokens.length > 0) {
            var matchRatio = matchedTokens / userTokens.length;
            // All user tokens matched → big bonus
            if (matchRatio === 1) {
              score += 100;
            } else if (matchRatio >= 0.5) {
              score += Math.round(50 * matchRatio);
            }
          }

          // ── 5. Prefer shorter names (more specific match) when scores are close ──
          // Subtract a tiny penalty for longer names so "MOULD_INVERTER_4" beats
          // "MOULD_INVERTER_4_EXTRA" if both score equally
          score -= deviceTokens.length * 0.1;

          if (score > bestScore) {
            bestScore = score;
            bestCandidate = candidates[i];
          }
        }

        // If we found a reasonable match, click it
        if (bestCandidate && bestScore > 0) {
          bestCandidate.el.click();
          return "Clicked: " + bestCandidate.name + " (score: " + bestScore + ")";
        }

        // List available items so user can try again
        var available = candidates.slice(0, 15).map(function(c) { return c.name; }).join(', ');
        return "No match found for: " + rawInput + ". Available: " + available;
      })()
    ''';
    final result = await webView.executeJS(script);
    await Future.delayed(const Duration(milliseconds: 1500));
    return result;
  }
}
