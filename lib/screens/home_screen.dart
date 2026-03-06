import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../services/command_router.dart';
import '../services/webview_controller_service.dart';
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
  late final CommandRouter _commandRouter;

  final List<ChatMessage> _messages = [];
  List<String> _suggestions = [];
  bool _isProcessing = false;
  bool _isChatExpanded = false;
  String _currentPageTitle = 'Dashboard';

  @override
  void initState() {
    super.initState();
    _toolRegistry = ToolRegistry(_webViewService);
    _commandRouter = CommandRouter(_toolRegistry);

    // Listen for URL changes to update the header title
    _webViewService.onUrlChanged = (url) {
      setState(() {
        _currentPageTitle = _getPageTitle(url);
      });
    };

    // Add welcome message
    _messages.add(ChatMessage(
      role: MessageRole.assistant,
      content:
          'Hello! I\'m your AI assistant for the solar monitoring dashboard. '
          'You can ask me to navigate, search sensors, read values, and more.\n\n'
          'Try saying: "open GOA plant" or "show sensors"',
    ));

    _suggestions = [
      'Open dashboard',
      'Open GOA plant',
      'Show sensors',
      'Show inverters',
    ];
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
        _suggestions = _parseSuggestions(result.response);
        if (_suggestions.isEmpty) {
          _suggestions = _getContextualSuggestions();
        }
      });
    } catch (e) {
      setState(() {
        _messages[loadingIndex] = ChatMessage(
          role: MessageRole.assistant,
          content: 'Sorry, an error occurred: $e',
        );
        _isProcessing = false;
      });
    }
  }

  /// Parse numbered suggestions from response text
  List<String> _parseSuggestions(String response) {
    final suggestions = <String>[];
    final lines = response.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (RegExp(r'^\d+\.\s').hasMatch(trimmed)) {
        final suggestion =
            trimmed.replaceFirst(RegExp(r'^\d+\.\s'), '').trim();
        if (suggestion.isNotEmpty && suggestion.length < 40) {
          suggestions.add(suggestion);
        }
      }
    }
    return suggestions.take(4).toList();
  }

  List<String> _getContextualSuggestions() {
    final url = _webViewService.currentUrl;
    if (url.contains('/sensors/')) {
      return [
        'Get sensor value',
        'Get sensor category',
        'Go back',
        'Open dashboard',
      ];
    } else if (url.contains('/sensors')) {
      return [
        'Open radiation sensor',
        'Show temperature sensors',
        'Show MFM sensors',
        'Open dashboard',
      ];
    } else if (url.contains('/plants') && url.contains('Details')) {
      return [
        'Show energy data',
        'Show revenue data',
        'Yearly revenue',
        'Go back',
      ];
    } else if (url.contains('/plants')) {
      return [
        'Open GOA plant',
        'GOA yearly revenue',
        'GOA energy',
        'Open dashboard',
      ];
    } else if (url.contains('/inverters')) {
      return [
        'Open dashboard',
        'Show sensors',
        'Go back',
      ];
    } else {
      return [
        'Open GOA plant',
        'Show sensors',
        'Show inverters',
        'Show energy',
      ];
    }
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
                        onPressed: () => setState(() => _isChatExpanded = true),
                        backgroundColor: const Color(0xFF6C63FF),
                        child: const Icon(Icons.auto_awesome, color: Colors.white),
                      ),
                    ),

                  // Chat panel (bottom sheet style)
                  if (_isChatExpanded)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: GestureDetector(
                        onVerticalDragEnd: (details) {
                          if (details.primaryVelocity! > 200) {
                            setState(() => _isChatExpanded = false);
                          }
                        },
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.of(context).size.height * 0.5,
                          ),
                          child: ChatPanel(
                            messages: _messages,
                            isProcessing: _isProcessing,
                            onSendMessage: _handleSendMessage,
                            suggestions: _suggestions,
                            onSuggestionTap: _handleSendMessage,
                          ),
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
