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
}
