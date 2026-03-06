import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../services/command_router.dart';
import '../services/webview_controller_service.dart';
import '../services/web_data_discovery.dart';
import '../tools/tool_registry.dart';
import '../widgets/chat_panel.dart';
import '../widgets/webview_container.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final WebViewControllerService _webViewService = WebViewControllerService();
  late final ToolRegistry _toolRegistry;
  late final WebDataDiscovery _discovery;
  late final CommandRouter _commandRouter;

  final List<ChatMessage> _messages = [];
  List<String> _suggestions = [];
  bool _isProcessing = false;
  bool _isChatExpanded = false;
  String _currentPageTitle = 'Dashboard';
  double _panelHeight = 0; // Tracks the current panel height in pixels

  @override
  void initState() {
    super.initState();
    _toolRegistry = ToolRegistry(_webViewService);
    _discovery = WebDataDiscovery(_webViewService);
    _commandRouter = CommandRouter(_toolRegistry, _discovery);

    // Listen for URL changes to update the header title and discover data
    _webViewService.onUrlChanged = (url) {
      setState(() {
        _currentPageTitle = _getPageTitle(url);
      });
      // Run lightweight init (nav links only) on first load
      if (!_discovery.isReady && url.contains('aalok.dyulabs.co.in')) {
        _discovery.runInitialDiscovery();
      }
      // Opportunistically scrape data from the page the user navigated to
      // (wait for page to load first)
      _discoverFromPageAfterDelay();
    };

    // Add welcome message
    _messages.add(ChatMessage(
      role: MessageRole.assistant,
      content:
          'Hello! I\'m your AI assistant for the solar monitoring dashboard. '
          'You can ask me to navigate, search sensors, read values, and more.\n\n'
          'Try saying: "open plants" or "show sensors"',
    ));

    _suggestions = [
      'Open dashboard',
      'Open plants',
      'Show sensors',
      'Show inverters',
    ];
  }

  /// Wait for the current page to load, then scrape its data into the cache.
  /// This runs in the background — no navigation, no page disruption.
  Future<void> _discoverFromPageAfterDelay() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    await _discovery.discoverFromCurrentPage();
  }

  /// Derive a friendly page title from the current URL
  String _getPageTitle(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return 'Dashboard';

    final path = uri.path.toLowerCase();

    if (path.contains('/sensors/')) {
      return 'Sensor Details';
    } else if (path.contains('/sensors')) {
      return 'Sensors';
    } else if (path.contains('/plants') && path.contains('details')) {
      return 'Plant Details';
    } else if (path.contains('/plants')) {
      return 'Plants';
    } else if (path.contains('/inverters')) {
      return 'Inverters';
    } else if (path.contains('/slmsdevices') || path.contains('/slms')) {
      return 'SLMs';
    } else if (path.contains('/dashboard') || path == '/') {
      return 'Dashboard';
    }

    return 'Dashboard';
  }

  /// Go back to the previous page
  void _handleGoBack() {
    _webViewService.controller?.goBack();
  }

  /// Refresh the current page
  void _handleRefresh() {
    _webViewService.controller?.reload();
  }

  Future<void> _handleSendMessage(String message) async {
    setState(() {
      _messages.add(ChatMessage(
        role: MessageRole.user,
        content: message,
      ));
      _isProcessing = true;
      _suggestions = [];
      _isChatExpanded = true;
    });

    // Add a loading message
    final loadingIndex = _messages.length;
    setState(() {
      _messages.add(ChatMessage(
        role: MessageRole.assistant,
        content: '',
        isLoading: true,
        toolCalls: [],
      ));
    });

    try {
      // Process via local command router (no external API calls)
      final result = await _commandRouter.processMessage(message);

      setState(() {
        _messages[loadingIndex] = ChatMessage(
          role: MessageRole.assistant,
          content: result.response,
          toolCalls: result.toolCalls.isNotEmpty ? result.toolCalls : null,
        );
        _isProcessing = false;
        // Use structured suggestions from CommandResult;
        // fall back to contextual suggestions if empty
        _suggestions = result.suggestions.isNotEmpty
            ? result.suggestions
            : _getContextualSuggestions();
      });
    } catch (e) {
      setState(() {
        _messages[loadingIndex] = ChatMessage(
          role: MessageRole.assistant,
          content: 'Sorry, an error occurred: $e',
        );
        _isProcessing = false;
        _suggestions = _getContextualSuggestions();
      });
    }
  }

  /// Build contextual suggestions based on the current page
  List<String> _getContextualSuggestions() {
    final url = _webViewService.currentUrl.toLowerCase();

    // Sensor detail page (specific sensor)
    if (url.contains('/sensors/')) {
      return ['Get sensor value', 'Go back', 'Open dashboard'];
    }

    // Sensors list page
    if (url.contains('/sensors')) {
      return ['Filter WMS', 'Filter MFM', 'Filter Temperature', 'Open dashboard'];
    }

    // Plant detail page
    if (url.contains('/plants') && url.contains('details')) {
      return ['Show energy data', 'Show revenue data', 'Go back'];
    }

    // Plants list page
    if (url.contains('/plants')) {
      return ['Open dashboard', 'Show sensors', 'Show inverters'];
    }

    // Inverters page
    if (url.contains('/inverters')) {
      return ['Open dashboard', 'Show sensors', 'Go back'];
    }

    // SLMs page
    if (url.contains('/slms')) {
      return ['Open dashboard', 'Open sensors', 'Open plants'];
    }

    // Dashboard (default)
    return ['Open plants', 'Show sensors', 'Show inverters', 'Show energy'];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Header bar ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E2C),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Go back button
                  IconButton(
                    onPressed: _handleGoBack,
                    icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
                    color: Colors.white,
                    tooltip: 'Go back',
                    splashRadius: 20,
                  ),
                  const SizedBox(width: 4),

                  // Page title
                  Expanded(
                    child: Text(
                      _currentPageTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // Refresh button
                  IconButton(
                    onPressed: _handleRefresh,
                    icon: const Icon(Icons.refresh_rounded, size: 22),
                    color: Colors.white,
                    tooltip: 'Refresh page',
                    splashRadius: 20,
                  ),
                ],
              ),
            ),

            // ── WebView + Chat overlay ──
            Expanded(
              child: Stack(
                children: [
                  // WebView fills the remaining space
                  Positioned.fill(
                    child: WebViewContainer(webViewService: _webViewService),
                  ),

                  // Chat toggle button (when chat is collapsed)
                  if (!_isChatExpanded)
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: FloatingActionButton(
                        onPressed: () {
                          final maxH = MediaQuery.of(context).size.height * 0.45;
                          setState(() {
                            _panelHeight = maxH;
                            _isChatExpanded = true;
                          });
                        },
                        backgroundColor: const Color(0xFF6C63FF),
                        child: const Icon(Icons.auto_awesome, color: Colors.white),
                      ),
                    ),

                  // Chat panel (smooth resizable slider)
                  if (_isChatExpanded)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: SizedBox(
                        height: _panelHeight,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // ── Drag handle (only this area is draggable) ──
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onVerticalDragUpdate: (details) {
                                final maxH = MediaQuery.of(context).size.height * 0.85;
                                setState(() {
                                  _panelHeight -= details.delta.dy;
                                  _panelHeight = _panelHeight.clamp(160.0, maxH);
                                });
                              },
                              onVerticalDragEnd: (details) {
                                // Only collapse if dragged very small
                                if (_panelHeight < 170) {
                                  setState(() {
                                    _isChatExpanded = false;
                                    _panelHeight = 0;
                                  });
                                }
                                // Otherwise stay at current height
                              },
                              child: Container(
                                width: double.infinity,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1A1A2E),
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                child: Center(
                                  child: Container(
                                    width: 40,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: Colors.white38,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // ── Chat content (fills remaining space) ──
                            Expanded(
                              child: ChatPanel(
                                messages: _messages,
                                isProcessing: _isProcessing,
                                onSendMessage: _handleSendMessage,
                                suggestions: _suggestions,
                                onSuggestionTap: _handleSendMessage,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
