import 'package:webview_flutter/webview_flutter.dart';
import 'dart:async';

class WebViewControllerService {
  WebViewController? _controller;
  final Completer<void> _readyCompleter = Completer<void>();
  bool _isReady = false;
  String _currentUrl = '';

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

  /// Simulate typing into an input field (triggers React's onChange)
  Future<String> typeIntoInput(String selector, String value) async {
    final script = '''
      (function() {
        var el = document.querySelector('$selector');
        if (!el) return 'Element not found';
        var nativeInputValueSetter = Object.getOwnPropertyDescriptor(
          window.HTMLInputElement.prototype, 'value').set;
        nativeInputValueSetter.call(el, '$value');
        el.dispatchEvent(new Event('input', { bubbles: true }));
        el.dispatchEvent(new Event('change', { bubbles: true }));
        return 'Typed: $value';
      })()
    ''';
    return await executeJS(script);
  }
}
