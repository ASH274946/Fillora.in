import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

/// Azure Blob Storage Service for file uploads and document storage
class AzureBlobService {
  static final AzureBlobService _instance = AzureBlobService._internal();
  factory AzureBlobService() => _instance;
  AzureBlobService._internal();

  String get _connectionString => AppConfig.azureBlobStorageConnectionString;
  String get _containerName => AppConfig.azureBlobStorageContainerName;

  // Parse connection string to get account name and key
  Map<String, String>? _connectionParams;

  Map<String, String> get connectionParams {
    if (_connectionParams != null) return _connectionParams!;
    
    if (_connectionString.isEmpty || _connectionString == 'YOUR_AZURE_STORAGE_CONNECTION_STRING') {
      throw Exception('Azure Blob Storage connection string is not configured');
    }

    _connectionParams = {};
    final parts = _connectionString.split(';');
    for (var part in parts) {
      final equalsIndex = part.indexOf('=');
      if (equalsIndex > 0) {
        final key = part.substring(0, equalsIndex).trim();
        final value = part.substring(equalsIndex + 1).trim();
        _connectionParams![key] = value;
      }
    }

    return _connectionParams!;
  }

  String get _accountName => connectionParams['AccountName'] ?? '';
  String get _accountKey => connectionParams['AccountKey'] ?? '';

  // Build storage URL
  String get _storageUrl => 'https://$_accountName.blob.core.windows.net';

  /// Upload file to Azure Blob Storage
  /// 
  /// [fileBytes] - File content as bytes
  /// [fileName] - Name of the file
  /// [contentType] - MIME type of the file
  /// Returns the blob URL
  Future<String> uploadFile(
    Uint8List fileBytes,
    String fileName, {
    String contentType = 'application/octet-stream',
  }) async {
    try {
      if (_accountName.isEmpty || _accountKey.isEmpty) {
        throw Exception('Azure Blob Storage not properly configured');
      }

      // Generate blob URL
      final blobName = '${DateTime.now().millisecondsSinceEpoch}_$fileName';
      final blobUrl = '$_storageUrl/$_containerName/$blobName';

      // Create authorization header
      final authHeader = _generateAuthorizationHeader('PUT', blobUrl, contentType, fileBytes.length);

      debugPrint('=== AZURE BLOB UPLOAD ===');
      debugPrint('Blob: $blobName');
      debugPrint('Size: ${fileBytes.length} bytes');

      // Upload file
      final response = await http.put(
        Uri.parse(blobUrl),
        headers: {
          'Authorization': authHeader,
          'Content-Type': contentType,
          'x-ms-blob-type': 'BlockBlob',
          'x-ms-version': '2021-04-10',
        },
        body: fileBytes,
      );

      debugPrint('Upload Status Code: ${response.statusCode}');

      if (response.statusCode == 201) {
        debugPrint('✅ File uploaded successfully');
        return blobUrl;
      } else {
        throw Exception('Failed to upload file: ${response.statusCode}, ${response.body}');
      }
    } catch (e, stackTrace) {
      debugPrint('Error uploading file to Azure Blob: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Download file from Azure Blob Storage
  Future<Uint8List> downloadFile(String blobUrl) async {
    try {
      final authHeader = _generateAuthorizationHeader('GET', blobUrl, '', 0);

      final response = await http.get(
        Uri.parse(blobUrl),
        headers: {
          'Authorization': authHeader,
          'x-ms-version': '2021-04-10',
        },
      );

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        throw Exception('Failed to download file: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error downloading file from Azure Blob: $e');
      rethrow;
    }
  }

  /// Delete file from Azure Blob Storage
  Future<void> deleteFile(String blobUrl) async {
    try {
      final authHeader = _generateAuthorizationHeader('DELETE', blobUrl, '', 0);

      final response = await http.delete(
        Uri.parse(blobUrl),
        headers: {
          'Authorization': authHeader,
          'x-ms-version': '2021-04-10',
        },
      );

      if (response.statusCode != 202 && response.statusCode != 404) {
        throw Exception('Failed to delete file: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error deleting file from Azure Blob: $e');
      rethrow;
    }
  }

  /// Generate Azure Storage authorization header
  /// This is a simplified version - for production, use azure_storage_blob package
  String _generateAuthorizationHeader(String method, String url, String contentType, int contentLength) {
    // Note: This is a simplified implementation
    // For production, use the azure_storage_blob package or implement proper
    // Shared Key authentication as per Azure Storage REST API documentation
    
    // Simplified: Return a placeholder
    // In production, you should implement the full Shared Key authentication:
    // https://learn.microsoft.com/en-us/rest/api/storageservices/authorize-with-shared-key
    
    debugPrint('Warning: Simplified authorization header generation. For production, use proper Shared Key authentication.');
    
    // For now, return placeholder (will need proper implementation or use SDK)
    return 'SharedKey $_accountName:PLACEHOLDER_SIGNATURE';
  }

  /// Upload PDF document
  Future<String> uploadPdf(Uint8List pdfBytes, String fileName) async {
    return await uploadFile(pdfBytes, fileName, contentType: 'application/pdf');
  }

  /// Upload image document
  Future<String> uploadImage(Uint8List imageBytes, String fileName, {String imageType = 'jpeg'}) async {
    final contentType = imageType == 'png' ? 'image/png' : 'image/jpeg';
    return await uploadFile(imageBytes, fileName, contentType: contentType);
  }

  /// Get file URL (public or with SAS token)
  String getFileUrl(String blobName, {bool generateSasToken = false}) {
    final blobUrl = '$_storageUrl/$_containerName/$blobName';
    
    if (generateSasToken) {
      // TODO: Generate SAS token for secure access
      // For now, return URL without SAS token
      return blobUrl;
    }
    
    return blobUrl;
  }
}
