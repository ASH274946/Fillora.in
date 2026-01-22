import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import '../config/app_config.dart';

/// Azure Speech Services for Speech-to-Text and Text-to-Speech
/// Replaces Google Speech-to-Text and Flutter TTS
class AzureSpeechService {
  static final AzureSpeechService _instance = AzureSpeechService._internal();
  factory AzureSpeechService() => _instance;
  AzureSpeechService._internal();

  // Azure Speech configuration
  String get _endpoint => AppConfig.azureSpeechEndpoint;
  String get _apiKey => AppConfig.azureSpeechApiKey;
  String get _region => AppConfig.azureSpeechRegion;

  bool _isListening = false;
  bool _isInitialized = false;
  String _lastWords = '';

  bool get isListening => _isListening;
  bool get isInitialized => _isInitialized;
  String get lastWords => _lastWords;

  // Text-to-Speech endpoint
  String get _ttsEndpoint {
    if (_endpoint.isEmpty || _endpoint == 'YOUR_AZURE_SPEECH_ENDPOINT') {
      throw Exception('Azure Speech endpoint is not configured');
    }
    final baseUrl = _endpoint.endsWith('/') ? _endpoint.substring(0, _endpoint.length - 1) : _endpoint;
    return '$baseUrl/tts/cognitiveservices/v1';
  }

  // Speech-to-Text endpoint (short audio)
  String get _sttEndpoint {
    if (_endpoint.isEmpty || _endpoint == 'YOUR_AZURE_SPEECH_ENDPOINT') {
      throw Exception('Azure Speech endpoint is not configured');
    }
    final baseUrl = _endpoint.endsWith('/') ? _endpoint.substring(0, _endpoint.length - 1) : _endpoint;
    return '$baseUrl/speech/recognition/conversation/cognitiveservices/v1?language=en-US';
  }

  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Request microphone permission
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        debugPrint('Microphone permission not granted');
        if (status.isPermanentlyDenied) {
          debugPrint('Microphone permission permanently denied');
        }
        return false;
      }

      // Validate Azure Speech configuration
      if (_apiKey.isEmpty || _apiKey == 'YOUR_AZURE_SPEECH_API_KEY') {
        debugPrint('Azure Speech API key not configured');
        return false;
      }

      _isInitialized = true;
      return true;
    } catch (e) {
      debugPrint('Error initializing Azure Speech Service: $e');
      return false;
    }
  }

  /// Start listening for speech (Speech-to-Text)
  /// Note: For production, consider using Azure Speech SDK WebSocket connection for real-time streaming
  Future<void> startListening({
    required Function(String) onResult,
    Function(String)? onPartialResult,
    Function(String)? onError,
  }) async {
    try {
      if (!_isInitialized) {
        final initialized = await initialize();
        if (!initialized) {
          final permissionStatus = await Permission.microphone.status;
          if (!permissionStatus.isGranted) {
            onError?.call('Microphone permission is required for voice input. Please grant permission in app settings.');
          } else {
            onError?.call('Azure Speech Service is not properly configured. Please check your configuration.');
          }
          return;
        }
      }

      // Check microphone permission again
      final permissionStatus = await Permission.microphone.status;
      if (!permissionStatus.isGranted) {
        final newStatus = await Permission.microphone.request();
        if (!newStatus.isGranted) {
          _isListening = false;
          onError?.call('Microphone permission is required. Please grant permission in app settings.');
          return;
        }
      }

      if (_isListening) {
        await stopListening();
      }

      _isListening = true;
      _lastWords = '';

      // Note: This is a simplified implementation
      // For production, you should use Azure Speech SDK WebSocket connection
      // or record audio first and then send to Azure Speech API
      
      // For now, we'll use a placeholder that indicates the need for audio recording
      // In production, you would:
      // 1. Record audio using Flutter audio plugins
      // 2. Send audio data to Azure Speech-to-Text API
      // 3. Get transcription results
      
      onError?.call('Audio recording and Azure Speech-to-Text integration requires additional setup. Please use text input for now.');
      _isListening = false;
      
      // TODO: Implement audio recording and Azure Speech API call
      // This requires: flutter_sound or record package for audio recording
      // Then send audio bytes to Azure Speech-to-Text REST API
      
    } catch (e) {
      _isListening = false;
      debugPrint('Error starting speech recognition: $e');
      onError?.call('Error starting voice recognition: ${e.toString()}');
    }
  }

  /// Stop listening
  Future<void> stopListening() async {
    _isListening = false;
    // Stop any ongoing audio recording here
  }

  /// Convert text to speech using Azure Text-to-Speech
  Future<void> speak(String text, {String languageCode = 'en-US', String voiceName = 'en-US-JennyNeural'}) async {
    try {
      if (_apiKey.isEmpty || _apiKey == 'YOUR_AZURE_SPEECH_API_KEY') {
        debugPrint('Azure Speech API key not configured for TTS');
        return;
      }

      // Build SSML for Azure TTS
      final ssml = '''<speak version='1.0' xml:lang='$languageCode'>
        <voice xml:lang='$languageCode' name='$voiceName'>
          $text
        </voice>
      </speak>''';

      // Call Azure Text-to-Speech API
      final response = await http.post(
        Uri.parse(_ttsEndpoint),
        headers: {
          'Ocp-Apim-Subscription-Key': _apiKey,
          'Content-Type': 'application/ssml+xml',
          'X-Microsoft-OutputFormat': 'audio-16khz-128kbitrate-mono-mp3',
        },
        body: ssml,
      );

      if (response.statusCode == 200) {
        // Get audio data from response
        final audioBytes = response.bodyBytes;
        
        // TODO: Play audio using audio player package
        // This requires: audioplayers or just_audio package
        // Example: await AudioPlayer().play(BytesSource(audioBytes));
        
        debugPrint('Azure TTS: Audio generated successfully (${audioBytes.length} bytes)');
      } else {
        debugPrint('Azure TTS Error: Status ${response.statusCode}, ${response.body}');
      }
    } catch (e) {
      debugPrint('Error in Azure Text-to-Speech: $e');
    }
  }

  /// Stop speaking
  Future<void> stopSpeaking() async {
    // TODO: Stop audio playback
    // Example: await AudioPlayer().stop();
  }

  /// Set language for TTS
  Future<void> setLanguage(String languageCode) async {
    // Language setting is handled per speak() call
  }

  void dispose() {
    stopListening();
    stopSpeaking();
  }

  /// Transcribe audio file using Azure Speech-to-Text (batch)
  /// This is useful for recorded audio files
  Future<String> transcribeAudioFile(List<int> audioBytes, {String languageCode = 'en-US'}) async {
    try {
      if (_apiKey.isEmpty || _apiKey == 'YOUR_AZURE_SPEECH_API_KEY') {
        throw Exception('Azure Speech API key is not configured');
      }

      final endpoint = _sttEndpoint.replaceAll('en-US', languageCode);

      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Ocp-Apim-Subscription-Key': _apiKey,
          'Content-Type': 'audio/wav', // Adjust based on your audio format
        },
        body: audioBytes,
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['RecognitionStatus'] == 'Success') {
          return result['DisplayText'] ?? '';
        } else {
          throw Exception('Speech recognition failed: ${result['RecognitionStatus']}');
        }
      } else {
        throw Exception('Azure Speech-to-Text API error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error transcribing audio: $e');
      rethrow;
    }
  }
}
