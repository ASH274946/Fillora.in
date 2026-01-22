import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

/// Azure Computer Vision Service for OCR and image analysis
/// Extracts text from PDFs and images
class AzureVisionService {
  static final AzureVisionService _instance = AzureVisionService._internal();
  factory AzureVisionService() => _instance;
  AzureVisionService._internal();

  String get _endpoint => AppConfig.azureVisionEndpoint;
  String get _apiKey => AppConfig.azureVisionApiKey;

  // OCR endpoint (Read API)
  String get _ocrEndpoint {
    if (_endpoint.isEmpty || _endpoint == 'YOUR_AZURE_VISION_ENDPOINT') {
      throw Exception('Azure Computer Vision endpoint is not configured');
    }
    final baseUrl = _endpoint.endsWith('/') ? _endpoint.substring(0, _endpoint.length - 1) : _endpoint;
    return '$baseUrl/vision/v3.2/read/analyze';
  }

  // Get Read results endpoint
  String _getReadResultsUrl(String operationId) {
    final baseUrl = _endpoint.endsWith('/') ? _endpoint.substring(0, _endpoint.length - 1) : _endpoint;
    return '$baseUrl/vision/v3.2/read/analyzeResults/$operationId';
  }

  /// Extract text from image using Azure Computer Vision Read API
  /// 
  /// [imageBytes] - Image file as bytes
  /// Returns extracted text
  Future<String> extractTextFromImage(Uint8List imageBytes) async {
    try {
      if (_apiKey.isEmpty || _apiKey == 'YOUR_AZURE_VISION_API_KEY') {
        throw Exception('Azure Computer Vision API key is not configured');
      }

      debugPrint('=== AZURE VISION OCR REQUEST ===');
      
      // Step 1: Submit image for analysis
      final response = await http.post(
        Uri.parse(_ocrEndpoint),
        headers: {
          'Ocp-Apim-Subscription-Key': _apiKey,
          'Content-Type': 'application/octet-stream',
        },
        body: imageBytes,
      );

      debugPrint('OCR Status Code: ${response.statusCode}');

      if (response.statusCode == 202) {
        // Operation accepted, get operation location
        final operationLocation = response.headers['operation-location'];
        if (operationLocation == null) {
          throw Exception('No operation-location header in response');
        }

        // Extract operation ID from URL
        final operationId = operationLocation.split('/').last;
        debugPrint('Operation ID: $operationId');

        // Step 2: Poll for results
        return await _pollForReadResults(operationId);
      } else {
        final errorBody = response.body;
        throw Exception('Azure Vision API error: ${response.statusCode}, $errorBody');
      }
    } catch (e, stackTrace) {
      debugPrint('Error extracting text from image: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Poll for Read API results
  Future<String> _pollForReadResults(String operationId, {int maxRetries = 20}) async {
    int retries = 0;
    
    while (retries < maxRetries) {
      await Future.delayed(const Duration(seconds: 1));
      
      final response = await http.get(
        Uri.parse(_getReadResultsUrl(operationId)),
        headers: {
          'Ocp-Apim-Subscription-Key': _apiKey,
        },
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        final status = result['status'] as String?;

        if (status == 'succeeded') {
          // Extract text from all pages
          final pages = result['analyzeResult']?['readResults'] as List? ?? [];
          final textBuffer = StringBuffer();

          for (var page in pages) {
            final lines = page['lines'] as List? ?? [];
            for (var line in lines) {
              final text = line['text'] as String? ?? '';
              textBuffer.writeln(text);
            }
          }

          final extractedText = textBuffer.toString().trim();
          debugPrint('✅ Text extracted successfully: ${extractedText.length} characters');
          return extractedText;
        } else if (status == 'failed') {
          throw Exception('OCR operation failed: ${result['analyzeResult']?['errors']}');
        }
        // If still running, continue polling
      } else {
        throw Exception('Failed to get OCR results: ${response.statusCode}');
      }

      retries++;
    }

    throw Exception('OCR operation timed out after $maxRetries retries');
  }

  /// Extract text from PDF (first page only, as image)
  /// Note: For full PDF support, consider using Azure Form Recognizer
  Future<String> extractTextFromPdf(Uint8List pdfBytes) async {
    // Azure Computer Vision Read API can process PDF, but for better results
    // use Azure Form Recognizer for structured PDF extraction
    return await extractTextFromImage(pdfBytes);
  }

  /// Analyze image and get key-value pairs (using Form Recognizer would be better)
  Future<Map<String, String>> analyzeDocumentImage(Uint8List imageBytes) async {
    final text = await extractTextFromImage(imageBytes);
    
    // Simple key-value extraction (basic implementation)
    // For better results, use Azure Form Recognizer
    final lines = text.split('\n').where((line) => line.trim().isNotEmpty).toList();
    final keyValues = <String, String>{};
    
    for (var line in lines) {
      if (line.contains(':') || line.contains(':')) {
        final parts = line.split(RegExp(r'[:：]'));
        if (parts.length >= 2) {
          keyValues[parts[0].trim()] = parts.sublist(1).join(':').trim();
        }
      }
    }
    
    return keyValues;
  }
}
