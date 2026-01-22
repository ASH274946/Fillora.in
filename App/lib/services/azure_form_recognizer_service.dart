import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

/// Azure Form Recognizer Service for intelligent form field detection and extraction
/// Uses prebuilt models for forms, invoices, receipts, etc.
class AzureFormRecognizerService {
  static final AzureFormRecognizerService _instance = AzureFormRecognizerService._internal();
  factory AzureFormRecognizerService() => _instance;
  AzureFormRecognizerService._internal();

  String get _endpoint => AppConfig.azureFormRecognizerEndpoint;
  String get _apiKey => AppConfig.azureFormRecognizerApiKey;

  // Document Analysis endpoint (v2023-07-31)
  String get _documentAnalysisEndpoint {
    if (_endpoint.isEmpty || _endpoint == 'YOUR_AZURE_FORM_RECOGNIZER_ENDPOINT') {
      throw Exception('Azure Form Recognizer endpoint is not configured');
    }
    final baseUrl = _endpoint.endsWith('/') ? _endpoint.substring(0, _endpoint.length - 1) : _endpoint;
    return '$baseUrl/formrecognizer/documentModels/prebuilt-layout:analyze?api-version=2023-07-31';
  }

  // Get analysis results endpoint
  String _getAnalysisResultsUrl(String operationId) {
    final baseUrl = _endpoint.endsWith('/') ? _endpoint.substring(0, _endpoint.length - 1) : _endpoint;
    return '$baseUrl/formrecognizer/documentModels/prebuilt-layout/analyzeResults/$operationId?api-version=2023-07-31';
  }

  /// Analyze document and extract form fields
  /// 
  /// [documentBytes] - Document file as bytes (PDF, image)
  /// [modelId] - Optional model ID (default: prebuilt-layout, can use prebuilt-form)
  /// Returns map of extracted fields
  Future<Map<String, dynamic>> analyzeDocument(
    Uint8List documentBytes, {
    String modelId = 'prebuilt-layout',
  }) async {
    try {
      if (_apiKey.isEmpty || _apiKey == 'YOUR_AZURE_FORM_RECOGNIZER_API_KEY') {
        throw Exception('Azure Form Recognizer API key is not configured');
      }

      debugPrint('=== AZURE FORM RECOGNIZER ANALYSIS ===');

      // Build endpoint URL with model
      final endpoint = _documentAnalysisEndpoint.replaceAll('prebuilt-layout', modelId);

      // Step 1: Submit document for analysis
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Ocp-Apim-Subscription-Key': _apiKey,
          'Content-Type': 'application/octet-stream',
        },
        body: documentBytes,
      );

      debugPrint('Analysis Status Code: ${response.statusCode}');

      if (response.statusCode == 202) {
        // Operation accepted, get operation location
        final operationLocation = response.headers['operation-location'];
        if (operationLocation == null) {
          throw Exception('No operation-location header in response');
        }

        // Extract operation ID from URL
        final operationId = operationLocation.split('/').last.split('?').first;
        debugPrint('Operation ID: $operationId');

        // Step 2: Poll for results
        return await _pollForAnalysisResults(operationId);
      } else {
        final errorBody = response.body;
        throw Exception('Azure Form Recognizer API error: ${response.statusCode}, $errorBody');
      }
    } catch (e, stackTrace) {
      debugPrint('Error analyzing document: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Poll for analysis results
  Future<Map<String, dynamic>> _pollForAnalysisResults(String operationId, {int maxRetries = 30}) async {
    int retries = 0;
    
    while (retries < maxRetries) {
      await Future.delayed(const Duration(seconds: 2));
      
      final response = await http.get(
        Uri.parse(_getAnalysisResultsUrl(operationId)),
        headers: {
          'Ocp-Apim-Subscription-Key': _apiKey,
        },
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        final status = result['status'] as String?;

        if (status == 'succeeded') {
          // Extract key-value pairs from document
          return _extractFieldsFromResults(result);
        } else if (status == 'failed') {
          throw Exception('Document analysis failed: ${result['analyzeResult']?['errors']}');
        }
        // If still running, continue polling
      } else {
        throw Exception('Failed to get analysis results: ${response.statusCode}');
      }

      retries++;
    }

    throw Exception('Document analysis timed out after $maxRetries retries');
  }

  /// Extract form fields from analysis results
  Map<String, dynamic> _extractFieldsFromResults(Map<String, dynamic> result) {
    final extractedFields = <String, dynamic>{};
    
    try {
      final analyzeResult = result['analyzeResult'];
      if (analyzeResult == null) {
        return extractedFields;
      }

      // Extract key-value pairs
      final keyValuePairs = analyzeResult['keyValuePairs'] as List? ?? [];
      for (var kvp in keyValuePairs) {
        final key = kvp['key']?['content'] as String?;
        final value = kvp['value']?['content'] as String?;
        if (key != null && value != null) {
          extractedFields[key.trim()] = value.trim();
        }
      }

      // Extract tables (if any)
      final tables = analyzeResult['tables'] as List? ?? [];
      for (var table in tables) {
        final rows = table['rows'] as List? ?? [];
        for (var row in rows) {
          final cells = row['cells'] as List? ?? [];
          if (cells.isNotEmpty) {
            final header = cells[0]['content'] as String?;
            if (cells.length > 1 && header != null) {
              final cellValue = cells[1]['content'] as String?;
              if (cellValue != null) {
                extractedFields[header.trim()] = cellValue.trim();
              }
            }
          }
        }
      }

      // Extract text content for additional context
      final pages = analyzeResult['pages'] as List? ?? [];
      final textBuffer = StringBuffer();
      for (var page in pages) {
        final content = page['content'] as String?;
        if (content != null) {
          textBuffer.writeln(content);
        }
      }
      
      if (textBuffer.isNotEmpty) {
        extractedFields['_rawText'] = textBuffer.toString().trim();
      }

      debugPrint('✅ Extracted ${extractedFields.length} fields from document');
    } catch (e) {
      debugPrint('Error extracting fields from results: $e');
    }

    return extractedFields;
  }

  /// Extract fields from PDF document
  Future<Map<String, dynamic>> extractFieldsFromPdf(Uint8List pdfBytes) async {
    return await analyzeDocument(pdfBytes, modelId: 'prebuilt-layout');
  }

  /// Extract fields from image document
  Future<Map<String, dynamic>> extractFieldsFromImage(Uint8List imageBytes) async {
    return await analyzeDocument(imageBytes, modelId: 'prebuilt-layout');
  }

  /// Use prebuilt-form model for structured forms
  Future<Map<String, dynamic>> analyzeForm(Uint8List documentBytes) async {
    return await analyzeDocument(documentBytes, modelId: 'prebuilt-form');
  }
}
