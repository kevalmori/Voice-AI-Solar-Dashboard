import 'package:webview_flutter/webview_flutter.dart';
import 'dart:async';

class WebViewControllerService {
  WebViewController? _controller;
  final Completer<void> _readyCompleter = Completer<void>();
  bool _isReady = false;
  String _currentUrl = '';
  void Function(String url)? onUrlChanged;

  WebViewController? get controller => _controller;
  Future<void> get ready => _readyCompleter.future;
  bool get isReady => _isReady;
  String get currentUrl => _currentUrl;

  void setController(WebViewController controller) {
    _controller = controller;
    if (!_readyCompleter.isCompleted) {
      _isReady = true;
      _readyCompleter.complete();
    }
  }

  void updateCurrentUrl(String url) {
    _currentUrl = url;
    onUrlChanged?.call(url);
  }

  /// Navigate to a route on the website
  Future<String> navigateTo(String path) async {
    if (_controller == null) return 'WebView not ready';
    final url = 'https://aalok.dyulabs.co.in$path';
    await _controller!.loadRequest(Uri.parse(url));
    // Wait for page to settle
    await Future.delayed(const Duration(milliseconds: 2000));
    _currentUrl = url;
    return 'Navigated to $path';
  }

  /// Execute JavaScript in the WebView and return the result
  Future<String> executeJS(String script) async {
    if (_controller == null) return 'WebView not ready';
    try {
      final result = await _controller!.runJavaScriptReturningResult(script);
      return result.toString();
    } catch (e) {
      return 'Error: $e';
    }
  }

  /// Wait for an element to appear, then execute a script
  Future<String> waitAndExecute(String selector, String script,
      {int maxWaitMs = 5000}) async {
    if (_controller == null) return 'WebView not ready';

    final startTime = DateTime.now();
    while (DateTime.now().difference(startTime).inMilliseconds < maxWaitMs) {
      try {
        final exists = await _controller!.runJavaScriptReturningResult(
          'document.querySelector("$selector") !== null',
        );
        if (exists.toString() == 'true') {
          return await executeJS(script);
        }
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 300));
    }
    return 'Element "$selector" not found after ${maxWaitMs}ms';
  }

  /// Simulate typing into an input field (triggers React's onChange).
  /// Uses multiple event-dispatching strategies for cross-device compatibility.
  Future<String> typeIntoInput(String selector, String value) async {
    final script = '''
      (function() {
        var el = document.querySelector('$selector');
        if (!el) return 'Element not found';

        // Focus the element first
        el.focus();
        el.dispatchEvent(new FocusEvent('focus', { bubbles: true }));

        // Try the React-specific native setter (works on most setups)
        try {
          var nativeInputValueSetter = Object.getOwnPropertyDescriptor(
            window.HTMLInputElement.prototype, 'value');
          if (nativeInputValueSetter && nativeInputValueSetter.set) {
            nativeInputValueSetter.set.call(el, '$value');
          } else {
            el.value = '$value';
          }
        } catch(e) {
          // Fallback: direct assignment
          el.value = '$value';
        }

        // Dispatch comprehensive set of events for maximum compatibility
        el.dispatchEvent(new Event('input', { bubbles: true }));
        el.dispatchEvent(new Event('change', { bubbles: true }));

        // Also dispatch InputEvent (React 17+ synthetic events)
        try {
          el.dispatchEvent(new InputEvent('input', {
            bubbles: true,
            data: '$value',
            inputType: 'insertText'
          }));
        } catch(e) {}

        // Simulate keydown/keyup for frameworks that listen to keyboard events
        try {
          el.dispatchEvent(new KeyboardEvent('keydown', { bubbles: true, key: '$value' }));
          el.dispatchEvent(new KeyboardEvent('keyup', { bubbles: true, key: '$value' }));
        } catch(e) {}

        // React 16+ internal instance hack — trigger onChange via fiber
        try {
          var tracker = el._valueTracker;
          if (tracker) {
            tracker.setValue('');
          }
          el.dispatchEvent(new Event('input', { bubbles: true }));
        } catch(e) {}

        return 'Typed: $value';
      })()
    ''';
    return await executeJS(script);
  }
}
