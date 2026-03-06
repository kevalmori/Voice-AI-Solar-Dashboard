import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/chat_message.dart';
import '../tools/tool_registry.dart';

class LlmService {
  final ToolRegistry toolRegistry;
  final List<Map<String, dynamic>> _conversationHistory = [];

  LlmService({required this.toolRegistry});

  /// Send a message and get response, handling tool calls in a loop
  Future<ChatMessage> sendMessage(
    String userMessage, {
    Function(String toolName, Map<String, dynamic> args)? onToolCall,
    Function(String toolName, String result)? onToolResult,
  }) async {
    // Add user message to history
    _conversationHistory.add({
      'role': 'user',
      'parts': [
        {'text': userMessage}
      ],
    });

    int toolCallCount = 0;
    const maxToolCalls = 10; // Safety limit to prevent infinite loops

    // Loop to handle multi-step tool calling
    while (toolCallCount < maxToolCalls) {
      final apiResult = await _callGeminiApiWithDetails();

      if (apiResult['data'] == null) {
        final errorDetail = apiResult['error'] ?? 'Unknown error';
        debugPrint('API Error Detail: $errorDetail');
        return ChatMessage(
          role: MessageRole.assistant,
          content:
              'Sorry, I encountered an error communicating with the AI service.\n\nError: $errorDetail',
        );
      }

      final response = apiResult['data'] as Map<String, dynamic>;

      // Check if the response contains a function call
      final candidates = response['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        return ChatMessage(
            role: MessageRole.assistant,
            content: 'No response received from AI.');
      }

      final content = candidates[0]['content'];
      final parts = content['parts'] as List;

      // Check for function call
      final functionCallPart = _findFunctionCall(parts);

      if (functionCallPart != null) {
        final functionCall = functionCallPart['functionCall'];
        final toolName = functionCall['name'] as String;
        final args =
            Map<String, dynamic>.from(functionCall['args'] as Map? ?? {});

        debugPrint('🔧 Tool call #${toolCallCount + 1}: $toolName($args)');

        // Notify caller about tool execution
        onToolCall?.call(toolName, args);

        // Execute the tool
        final toolResult = await toolRegistry.executeTool(toolName, args);

        debugPrint('📋 Tool result: $toolResult');

        // Notify caller about result
        onToolResult?.call(toolName, toolResult);

        // Add model's function call to history
        _conversationHistory.add({
          'role': 'model',
          'parts': [
            {
              'functionCall': {'name': toolName, 'args': args}
            }
          ],
        });

        // Add function response to history
        // IMPORTANT: Gemini API expects function responses with role 'user'
        // and functionResponse part (NOT role 'function')
        _conversationHistory.add({
          'role': 'user',
          'parts': [
            {
              'functionResponse': {
                'name': toolName,
                'response': {
                  'name': toolName,
                  'content': {'result': toolResult}
                }
              }
            }
          ],
        });

        toolCallCount++;
        // Continue the loop — LLM may call another tool or respond
        continue;
      }

      // No function call — extract text response
      final textPart = _findTextPart(parts);
      final responseText = textPart ?? 'Action completed.';

      // Add model response to history
      _conversationHistory.add({
        'role': 'model',
        'parts': [
          {'text': responseText}
        ],
      });

      debugPrint('💬 Final response after $toolCallCount tool calls');

      return ChatMessage(
        role: MessageRole.assistant,
        content: responseText,
      );
    }

    // If we hit the max tool calls, return what we have
    return ChatMessage(
      role: MessageRole.assistant,
      content:
          'I completed $toolCallCount actions. The task may need more steps — please tell me what to do next.',
    );
  }

  /// Find a functionCall in parts
  Map<String, dynamic>? _findFunctionCall(List parts) {
    for (var part in parts) {
      if (part is Map && part.containsKey('functionCall')) {
        return part as Map<String, dynamic>;
      }
    }
    return null;
  }

  /// Find text in parts
  String? _findTextPart(List parts) {
    for (var part in parts) {
      if (part is Map && part.containsKey('text')) {
        return part['text'] as String;
      }
    }
    return null;
  }

  /// Call the Gemini API with detailed error reporting
  Future<Map<String, dynamic>> _callGeminiApiWithDetails() async {
    final url = Uri.parse(
      '${AppConfig.geminiBaseUrl}/${AppConfig.geminiModel}:generateContent?key=${AppConfig.geminiApiKey}',
    );

    final body = {
      // Use systemInstruction for the system prompt (much more effective)
      'systemInstruction': {
        'parts': [
          {'text': AppConfig.systemPrompt}
        ]
      },
      'contents': _conversationHistory,
      'tools': [
        {
          'functionDeclarations': ToolRegistry.toolDeclarations,
        }
      ],
      // Force the model to consider tools on every turn
      'toolConfig': {
        'functionCallingConfig': {
          'mode': 'AUTO',
        }
      },
      'generationConfig': {
        'temperature': 0.1,
        'maxOutputTokens': 1024,
      },
    };

    try {
      debugPrint('📡 Calling Gemini API with ${_conversationHistory.length} messages...');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        // Debug: log if it's a function call or text
        final candidates = data['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final parts = candidates[0]['content']['parts'] as List;
          for (var part in parts) {
            if (part is Map && part.containsKey('functionCall')) {
              debugPrint('📡 API returned function call: ${part['functionCall']['name']}');
            } else if (part is Map && part.containsKey('text')) {
              debugPrint('📡 API returned text response (${(part['text'] as String).length} chars)');
            }
          }
        }
        return {'data': data};
      } else {
        debugPrint('Gemini API error: ${response.statusCode} ${response.body}');
        return {
          'data': null,
          'error': 'HTTP ${response.statusCode}: ${response.body}'
        };
      }
    } catch (e) {
      debugPrint('Network error: $e');
      return {'data': null, 'error': 'Network error: $e'};
    }
  }

  /// Parse suggestions from assistant response
  List<String> parseSuggestions(String response) {
    final suggestions = <String>[];
    final lines = response.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('- ') || trimmed.startsWith('• ')) {
        suggestions.add(trimmed.substring(2).trim());
      } else if (RegExp(r'^\d+\.\s').hasMatch(trimmed)) {
        suggestions.add(trimmed.replaceFirst(RegExp(r'^\d+\.\s'), '').trim());
      }
    }
    return suggestions.take(4).toList();
  }

  /// Clear conversation history
  void clearHistory() {
    _conversationHistory.clear();
  }
}
