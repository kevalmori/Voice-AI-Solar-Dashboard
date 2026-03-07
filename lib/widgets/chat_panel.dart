import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../models/chat_message.dart';

class ChatPanel extends StatefulWidget {
  final List<ChatMessage> messages;
  final bool isProcessing;
  final Function(String) onSendMessage;
  final List<String> suggestions;
  final Function(String) onSuggestionTap;

  const ChatPanel({
    super.key,
    required this.messages,
    required this.isProcessing,
    required this.onSendMessage,
    required this.suggestions,
    required this.onSuggestionTap,
  });

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _speechAvailable = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    // Scroll to bottom on first mount so the panel always shows the latest messages
    _scrollToBottom();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onError: (error) {
        debugPrint('Speech error: $error');
        setState(() => _isListening = false);
      },
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
        }
      },
    );
  }

  void _toggleListening() async {
    if (!_speechAvailable) {
      _speechAvailable = await _speech.initialize();
      if (!_speechAvailable) return;
    }

    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      if (_textController.text.trim().isNotEmpty) {
        _handleSend();
      }
    } else {
      setState(() => _isListening = true);
      await _speech.listen(
        onResult: (result) {
          setState(() {
            _textController.text = result.recognizedWords;
          });
          if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
            _handleSend();
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
      );
    }
  }

  void _handleSend() {
    final text = _textController.text.trim();
    if (text.isEmpty || widget.isProcessing) return;
    _textController.clear();
    if (_isListening) {
      _speech.stop();
      setState(() => _isListening = false);
    }
    widget.onSendMessage(text);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        // With reverse: true, position 0 is the bottom (latest messages)
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void didUpdateWidget(ChatPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Always scroll to bottom when parent rebuilds (message added or updated)
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 20,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          // Chat header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFF4A42D1)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Smart Assistant',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (_isListening)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.mic, color: Colors.red, size: 14),
                        SizedBox(width: 4),
                        Text('Listening...', style: TextStyle(color: Colors.red, fontSize: 11)),
                      ],
                    ),
                  ),
                if (widget.isProcessing && !_isListening)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Color(0xFF6C63FF)),
                    ),
                  ),
              ],
            ),
          ),

          const Divider(color: Colors.white10, height: 1),

          // Messages
          Flexible(
            child: ListView.builder(
              controller: _scrollController,
              reverse: true,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shrinkWrap: true,
              itemCount: widget.messages.length,
              itemBuilder: (context, index) {
                // With reverse: true, index 0 is at the bottom.
                // Map so that the latest message (last in the list) is at index 0.
                final msgIndex = widget.messages.length - 1 - index;
                return _buildMessage(widget.messages[msgIndex]);
              },
            ),
          ),

          // Suggestions
          if (widget.suggestions.isNotEmpty && !widget.isProcessing)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: widget.suggestions.map((s) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        label: Text(s,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11)),
                        backgroundColor: const Color(0xFF2A2A4A),
                        side: BorderSide(
                            color: const Color(0xFF6C63FF).withValues(alpha: 0.3)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        onPressed: () => widget.onSuggestionTap(s),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

          // Input bar with mic + send
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A4A),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _isListening
                            ? Colors.red.withValues(alpha: 0.5)
                            : const Color(0xFF6C63FF).withValues(alpha: 0.2),
                      ),
                    ),
                    child: TextField(
                      controller: _textController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: _isListening ? 'Speak now...' : 'Ask me anything...',
                        hintStyle: TextStyle(
                          color: _isListening ? Colors.red.withValues(alpha: 0.6) : Colors.white38,
                        ),
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onSubmitted: (_) => _handleSend(),
                      enabled: !widget.isProcessing,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Mic button
                GestureDetector(
                  onTap: widget.isProcessing ? null : _toggleListening,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _isListening ? Colors.red : const Color(0xFF2A2A4A),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _isListening
                            ? Colors.red
                            : const Color(0xFF6C63FF).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Icon(
                      _isListening ? Icons.mic_off : Icons.mic,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Send button
                GestureDetector(
                  onTap: _handleSend,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6C63FF), Color(0xFF4A42D1)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      widget.isProcessing ? Icons.hourglass_top : Icons.send,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(ChatMessage message) {
    final isUser = message.role == MessageRole.user;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser)
            Container(
              margin: const EdgeInsets.only(right: 6, top: 4),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF4A42D1)],
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.auto_awesome,
                  color: Colors.white, size: 12),
            ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isUser
                    ? const Color(0xFF6C63FF).withValues(alpha: 0.2)
                    : const Color(0xFF2A2A4A),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: Radius.circular(isUser ? 12 : 2),
                  bottomRight: Radius.circular(isUser ? 2 : 12),
                ),
                border: isUser
                    ? Border.all(
                        color: const Color(0xFF6C63FF).withValues(alpha: 0.3))
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.toolCalls != null)
                    ...message.toolCalls!.map((tc) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                tc.isExecuting
                                    ? Icons.sync
                                    : Icons.check_circle,
                                size: 12,
                                color: tc.isExecuting
                                    ? const Color(0xFFFFD93D)
                                    : const Color(0xFF4ADE80),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  tc.displayName,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        )),

                  if (message.content.isNotEmpty)
                    Text(
                      message.content,
                      style: TextStyle(
                        color: isUser ? Colors.white : Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),

                  if (message.isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation(Color(0xFF6C63FF)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _speech.stop();
    super.dispose();
  }
}
