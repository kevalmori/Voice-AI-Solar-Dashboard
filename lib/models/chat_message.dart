enum MessageRole { user, assistant, system, tool }

class ChatMessage {
  final MessageRole role;
  final String content;
  final DateTime timestamp;
  final List<ToolCallInfo>? toolCalls;
  final bool isLoading;

  ChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.toolCalls,
    this.isLoading = false,
  }) : timestamp = timestamp ?? DateTime.now();

  ChatMessage copyWith({
    MessageRole? role,
    String? content,
    DateTime? timestamp,
    List<ToolCallInfo>? toolCalls,
    bool? isLoading,
  }) {
    return ChatMessage(
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      toolCalls: toolCalls ?? this.toolCalls,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class ToolCallInfo {
  final String name;
  final Map<String, dynamic> arguments;
  final String? result;
  final bool isExecuting;

  ToolCallInfo({
    required this.name,
    required this.arguments,
    this.result,
    this.isExecuting = false,
  });

  ToolCallInfo copyWith({String? result, bool? isExecuting}) {
    return ToolCallInfo(
      name: name,
      arguments: arguments,
      result: result ?? this.result,
      isExecuting: isExecuting ?? this.isExecuting,
    );
  }

  String get displayName {
    final args = arguments.entries
        .map((e) => '${e.value}')
        .join(', ');
    return '$name(${args.isNotEmpty ? args : ''})';
  }
}
