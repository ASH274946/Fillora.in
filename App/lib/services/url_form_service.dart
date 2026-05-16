import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../config/app_config.dart';
import '../models/form_model.dart';
import 'database_service.dart';
import 'debug_log_service.dart';
import 'profile_autofill_service.dart';
import 'auth_service.dart';

/// Exception thrown when a Google Form requires authentication
class GoogleFormAuthenticationRequiredException implements Exception {
  final String message;
  GoogleFormAuthenticationRequiredException(this.message);
  
  @override
  String toString() => message;
}

class UrlFormService {
  static final UrlFormService _instance = UrlFormService._internal();
  factory UrlFormService() => _instance;
  UrlFormService._internal();

  final DatabaseService _dbService = DatabaseService();
  final _uuid = const Uuid();
  final DebugLogService _logService = DebugLogService();
  
  // Helper method to log and print
  void _log(String message, [LogType type = LogType.info]) {
    _logService.addLog(message, type);
    print(message);
  }

  // Analyze URL and create form from it
  // If authentication is required, returns null and caller should handle account selection
  // If htmlContent is provided, it will be used instead of fetching from URL
  Future<FormModel?> analyzeUrlAndCreateForm(String url, {String? googleAccessToken, String? htmlContent}) async {
    try {
      // Validate URL
      if (!_isValidUrl(url)) {
        throw Exception('Invalid URL format');
      }

      // Normalize Google Forms URL
      String normalizedUrl = url;
      if (url.contains('docs.google.com/forms')) {
        // Extract form ID from Google Forms URL
        normalizedUrl = _normalizeGoogleFormsUrl(url);
      }

      // Fetch and analyze the form
      _log('=== Starting form analysis for URL: $normalizedUrl ===');
      final formStructure = await _analyzeFormFromUrl(
        normalizedUrl, 
        googleAccessToken: googleAccessToken,
        htmlContent: htmlContent,
      );
      
      _log('=== Form structure received ===');
      _log('Title: ${formStructure['title']}');
      _log('Has fields: ${formStructure['fields'] != null}');
      if (formStructure['fields'] != null) {
        _log('Fields count: ${(formStructure['fields'] as List).length}');
      }
      
      // Validate that we have fields
      if (formStructure['fields'] == null || (formStructure['fields'] as List).isEmpty) {
        _log('WARNING: No fields extracted! Using fallback structure.', LogType.warning);
        // Use a more comprehensive fallback based on URL type
        if (url.contains('unstop.com') || url.contains('competitions')) {
          formStructure['fields'] = _getUnstopFallbackFields();
        } else if (url.contains('docs.google.com/forms')) {
          formStructure['fields'] = _getGoogleFormsFallbackFields();
        } else {
          formStructure['fields'] = _getDefaultFallbackFields();
        }
        _log('Using fallback with ${(formStructure['fields'] as List).length} fields', LogType.warning);
      }
      
      // Create form model
      final formId = _uuid.v4();
      final formData = <String, dynamic>{};
      
      // Store field metadata and initialize form data
      final fieldMetadata = <String, dynamic>{};
      if (formStructure['fields'] != null) {
        final fields = formStructure['fields'] as List<dynamic>;
        _log('Processing ${fields.length} fields...');
        for (int index = 0; index < fields.length; index++) {
          final field = fields[index];
          if (field is! Map<String, dynamic>) {
            _log('WARNING: Field at index $index is not a Map, skipping', LogType.warning);
            continue;
          }
          final fieldMap = field as Map<String, dynamic>;
          final fieldName = fieldMap['name'] as String?;
          if (fieldName == null || fieldName.isEmpty) {
            _log('WARNING: Field at index $index has no name, skipping', LogType.warning);
            continue;
          }
          final fieldType = fieldMap['type'] as String? ?? 'text';
          
          // Store field metadata with order index to preserve original order
          fieldMetadata[fieldName] = {
            'type': fieldType,
            'required': fieldMap['required'] ?? false,
            'options': fieldMap['options'],
            'page': fieldMap['page'] ?? 1,
            'description': fieldMap['description'],
            'order': fieldMap['order'] ?? index, // Preserve original order
          };
          
          // Set default empty values based on field type
          switch (fieldType) {
            case 'radio':
            case 'dropdown':
            case 'select':
              formData[fieldName] = null; // No selection initially
              break;
            case 'checkbox':
              formData[fieldName] = <String>[]; // Empty list for checkboxes
              break;
            case 'number':
              formData[fieldName] = null;
              break;
            case 'date':
              formData[fieldName] = null;
              break;
            case 'file':
              formData[fieldName] = null; // No file selected initially
              break;
            case 'textarea':
              formData[fieldName] = '';
              break;
            case 'static':
              // Static content doesn't need form data, but we'll add a placeholder
              // so it's included in formData for rendering purposes
              formData[fieldName] = null;
              break;
            default:
              formData[fieldName] = '';
          }
        }
      }
      
      // Debug: Print what was extracted
      _log('=== URL Form Service Debug ===');
      _log('Form title: ${formStructure['title']}');
      _log('Total fields extracted: ${fieldMetadata.length}');
      _log('Fields in formData: ${formData.length}');
      _log('Field names: ${fieldMetadata.keys.join(", ")}');
      // Log detailed field information
      for (var entry in fieldMetadata.entries) {
        final fieldName = entry.key;
        final metadata = entry.value as Map<String, dynamic>;
        final fieldType = metadata['type'] ?? 'unknown';
        final isRequired = metadata['required'] ?? false;
        final hasOptions = metadata['options'] != null;
        final optionsCount = hasOptions ? (metadata['options'] as List).length : 0;
        _log('  Field: "$fieldName" - type: $fieldType, required: $isRequired${hasOptions ? ", options: $optionsCount" : ""}');
      }
      _log('=== End URL Form Service Debug ===');
      
      // Store field metadata in form description or as a separate field
      // We'll encode it in the description for now
      String? description = formStructure['description'] as String?;
      
      // Clean up description (remove metadata separator if it exists, we'll add it back)
      if (description != null && description.contains('__METADATA__:')) {
        description = description.substring(0, description.indexOf('__METADATA__:')).trim();
      }
      
      // If no description from form structure, try to extract from HTML
      if ((description == null || description.isEmpty) && htmlContent != null) {
        final htmlDesc = _extractDescriptionFromHtml(htmlContent);
        if (htmlDesc != null && htmlDesc.isNotEmpty) {
          description = htmlDesc;
          _log('Extracted description from HTML in analyzeUrlAndCreateForm');
        }
      }
      
      if (fieldMetadata.isNotEmpty) {
        final metadataJson = jsonEncode(fieldMetadata);
        description = description != null && description.isNotEmpty
            ? '$description\n__METADATA__:$metadataJson'
            : '__METADATA__:$metadataJson';
      }

      // Auto-fill form data with profile information
      final profileAutofillService = ProfileAutofillService();
      final autofilledFormData = await profileAutofillService.autofillFormData(
        formData,
        fieldMetadata,
      );

      // Use the actual form name as the title
      String formTitle = formStructure['title'] as String? ?? 'Web Form';
      // Clean up generic titles
      if (formTitle == 'Untitled Form' || formTitle.toLowerCase() == 'untitled form' || formTitle.isEmpty) {
        formTitle = 'Web Form';
      }

      final form = FormModel(
        id: formId,
        title: formTitle,
        description: description ?? formStructure['description'] as String?,
        formData: autofilledFormData,
        status: 'in_progress',
        progress: 0.0,
        createdAt: DateTime.now(),
        formType: 'url',
      );

      // Save to database
      await _dbService.insertForm(form);

      return form;
    } catch (e, stackTrace) {
      // Re-throw authentication required exception so UI can handle it
      if (e is GoogleFormAuthenticationRequiredException) {
        _log('Re-throwing authentication required exception to UI', LogType.warning);
        rethrow;
      }
      
      _log('Error analyzing URL form: $e', LogType.error);
      _log('Stack trace: $stackTrace', LogType.error);
      
      // Even if extraction fails, return a form with fallback fields
      // BUT: Don't create fallback for authentication errors - let UI handle account selection
      // This ensures the user always gets something they can use (except for auth errors)
      try {
        _log('Attempting to create form with fallback fields...', LogType.warning);
        final formId = _uuid.v4();
        final fallbackFields = url.contains('unstop.com') || url.contains('competitions')
            ? _getUnstopFallbackFields()
            : url.contains('docs.google.com/forms')
                ? _getGoogleFormsFallbackFields()
                : _getDefaultFallbackFields();
        
        final formData = <String, dynamic>{};
        final fieldMetadata = <String, dynamic>{};
        
        for (int index = 0; index < fallbackFields.length; index++) {
          final field = fallbackFields[index];
          final fieldName = field['name'] as String;
          final fieldType = field['type'] as String;
          
          fieldMetadata[fieldName] = {
            'type': fieldType,
            'required': field['required'] ?? false,
            'options': field['options'],
            'page': field['page'] ?? 1,
            'order': field['order'] ?? index,
          };
          
          switch (fieldType) {
            case 'radio':
            case 'dropdown':
            case 'select':
              formData[fieldName] = null;
              break;
            case 'checkbox':
              formData[fieldName] = <String>[];
              break;
            case 'textarea':
              formData[fieldName] = '';
              break;
            default:
              formData[fieldName] = '';
          }
        }
        
        // Auto-fill form data with profile information
        final profileAutofillService = ProfileAutofillService();
        final autofilledFormData = await profileAutofillService.autofillFormData(
          formData,
          fieldMetadata,
        );
        
        final metadataJson = jsonEncode(fieldMetadata);
        final description = 'Form loaded from URL (fallback fields used)\n__METADATA__:$metadataJson';
        
        final formTitle = url.contains('unstop.com') 
            ? 'Web Form • Competition Registration'
            : url.contains('docs.google.com/forms')
                ? 'Web Form • Google Form'
                : 'Web Form';
        
        final fallbackForm = FormModel(
          id: formId,
          title: formTitle,
          description: description,
          formData: autofilledFormData,
          status: 'in_progress',
          progress: 0.0,
          createdAt: DateTime.now(),
          formType: 'url',
        );
        
        await _dbService.insertForm(fallbackForm);
        _log('Created fallback form with ${fallbackFields.length} fields', LogType.warning);
        return fallbackForm;
      } catch (fallbackError) {
        // If fallback creation also fails and it's an auth exception, re-throw it
        if (fallbackError is GoogleFormAuthenticationRequiredException) {
          rethrow;
        }
        _log('Even fallback creation failed: $fallbackError', LogType.error);
        rethrow;
      }
    }
  }

  bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  String _normalizeGoogleFormsUrl(String url) {
    // Google Forms URLs can be in different formats
    // Extract the form ID and create a standard public view URL
    final uri = Uri.parse(url);
    
    // Handle forms.gle short URLs - these need to be resolved first
    if (url.contains('forms.gle/') || url.contains('goo.gl/forms/')) {
      // For short URLs, we'll try to extract the form ID from the redirect
      // But for now, return as-is and let the HTTP request handle the redirect
      _log('Detected Google Forms short URL, will follow redirect');
      return url;
    }
    
    // Remove query parameters that might interfere
    final cleanUrl = uri.replace(queryParameters: {}).toString();
    
    if (uri.path.contains('/forms/d/e/')) {
      // Format: /forms/d/e/FORM_ID/viewform
      // Ensure it ends with /viewform (public view)
      if (!cleanUrl.endsWith('/viewform')) {
        return cleanUrl.endsWith('/') ? '${cleanUrl}viewform' : '$cleanUrl/viewform';
      }
      return cleanUrl;
    } else if (uri.path.contains('/forms/d/')) {
      // Format: /forms/d/FORM_ID/edit or /forms/d/FORM_ID/viewform
      // Convert edit URLs to viewform (public view)
      if (cleanUrl.contains('/edit')) {
        return cleanUrl.replaceAll('/edit', '/viewform');
      } else if (!cleanUrl.endsWith('/viewform')) {
        return cleanUrl.endsWith('/') ? '${cleanUrl}viewform' : '$cleanUrl/viewform';
      }
      return cleanUrl;
    }
    
    // If it's a Google Forms URL but doesn't match patterns, try to construct it
    if (url.contains('docs.google.com/forms')) {
      // Try to extract form ID from URL
      final formIdMatch = RegExp(r'/forms/d/e/([^/]+)').firstMatch(url);
      if (formIdMatch != null) {
        final formId = formIdMatch.group(1);
        return 'https://docs.google.com/forms/d/e/$formId/viewform';
      }
    }
    
    return url;
  }

