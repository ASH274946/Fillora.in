import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

/// Azure OpenAI Service for conversational AI
/// Replaces Google Gemini API
class AzureOpenAiService {
  static final AzureOpenAiService _instance = AzureOpenAiService._internal();
  factory AzureOpenAiService() => _instance;
  AzureOpenAiService._internal();

  // Azure OpenAI endpoint and configuration
  String get _endpoint => AppConfig.azureOpenAiEndpoint;
  String get _apiKey => AppConfig.azureOpenAiApiKey;
  String get _deploymentName => AppConfig.azureOpenAiDeploymentName;
  String get _apiVersion => AppConfig.azureOpenAiApiVersion;

  // Build the API URL for chat completions
  String get _chatCompletionsUrl {
    if (_endpoint.isEmpty || _endpoint == 'YOUR_AZURE_OPENAI_ENDPOINT') {
      throw Exception('Azure OpenAI endpoint is not configured. Please set it in lib/config/app_config.dart');
    }
    final baseUrl = _endpoint.endsWith('/') ? _endpoint.substring(0, _endpoint.length - 1) : _endpoint;
    return '$baseUrl/openai/deployments/$_deploymentName/chat/completions?api-version=$_apiVersion';
  }

  /// Get AI response using Azure OpenAI
  /// 
  /// [userMessage] - The user's message
  /// [context] - Optional context about the form (formTitle, currentField, etc.)
  /// [conversationHistory] - Optional conversation history
  Future<String> getResponse(
    String userMessage,
    Map<String, dynamic>? context, {
    List<Map<String, dynamic>>? conversationHistory,
  }) async {
    try {
      if (_apiKey.isEmpty || _apiKey == 'YOUR_AZURE_OPENAI_API_KEY') {
        throw Exception('Azure OpenAI API key is not configured. Please set it in lib/config/app_config.dart');
      }

      // Build system prompt
      String systemPrompt = _buildSystemPrompt(context);

      // Build messages array for Azure OpenAI API
      List<Map<String, dynamic>> messages = [
        {
          'role': 'system',
          'content': systemPrompt,
        },
      ];

      // Add conversation history if available
      if (conversationHistory != null && conversationHistory.isNotEmpty) {
        for (var message in conversationHistory) {
          final isAI = message['isAI'] as bool? ?? false;
          final text = message['text'] as String? ?? '';
          if (text.isNotEmpty) {
            messages.add({
              'role': isAI ? 'assistant' : 'user',
              'content': text,
            });
          }
        }
      }

      // Add current user message
      messages.add({
        'role': 'user',
        'content': userMessage,
      });

      // Build request body
      final requestBody = {
        'messages': messages,
        'temperature': 0.7,
        'max_tokens': 1000,
      };

      debugPrint('=== AZURE OPENAI REQUEST ===');
      debugPrint('URL: $_chatCompletionsUrl');
      debugPrint('Deployment: $_deploymentName');
      debugPrint('Messages: ${messages.length}');

      // Call Azure OpenAI API
      final response = await http.post(
        Uri.parse(_chatCompletionsUrl),
        headers: {
          'Content-Type': 'application/json',
          'api-key': _apiKey,
        },
        body: jsonEncode(requestBody),
      );

      debugPrint('=== AZURE OPENAI RESPONSE ===');
      debugPrint('Status Code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        if (responseData['choices'] != null && 
            responseData['choices'].isNotEmpty) {
          final choice = responseData['choices'][0];
          final message = choice['message'];
          
          if (message != null && message['content'] != null) {
            final aiResponse = message['content'] as String;
            debugPrint('✅ Azure OpenAI Success');
            debugPrint('Response: ${aiResponse.substring(0, aiResponse.length > 200 ? 200 : aiResponse.length)}...');
            return aiResponse;
          }
        }
        
        throw Exception('Azure OpenAI returned 200 but no valid response content');
      } else {
        // Handle error
        String errorMessage = 'Azure OpenAI API call failed';
        try {
          final errorData = jsonDecode(response.body);
          if (errorData['error'] != null) {
            final error = errorData['error'];
            final errorMsg = error['message'] ?? error.toString();
            final errorCode = error['code'] ?? response.statusCode;
            errorMessage = 'Azure OpenAI Error ($errorCode): $errorMsg';
          }
        } catch (e) {
          errorMessage = 'Azure OpenAI call failed with status ${response.statusCode}. Response: ${response.body.length > 200 ? response.body.substring(0, 200) + "..." : response.body}';
        }
        
        debugPrint('❌ Azure OpenAI Error: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Exception calling Azure OpenAI: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Build system prompt with context
  String _buildSystemPrompt(Map<String, dynamic>? context) {
    String prompt = "You are a helpful AI assistant for Fillora.in, an AI-powered form filling application. "
        "Your role is to help users fill out forms by providing guidance, explaining fields, and assisting with form completion.\n\n"
        "IMPORTANT GUIDELINES:\n"
        "- Stay focused on form filling assistance and helping users complete the form\n"
        "- Keep responses relevant to the user's question about the form\n"
        "- Provide helpful external links when they help users get information needed for the form (e.g., official portals, registration pages, documentation)\n"
        "- When users ask how to do something or get information needed for the form, provide clear step-by-step processes and instructions\n"
        "- If the user needs external information (like registration numbers, account details, etc.), provide links to official sources and explain the process to obtain that information\n"
        "- Be helpful, friendly, and conversational\n"
        "- Provide detailed explanations when users ask for processes or steps (e.g., 'how to find my registration number', 'how to get my certificate', etc.)\n"
        "- Include actual URLs/links when providing external resources\n"
        "- IMPORTANT: When providing URLs, use plain URLs (e.g., https://example.com) instead of markdown format. This ensures links work properly in the app.\n"
        "- If the user asks something completely unrelated to forms, politely redirect them back to form assistance\n"
        "- Be concise for simple questions, but provide detailed step-by-step instructions when users ask for processes\n"
        "- Do not make assumptions about form fields or data unless explicitly mentioned\n";

    if (context != null && context['formTitle'] != null) {
      prompt += "\nYou are currently helping with the form: ${context['formTitle']}";
    }

    if (context != null && context['currentField'] != null) {
      prompt += "\nCurrent form field being filled: ${context['currentField']}";
    }

    return prompt;
  }

  /// Extract fields from document using Azure OpenAI vision capabilities
  /// This can be enhanced with Azure Form Recognizer for better results
  Future<Map<String, dynamic>> extractFieldsFromDocument(String documentPath) async {
    // This would typically use Azure Form Recognizer or Computer Vision
    // For now, return a placeholder that should be handled by Form Recognizer service
    throw UnimplementedError('Use AzureFormRecognizerService.extractFieldsFromDocument instead');
  }

  /// Calculate confidence score for extracted data
  double calculateConfidence(Map<String, dynamic> extractedData) {
    // Simple confidence calculation based on number of fields filled
    final fieldCount = extractedData.length;
    if (fieldCount == 0) return 0.0;
    if (fieldCount < 3) return 0.6;
    if (fieldCount < 5) return 0.8;
    return 0.9;
  }
}
