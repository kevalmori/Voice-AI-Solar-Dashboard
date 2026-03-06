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

        // ── Normalize: strip apostrophes, underscores/hyphens → spaces, lowercase ──
        function normalize(str) {
          return str.toLowerCase().replace(/[''\u2019]/g, '').replace(/[_\\-]+/g, ' ').replace(/\\s+/g, ' ').trim();
        }

        // ── Tokenize: split into individual word tokens ──
        function tokenize(str) {
          return normalize(str).split(' ').filter(function(w) { return w.length > 0; });
        }

        // ── Simple edit distance for character-level similarity ──
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

        // ── Character-level longest common substring ──
        function longestCommonSubstring(a, b) {
          var maxLen = 0;
          for (var i = 0; i < a.length; i++) {
            for (var j = 0; j < b.length; j++) {
              var len = 0;
              while (i + len < a.length && j + len < b.length && a[i+len] === b[j+len]) len++;
              if (len > maxLen) maxLen = len;
            }
          }
          return maxLen;
        }

        for (var i = 0; i < candidates.length; i++) {
          var deviceRaw = candidates[i].name;
          var deviceNorm = normalize(deviceRaw);
          var deviceTokens = tokenize(deviceRaw);
          var score = 0;

          // ── 1. Exact normalized string match ──
          if (deviceNorm === userNorm) {
            score += 2000;
          }
          // ── 2. One contains the other fully ──
          else if (deviceNorm.includes(userNorm)) {
            score += 800;
            // Bonus for tighter match (penalize extra chars in device name)
            var tightness = userNorm.length / deviceNorm.length;
            score += Math.round(200 * tightness);
          }
          else if (userNorm.includes(deviceNorm)) {
            score += 600;
          }

          // ── 3. Character-level overlap (STRICT — dominates scoring) ──
          var lcs = longestCommonSubstring(userNorm, deviceNorm);
          // Quadratic bonus: more matching chars → disproportionately higher
          score += lcs * lcs * 2;

          // ── 4. Token-by-token matching ──
          var matchedTokens = 0;
          var matchedDeviceTokens = 0;
          for (var j = 0; j < userTokens.length; j++) {
            var ut = userTokens[j];
            var tokenMatched = false;

            for (var k = 0; k < deviceTokens.length; k++) {
              var dt = deviceTokens[k];

              if (ut === dt) {
                // Exact token match — high weight
                score += 50;
                tokenMatched = true;
                matchedDeviceTokens++;
                break;
              } else if (dt.indexOf(ut) === 0 || ut.indexOf(dt) === 0) {
                // Prefix match
                var overlap = Math.min(ut.length, dt.length);
                score += 15 + overlap * 3;
                tokenMatched = true;
                matchedDeviceTokens++;
                break;
              } else if (dt.includes(ut) || ut.includes(dt)) {
                // Substring match
                score += 10;
                tokenMatched = true;
                matchedDeviceTokens++;
                break;
              } else if (ut.length >= 3 && dt.length >= 3) {
                if (dt.substring(0, 3) === ut.substring(0, 3)) {
                  score += 8;
                  tokenMatched = true;
                  matchedDeviceTokens++;
                  break;
                }
                var maxLen = Math.max(ut.length, dt.length);
                var dist = editDistance(ut, dt);
                if (dist <= Math.ceil(maxLen * 0.3)) {
                  score += Math.round(15 * (1 - dist / maxLen));
                  tokenMatched = true;
                  matchedDeviceTokens++;
                  break;
                }
              }
            }

            if (tokenMatched) {
              matchedTokens++;
            }
          }

          // ── 5. Bonus for match completeness ──
          if (userTokens.length > 0) {
            var matchRatio = matchedTokens / userTokens.length;
            if (matchRatio === 1) {
              score += 150;
            } else if (matchRatio >= 0.5) {
              score += Math.round(60 * matchRatio);
            }
          }

          // ── 6. Penalty for unmatched device tokens (prefer tighter fits) ──
          var unmatchedDevice = deviceTokens.length - matchedDeviceTokens;
          score -= unmatchedDevice * 15;

          // ── 7. Length similarity bonus (prefer names closest in length) ──
          var lenRatio = Math.min(userNorm.length, deviceNorm.length) / Math.max(userNorm.length, deviceNorm.length);
          score += Math.round(50 * lenRatio);

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

  /// Change the displayed month by clicking the specific navigation arrows
  /// next to the month label on the dashboard. The dashboard shows full month
  /// names (e.g. "March") in a <p> tag flanked by two MuiIconButton-root arrows.
  Future<String> changeMonth(String targetMonth) async {
    final safeMonth = _escapeJs(targetMonth);

    // Step 1: Ensure "Monthly" view is selected (month arrows only appear in Monthly view)
    await clickByText('Monthly');
    await Future.delayed(const Duration(milliseconds: 500));

    // Step 2: Read the current month from the page and calculate direction
    final planScript = '''
      (function() {
        var fullMonths = ['January','February','March','April','May','June',
                          'July','August','September','October','November','December'];
        var shortMonths = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

        // Find target index (match both short and full names)
        var targetIdx = -1;
        var targetLower = '$safeMonth'.toLowerCase();
        for (var i = 0; i < fullMonths.length; i++) {
          if (fullMonths[i].toLowerCase() === targetLower ||
              shortMonths[i].toLowerCase() === targetLower) {
            targetIdx = i;
            break;
          }
        }
        if (targetIdx === -1) return JSON.stringify({error: 'Unknown month: $safeMonth'});

        // Find the month label: look for a <p> or <span> that contains exactly a month name
        var currentIdx = -1;
        var labels = document.querySelectorAll('p, span, h6');
        for (var i = 0; i < labels.length; i++) {
          var txt = labels[i].innerText.trim();
          for (var m = 0; m < fullMonths.length; m++) {
            if (txt === fullMonths[m] || txt === shortMonths[m]) {
              currentIdx = m;
              break;
            }
          }
          if (currentIdx >= 0) break;
        }
        if (currentIdx === -1) return JSON.stringify({error: 'Could not detect current month on page'});
        if (currentIdx === targetIdx) return JSON.stringify({error: 'Already on ' + fullMonths[targetIdx]});

        // Calculate shortest direction
        var forwardSteps = (targetIdx - currentIdx + 12) % 12;
        var backwardSteps = (currentIdx - targetIdx + 12) % 12;
        var direction = forwardSteps <= backwardSteps ? 'next' : 'prev';
        var steps = Math.min(forwardSteps, backwardSteps);

        return JSON.stringify({
          current: fullMonths[currentIdx],
          target: fullMonths[targetIdx],
          direction: direction,
          steps: steps
        });
      })()
    ''';
    final planResult = await webView.executeJS(planScript);

    // Parse result
    final cleaned = planResult.replaceAll(RegExp(r'^"|"$'), '').replaceAll(r'\"', '"');

    if (cleaned.contains('"error"')) {
      final errorMatch = RegExp(r'"error"\s*:\s*"([^"]+)"').firstMatch(cleaned);
      return errorMatch?.group(1) ?? 'Error detecting month';
    }

    final dirMatch = RegExp(r'"direction"\s*:\s*"(\w+)"').firstMatch(cleaned);
    final stepsMatch = RegExp(r'"steps"\s*:\s*(\d+)').firstMatch(cleaned);
    final targetMatch = RegExp(r'"target"\s*:\s*"(\w+)"').firstMatch(cleaned);

    if (dirMatch == null || stepsMatch == null) {
      return 'Could not determine navigation direction';
    }

    final direction = dirMatch.group(1)!;
    final steps = int.parse(stepsMatch.group(1)!);
    final target = targetMatch?.group(1) ?? targetMonth;

    // Step 3: Click the specific month arrow buttons N times
    // The arrows are MuiIconButton-root siblings of the month <p> label
    for (int i = 0; i < steps; i++) {
      final clickScript = '''
        (function() {
          var fullMonths = ['January','February','March','April','May','June',
                            'July','August','September','October','November','December'];
          var shortMonths = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

          // Find the month label element
          var monthLabel = null;
          var labels = document.querySelectorAll('p, span, h6');
          for (var i = 0; i < labels.length; i++) {
            var txt = labels[i].innerText.trim();
            for (var m = 0; m < fullMonths.length; m++) {
              if (txt === fullMonths[m] || txt === shortMonths[m]) {
                monthLabel = labels[i];
                break;
              }
            }
            if (monthLabel) break;
          }
          if (!monthLabel) return 'Month label not found';

          // Find arrow buttons near the month label (siblings in the parent container)
          var parent = monthLabel.parentElement;
          if (!parent) return 'Parent container not found';

          var buttons = parent.querySelectorAll('button, .MuiIconButton-root');
          if (buttons.length < 2) {
            // Try grandparent
            parent = parent.parentElement;
            if (parent) buttons = parent.querySelectorAll('button, .MuiIconButton-root');
          }

          if (buttons.length >= 2) {
            // First button = prev (left arrow), last button = next (right arrow)
            var btn = '${direction == 'next' ? 'true' : 'false'}' === 'true'
                      ? buttons[buttons.length - 1]
                      : buttons[0];
            btn.click();
            return 'Clicked $direction arrow';
          }

          return 'Navigation arrows not found near month label';
        })()
      ''';
      await webView.executeJS(clickScript);
      await Future.delayed(const Duration(milliseconds: 800));
    }

    return 'Changed to $target';
  }

  /// Change the displayed year by clicking the specific navigation arrows
  /// next to the year label on the dashboard. The dashboard shows the year (e.g. "2026")
  /// in a <p> tag flanked by two MuiIconButton-root arrows (only in Yearly view).
  Future<String> changeYear(String targetYear) async {
    final safeYear = _escapeJs(targetYear);
    final targetYearInt = int.tryParse(targetYear);
    if (targetYearInt == null) return 'Invalid year: $targetYear';

    // Step 1: Wait a moment for any previous UI actions to settle
    await Future.delayed(const Duration(milliseconds: 500));

    // Step 2: Read the current year from the page and calculate steps
    final planScript = '''
      (function() {
        var target = parseInt('$safeYear');
        if (isNaN(target)) return JSON.stringify({error: 'Invalid year: $safeYear'});

        // Find the year label: look for a <p> or <span> that contains exactly a 4-digit year
        var currentYear = -1;
        var labels = document.querySelectorAll('p, span, h6');
        for (var i = 0; i < labels.length; i++) {
          var txt = labels[i].innerText.trim();
          var yearMatch = txt.match(/^(20\\d{2})\$/);
          if (yearMatch) {
            currentYear = parseInt(yearMatch[1]);
            break;
          }
        }
        if (currentYear === -1) return JSON.stringify({error: 'Could not detect current year on page'});
        if (currentYear === target) return JSON.stringify({error: 'Already on year ' + target});

        var steps = Math.abs(target - currentYear);
        var direction = target > currentYear ? 'next' : 'prev';

        return JSON.stringify({
          current: currentYear,
          target: target,
          direction: direction,
          steps: steps
        });
      })()
    ''';
    final planResult = await webView.executeJS(planScript);

    final cleaned = planResult.replaceAll(RegExp(r'^"|"$'), '').replaceAll(r'\"', '"');

    if (cleaned.contains('"error"')) {
      final errorMatch = RegExp(r'"error"\s*:\s*"([^"]+)"').firstMatch(cleaned);
      return errorMatch?.group(1) ?? 'Sorry, could not navigate to year.';
    }

    final dirMatch = RegExp(r'"direction"\s*:\s*"(\w+)"').firstMatch(cleaned);
    final stepsMatch = RegExp(r'"steps"\s*:\s*(\d+)').firstMatch(cleaned);

    if (dirMatch == null || stepsMatch == null) {
      return 'Sorry, could not determine which direction to navigate.';
    }

    final direction = dirMatch.group(1)!;
    final steps = int.parse(stepsMatch.group(1)!);

    // Step 3: Click the year arrow buttons N times, verifying each click
    for (int i = 0; i < steps; i++) {
      // Read the year BEFORE clicking so we can verify it changed
      final readYearScript = '''
        (function() {
          var labels = document.querySelectorAll('p, span, h6');
          for (var i = 0; i < labels.length; i++) {
            var txt = labels[i].innerText.trim();
            if (txt.match(/^20\\d{2}\$/)) return txt;
          }
          return '';
        })()
      ''';
      final yearBefore = await webView.executeJS(readYearScript);

      // Click the arrow
      final clickScript = '''
        (function() {
          var yearLabel = null;
          var labels = document.querySelectorAll('p, span, h6');
          for (var i = 0; i < labels.length; i++) {
            var txt = labels[i].innerText.trim();
            if (txt.match(/^20\\d{2}\$/)) {
              yearLabel = labels[i];
              break;
            }
          }
          if (!yearLabel) return 'Year label not found';

          var parent = yearLabel.parentElement;
          if (!parent) return 'Parent container not found';

          var buttons = parent.querySelectorAll('button, .MuiIconButton-root');
          if (buttons.length < 2) {
            parent = parent.parentElement;
            if (parent) buttons = parent.querySelectorAll('button, .MuiIconButton-root');
          }

          if (buttons.length >= 2) {
            var btn = '${direction == 'next' ? 'true' : 'false'}' === 'true'
                      ? buttons[buttons.length - 1]
                      : buttons[0];
            btn.click();
            return 'Clicked $direction arrow';
          }

          return 'Navigation arrows not found near year label';
        })()
      ''';
      await webView.executeJS(clickScript);

      // Verify the year actually changed (poll up to 2 seconds)
      bool changed = false;
      for (int retry = 0; retry < 8; retry++) {
        await Future.delayed(const Duration(milliseconds: 300));
        final yearAfter = await webView.executeJS(readYearScript);
        if (yearAfter != yearBefore && yearAfter.isNotEmpty) {
          changed = true;
          break;
        }
      }

      // If the year didn't change, wait a bit longer and try clicking again
      if (!changed) {
        await Future.delayed(const Duration(milliseconds: 500));
        await webView.executeJS(clickScript);
        await Future.delayed(const Duration(milliseconds: 1000));
      }
    }

    return 'Changed to year $targetYear';
  }
}