  Future<Map<String, dynamic>> _analyzeFormFromUrl(String url, {String? googleAccessToken, String? htmlContent}) async {
    String? extractedTitle;
    
    try {
      // Use Gemini API to analyze the form
      final geminiApiKey = AppConfig.geminiApiKey;
      if (geminiApiKey.isEmpty) {
        _log('WARNING: Gemini API key is not configured!', LogType.warning);
        _log('Form extraction will be limited. Please configure GEMINI_API_KEY in app_config.dart', LogType.warning);
      }
      // Use gemini-1.5-flash for faster responses
      // Try different API versions and model names if one fails
      String geminiUrl;
      try {
        // Try v1beta with gemini-1.5-flash-latest (this seems to work better)
        geminiUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=$geminiApiKey';
      } catch (e) {
        // Fallback: Try with gemini-pro
        geminiUrl = 'https://generativelanguage.googleapis.com/v1/models/gemini-pro:generateContent?key=$geminiApiKey';
      }

      // Try to extract title from URL first (for Google Forms)
      // Note: Google Forms URLs don't typically contain the form name, but we can try
      if (url.contains('docs.google.com/forms')) {
        final uri = Uri.parse(url);
        // Google Forms URLs are typically: https://docs.google.com/forms/d/FORM_ID/viewform
        // The form name is not in the URL, but we can note this is a Google Form
        _log('Detected Google Forms URL: $url');
      }

      // Fetch the form HTML with proper headers
      // For Google Forms, try to access the public view directly
      http.Response? response;
      
      // Declare variables outside try block so they're accessible for retry logic
      String fetchUrl = url;
      String? tokenToUse = googleAccessToken; // Use provided token or try to get one
      final authService = AuthService();
      Map<String, String> headers = <String, String>{};
      
      try {
        // Enhanced headers for better compatibility - simulate a real browser
        
        // For short URLs (forms.gle, goo.gl, tinyurl), follow redirects to get the actual form URL
        if (url.contains('forms.gle/') || url.contains('goo.gl/forms/') || url.contains('tinyurl.com/')) {
          _log('Following redirect for short URL: $url');
          // Make a HEAD request first to get the redirect location
          try {
            final redirectResponse = await http.head(
              Uri.parse(url),
              headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
              },
            ).timeout(const Duration(seconds: 10));
            
            // Check if we got a redirect
            if (redirectResponse.statusCode >= 300 && redirectResponse.statusCode < 400) {
              final location = redirectResponse.headers['location'];
              if (location != null) {
                fetchUrl = location;
                _log('Resolved short URL to: $fetchUrl');
                // Extract form ID and construct public view URL
                final formIdMatch = RegExp(r'/forms/d/e/([^/?#]+)').firstMatch(fetchUrl);
                if (formIdMatch != null) {
                  final formId = formIdMatch.group(1);
                  fetchUrl = 'https://docs.google.com/forms/d/e/$formId/viewform';
                  _log('Constructed public viewform URL: $fetchUrl');
                }
              }
            }
          } catch (e) {
            _log('Could not resolve short URL redirect: $e', LogType.warning);
          }
        }
        
        // For Google Forms, ensure we're using the public viewform URL
        if (fetchUrl.contains('docs.google.com/forms')) {
          // Make sure we're using /viewform (public) not /edit (requires auth)
          if (fetchUrl.contains('/edit')) {
            fetchUrl = fetchUrl.replaceAll('/edit', '/viewform');
            _log('Converted edit URL to public viewform URL: $fetchUrl');
          } else if (!fetchUrl.contains('/viewform') && !fetchUrl.contains('/forms.gle')) {
            // Try to construct viewform URL if we have a form ID
            final formIdMatch = RegExp(r'/forms/d/e/([^/?#]+)').firstMatch(fetchUrl);
            if (formIdMatch != null) {
              final formId = formIdMatch.group(1);
              fetchUrl = 'https://docs.google.com/forms/d/e/$formId/viewform';
              _log('Constructed public viewform URL: $fetchUrl');
            }
          }
        }
        
        // Get Google authentication token if not provided and user is signed in with Google
        if (tokenToUse == null) {
          try {
            final userData = await authService.getCurrentUser();
            if (userData != null && userData['provider'] == 'google') {
              // Check if we have a stored access token
              if (userData['accessToken'] != null && userData['accessToken'].toString().isNotEmpty) {
                tokenToUse = userData['accessToken'].toString();
                _log('Found Google access token for authenticated request', LogType.info);
              } else {
                // Try to get fresh token from GoogleSignIn
                final googleUser = authService.currentGoogleUser;
                if (googleUser != null) {
                  try {
                    final auth = await googleUser.authentication;
                    tokenToUse = auth.accessToken;
                    if (tokenToUse != null) {
                      _log('Retrieved fresh Google access token', LogType.info);
                    }
                  } catch (e) {
                    _log('Could not retrieve Google access token: $e', LogType.warning);
                  }
                }
              }
            }
          } catch (e) {
            _log('Error getting Google authentication: $e', LogType.warning);
          }
        } else {
          _log('Using provided Google access token for form access', LogType.info);
        }
        
        headers = <String, String>{
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9',
          'Accept-Encoding': 'gzip, deflate, br',
          'Connection': 'keep-alive',
          'Upgrade-Insecure-Requests': '1',
          'Sec-Fetch-Dest': 'document',
          'Sec-Fetch-Mode': 'navigate',
          'Sec-Fetch-Site': 'none',
          'Cache-Control': 'max-age=0',
          'Referer': 'https://www.google.com/', // Add referer to look more like a browser
        };
        
        // Add Google authentication if available and URL is a Google service
        if (tokenToUse != null && 
            (fetchUrl.contains('docs.google.com') || 
             fetchUrl.contains('forms.gle') || 
             fetchUrl.contains('goo.gl/forms'))) {
          headers['Authorization'] = 'Bearer $tokenToUse';
          _log('Added Google authentication header for form access', LogType.info);
        }
        
        if (htmlContent == null) {
          response = await http.get(
            Uri.parse(fetchUrl),
            headers: headers,
          ).timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Request timeout: The URL took too long to respond');
            },
          );
          
          _log('Response status: ${response.statusCode}');
          _log('Response body length: ${response.body.length}');
        } else {
          _log('Skipping HTTP fetch - using provided HTML content');
        }
      } catch (e) {
        print('Error fetching URL: $e');
        // For sites that require cookies (like Unstop), try using Gemini with URL only
        if (url.contains('unstop.com') || url.contains('competitions')) {
          print('Detected Unstop/competition URL - attempting Gemini extraction...');
          try {
            final geminiApiKey = AppConfig.geminiApiKey;
            // Use gemini-1.5-flash for v1 API
            final geminiUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=$geminiApiKey';
            final geminiResult = await _tryExtractWithGeminiUrlOnly(url, geminiUrl, geminiApiKey);
            if (geminiResult != null && geminiResult['fields'] != null && (geminiResult['fields'] as List).isNotEmpty) {
              print('Successfully extracted form using Gemini for protected URL');
              return geminiResult;
            }
          } catch (geminiError) {
            print('Gemini extraction also failed: $geminiError');
          }
        }
        // Try alternative method or return default
        return _getDefaultFormStructure(url);
      }
      
      if (response != null && response.statusCode != 200) {
        print('Failed to fetch form from URL (Status: ${response.statusCode})');
        
        // For sites that require cookies (like Unstop), try Gemini extraction immediately
        if (url.contains('unstop.com') || url.contains('competitions')) {
          print('Detected Unstop/competition URL with non-200 status - attempting Gemini extraction...');
          try {
            final geminiApiKey = AppConfig.geminiApiKey;
            // Use gemini-1.5-flash for v1 API
            final geminiUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=$geminiApiKey';
            final geminiResult = await _tryExtractWithGeminiUrlOnly(url, geminiUrl, geminiApiKey);
            if (geminiResult != null && geminiResult['fields'] != null && (geminiResult['fields'] as List).isNotEmpty) {
              print('Successfully extracted form using Gemini for protected URL');
              return geminiResult;
            }
          } catch (geminiError) {
            print('Gemini extraction failed: $geminiError');
          }
        }
        
        // Try to extract title even from error page
        if (response.body.isNotEmpty) {
          final errorPageTitle = _extractTitleFromHtml(response.body);
          print('Extracted title from error page: "$errorPageTitle"');
          if (errorPageTitle != null && errorPageTitle != 'Web Form' && errorPageTitle.isNotEmpty) {
            extractedTitle = errorPageTitle;
          }
        }
        
        // For 401/403 errors (authentication required), try to use Gemini API with just the URL
        if (response.statusCode == 401 || response.statusCode == 403) {
          print('Attempting to extract form info using Gemini API with URL only...');
          try {
            final geminiApiKey = AppConfig.geminiApiKey;
            // Use gemini-1.5-flash for v1 API
            final geminiUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=$geminiApiKey';
            final geminiResult = await _tryExtractWithGeminiUrlOnly(url, geminiUrl, geminiApiKey);
            print('Gemini result: $geminiResult');
            if (geminiResult != null && geminiResult['title'] != null) {
              final geminiTitle = geminiResult['title'] as String;
              print('Gemini returned title: "$geminiTitle"');
              if (geminiTitle != 'Web Form' && geminiTitle.isNotEmpty && geminiTitle.trim().isNotEmpty) {
                extractedTitle = geminiTitle.trim();
                print('Successfully extracted title from Gemini: "$extractedTitle"');
                // If we got fields too, return the full structure
                if (geminiResult['fields'] != null && (geminiResult['fields'] as List).isNotEmpty) {
                  print('Returning full Gemini result with ${(geminiResult['fields'] as List).length} fields');
                  return geminiResult;
                }
              } else {
                print('Gemini title is generic or empty: "$geminiTitle"');
              }
            } else {
              print('Gemini result is null or missing title field');
            }
          } catch (e, stackTrace) {
            print('Error trying Gemini extraction with URL only: $e');
            print('Stack trace: $stackTrace');
          }
        }
        
        // Return default structure but with extracted title if available
        final defaultStructure = _getDefaultFormStructure(url);
        if (extractedTitle != null && extractedTitle != 'Web Form' && extractedTitle.isNotEmpty) {
          defaultStructure['title'] = extractedTitle;
          print('Using extracted title in default structure: "$extractedTitle"');
        } else {
          // If we still don't have a title, try to create a descriptive one from the URL
          if (url.contains('docs.google.com/forms')) {
            // Try to extract form ID and create a descriptive title
            final uri = Uri.parse(url);
            final pathSegments = uri.pathSegments;
            if (pathSegments.isNotEmpty) {
              // Google Forms URL structure: /forms/d/e/FORM_ID/viewform
              // We can't get the actual title, but we can make it more descriptive
              defaultStructure['title'] = 'Google Form';
              print('Using generic Google Form title');
            }
          }
        }
        return defaultStructure;
      }

      var htmlContentToUse = htmlContent ?? response!.body;
      _log('HTML content length: ${htmlContentToUse.length}');
      if (htmlContent != null) {
        _log('Using provided HTML content from WebView');
      } else {
        _log('Using HTML content from HTTP response');
      }
      
      // Check if we got a sign-in page or error page instead of the actual form
      bool isSignInPage = (
          htmlContentToUse.contains('Sign in') || 
          htmlContentToUse.contains('sign in') || 
          htmlContentToUse.contains('Sign-in') ||
          htmlContentToUse.contains('accounts.google.com') ||
          htmlContentToUse.contains('This form can only be viewed by users in the owner\'s organization') ||
          htmlContentToUse.contains('You need permission') ||
          htmlContentToUse.contains('Access denied')
      );
      
      // If HTML was provided via WebView, we shouldn't throw the Auth exception AGAIN
      // as it would cause an infinite loop. We'll try to extract anyway.
      final shouldThrowAuthException = htmlContent == null && isSignInPage;
      
      if (isSignInPage) {
        _log('WARNING: Detected sign-in/restricted page instead of form content', LogType.warning);
        
        // If we haven't tried with authentication yet, try to get token from app auth
        if (tokenToUse == null || !headers.containsKey('Authorization')) {
          _log('Attempting to retry with Google authentication...', LogType.info);
          try {
            final userData = await authService.getCurrentUser();
            if (userData != null && userData['provider'] == 'google') {
              String? retryToken;
              if (userData['accessToken'] != null && userData['accessToken'].toString().isNotEmpty) {
                retryToken = userData['accessToken'].toString();
              } else {
                final googleUser = authService.currentGoogleUser;
                if (googleUser != null) {
                  final auth = await googleUser.authentication;
                  retryToken = auth.accessToken;
                }
              }
              
              if (retryToken != null && 
                  (fetchUrl.contains('docs.google.com') || 
                   fetchUrl.contains('forms.gle') || 
                   fetchUrl.contains('goo.gl/forms'))) {
                _log('Retrying request with Google authentication token', LogType.info);
                final retryHeaders = Map<String, String>.from(headers);
                retryHeaders['Authorization'] = 'Bearer $retryToken';
                
                final retryResponse = await http.get(
                  Uri.parse(fetchUrl),
                  headers: retryHeaders,
                ).timeout(const Duration(seconds: 30));
                
                if (retryResponse.statusCode == 200) {
                  final retryHtml = retryResponse.body;
                  // Check if we still got a sign-in page
                  final stillSignInPage = retryHtml.contains('Sign in') || 
                      retryHtml.contains('sign in') || 
                      retryHtml.contains('Sign-in') ||
                      retryHtml.contains('accounts.google.com');
                  
                  if (!stillSignInPage) {
                    _log('Successfully accessed form with authentication!', LogType.success);
                    response = retryResponse;
                    htmlContentToUse = retryHtml;
                    isSignInPage = false; // Reset flag since we got the form now
                  }
                }
              }
            }
          } catch (e) {
            _log('Error retrying with authentication: $e', LogType.warning);
          }
        }
        
        // If still a sign-in page and we're dealing with a Google Form, throw special exception
        // This will trigger the account selection dialog in the UI
        // Check both original URL and resolved URL for Google Forms patterns
        final isGoogleForm = fetchUrl.contains('docs.google.com') || 
            fetchUrl.contains('forms.gle') || 
            fetchUrl.contains('goo.gl/forms') ||
            url.contains('docs.google.com') ||
            url.contains('forms.gle') ||
            url.contains('goo.gl/forms') ||
            url.contains('tinyurl.com'); // tinyurl.com often redirects to Google Forms
        
        if (shouldThrowAuthException && isGoogleForm) {
          _log('Google Form requires authentication - account selection needed', LogType.warning);
          throw GoogleFormAuthenticationRequiredException('This Google Form requires authentication. Please select a Google account.');
        }
        
        // If still a sign-in page, try Gemini URL-only extraction
        if (isSignInPage) {
          _log('This form may require authentication. Trying Gemini URL-only extraction...', LogType.warning);
          try {
            final geminiApiKey = AppConfig.geminiApiKey;
            final geminiUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=$geminiApiKey';
            final geminiResult = await _tryExtractWithGeminiUrlOnly(url, geminiUrl, geminiApiKey)
                .timeout(const Duration(seconds: 45));
            if (geminiResult != null && geminiResult['fields'] != null && (geminiResult['fields'] as List).isNotEmpty) {
              _log('Successfully extracted form using Gemini URL-only extraction', LogType.success);
              return geminiResult;
            }
          } catch (e) {
            _log('Gemini URL-only extraction failed: $e', LogType.error);
          }
          _log('Will continue with HTML-based extraction...');
        }
      }
      
      // Extract page title from HTML first
      // Try multiple patterns to get the actual form name
      String pageTitle = _extractTitleFromHtml(htmlContentToUse);
      extractedTitle = pageTitle;
      _log('Extracted title from HTML: "$extractedTitle"');
      
      // Extract description from HTML (instructions text)
      String? htmlDescription = _extractDescriptionFromHtml(htmlContentToUse);
      if (htmlDescription != null && htmlDescription.isNotEmpty) {
        _log('Extracted description from HTML: "${htmlDescription.substring(0, htmlDescription.length > 100 ? 100 : htmlDescription.length)}..."');
      }
      
      // For Google Forms, try to extract form structure directly from internal data
      // Check both URL and HTML content for Google Forms indicators
      bool googleFormsParsed = false;
      final isGoogleFormUrl = url.contains('docs.google.com/forms') || 
                              url.contains('forms.gle') || 
                              url.contains('goo.gl/forms');
      final isGoogleFormHtml = htmlContentToUse.contains('FB_PUBLIC_LOAD_DATA') ||
                               htmlContentToUse.contains('freebirdFormviewerViewFormContentWrapper') ||
                               htmlContentToUse.contains('docs.google.com/forms');
      
      _log('Checking for Google Forms: URL check=${isGoogleFormUrl}, HTML check=${isGoogleFormHtml}');
      _log('URL: $url');
      _log('HTML contains FB_PUBLIC_LOAD_DATA: ${htmlContentToUse.contains('FB_PUBLIC_LOAD_DATA')}');
      _log('HTML contains freebirdFormviewerViewFormContentWrapper: ${htmlContentToUse.contains('freebirdFormviewerViewFormContentWrapper')}');
      
      if (isGoogleFormUrl || isGoogleFormHtml) {
        try {
          _log('=== Attempting to parse Google Forms data directly from HTML ===');
          final parsedForm = _parseGoogleFormsData(htmlContentToUse, extractedTitle);
          if (parsedForm != null && parsedForm['fields'] != null && (parsedForm['fields'] as List).isNotEmpty) {
            _log('✓ Successfully parsed Google Forms data directly', LogType.success);
            _log('✓ Extracted ${(parsedForm['fields'] as List).length} fields', LogType.success);
            _log('✓ Field names: ${(parsedForm['fields'] as List).map((f) => f['name']).join(", ")}', LogType.success);
            
            // Ensure title is a clean string, not an array or complex object
            final parsedTitle = parsedForm['title'];
            String cleanTitle = 'Web Form';
            
            // If parsedTitle is a string and valid, use it
            if (parsedTitle is String && 
                parsedTitle.isNotEmpty && 
                parsedTitle != 'Google Form' && 
                parsedTitle != 'Web Form' &&
                parsedTitle.length < 200 && // Ensure it's not a huge string (could be array serialized)
                !parsedTitle.startsWith('[') && // Ensure it's not a JSON array string
                !parsedTitle.contains('null,')) { // Ensure it's not a serialized array
              cleanTitle = parsedTitle.trim();
              _log('Using parsed title from Google Forms: $cleanTitle');
            } else if (extractedTitle != null && extractedTitle != 'Web Form' && extractedTitle.isNotEmpty) {
              cleanTitle = extractedTitle.trim();
              _log('Using extracted title from HTML: $cleanTitle');
            }
            
            parsedForm['title'] = cleanTitle;
            
            // Merge HTML-extracted description with parsed description
            String? finalDescription = parsedForm['description'] as String?;
            if (htmlDescription != null && htmlDescription.isNotEmpty) {
              if (finalDescription != null && finalDescription.isNotEmpty) {
                // Combine both descriptions
                finalDescription = '$htmlDescription\n\n$finalDescription';
              } else {
                finalDescription = htmlDescription;
              }
            }
            parsedForm['description'] = finalDescription;
            
            _log('Final clean title: $cleanTitle');
            googleFormsParsed = true;
            return parsedForm;
          } else {
            _log('✗ Google Forms parsing returned null or empty fields', LogType.warning);
            if (parsedForm != null) {
              _log('Parsed form keys: ${parsedForm.keys.toList()}');
              if (parsedForm['fields'] != null) {
                _log('Fields list length: ${(parsedForm['fields'] as List).length}');
              } else {
                _log('Fields list is null');
              }
            } else {
              _log('Parsed form is null - parsing function returned null');
            }
            _log('Will try Gemini extraction with HTML content...');
          }
        } catch (e, stackTrace) {
          _log('✗ Error parsing Google Forms data directly: $e', LogType.error);
          _log('Error type: ${e.runtimeType}', LogType.error);
          _log('Stack trace: $stackTrace', LogType.error);
          _log('Will try Gemini extraction with HTML content...');
        }
      }
      
      // If Google Forms direct parsing failed, continue with Gemini extraction using HTML
      _log('=== Proceeding to Gemini extraction ===');
      
      // For Unstop and other competition/registration forms, try enhanced extraction
      if (url.contains('unstop.com') || url.contains('competitions') || url.contains('register')) {
        print('Detected competition/registration form - using enhanced extraction...');
        // These forms often have dynamic content, so we'll rely more on Gemini
      }
      
      // For Google Forms, try to extract more content - look for form data in script tags
      String formDataHtml = htmlContentToUse;
      
      // Try to extract form structure from Google Forms specific patterns
      // Google Forms stores form data in script tags with FB_PUBLIC_LOAD_DATA
      // Try multiple patterns to find the data
      String? formDataJson;
      
      // Pattern 0: New GOOGLE_FORM_DATA tag (optimized extraction)
      var scriptDataMatch = RegExp(r'<!-- GOOGLE_FORM_DATA_START -->(.*?)<!-- GOOGLE_FORM_DATA_END -->', dotAll: true).firstMatch(htmlContentToUse);
      
      if (scriptDataMatch == null) {
        // Pattern 1: Standard FB_PUBLIC_LOAD_DATA
        scriptDataMatch = RegExp(r'FB_PUBLIC_LOAD_DATA_\s*=\s*(\[.*?\]);', dotAll: true).firstMatch(htmlContentToUse);
      }
      if (scriptDataMatch == null) {
        // Pattern 2: Without semicolon
        scriptDataMatch = RegExp(r'FB_PUBLIC_LOAD_DATA_\s*=\s*(\[.*?\])', dotAll: true).firstMatch(htmlContentToUse);
      }
      if (scriptDataMatch == null) {
        // Pattern 3: With var keyword
        scriptDataMatch = RegExp(r'var\s+FB_PUBLIC_LOAD_DATA_\s*=\s*(\[.*?\]);', dotAll: true).firstMatch(htmlContentToUse);
      }
      if (scriptDataMatch == null) {
        // Pattern 4: In script tag content
        final scriptTags = RegExp(r'<script[^>]*>(.*?)</script>', dotAll: true).allMatches(htmlContentToUse);
        for (var match in scriptTags) {
          final scriptContent = match.group(1) ?? '';
          if (scriptContent.contains('FB_PUBLIC_LOAD_DATA')) {
            final dataMatch = RegExp(r'FB_PUBLIC_LOAD_DATA[^=]*=\s*(\[.*?\])', dotAll: true).firstMatch(scriptContent);
            if (dataMatch != null) {
              scriptDataMatch = dataMatch;
              break;
            }
          }
        }
      }
      
      if (scriptDataMatch != null) {
        // Found Google Forms data structure
        try {
          formDataJson = scriptDataMatch.group(1);
          if (formDataJson != null && formDataJson.length < 200000) {
            print('Found FB_PUBLIC_LOAD_DATA with length: ${formDataJson.length}');
            // Use the structured data for better extraction
            formDataHtml = 'Google Forms Data: $formDataJson\n\nHTML Content: ${htmlContentToUse.substring(0, htmlContentToUse.length > 20000 ? 20000 : htmlContentToUse.length)}';
          } else if (formDataJson != null) {
            print('FB_PUBLIC_LOAD_DATA extremely large (${formDataJson.length} chars), using first 100k');
            formDataHtml = 'Google Forms Data: ${formDataJson.substring(0, 100000)}\n\nHTML Content: ${htmlContentToUse.substring(0, 10000)}';
          }
        } catch (e) {
          print('Error parsing Google Forms data: $e');
        }
      } else {
        print('Could not find FB_PUBLIC_LOAD_DATA in HTML');
      }
      
      // Increase content limit for better extraction (up to 100,000 characters for Google Forms)
      // Reuse the isGoogleFormUrl and isGoogleFormHtml variables declared above
      final maxLength = (isGoogleFormUrl || isGoogleFormHtml) ? 100000 : 30000;
      final limitedHtml = formDataHtml.length > maxLength 
          ? formDataHtml.substring(0, maxLength) + '...'
          : formDataHtml;
      
      print('Sending ${limitedHtml.length} characters to Gemini for extraction...');
      print('First 500 chars: ${limitedHtml.substring(0, limitedHtml.length > 500 ? 500 : limitedHtml.length)}');
      
      // Use Gemini to extract form structure with comprehensive field types
      // Reuse the isGoogleFormUrl and isGoogleFormHtml variables declared above
      final formTypeContext = (isGoogleFormUrl || isGoogleFormHtml)
          ? 'Google Form' 
          : url.contains('unstop.com') || url.contains('competitions')
              ? 'competition/hackathon registration form'
              : 'web form';
      
      final prompt = '''
You are analyzing a $formTypeContext. Your task is to extract EVERY SINGLE field from this form.

CRITICAL: You MUST extract ALL fields. Count them carefully and ensure none are missing.

Return a JSON object with:
- title: The actual form name/title (extract the real form name, not just page title. If "$pageTitle" contains the form name, use it but clean it up. Otherwise extract from form content, headings, or form labels. Do NOT use generic titles like "Google Forms" or "Form". Extract the actual form name like "Contact Form", "Survey", "Application Form", etc.)
- description: Form description if available
- fields: Array of ALL form fields in the exact order they appear, with:
  - name: Field name/label (use EXACT label from form, preserve original text exactly)
  - type: Field type (text, email, number, date, textarea, radio, checkbox, dropdown, select, time, datetime, static)
  - required: Boolean indicating if field is required (look for asterisks or "required" indicators)
  - options: Array of ALL options for radio/checkbox/dropdown fields (preserve exact text, include ALL options)
  - page: Page number (detect actual page breaks/sections from the form, starting from page 1. If no page breaks, use page 1 for all)
  - order: Sequential order index starting from 0 (CRITICAL: this must match the exact order fields appear in the form)
  - description: Any additional description, help text, or instructions for the field

MANDATORY REQUIREMENTS:
1. Extract EVERY SINGLE field - count them and verify none are skipped
2. Preserve the EXACT order of fields as they appear in the form - assign an "order" field starting from 0 for the first field
3. Use exact field labels as they appear (case-sensitive, preserve special characters, spaces, punctuation)
4. Extract ALL options for multiple choice, checkbox, and dropdown fields - do not miss any option
5. Include static content sections (instructions, headings, descriptions, images with text) as fields with type "static" - these should also have an "order" field
6. Detect and preserve page breaks/sections - when a new section starts, increment the page number
7. For Google Forms, extract ALL question types including:
   - Short answer text
   - Paragraph/long answer
   - Multiple choice (with ALL options)
   - Checkboxes (with ALL options)
   - Dropdown (with ALL options)
   - Linear scale (with all scale points)
   - Multiple choice grid
   - Checkbox grid
   - Date
   - Time
   - File upload (mark as "text" type with description)
   - Section headers (as "static" type)

Field type mapping:
- Short answer text → "text"
- Paragraph/long answer → "textarea"
- Multiple choice → "radio" (include ALL options)
- Checkboxes → "checkbox" (include ALL options)
- Dropdown → "dropdown" (include ALL options)
- Linear scale → "radio" (with numeric options like ["1", "2", "3", "4", "5"])
- Date → "date"
- Time → "time"
- Number → "number"
- Email → "email"
- Section headers/instructions → "static"

${(isGoogleFormUrl || isGoogleFormHtml) ? 'IMPORTANT: This is a Google Form. The HTML may contain FB_PUBLIC_LOAD_DATA with structured form data. Extract ALL questions from the form, including their exact labels, types, required status, and all options for multiple choice/checkbox/dropdown fields.' : ''}

Content to analyze:
$limitedHtml

CRITICAL ORDERING RULES:
- The "order" field MUST be sequential: 0, 1, 2, 3... matching the exact order fields appear
- If there are section headers/page breaks, they should also have an "order" value
- Fields on the same page should have consecutive order values
- When a new page/section starts, continue the order sequence (don't reset to 0)

IMPORTANT: Before returning, verify you have extracted ALL fields. The fields array should contain every single question and content section from the form in the EXACT order they appear.

Return ONLY valid JSON, no markdown formatting, no explanations, no code blocks. Start directly with { and end with }.
''';

      _log('Calling Gemini API for form extraction...');
      _log('Gemini URL: $geminiUrl');
      _log('Prompt length: ${prompt.length}');
      
      http.Response geminiResponse;
      try {
        _log('Sending prompt to Gemini...');
        geminiResponse = await http.post(
          Uri.parse(geminiUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': prompt}
                ]
              }
            ],
          }),
        ).timeout(
          const Duration(seconds: 45), // Reduced timeout slightly to allow for fallback
          onTimeout: () {
            throw Exception('Gemini API request timeout');
          },
        );
      } catch (e) {
        _log('Gemini API failed or timed out: $e', LogType.warning);
        _log('Attempting fallback with NVIDIA NIM...', LogType.info);
        
        try {
          final nvidiaResult = await _tryExtractWithNvidia(prompt, url);
          if (nvidiaResult != null) {
            _log('✓ Successfully extracted form using NVIDIA NIM fallback', LogType.success);
            return nvidiaResult;
          }
        } catch (nvidiaError) {
          _log('ERROR: NVIDIA NIM fallback also failed: $nvidiaError', LogType.error);
        }
        
        _log('All AI methods failed, using default structure', LogType.warning);
        final defaultStructure = _getDefaultFormStructure(url);
        if (extractedTitle != null && extractedTitle != 'Web Form') {
          defaultStructure['title'] = extractedTitle;
        }
        return defaultStructure;
      }

      _log('Gemini API response status: ${geminiResponse.statusCode}');
      _log('Response body length: ${geminiResponse.body.length}');
      
      if (geminiResponse.statusCode == 200) {
        _log('Gemini API returned 200, parsing response...');
        Map<String, dynamic> responseData;
        try {
          responseData = jsonDecode(geminiResponse.body) as Map<String, dynamic>;
        } catch (e) {
          _log('ERROR: Failed to parse Gemini response as JSON: $e', LogType.error);
          _log('Response body (first 500 chars): ${geminiResponse.body.substring(0, geminiResponse.body.length > 500 ? 500 : geminiResponse.body.length)}', LogType.error);
          final defaultStructure = _getDefaultFormStructure(url);
          if (extractedTitle != null && extractedTitle != 'Web Form') {
            defaultStructure['title'] = extractedTitle;
          }
          return defaultStructure;
        }
        if (responseData['candidates'] != null && 
            responseData['candidates'].isNotEmpty &&
            responseData['candidates'][0]['content'] != null &&
            responseData['candidates'][0]['content']['parts'] != null &&
            responseData['candidates'][0]['content']['parts'].isNotEmpty) {
          
          final extractedText = responseData['candidates'][0]['content']['parts'][0]['text'] as String;
          
          // Try to parse JSON from the response
          try {
            // Remove markdown code blocks if present
            String jsonText = extractedText.trim();
            if (jsonText.startsWith('```json')) {
              jsonText = jsonText.substring(7);
            }
            if (jsonText.startsWith('```')) {
              jsonText = jsonText.substring(3);
            }
            if (jsonText.endsWith('```')) {
              jsonText = jsonText.substring(0, jsonText.length - 3);
            }
            jsonText = jsonText.trim();
            
            // Try to find JSON object in the text if it's not at the start
            final jsonStart = jsonText.indexOf('{');
            final jsonEnd = jsonText.lastIndexOf('}');
            if (jsonStart >= 0 && jsonEnd > jsonStart) {
              jsonText = jsonText.substring(jsonStart, jsonEnd + 1);
            }
            
            final formData = jsonDecode(jsonText) as Map<String, dynamic>;
            
            // Use extracted title if we found one and the AI title is generic
            final aiTitle = formData['title'] as String? ?? 'Web Form';
            _log('AI extracted title: "$aiTitle"');
            _log('HTML extracted title: "$extractedTitle"');
            
            // Prefer AI title if it's not generic, otherwise use HTML extracted title
            if (aiTitle != 'Web Form' && aiTitle != 'Google Form' && aiTitle.isNotEmpty && aiTitle.trim().isNotEmpty) {
              formData['title'] = aiTitle;
              _log('Using AI extracted title: "$aiTitle"');
            } else if (extractedTitle != null && extractedTitle != 'Web Form' && extractedTitle.isNotEmpty) {
              formData['title'] = extractedTitle;
              _log('Using HTML extracted title: "$extractedTitle"');
            } else {
              formData['title'] = 'Web Form';
              _log('Using default title: "Web Form"');
            }
            
            // Validate that we have fields
            if (formData['fields'] != null && (formData['fields'] as List).isNotEmpty) {
              _log('Successfully extracted ${(formData['fields'] as List).length} fields from Gemini', LogType.success);
              // Ensure all fields have order and page, and filter invalid ones
              final fields = formData['fields'] as List;
              final validFields = <Map<String, dynamic>>[];
              
              for (int i = 0; i < fields.length; i++) {
                if (fields[i] is Map<String, dynamic>) {
                  final field = fields[i] as Map<String, dynamic>;
                  
                  // Skip if no name
                  if (!field.containsKey('name') || field['name'] == null || (field['name'] as String).isEmpty) {
                    _log('WARNING: Field at index $i has no name, skipping', LogType.warning);
                    continue;
                  }
                  
                  // Ensure order and page
                  if (!field.containsKey('order')) {
                    field['order'] = i;
                  }
                  if (!field.containsKey('page')) {
                    field['page'] = 1;
                  }
                  
                  validFields.add(field);
                }
              }
              
              if (validFields.isNotEmpty) {
                formData['fields'] = validFields;
                _log('Returning ${validFields.length} valid fields from Gemini', LogType.success);
                // Use extracted title if we found one
                if (extractedTitle != null && extractedTitle != 'Web Form' && extractedTitle.isNotEmpty) {
                  final aiTitle = formData['title'] as String? ?? 'Web Form';
                  if (aiTitle == 'Web Form' || aiTitle.isEmpty) {
                    formData['title'] = extractedTitle;
                  }
                }
                return formData;
              } else {
                _log('WARNING: No valid fields after filtering from Gemini response', LogType.warning);
              }
            } else {
              _log('WARNING: Gemini returned form data but no fields found', LogType.warning);
              _log('Form data keys: ${formData.keys.toList()}');
            }
            
            // If we get here, Gemini extraction didn't work properly
            _log('Gemini extraction did not return valid fields', LogType.warning);
            // Don't return formData with empty fields - let it fall through to default
          } catch (e, stackTrace) {
            _log('ERROR: Error parsing Gemini response JSON: $e', LogType.error);
            _log('Stack trace: $stackTrace', LogType.error);
            if (extractedText != null) {
              _log('Extracted text (first 1000 chars): ${extractedText.substring(0, extractedText.length > 1000 ? 1000 : extractedText.length)}', LogType.error);
            } else {
              _log('Raw response (first 1000 chars): ${geminiResponse.body.substring(0, geminiResponse.body.length > 1000 ? 1000 : geminiResponse.body.length)}', LogType.error);
            }
            // Don't return default here - let it fall through to try again or use default at the end
          }
        } else {
          _log('ERROR: Gemini API response structure invalid', LogType.error);
          _log('Response body (first 1000 chars): ${geminiResponse.body.substring(0, geminiResponse.body.length > 1000 ? 1000 : geminiResponse.body.length)}', LogType.error);
          if (responseData.containsKey('error')) {
            _log('API Error details: ${responseData['error']}', LogType.error);
          }
        }
      } else {
        _log('ERROR: Gemini API returned non-200 status: ${geminiResponse.statusCode}', LogType.error);
        _log('Attempting fallback with NVIDIA NIM...', LogType.info);
        
        try {
          final nvidiaResult = await _tryExtractWithNvidia(prompt, url);
          if (nvidiaResult != null) {
            _log('✓ Successfully extracted form using NVIDIA NIM fallback', LogType.success);
            return nvidiaResult;
          }
        } catch (nvidiaError) {
          _log('ERROR: NVIDIA NIM fallback also failed: $nvidiaError', LogType.error);
        }
      }
      
      // If we get here, Gemini extraction failed - return default structure
      _log('All extraction methods failed, using default structure', LogType.warning);
      final defaultStructure = _getDefaultFormStructure(url);
      if (extractedTitle != null && extractedTitle != 'Web Form') {
        defaultStructure['title'] = extractedTitle;
      }
      return defaultStructure;
    } catch (e) {
      // Re-throw authentication required exception - don't convert to default structure
      if (e is GoogleFormAuthenticationRequiredException) {
        rethrow;
      }
      print('Error analyzing form: $e');
      final defaultStructure = _getDefaultFormStructure(url);
      if (extractedTitle != null && extractedTitle != 'Web Form') {
        defaultStructure['title'] = extractedTitle;
      }
      return defaultStructure;
    }
  }

  Future<Map<String, dynamic>?> _tryExtractWithNvidia(String prompt, String url) async {
    try {
      final apiKey = AppConfig.nvidiaApiKey;
      final baseUrl = AppConfig.nvidiaBaseUrl;
      final model = AppConfig.nvidiaModel;
      
      if (apiKey.isEmpty || apiKey.contains('YOUR_NVIDIA_API_KEY')) {
        _log('NVIDIA API key not configured, skipping fallback');
        return null;
      }
      
      _log('Calling NVIDIA NIM API (Model: $model)...');
      
      final response = await http.post(
        Uri.parse('$baseUrl/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': model,
          'messages': [
            {
              'role': 'system',
              'content': 'You are a form extraction assistant. Extract form fields and return ONLY valid JSON.'
            },
            {
              'role': 'user',
              'content': prompt
            }
          ],
          'temperature': 0.1,
          'max_tokens': 4096,
        }),
      ).timeout(const Duration(seconds: 40));
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final extractedText = responseData['choices'][0]['message']['content'] as String;
        
        // Use a more robust JSON extraction helper
        return _parseJsonResponse(extractedText);
      } else {
        _log('NVIDIA API returned error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      _log('Error in NVIDIA NIM extraction: $e');
      return null;
    }
  }

  Map<String, dynamic>? _parseJsonResponse(String text) {
    try {
      String jsonText = text.trim();
      
      // Remove markdown code blocks
      if (jsonText.contains('```')) {
        final match = RegExp(r'```(?:json)?\s*(.*?)\s*```', dotAll: true).firstMatch(jsonText);
        if (match != null) {
          jsonText = match.group(1) ?? jsonText;
        }
      }
      
      // Find the first { and last }
      final start = jsonText.indexOf('{');
      final end = jsonText.lastIndexOf('}');
      if (start >= 0 && end > start) {
        jsonText = jsonText.substring(start, end + 1);
      }
      
      final data = jsonDecode(jsonText) as Map<String, dynamic>;
      
      // Basic validation
      if (data.containsKey('fields') && data['fields'] is List) {
        return data;
      }
    } catch (e) {
      _log('Failed to parse JSON from AI response: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> _tryExtractWithGeminiUrlOnly(String url, String geminiUrl, String geminiApiKey) async {
    try {
      print('Calling Gemini API with URL: $url');
      
      // Detect form type from URL
      String formTypeHint = 'form';
      List<Map<String, dynamic>> commonFields = [];
      
      if (url.contains('unstop.com') || url.contains('competitions') || url.contains('register')) {
        formTypeHint = 'hackathon competition registration';
        commonFields = [
          {'name': 'Full Name', 'type': 'text', 'required': true, 'order': 0, 'page': 1},
          {'name': 'Email', 'type': 'email', 'required': true, 'order': 1, 'page': 1},
          {'name': 'Phone Number', 'type': 'text', 'required': true, 'order': 2, 'page': 1},
          {'name': 'College/University', 'type': 'text', 'required': true, 'order': 3, 'page': 1},
          {'name': 'Course/Stream', 'type': 'text', 'required': false, 'order': 4, 'page': 1},
          {'name': 'Year of Study', 'type': 'dropdown', 'required': false, 'options': ['1st Year', '2nd Year', '3rd Year', '4th Year', 'Graduate'], 'order': 5, 'page': 1},
          {'name': 'Team Name (if applicable)', 'type': 'text', 'required': false, 'order': 6, 'page': 2},
          {'name': 'Team Members', 'type': 'textarea', 'required': false, 'order': 7, 'page': 2},
          {'name': 'Why do you want to participate?', 'type': 'textarea', 'required': false, 'order': 8, 'page': 2},
        ];
      } else if (url.contains('docs.google.com/forms')) {
        formTypeHint = 'Google Form';
      } else if (url.contains('register') || url.contains('signup')) {
        formTypeHint = 'registration';
        commonFields = [
          {'name': 'Full Name', 'type': 'text', 'required': true, 'order': 0, 'page': 1},
          {'name': 'Email', 'type': 'email', 'required': true, 'order': 1, 'page': 1},
          {'name': 'Password', 'type': 'text', 'required': true, 'order': 2, 'page': 1},
        ];
      }
      
      final prompt = '''
You are analyzing a $formTypeHint form URL. Your task is to extract form information from this URL: $url

IMPORTANT CONTEXT:
${url.contains('unstop.com') ? '- This is an Unstop competition/hackathon registration form' : ''}
${url.contains('docs.google.com/forms') ? '- This is a Google Form' : ''}
${url.contains('register') || url.contains('signup') ? '- This appears to be a registration/signup form' : ''}

The form may require cookies or authentication to access, so I cannot fetch the HTML directly. However, based on the URL structure and common patterns for this type of form, please provide:

1. A descriptive form title based on:
   - URL structure and domain
   - Common form types for this domain
   - Any keywords in the URL (competition, register, hackathon, etc.)
   
2. Common fields that typically appear in this type of form

CRITICAL REQUIREMENTS:
- Do NOT return "Web Form" as the title - be descriptive
- For Unstop/competition forms, include typical hackathon registration fields
- For Google Forms, try to infer from URL structure
- Include an "order" field (0, 1, 2...) for each field
- Include a "page" field (starting from 1) for each field
- Organize fields logically across 1-3 pages

Return a JSON object with:
- title: A descriptive form name (e.g., "Hackathon Registration", "Competition Entry Form", etc.)
- description: Brief description based on URL context
- fields: Array of typical form fields with:
  - name: Field label
  - type: Field type (text, email, number, date, textarea, radio, checkbox, dropdown)
  - required: Boolean
  - options: Array of options (for radio/checkbox/dropdown)
  - page: Page number (1, 2, 3...)
  - order: Sequential order (0, 1, 2...)

${commonFields.isNotEmpty ? 'EXAMPLE FIELDS (use as reference but adapt based on URL): ${jsonEncode(commonFields)}' : ''}

Return ONLY valid JSON, no markdown formatting, no explanations, no code blocks. Start directly with { and end with }.
''';

      final geminiResponse = await http.post(
        Uri.parse(geminiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
        }),
      ).timeout(const Duration(seconds: 45));

      if (geminiResponse.statusCode == 200) {
        final responseData = jsonDecode(geminiResponse.body);
        if (responseData['candidates'] != null && 
            responseData['candidates'].isNotEmpty &&
            responseData['candidates'][0]['content'] != null &&
            responseData['candidates'][0]['content']['parts'] != null &&
            responseData['candidates'][0]['content']['parts'].isNotEmpty) {
          
          final extractedText = responseData['candidates'][0]['content']['parts'][0]['text'] as String;
          
          // Try to parse JSON from the response
          try {
            String jsonText = extractedText.trim();
            if (jsonText.startsWith('```json')) {
              jsonText = jsonText.substring(7);
            }
            if (jsonText.startsWith('```')) {
              jsonText = jsonText.substring(3);
            }
            if (jsonText.endsWith('```')) {
              jsonText = jsonText.substring(0, jsonText.length - 3);
            }
            jsonText = jsonText.trim();
            
            final jsonStart = jsonText.indexOf('{');
            final jsonEnd = jsonText.lastIndexOf('}');
            if (jsonStart >= 0 && jsonEnd > jsonStart) {
              jsonText = jsonText.substring(jsonStart, jsonEnd + 1);
            }
            
            final formData = jsonDecode(jsonText) as Map<String, dynamic>;
            print('Gemini API returned: ${formData.toString()}');
            final title = formData['title'] as String?;
            print('Extracted title from Gemini: "$title"');
            return formData;
          } catch (e) {
            print('Error parsing Gemini response for URL-only extraction: $e');
            print('Raw response text: ${extractedText.substring(0, extractedText.length > 500 ? 500 : extractedText.length)}');
          }
        } else {
          print('Gemini API response structure invalid or empty');
        }
      } else {
        print('Gemini API returned status code: ${geminiResponse.statusCode}');
        print('Response body: ${geminiResponse.body.substring(0, geminiResponse.body.length > 500 ? 500 : geminiResponse.body.length)}');
      }
    } catch (e) {
      print('Error in Gemini URL-only extraction: $e');
    }
    return null;
  }

  String? _extractDescriptionFromHtml(String htmlContent) {
    // Look for form description/instructions in HTML
    // Common patterns: text in specific divs, paragraphs, or data attributes
    
    // Pattern 1: Look for description in common HTML structures
    // Google Forms often has instructions in specific divs or spans
    final descriptionPatterns = [
      // Pattern for modern Google Forms description (F9U9id class)
      RegExp(r'<div[^>]*class="[^"]*F9U9id[^"]*"[^>]*>(.*?)</div>', dotAll: true, caseSensitive: false),
      // Look for description in specific Google Forms structure
      RegExp(r'<div[^>]*role="heading"[^>]*>.*?</div>\s*<div[^>]*>(.*?)</div>', dotAll: true, caseSensitive: false),
      // Look for text in divs with common description classes
      RegExp(r'<div[^>]*class="[^"]*(?:description|instructions|help-text|helpText)[^"]*"[^>]*>(.*?)</div>', dotAll: true, caseSensitive: false),
      // Original patterns
      RegExp(r'<div[^>]*class="[^"]*freebirdFormviewerViewItemsItemItemHelpText[^"]*"[^>]*>(.*?)</div>', dotAll: true, caseSensitive: false),
      RegExp(r'<p[^>]*class="[^"]*freebirdFormviewerViewItemsItemItemHelpText[^"]*"[^>]*>(.*?)</p>', dotAll: true, caseSensitive: false),
      RegExp(r'data-description="([^"]+)"', dotAll: true, caseSensitive: false),
      RegExp(r'<meta[^>]*name="description"[^>]*content="([^"]+)"', dotAll: true, caseSensitive: false),
    ];
    
    for (var pattern in descriptionPatterns) {
      final match = pattern.firstMatch(htmlContent);
      if (match != null && match.groupCount > 0) {
        final desc = match.group(1)?.trim();
        if (desc != null && desc.isNotEmpty && desc.length > 10 && desc.length < 1000) {
          // Clean up HTML tags
          final cleaned = desc.replaceAll(RegExp(r'<[^>]+>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
          if (cleaned.isNotEmpty) {
            print('Extracted description from HTML: "${cleaned.substring(0, cleaned.length > 100 ? 100 : cleaned.length)}..."');
            return cleaned;
          }
        }
      }
    }
    
    return null;
  }

  String _extractTitleFromHtml(String htmlContent) {
    String pageTitle = 'Web Form';
    
    // Pattern 1: Standard HTML title tag
    final titleMatch = RegExp(r'<title[^>]*>([^<]+)</title>', caseSensitive: false).firstMatch(htmlContent);
    if (titleMatch != null) {
      pageTitle = titleMatch.group(1)?.trim() ?? 'Web Form';
      // Clean up common suffixes like " - Google Forms"
      pageTitle = pageTitle.replaceAll(RegExp(r'\s*-\s*Google Forms.*$', caseSensitive: false), '');
      pageTitle = pageTitle.replaceAll(RegExp(r'\s*-\s*Google.*$', caseSensitive: false), '');
      pageTitle = pageTitle.replaceAll(RegExp(r'\s*-\s*Untitled.*$', caseSensitive: false), '');
      pageTitle = pageTitle.trim();
    }
    
    // Pattern 2: Look for h1 or form title in HTML
    if (pageTitle == 'Web Form' || pageTitle.isEmpty || pageTitle.toLowerCase() == 'untitled form') {
      final h1Match = RegExp(r'<h1[^>]*>([^<]+)</h1>', caseSensitive: false).firstMatch(htmlContent);
      if (h1Match != null) {
        final h1Text = h1Match.group(1)?.trim() ?? '';
        if (h1Text.isNotEmpty && h1Text.toLowerCase() != 'untitled form') {
          pageTitle = h1Text;
        }
      }
    }
    
    // Pattern 3: Look for form title in meta tags
    if (pageTitle == 'Web Form' || pageTitle.isEmpty || pageTitle.toLowerCase() == 'untitled form') {
      // Try with double quotes first
      var metaTitleMatch = RegExp(r'<meta[^>]*property="og:title"[^>]*content="([^"]+)"', caseSensitive: false).firstMatch(htmlContent);
      if (metaTitleMatch == null) {
        // Try with single quotes
        metaTitleMatch = RegExp(r"<meta[^>]*property='og:title'[^>]*content='([^']+)'", caseSensitive: false).firstMatch(htmlContent);
      }
      if (metaTitleMatch != null) {
        final metaTitle = metaTitleMatch.group(1)?.trim() ?? '';
        if (metaTitle.isNotEmpty && metaTitle.toLowerCase() != 'untitled form') {
          pageTitle = metaTitle;
        }
      }
    }
    
    // Pattern 4: Look for form title in data attributes or other patterns
    if (pageTitle == 'Web Form' || pageTitle.isEmpty || pageTitle.toLowerCase() == 'untitled form') {
      // Try to find form title in data-form-title or similar attributes
      // Try with double quotes first
      var dataTitleMatch = RegExp(r'data-form-title="([^"]+)"', caseSensitive: false).firstMatch(htmlContent);
      if (dataTitleMatch == null) {
        // Try with single quotes
        dataTitleMatch = RegExp(r"data-form-title='([^']+)'", caseSensitive: false).firstMatch(htmlContent);
      }
      if (dataTitleMatch != null) {
        final dataTitle = dataTitleMatch.group(1)?.trim() ?? '';
        if (dataTitle.isNotEmpty && dataTitle.toLowerCase() != 'untitled form') {
          pageTitle = dataTitle;
        }
      }
    }
    
    // Clean up the title
    if (pageTitle.isEmpty || pageTitle.toLowerCase() == 'untitled form' || pageTitle.toLowerCase() == 'google form') {
      pageTitle = 'Web Form';
    }
    
    return pageTitle;
  }

  // Parse Google Forms data directly from FB_PUBLIC_LOAD_DATA
  Map<String, dynamic>? _parseGoogleFormsData(String htmlContent, String? fallbackTitle) {
    try {
      print('Parsing Google Forms data from HTML (length: ${htmlContent.length})');
      
      // Try multiple patterns to find FB_PUBLIC_LOAD_DATA
      RegExpMatch? dataStartMatch;
      int startPos = -1;
      
      // Pattern 1: Standard with underscore
      dataStartMatch = RegExp(r'FB_PUBLIC_LOAD_DATA_\s*=\s*\[', dotAll: true).firstMatch(htmlContent);
      if (dataStartMatch != null) {
        startPos = dataStartMatch.end - 1;
        print('Found FB_PUBLIC_LOAD_DATA_ at position $startPos');
      }
      
      // Pattern 2: Without underscore
      if (dataStartMatch == null) {
        dataStartMatch = RegExp(r'FB_PUBLIC_LOAD_DATA\s*=\s*\[', dotAll: true).firstMatch(htmlContent);
        if (dataStartMatch != null) {
          startPos = dataStartMatch.end - 1;
          print('Found FB_PUBLIC_LOAD_DATA at position $startPos');
        }
      }
      
      // Pattern 3: With var keyword
      if (dataStartMatch == null) {
        dataStartMatch = RegExp(r'var\s+FB_PUBLIC_LOAD_DATA[_\s]*=\s*\[', dotAll: true).firstMatch(htmlContent);
        if (dataStartMatch != null) {
          startPos = dataStartMatch.end - 1;
          print('Found var FB_PUBLIC_LOAD_DATA at position $startPos');
        }
      }
      
      // Pattern 4: Search in script tags
      if (dataStartMatch == null) {
        final scriptTags = RegExp(r'<script[^>]*>(.*?)</script>', dotAll: true).allMatches(htmlContent);
        for (var match in scriptTags) {
          final scriptContent = match.group(1) ?? '';
          if (scriptContent.contains('FB_PUBLIC_LOAD_DATA')) {
            final scriptMatch = RegExp(r'FB_PUBLIC_LOAD_DATA[_\s]*=\s*\[', dotAll: true).firstMatch(scriptContent);
            if (scriptMatch != null) {
              // Calculate absolute position in HTML
              final scriptStart = match.start;
              startPos = scriptStart + match.group(0)!.length + scriptMatch.end - 1;
              print('Found FB_PUBLIC_LOAD_DATA in script tag at position $startPos');
              break;
            }
          }
        }
      }
      
      if (startPos == -1) {
        print('Could not find FB_PUBLIC_LOAD_DATA in HTML');
        return null;
      }
      
      // Extract from the start position to find matching closing bracket
      final formDataJson = _extractJsonArray(htmlContent, startPos);
      if (formDataJson == null) {
        print('Could not extract JSON array from position $startPos');
        return null;
      }
      
      print('Extracted JSON array (length: ${formDataJson.length})');
      return _parseFormDataFromJson(formDataJson, fallbackTitle);
    } catch (e, stackTrace) {
      print('Error parsing Google Forms data: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }
  
  // Extract JSON array by finding matching brackets
  String? _extractJsonArray(String html, int startPos) {
    try {
      int bracketCount = 0;
      int pos = startPos;
      int start = pos;
      
      while (pos < html.length) {
        if (html[pos] == '[') {
          bracketCount++;
        } else if (html[pos] == ']') {
          bracketCount--;
          if (bracketCount == 0) {
            // Found matching closing bracket
            return html.substring(start, pos + 1);
          }
        }
        pos++;
        
        // Safety limit to avoid infinite loops
        if (pos - start > 500000) {
          print('JSON extraction exceeded size limit');
          return null;
        }
      }
      
      return null;
    } catch (e) {
      print('Error extracting JSON array: $e');
      return null;
    }
  }
  
  // Parse form data from JSON string
  Map<String, dynamic>? _parseFormDataFromJson(String formDataJson, String? fallbackTitle) {
    try {
      
      // Parse the JSON array
      final formData = jsonDecode(formDataJson) as List<dynamic>;
      if (formData.isEmpty) return null;
      
      // Google Forms data structure: [null, [formInfo], [questions...], ...]
      // formInfo: [null, formTitle, description, ...]
      // questions: usually in formData[1][1] which is a list of question arrays
      String formTitle = fallbackTitle ?? 'Google Form';
      String? description;
      
      // Extract form title and description from formData[1]
      if (formData.length > 1 && formData[1] is List) {
        final formInfo = formData[1] as List;
        print('FormInfo length: ${formInfo.length}');
        
        // Strategy 1: Targeted Index Extraction (Highly Reliable for Google Forms)
        String? primaryTitle;
        List<String> instructionBlocks = [];
        
        // Comprehensive cleaner to handle HTML, entities, and preserve formatting
        String clean(dynamic input) {
          if (input == null || input is! String || input == 'null') return '';
          
          // 1. Decode common HTML entities first
          String decoded = (input as String)
            .replaceAll('&amp;', '&')
            .replaceAll('&quot;', '"')
            .replaceAll('&#39;', "'")
            .replaceAll('&lt;', '<')
            .replaceAll('&gt;', '>')
            .replaceAll('&nbsp;', ' ')
            .replaceAll('&#10;', '\n');
            
          // 2. Convert structural tags to newlines
          String structured = decoded
            .replaceAll(RegExp(r'<(br|p|div|li)[^>]*>', caseSensitive: false), '\n')
            .replaceAll(RegExp(r'</(p|div|li)>', caseSensitive: false), '\n');
            
          // 3. Remove remaining HTML tags
          String stripped = structured.replaceAll(RegExp(r'<[^>]*>'), '');
            
          // 4. Normalize lines but preserve the vertical structure
          List<String> lines = stripped.split('\n');
          List<String> processedLines = [];
          for (var line in lines) {
            final trimmed = line.trim();
            if (trimmed.isNotEmpty) {
              processedLines.add(trimmed);
            }
          }
          
          return processedLines.join('\n');
        }

        // Normalization for deduplication (strips everything for comparison)
        String normalize(String s) {
          return s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        }

        // Expanded system metadata and post-submission filter
        bool isSystemMetadata(String s) {
          final lower = s.toLowerCase();
          return lower == 'null' ||
                 lower.contains('submitted successfully') || 
                 lower.contains('response has been recorded') ||
                 lower.contains('further changes to be made') ||
                 lower.contains('thank you for your response') ||
                 lower.contains('switch accounts') ||
                 lower.contains('indicates required question') ||
                 lower.contains('click to edit') ||
                 lower.contains('submit another response') ||
                 lower.contains('edit your response') ||
                 lower.contains('see previous responses');
        }

        // Indices where titles usually live: 1, 8, 24
        for (int idx in [8, 1, 24, 0, 2]) {
          if (formInfo.length > idx && formInfo[idx] is String) {
            final cand = clean(formInfo[idx]);
            if (cand.length > 3 && !cand.toLowerCase().contains('google')) {
              if (primaryTitle == null) {
                primaryTitle = cand;
                print('Targeted Strategy: Identified Primary Title at index $idx: "$primaryTitle"');
              } else if (normalize(cand) != normalize(primaryTitle) && 
                         !instructionBlocks.any((b) => normalize(b) == normalize(cand))) {
                instructionBlocks.add(cand);
              }
            }
          }
        }

        // Strategy 2: Aggregated Scan for anything missed (up to index 60)
        for (int i = 0; i < formInfo.length && i < 60; i++) {
          final item = formInfo[i];
          if (item is String) {
            final cand = clean(item);
            if (cand.length > 5 && !cand.toLowerCase().contains('google') && !isSystemMetadata(cand)) {
              if (primaryTitle == null) {
                primaryTitle = cand;
              } else if (normalize(cand) != normalize(primaryTitle) && 
                         !instructionBlocks.any((b) => normalize(b) == normalize(cand))) {
                instructionBlocks.add(cand);
              }
            }
          } else if (item is List) {
            for (var sub in item) {
              if (sub is String) {
                final cand = clean(sub);
                if (cand.length > 5 && !isSystemMetadata(cand)) {
                  if (primaryTitle == null) primaryTitle = cand;
                  else if (normalize(cand) != normalize(primaryTitle) && 
                           !instructionBlocks.any((b) => normalize(b) == normalize(cand))) {
                    instructionBlocks.add(cand);
                  }
                }
              }
            }
          }
        }

        if (primaryTitle != null) {
          formTitle = primaryTitle;
          if (instructionBlocks.isNotEmpty) {
            description = instructionBlocks.join('\n\n');
          }
        }
      }
      
      // Final fallback for title: search recursively in the whole structure
      if (formTitle == 'Google Form' || formTitle == 'Web Form' || formTitle.isEmpty) {
        final foundTitle = _findTitleInDataStructure(formData);
        if (foundTitle != null) {
          formTitle = foundTitle;
          print('Found title recursively: "$formTitle"');
        }
      }
      
      print('Final extracted form title: "$formTitle"');
      
      final questions = <Map<String, dynamic>>[];
      int currentPage = 1;
      int fieldOrder = 0;

      // 1. Check for email collection settings in Google Forms
      bool collectEmail = false;
      if (formData.length > 1 && formData[1] is List) {
        final formInfo = formData[1] as List;
        
        // Strategy A: Check specific common indices in formInfo (10, 16, 21 are common)
        final settingIndices = [10, 16, 21, 24];
        for (int idx in settingIndices) {
          if (formInfo.length > idx) {
            final val = formInfo[idx];
            if (val == 1 || val == true) {
              collectEmail = true;
              print('Found email collection flag at formInfo[$idx]');
              break;
            } else if (val is List && val.isNotEmpty && (val[0] == 1 || val[0] == true)) {
              collectEmail = true;
              print('Found email collection flag in list at formInfo[$idx]');
              break;
            }
          }
        }
        
        // Strategy B: Deep search for email collection flag or string
        if (!collectEmail) {
          for (var item in formInfo) {
            if (item is List && item.length > 1 && (item[0] == 1 || item[0] == true)) {
              // This is a common pattern for various form settings
              // We'll be careful here, but if we haven't found email yet, it's a good candidate
              // if it's in a list at a high index
            }
          }
        }
      }

      if (collectEmail) {
        print('Form has email collection enabled, adding Email field');
        questions.add({
          'name': 'Email Address',
          'type': 'email',
          'required': true,
          'page': 1,
          'order': fieldOrder++,
          'description': 'Record email as the address to be included with your response',
        });
      }

      // 2. Add Form Instructions as a static field if description exists
      if (description != null && description.isNotEmpty) {
        print('Adding Form Instructions as a static field');
        questions.add({
          'name': 'Form Instructions',
          'type': 'static',
          'required': false,
          'page': 1,
          'order': fieldOrder++,
          'description': description,
        });
      }
      
      // Extract questions - Google Forms structure can vary
      
      print('Form data structure: length=${formData.length}');
      
      // Try multiple possible structures for questions array
      List<dynamic>? questionsArray;
      
      // Look everywhere for a list that contains question structures
      void findQuestionsInStructure(dynamic struct) {
        if (questionsArray != null) return;
        
        if (struct is List) {
          // Check if this list looks like a questions array
          // Google Form questions are lists of lists where sub-lists start with a small integer ID or have a specific structure
          int matches = 0;
          for (var item in struct) {
            if (item is List && item.length >= 3) {
              // Typically: [id, "Question Text", description, type, options...]
              if (item[0] is int || (item.length > 1 && item[1] is String && (item[1] as String).length > 2)) {
                matches++;
              }
            }
          }
          
          if (matches >= 1) {
            questionsArray = struct;
            return;
          }
          
          // Recurse
          for (var item in struct) {
            findQuestionsInStructure(item);
            if (questionsArray != null) return;
          }
        } else if (struct is Map) {
          for (var value in struct.values) {
            findQuestionsInStructure(value);
            if (questionsArray != null) return;
          }
        }
      }

      findQuestionsInStructure(formData);
      
      if (questionsArray != null) {
        print('Found questions array with ${questionsArray!.length} items using deep search');
      } else {
        // Fallback to traditional indices if deep search failed
        if (formData.length > 1 && formData[1] is List) {
          final fs = formData[1] as List;
          if (fs.length > 1 && fs[1] is List) {
            questionsArray = fs[1] as List;
            print('Found questions array in traditional index [1][1]');
          }
        }
      }
      
      // If we found questions, parse them
      final qa = questionsArray;
      if (qa != null && qa.isNotEmpty) {
        print('Processing ${qa.length} question items...');
        for (int i = 0; i < qa.length; i++) {
          final questionItem = qa[i];
          if (questionItem is List && questionItem.isNotEmpty) {
            // Check if this is a section header (page break)
            final isSection = _isGoogleFormsSection(questionItem);
            if (isSection) {
              final sectionTitle = _extractSectionTitle(questionItem);
              if (sectionTitle != null) {
                questions.add({
                  'name': sectionTitle,
                  'type': 'static',
                  'required': false,
                  'page': currentPage,
                  'order': fieldOrder++,
                  'description': sectionTitle,
                });
              }
              currentPage++;
            } else {
              // Regular question
              final question = _parseGoogleFormsQuestion(questionItem, fieldOrder);
              if (question != null && question['name'] != null) {
                question['page'] = currentPage;
                question['order'] = fieldOrder++;
                questions.add(question);
                final optionsInfo = question['options'] != null 
                    ? ' (options: ${(question['options'] as List).join(", ")})' 
                    : '';
                print('  Added question ${fieldOrder - 1}: ${question['name']} - type: ${question['type']}, required: ${question['required']}$optionsInfo');
              }
            }
          }
        }
      } else {
        print('WARNING: Could not find questions array in form data structure');
        // Try recursive search as last resort
        print('Attempting recursive search...');
        _findQuestionsRecursive(formData, questions, currentPage, fieldOrder);
      }
      
      // 4. Last Resort: If no email field was found but it seems to be in the form, add it
      bool hasEmailField = questions.any((q) => 
        q['name']?.toString().toLowerCase().contains('email') == true || 
        q['type'] == 'email');
      
      if (!hasEmailField) {
        // Search deeper for any string "Email" in the WHOLE structure
        bool foundEmailMention = false;
        void searchForEmail(dynamic item) {
          if (foundEmailMention) return;
          if (item is String) {
            final s = item.toLowerCase();
            if (s == 'email' || s == 'email address' || s == 'record email' || s.contains('email to be included')) {
              foundEmailMention = true;
            }
          } else if (item is List) {
            for (var element in item) searchForEmail(element);
          } else if (item is Map) {
            for (var value in item.values) searchForEmail(value);
          }
        }
        searchForEmail(formData);
        
        if (foundEmailMention) {
          print('Found "Email" mention in data structure, adding Email field as last resort');
          questions.add({
            'name': 'Email Address',
            'type': 'email',
            'required': true,
            'page': 1,
            'order': -5, // Put it at the very top (before instructions)
            'description': 'Please enter your email address as required by the form',
          });
        }
      }
      
      // Sort questions by order to preserve original sequence
      questions.sort((a, b) {
        final orderA = (a['order'] as int?) ?? 0;
        final orderB = (b['order'] as int?) ?? 0;
        return orderA.compareTo(orderB);
      });
      
      if (questions.isEmpty) {
        print('ERROR: No questions extracted from Google Forms data!');
        print('Form data had ${formData.length} top-level elements');
        if (formData.length > 1 && formData[1] is List) {
          print('formData[1] had ${(formData[1] as List).length} elements');
        }
        return null;
      }
      
      print('SUCCESS: Extracted ${questions.length} questions from Google Forms');
      for (int i = 0; i < questions.length && i < 5; i++) {
        print('  Question $i: ${questions[i]['name']} (type: ${questions[i]['type']})');
      }
      
      return {
        'title': formTitle,
        'description': description,
        'fields': questions,
      };
    } catch (e) {
      print('Error parsing form data from JSON: $e');
      return null;
    }
  }
  
  // Helper function to find title in data structure
  String? _findTitleInDataStructure(dynamic data) {
    if (data is String) {
      // Check if this string looks like a form title
      final trimmed = data.trim();
      if (trimmed.isNotEmpty && 
          trimmed.length > 3 && 
          trimmed.length < 200 &&
          trimmed.toLowerCase() != 'untitled form' &&
          !trimmed.toLowerCase().contains('google') &&
          !trimmed.toLowerCase().startsWith('http') &&
          !trimmed.startsWith('[') && // Not an array
          !trimmed.contains('null,') && // Not a serialized array
          !trimmed.contains(', null')) { // Not a serialized array
        return trimmed;
      }
    } else if (data is List) {
      // Skip Lists - they're likely question arrays, not titles
      // Only search in Lists if they're very short (potential metadata)
      if (data.length < 5) {
        for (var item in data) {
          // Only recurse if item is not a List itself (avoid deep array structures)
          if (item is! List) {
            final found = _findTitleInDataStructure(item);
            if (found != null) return found;
          }
        }
      }
    } else if (data is Map) {
      for (var value in data.values) {
        final found = _findTitleInDataStructure(value);
        if (found != null) return found;
      }
    }
    return null;
  }

  // Recursive function to find questions in nested structure
  void _findQuestionsRecursive(dynamic data, List<Map<String, dynamic>> questions, int startPage, int startOrder) {
    int currentPage = startPage;
    int fieldOrder = startOrder;
    
    void search(dynamic item) {
      if (item is List) {
        for (var element in item) {
          if (element is List && element.isNotEmpty) {
            final isSection = _isGoogleFormsSection(element);
            if (isSection) {
              final sectionTitle = _extractSectionTitle(element);
              if (sectionTitle != null && !questions.any((q) => q['name'] == sectionTitle && q['type'] == 'static')) {
                questions.add({
                  'name': sectionTitle,
                  'type': 'static',
                  'required': false,
                  'page': currentPage,
                  'order': fieldOrder++,
                  'description': sectionTitle,
                });
                currentPage++;
              }
            } else {
              final question = _parseGoogleFormsQuestion(element, fieldOrder);
              if (question != null && !questions.any((q) => q['name'] == question['name'] && q['order'] == question['order'])) {
                question['page'] = currentPage;
                question['order'] = fieldOrder++;
                questions.add(question);
              } else {
                search(element);
              }
            }
          } else {
            search(element);
          }
        }
      }
    }
    
    search(data);
  }
  
  // Check if a question item is a section header/page break
  bool _isGoogleFormsSection(List<dynamic> questionData) {
    try {
      // Section headers in Google Forms typically have specific structure
      // They might have type indicators or specific patterns
      for (var item in questionData) {
        if (item is String && (item.toLowerCase().contains('section') || 
            item.toLowerCase().contains('page break') ||
            item.toLowerCase().contains('new section'))) {
          return true;
        }
        // Check for section type indicators (usually type 7 or 8)
        if (item is num && (item == 7 || item == 8)) {
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }
  
  // Extract section title from section header
  String? _extractSectionTitle(List<dynamic> questionData) {
    try {
      // Section title is usually the first meaningful string
      for (var item in questionData) {
        if (item is String && item.trim().isNotEmpty && item.length > 2) {
          final trimmed = item.trim();
          if (!trimmed.toLowerCase().contains('section') && 
              !trimmed.toLowerCase().contains('page break') &&
              trimmed.length < 200) {
            return trimmed;
          }
        }
      }
      return 'Section';
    } catch (e) {
      return 'Section';
    }
  }
  
  // Helper to extract options from various structures
  List<String>? _extractOptions(dynamic optionsData) {
    if (optionsData == null) return null;
    
    final options = <String>[];
    if (optionsData is List) {
      for (var opt in optionsData) {
        if (opt is List && opt.isNotEmpty) {
          // Option structure: [optionId, optionText, ...]
          // Try index 1 first (most common), then index 0
          String? optText;
          if (opt.length > 1 && opt[1] is String) {
            optText = opt[1] as String;
          } else if (opt.length > 0 && opt[0] is String) {
            optText = opt[0] as String;
          } else if (opt.length > 0) {
            optText = opt[0]?.toString();
          }
          if (optText != null && optText.trim().isNotEmpty) {
            options.add(optText.trim());
          }
        } else if (opt is String && opt.trim().isNotEmpty) {
          options.add(opt.trim());
        } else if (opt != null) {
          final optStr = opt.toString().trim();
          if (optStr.isNotEmpty && optStr != 'null') {
            options.add(optStr);
          }
        }
      }
    }
    return options.isNotEmpty ? options : null;
  }
  
  // Parse a single Google Forms question
  Map<String, dynamic>? _parseGoogleFormsQuestion(List<dynamic> questionData, [int order = 0]) {
    try {
      if (questionData.isEmpty) return null;
      
      print('  Parsing question item with ${questionData.length} elements');
      print('  Question data structure: ${questionData.toString().substring(0, questionData.toString().length > 500 ? 500 : questionData.toString().length)}');
      
      // Google Forms question structure: [questionId, questionText, null, type, [options structure], ...]
      // Common structure: [id, text, null, 3, [[...options...]], ...]
      String? questionText;
      String? itemDescription;
      dynamic questionType;
      bool isRequired = false;
      List<String>? options;
      
      // Strategy 1: Look for question text at index 1 (most common structure)
      if (questionData.length > 1) {
        final item1 = questionData[1];
        if (item1 is String) {
          final trimmed = item1.trim();
          if (trimmed.isNotEmpty && trimmed != 'null' && trimmed.length >= 1 && trimmed.length <= 500) {
            questionText = trimmed;
            print('    Found question text at index 1: "$questionText"');
            
            // Extract item description/help text from index 2
            if (questionData.length > 2 && questionData[2] != null && questionData[2] is String) {
              final candidate = (questionData[2] as String).trim();
              if (candidate.isNotEmpty && candidate != 'null' && candidate.length > 2) {
                itemDescription = candidate;
                print('    Found field help text at index 2: "${itemDescription!.substring(0, itemDescription!.length > 50 ? 50 : itemDescription!.length)}..."');
              }
            }
            
            // Type is typically at index 3 (after questionText and null)
            if (questionData.length > 3) {
              questionType = questionData[3];
              print('    Found question type at index 3: $questionType');
            }
            
            // Options are typically at index 4 (after type)
            if (questionData.length > 4 && questionType != null) {
              final typeValue = questionType is num ? questionType.toInt() : null;
              // Only extract options for fields that should have them:
              // Type 2 = multiple choice (radio)
              // Type 3 = dropdown
              // Type 4 = checkbox
              if (typeValue == 2 || typeValue == 3 || typeValue == 4) {
                final optionsData = questionData[4];
                options = _extractOptionsFromGoogleForms(optionsData, questionText);
                if (options != null && options.isNotEmpty) {
                  // Filter out options that are the same as the field name (these are metadata, not real options)
                  options = options.where((opt) => opt != questionText && opt.trim().isNotEmpty).toList();
                  if (options.isNotEmpty) {
                    print('    Found ${options.length} options: ${options.join(", ")}');
                  } else {
                    options = null; // No valid options found
                  }
                }
              } else {
                // For other field types (text, textarea, date, file), skip options extraction
                // Index 4 contains metadata, not options
                print('    Skipping options extraction for type $typeValue (not a choice field)');
              }
            }
            
            // Check for required flag
            // Google Forms stores required flag in multiple locations
            // Common index for required flag is 4[0][6] or last element
            if (questionData.length > 4 && questionData[4] is List && (questionData[4] as List).isNotEmpty) {
              final optionsList = questionData[4] as List;
              if (optionsList[0] is List) {
                final firstOpt = optionsList[0] as List;
                // Check multiple indices that commonly contain required flag
                for (int idx in [2, 3, 4, 5, 6, 7, 8]) {
                  if (firstOpt.length > idx && (firstOpt[idx] == 1 || firstOpt[idx] == true)) {
                    isRequired = true;
                    break;
                  }
                }
              }
            }
            
            if (!isRequired && questionData.isNotEmpty) {
              final last = questionData.last;
              if (last == 1 || last == true) isRequired = true;
              else if (last is List && last.isNotEmpty) {
                if (last.contains(1) || last.contains(true)) isRequired = true;
              }
            }
          }
        }
      }
      
      // Strategy 2: If we didn't find text at index 1, search for it
      if (questionText == null) {
        for (int i = 0; i < questionData.length; i++) {
          final item = questionData[i];
          if (item is String) {
            final trimmed = item.trim();
            if (trimmed.length >= 2 && 
                trimmed.length <= 500 && 
                !trimmed.startsWith('http') &&
                !trimmed.toLowerCase().contains('google') &&
                trimmed != 'null') {
              questionText = trimmed;
              print('    Found question text at index $i: "$questionText" (Strategy 2)');
              
              // Try to find type after this string
              if (i + 2 < questionData.length) {
                questionType = questionData[i + 2];
              } else if (i + 1 < questionData.length && questionData[i + 1] is num) {
                questionType = questionData[i + 1];
              }
              break;
            }
          }
        }
      }
      
      // Strategy 3: Search for type number in the array
      if (questionType == null) {
        for (int i = 0; i < questionData.length; i++) {
          final item = questionData[i];
          if (item is num && (item == 0 || item == 1 || item == 2 || item == 3 || item == 4 || item == 5 || item == 9 || item == 13)) {
            questionType = item;
            print('    Found question type at index $i: $questionType');
            
            // Question text might be before the type
            if (i > 1 && questionData[i - 1] is String) {
              final candidate = (questionData[i - 1] as String).trim();
              if (candidate.isNotEmpty && candidate != 'null' && candidate.length >= 1) {
                questionText = candidate;
                print('    Found question text before type: "$questionText"');
              }
            } else if (i > 0 && questionData[i - 1] is String) {
              final candidate = (questionData[i - 1] as String).trim();
              if (candidate.isNotEmpty && candidate != 'null' && candidate.length >= 1) {
                questionText = candidate;
                print('    Found question text before type: "$questionText"');
              }
            }
            
            // Options might be after the type
            if (i + 1 < questionData.length && questionData[i + 1] is List) {
              options = _extractOptionsFromGoogleForms(questionData[i + 1], questionText);
              if (options != null && options.isNotEmpty) {
                // Filter out options that are the same as the field name
                options = options.where((opt) => opt != questionText && opt.trim().isNotEmpty).toList();
                if (options.isEmpty) {
                  options = null;
                }
              }
            }
            break;
          }
        }
      }
      
      if (questionText == null || questionText.isEmpty || questionText.length < 1) {
        print('    Could not find question text, skipping');
        return null;
      }
      
      // Extract options from anywhere in the structure if not already found
      // Only do this for fields that should have options (type 2, 3, 4)
      if (options == null) {
        final typeValue = questionType is num ? questionType.toInt() : null;
        // Only search for options if this is a field type that should have options
        if (typeValue == 2 || typeValue == 3 || typeValue == 4) {
          for (var item in questionData) {
            if (item is List) {
              options = _extractOptionsFromGoogleForms(item, questionText);
              if (options != null && options.isNotEmpty) {
                // Filter out options that are the same as the field name
                options = options.where((opt) => opt != questionText && opt.trim().isNotEmpty).toList();
                if (options.isNotEmpty) {
                  print('    Found options in nested structure: ${options.join(", ")}');
                  break;
                } else {
                  options = null;
                }
              }
            }
          }
        }
      }
      
      // Check for required flag - Google Forms stores it in multiple locations
      // 1. Check in the options structure (at specific indices)
      if (!isRequired && questionData.length > 4 && questionData[4] is List) {
        final optionsList = questionData[4] as List;
        if (optionsList.isNotEmpty) {
          // Check first option structure for required flag
          if (optionsList[0] is List) {
            final firstOption = optionsList[0] as List;
            // Required flag is often at index 2, 3, or 6 in the option structure
            for (int idx in [2, 3, 4, 5, 6]) {
              if (firstOption.length > idx && firstOption[idx] == 1) {
                isRequired = true;
                print('    Found required flag in options structure at index $idx');
                break;
              }
            }
          }
          // Also check if the entire options list structure indicates required
          // Sometimes required is indicated by a specific pattern
          if (!isRequired && optionsList.length > 0) {
            // Check if any option has a required indicator
            for (var opt in optionsList) {
              if (opt is List && opt.length > 2) {
                // Check indices that commonly contain required flag
                for (int idx in [2, 3, 4, 5, 6, 7]) {
                  if (opt.length > idx && opt[idx] == 1) {
                    isRequired = true;
                    print('    Found required flag in option at index $idx');
                    break;
                  }
                }
                if (isRequired) break;
              }
            }
          }
        }
      }
      
      // 2. Check the last element of the question array (common location)
      if (!isRequired && questionData.isNotEmpty) {
        final lastElement = questionData.last;
        if (lastElement is List && lastElement.isNotEmpty) {
          // Check if last element contains required indicator
          for (var item in lastElement) {
            if (item == 1 || item == true || item == 'required' || item == 'true') {
              isRequired = true;
              print('    Found required flag in last element');
              break;
            }
          }
        } else if (lastElement == 1 || lastElement == true || lastElement == 'required') {
          isRequired = true;
          print('    Found required flag as last element value');
        }
      }
      
      // 3. Check specific indices where required flag might be stored
      if (!isRequired) {
        // Check index 5, 6, 7, 8, 9, 10 (common locations for required flag)
        for (int idx in [5, 6, 7, 8, 9, 10]) {
          if (questionData.length > idx) {
            final item = questionData[idx];
            if (item == 1 || item == true || item == 'required') {
              isRequired = true;
              print('    Found required flag at index $idx');
              break;
            }
          }
        }
      }
      
      // 4. Final check: look for 1 or true anywhere in the structure (but be careful with option values)
      if (!isRequired) {
        for (var item in questionData) {
          if (item == 1 || item == true || item == 'true') {
            // But check if it's not part of options (options might have 1 as a value)
            if (options == null || !options.contains('1')) {
              isRequired = true;
              print('    Found required flag in question data');
              break;
            }
          }
        }
      }
      
      // Map Google Forms question types to our field types
      // Google Forms uses numeric codes:
      // 0 = short answer (text)
      // 1 = paragraph (textarea)
      // 2 = multiple choice (radio)
      // 3 = dropdown
      // 4 = checkbox
      // 5 = linear scale
      // 9 = date
      // 13 = file upload
      String fieldType = 'text';
      if (questionType != null) {
        final typeValue = questionType is num ? questionType.toInt() : 
                         (questionType is String && RegExp(r'^\d+$').hasMatch(questionType)) 
                            ? int.tryParse(questionType) : null;
        
        if (typeValue != null) {
          switch (typeValue) {
            case 0:
              fieldType = 'text';
              break;
            case 1:
              fieldType = 'textarea';
              break;
            case 2:
              fieldType = options != null && options.isNotEmpty ? 'radio' : 'text';
              break;
            case 3:
              fieldType = 'dropdown';
              break;
            case 4:
              fieldType = 'checkbox';
              break;
            case 5:
              fieldType = 'radio';
              // Generate numeric options for scale if not provided
              if (options == null || options.isEmpty) {
                options = List.generate(5, (i) => '${i + 1}');
              }
              break;
            case 6: // Title and Description item
              fieldType = 'static';
              break;
            case 7: // Section Header / Page Break
            case 8: // Page Break
              fieldType = 'static';
              break;
            case 9:
              fieldType = 'date';
              break;
            case 13:
              fieldType = 'file';
              break;
            default:
              fieldType = 'text';
          }
          print('    Mapped type $typeValue to field type: $fieldType');
        } else {
          // Fallback to string matching
          final typeStr = questionType.toString().toLowerCase();
          if (typeStr.contains('date')) {
            fieldType = 'date';
          } else if (typeStr.contains('file') || typeStr.contains('upload')) {
            fieldType = 'file';
          } else if (typeStr.contains('checkbox')) {
            fieldType = 'checkbox';
          } else if (typeStr.contains('dropdown') || typeStr.contains('list')) {
            fieldType = 'dropdown';
          } else if (typeStr.contains('choice') && !typeStr.contains('checkbox')) {
            fieldType = options != null && options.isNotEmpty ? 'radio' : 'text';
          } else if (typeStr.contains('paragraph') || typeStr.contains('long')) {
            fieldType = 'textarea';
          }
        }
      }
      
      final question = <String, dynamic>{
        'name': questionText,
        'type': fieldType,
        'required': isRequired,
        'order': order,
      };
      
      if (itemDescription != null) {
        question['description'] = itemDescription;
      }
      
      if (options != null && options.isNotEmpty) {
        question['options'] = options;
      }
      
      print('    Final parsed question: name="${question['name']}", type=${question['type']}, required=${question['required']}, options=${question['options']}');
      return question;
    } catch (e, stackTrace) {
      print('Error parsing Google Forms question: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }
  
  // Enhanced options extraction specifically for Google Forms nested structure
  List<String>? _extractOptionsFromGoogleForms(dynamic optionsData, String? fieldName) {
    if (optionsData == null) return null;
    
    final options = <String>[];
    
    try {
      if (optionsData is List && optionsData.isNotEmpty) {
        // Google Forms options structure can be:
        // Structure 1: [[optionId, [[optionText, ...], ...], ...], ...]
        // Structure 2: [[optionId, optionText, ...], ...]
        // Structure 3: [[[optionId, optionText, ...], ...], ...]
        
        for (var opt in optionsData) {
          if (opt is List && opt.isNotEmpty) {
            // Check if first element is a List (double nested)
            if (opt[0] is List) {
              // Structure: [[[optionText, ...], ...], ...]
              for (var nestedLevel1 in opt) {
                if (nestedLevel1 is List && nestedLevel1.isNotEmpty) {
                  // Check if this is another nested level
                  if (nestedLevel1[0] is List) {
                    // Triple nested: [[[optionText, ...], ...], ...]
                    for (var nestedLevel2 in nestedLevel1) {
                      if (nestedLevel2 is List && nestedLevel2.isNotEmpty) {
                        String? optText = _extractOptionText(nestedLevel2);
                        if (optText != null) {
                          options.add(optText);
                        }
                      }
                    }
                  } else {
                    // Double nested: [[optionText, ...], ...]
                    String? optText = _extractOptionText(nestedLevel1);
                    if (optText != null) {
                      options.add(optText);
                    }
                  }
                }
              }
            } else {
              // Single level: [optionId, optionText, ...] or [optionId, [optionText, ...], ...]
              // Check if index 1 is a List (contains nested options)
              if (opt.length > 1 && opt[1] is List) {
                // Structure: [optionId, [[optionText, ...], ...], ...]
                final nestedOptions = opt[1] as List;
                for (var nestedOpt in nestedOptions) {
                  if (nestedOpt is List && nestedOpt.isNotEmpty) {
                    String? optText = _extractOptionText(nestedOpt);
                    if (optText != null) {
                      options.add(optText);
                    }
                  }
                }
              } else {
                // Simple structure: [optionId, optionText, ...]
                String? optText = _extractOptionText(opt);
                if (optText != null) {
                  options.add(optText);
                }
              }
            }
          } else if (opt is String && opt.trim().isNotEmpty && opt != 'null') {
            options.add(opt.trim());
          }
        }
      }
    } catch (e, stackTrace) {
      print('Error extracting options: $e');
      print('Stack trace: $stackTrace');
      print('Options data: ${optionsData.toString().substring(0, optionsData.toString().length > 500 ? 500 : optionsData.toString().length)}');
    }
    
    // Filter out options that match the field name (these are metadata, not real options)
    final filteredOptions = <String>[];
    for (var opt in options) {
      if (fieldName != null && opt.trim().toLowerCase() == fieldName.trim().toLowerCase()) {
        // Skip option if it matches the field name
        continue;
      }
      filteredOptions.add(opt);
    }
    
    if (filteredOptions.isNotEmpty) {
      print('    Extracted ${filteredOptions.length} options: ${filteredOptions.join(", ")}');
      return filteredOptions;
    }
    return null;
  }
  
  // Helper to extract option text from a list
  String? _extractOptionText(List<dynamic> optionList) {
    if (optionList.isEmpty) return null;
    
    // Skip if this looks like metadata structure [null, fieldName] - this is not an option
    if (optionList.length == 2 && 
        optionList[0] == null && 
        optionList[1] is String) {
      // This is likely metadata [null, fieldName], not an option
      return null;
    }
    
    // Try index 0 first
    if (optionList[0] is String) {
      final text = (optionList[0] as String).trim();
      if (text.isNotEmpty && text != 'null' && text.length < 500 && !text.startsWith('http')) {
        return text;
      }
    }
    
    // Try index 1
    if (optionList.length > 1 && optionList[1] is String) {
      final text = (optionList[1] as String).trim();
      if (text.isNotEmpty && text != 'null' && text.length < 500 && !text.startsWith('http')) {
        return text;
      }
    }
    
    // Try any string
    for (int i = 0; i < optionList.length; i++) {
      final item = optionList[i];
      if (item is String) {
        final text = item.trim();
        if (text.isNotEmpty && text != 'null' && text.length < 500 && !text.startsWith('http') && !text.toLowerCase().contains('google')) {
          return text;
        }
      }
    }
    
    return null;
  }

  Map<String, dynamic> _getDefaultFormStructure(String url) {
    // Return a default form structure if analysis fails
    List<Map<String, dynamic>> fields;
    
    if (url.contains('unstop.com') || url.contains('competitions')) {
      fields = _getUnstopFallbackFields();
    } else if (url.contains('docs.google.com/forms')) {
      fields = _getGoogleFormsFallbackFields();
    } else {
      fields = _getDefaultFallbackFields();
    }
    
    return {
      'title': url.contains('unstop.com') ? 'Competition Registration' : 
               url.contains('docs.google.com/forms') ? 'Google Form' : 'Web Form',
      'description': 'Form loaded from URL',
      'fields': fields,
    };
  }
  
  List<Map<String, dynamic>> _getUnstopFallbackFields() {
    return [
      {'name': 'Full Name', 'type': 'text', 'required': true, 'page': 1, 'order': 0},
      {'name': 'Email', 'type': 'email', 'required': true, 'page': 1, 'order': 1},
      {'name': 'Phone Number', 'type': 'text', 'required': true, 'page': 1, 'order': 2},
      {'name': 'College/University', 'type': 'text', 'required': true, 'page': 1, 'order': 3},
      {'name': 'Course/Stream', 'type': 'text', 'required': false, 'page': 1, 'order': 4},
      {'name': 'Year of Study', 'type': 'dropdown', 'required': false, 'options': ['1st Year', '2nd Year', '3rd Year', '4th Year', 'Graduate'], 'page': 1, 'order': 5},
      {'name': 'Team Name (if applicable)', 'type': 'text', 'required': false, 'page': 2, 'order': 6},
      {'name': 'Team Members', 'type': 'textarea', 'required': false, 'page': 2, 'order': 7},
      {'name': 'Why do you want to participate?', 'type': 'textarea', 'required': false, 'page': 2, 'order': 8},
    ];
  }
  
  List<Map<String, dynamic>> _getGoogleFormsFallbackFields() {
    return [
      {'name': 'Name', 'type': 'text', 'required': true, 'page': 1, 'order': 0},
      {'name': 'Email', 'type': 'email', 'required': true, 'page': 1, 'order': 1},
      {'name': 'Response', 'type': 'textarea', 'required': false, 'page': 1, 'order': 2},
    ];
  }
  
  List<Map<String, dynamic>> _getDefaultFallbackFields() {
    return [
      {'name': 'Full Name', 'type': 'text', 'required': true, 'page': 1, 'order': 0},
      {'name': 'Email', 'type': 'email', 'required': true, 'page': 1, 'order': 1},
      {'name': 'Phone', 'type': 'text', 'required': false, 'page': 1, 'order': 2},
    ];
  }
}


