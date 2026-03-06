import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../services/command_router.dart';
import '../services/llm_service.dart';
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
  late final LlmService _llmService;

  final List<ChatMessage> _messages = [];
  List<String> _suggestions = [];
  bool _isProcessing = false;
  bool _isChatExpanded = false;

  @override
  void initState() {
    super.initState();
    _toolRegistry = ToolRegistry(_webViewService);
    _commandRouter = CommandRouter(_toolRegistry);
    _llmService = LlmService(toolRegistry: _toolRegistry);

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
      // 1) Try local command router first (fast, no API call)
      final localResult = await _commandRouter.processMessage(message);

      if (localResult.matched) {
        // Local match — use it directly
        setState(() {
          _messages[loadingIndex] = ChatMessage(
            role: MessageRole.assistant,
            content: localResult.response,
            toolCalls: localResult.toolCalls.isNotEmpty ? localResult.toolCalls : null,
          );
          _isProcessing = false;
          _suggestions = _parseSuggestions(localResult.response);
          if (_suggestions.isEmpty) {
            _suggestions = _getContextualSuggestions();
          }
        });
      } else {
        // 2) No local match — fall back to Gemini LLM
        final toolCalls = <ToolCallInfo>[];
        final llmResult = await _llmService.sendMessage(
          message,
          onToolCall: (name, args) {
            toolCalls.add(ToolCallInfo(name: name, arguments: args, isExecuting: true));
            setState(() {
              _messages[loadingIndex] = ChatMessage(
                role: MessageRole.assistant,
                content: '',
                isLoading: true,
                toolCalls: List.from(toolCalls),
              );
            });
          },
          onToolResult: (name, result) {
            final idx = toolCalls.lastIndexWhere((t) => t.name == name);
            if (idx >= 0) {
              toolCalls[idx] = toolCalls[idx].copyWith(isExecuting: false, result: result);
            }
          },
        );

        setState(() {
          _messages[loadingIndex] = ChatMessage(
            role: MessageRole.assistant,
            content: llmResult.content,
            toolCalls: toolCalls.isNotEmpty ? toolCalls : null,
          );
          _isProcessing = false;
          _suggestions = _parseSuggestions(llmResult.content);
          if (_suggestions.isEmpty) {
            _suggestions = _getContextualSuggestions();
          }
        });
      }
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
        child: Stack(
          children: [
            // WebView fills the screen
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
    );
  }
}
