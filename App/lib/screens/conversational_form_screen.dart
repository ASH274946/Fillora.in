import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/ai_chat_service.dart';
import '../services/voice_service.dart';
import '../services/database_service.dart';
import '../services/profile_autofill_service.dart';
import '../models/form_model.dart';
import 'google_form_webview_screen.dart';
import '../services/app_logger_service.dart';
import '../services/azure_translation_service.dart'; // Added: Azure Translation Service
import '../services/language_service.dart'; // Added: Language Service for codes
import '../services/url_form_service.dart';
import '../widgets/app_snackbar.dart';


class ConversationalFormScreen extends StatefulWidget {
  final String? formId;
  final String? initialUrl;
  final String? initialHtml;
  
  const ConversationalFormScreen({
    super.key, 
    this.formId, 
    this.initialUrl, 
    this.initialHtml,
  });

  @override
  State<ConversationalFormScreen> createState() =>
      _ConversationalFormScreenState();
}

class _ConversationalFormScreenState extends State<ConversationalFormScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  final Map<String, TextEditingController> _fieldControllers = {};
  final Map<String, FocusNode> _fieldFocusNodes = {};
  final AiChatService _aiService = AiChatService();
  final VoiceService _voiceService = VoiceService();
  final DatabaseService _dbService = DatabaseService();
  final List<Map<String, dynamic>> _messages = [];
  bool _isListening = false;
  String? _formTitle;
  FormModel? _form;
  TextEditingController? _activeController;
  Map<String, dynamic> _fieldMetadata = {};
  Map<int, List<String>> _fieldsByPage = {};
  int _currentPage = 1;
  int _totalPages = 1;
  bool _isChatOpen = false; // Track if chat interface is open
  final ScrollController _chatScrollController = ScrollController(); // Controller for chat messages
  bool _isSubmitting = false; // Track if form is being submitted
  bool _isAnalyzing = false; // Track if form is being analyzed
  final ProfileAutofillService _autofillService = ProfileAutofillService();
  
  // Multi-Language Support
  final AzureTranslationService _translationService = AzureTranslationService();
  String _currentChatLanguage = 'en'; // Default to English
  String _currentFormLanguage = 'en'; // Language for the form UI
  final List<Map<String, dynamic>> _englishConversationHistory = []; // Hidden history in English for AI
  Map<String, String> _translatedFieldLabels = {}; // Stores translated labels: "Name" -> "పేరు"
  Map<String, String> _translatedHints = {}; // Stores translated hints: "Enter Name" -> "పేరు నమోదు చేయండి"
  bool _isTranslatingForm = false;


  @override
  void initState() {
    super.initState();
    AppLoggerService().logScreenEvent('ConversationalFormScreen', 'Initialized', 
      details: {'formId': widget.formId ?? 'new'});
    _voiceService.initialize();
    _loadForm();
    // Listen to message controller focus
    _messageFocusNode.addListener(() {
      if (_messageFocusNode.hasFocus) {
        setState(() {
          _activeController = _messageController;
        });
        AppLoggerService().logUserInteraction('Focus', details: 'Message input field');
      }
    });
  }


  Future<void> _loadForm() async {
    if (widget.formId != null) {
      try {
        AppLoggerService().logFormAction('Loading form', formId: widget.formId);
        print('Loading form with ID: ${widget.formId}');
        final form = await _dbService.getFormById(widget.formId!);
        if (form != null && mounted) {
          AppLoggerService().logFormAction('Form loaded', 
            formId: widget.formId, 
            formTitle: form.title,
            details: {'fields': form.formData?.keys.length ?? 0});
          print('Form loaded: ${form.title}');
          print('Form description length: ${form.description?.length ?? 0}');
          print('Form data keys: ${form.formData?.keys.toList() ?? []}');
          
          // Parse field metadata from description
          _parseFieldMetadata(form.description);
          
          // Auto-fill empty fields with profile data
          final profileAutofillService = ProfileAutofillService();
          final formDataToUse = form.formData ?? <String, dynamic>{};
          final autofilledFormData = await profileAutofillService.autofillFormData(
            formDataToUse,
            _fieldMetadata,
          );
          
          // Update form data in database if auto-fill added any values
          bool formDataUpdated = false;
          for (var entry in autofilledFormData.entries) {
            final key = entry.key;
            final newValue = entry.value;
            final oldValue = formDataToUse[key];
            
            // Check if value was filled by auto-fill (was empty/null, now has value)
            if ((oldValue == null || oldValue == '' || (oldValue is List && (oldValue as List).isEmpty)) &&
                newValue != null && newValue != '' && !(newValue is List && (newValue as List).isEmpty)) {
              formDataUpdated = true;
              break;
            }
          }
          
          // Save updated form data if auto-fill filled any fields
          if (formDataUpdated) {
            final updatedForm = FormModel(
              id: form.id,
              title: form.title,
              description: form.description,
              formData: autofilledFormData,
              status: form.status,
              progress: form.progress,
              createdAt: form.createdAt,
              updatedAt: DateTime.now(),
              submittedAt: form.submittedAt,
              formType: form.formType,
              tags: form.tags,
              templateId: form.templateId,
            );
            await _dbService.updateForm(updatedForm);
          }
          
          setState(() {
            _form = formDataUpdated 
                ? FormModel(
                    id: form.id,
                    title: form.title,
                    description: form.description,
                    formData: autofilledFormData,
                    status: form.status,
                    progress: form.progress,
                    createdAt: form.createdAt,
                    updatedAt: DateTime.now(),
                    submittedAt: form.submittedAt,
                    formType: form.formType,
                    tags: form.tags,
                    templateId: form.templateId,
                  )
                : form;
            _formTitle = form.title;
            
            // Initialize form field controllers with existing data (including auto-filled)
            final dataToUse = formDataUpdated ? autofilledFormData : (form.formData ?? {});
            if (dataToUse.isNotEmpty) {
              for (var entry in dataToUse.entries) {
                final fieldKey = entry.key;
                final fieldValue = entry.value;
                final fieldMeta = _fieldMetadata[fieldKey] as Map<String, dynamic>?;
                final fieldType = fieldMeta?['type'] as String? ?? 'text';
                
                if (fieldType == 'static') continue; // Skip static fields for controller initialization
                
                final controller = _getFieldController(fieldKey);
                if (fieldValue != null) {
                  if (fieldType == 'checkbox' && fieldValue is List) {
                    // Checkboxes are handled differently
                  } else {
                    controller.text = fieldValue.toString();
                  }
                }
              }
            }
            
            // Initialize with a welcome message
            if (_messages.isEmpty) {
              _messages.add({
                'text': 'Welcome! I\'ll help you fill out your ${form.title}. Let\'s get started!',
                'isAI': true,
              });
            }
          });
          
          // Organize fields by page AFTER form is set
          _organizeFieldsByPage();
          
          // Update state again to reflect page organization
          if (mounted) {
            setState(() {
              print('State updated after field organization');
              print('Current page fields count: ${_getCurrentPageFields().length}');
            });
          }
        } else {
          print('WARNING: Form not found with ID: ${widget.formId}');
          if (mounted) {
            AppSnackBar.show(context, 'Form not found. Redirecting...', isError: true);
            context.go('/dashboard');
          }
        }
      } catch (e) {
        print('Error loading form: $e');
        if (mounted) {
          AppSnackBar.show(context, 'Error loading form: $e', isError: true);
          context.go('/dashboard');
        }
      }
    } else if (widget.initialUrl != null || widget.initialHtml != null) {
      // Handle direct analysis from URL/HTML
      _analyzeFromUrl();
    } else {
      // Default welcome message if no form ID
      setState(() {
        _messages.add({
          'text': 'Welcome! I\'ll help you fill out this form. Let\'s get started!',
          'isAI': true,
        });
      });
    }
  }

  Future<void> _analyzeFromUrl() async {
    setState(() {
      _isAnalyzing = true;
      _formTitle = 'Analyzing Form...';
      _messages.add({
        'text': '🔍 Please wait while I analyze the form structure. This usually takes 10-30 seconds...',
        'isAI': true,
      });
    });

    try {
      final urlFormService = UrlFormService();
      final form = await urlFormService.analyzeUrlAndCreateForm(
        widget.initialUrl ?? '',
        htmlContent: widget.initialHtml,
      ).timeout(const Duration(seconds: 45));

      if (form != null && mounted) {
        setState(() {
          _form = form;
          _formTitle = form.title;
          _isAnalyzing = false;
          _parseFieldMetadata(form.description);
          _organizeFieldsByPage();
          
          // Add a follow-up message
          _messages.add({
            'text': '✅ Form analysis complete! I\'ve found ${(form.formData?.length ?? 0)} fields. Let\'s start filling them out.',
            'isAI': true,
          });
        });
      } else if (mounted) {
        setState(() => _isAnalyzing = false);
        AppSnackBar.show(context, 'Could not analyze form. Redirecting...', isError: true);
        context.go('/dashboard');
      }
    } catch (e) {
      print('Error during internal analysis: $e');
      
      final isAuthError = e is GoogleFormAuthenticationRequiredException || 
          e.toString().contains('requires authentication') || 
          e.toString().contains('Please select a Google account');

      if (isAuthError && mounted) {
        setState(() {
          _messages.add({
            'text': '🔑 This form requires authentication. Opening Google Sign-in...',
            'isAI': true,
          });
        });

        // Launch WebView to handle authentication
        final extractedHtml = await Navigator.of(context).push<String>(
          MaterialPageRoute(
            builder: (context) => GoogleFormWebViewScreen(formUrl: widget.initialUrl ?? ''),
            fullscreenDialog: true,
          ),
        );

        if (extractedHtml != null && extractedHtml.isNotEmpty && mounted) {
          setState(() {
            _isAnalyzing = true;
            _messages.add({
              'text': '✅ Authentication successful! Resuming analysis...',
              'isAI': true,
            });
          });
          // Re-trigger analysis with the extracted HTML
          _analyzeFromUrlWithHtml(extractedHtml);
        } else if (mounted) {
          setState(() => _isAnalyzing = false);
          AppSnackBar.show(context, 'Authentication cancelled or failed.', isError: true);
          context.go('/dashboard');
        }
      } else if (mounted) {
        setState(() => _isAnalyzing = false);
        AppSnackBar.show(context, 'Analysis failed: $e', isError: true);
        context.go('/dashboard');
      }
    }
  }

  Future<void> _analyzeFromUrlWithHtml(String html) async {
    try {
      final urlFormService = UrlFormService();
      final form = await urlFormService.analyzeUrlAndCreateForm(
        widget.initialUrl ?? '',
        htmlContent: html,
      ).timeout(const Duration(seconds: 45));

      if (form != null && mounted) {
        setState(() {
          _form = form;
          _formTitle = form.title;
          _isAnalyzing = false;
          _parseFieldMetadata(form.description);
          _organizeFieldsByPage();
          
          _messages.add({
            'text': 'Form analysis complete! I\'ve found ${(form.formData?.length ?? 0)} fields. Let\'s start filling them out.',
            'isAI': true,
          });
        });
      } else if (mounted) {
        setState(() => _isAnalyzing = false);
        AppSnackBar.show(context, 'Could not analyze form after sign-in.', isError: true);
        context.go('/dashboard');
      }
    } catch (e) {
      print('Error during post-auth analysis: $e');
      if (mounted) {
        setState(() => _isAnalyzing = false);
        AppSnackBar.show(context, 'Analysis failed after sign-in: $e', isError: true);
        context.go('/dashboard');
      }
    }
  }
  
  void _parseFieldMetadata(String? description) {
    _fieldMetadata = {};
    if (description == null) return;
    
    try {
      // Look for metadata in description
      if (description.contains('__METADATA__:')) {
        final parts = description.split('__METADATA__:');
        if (parts.length > 1) {
          final metadataJson = parts[1].trim();
          _fieldMetadata = jsonDecode(metadataJson) as Map<String, dynamic>;
          print('=== Metadata Parsed ===');
          print('Metadata keys: ${_fieldMetadata.keys.toList()}');
          for (var key in _fieldMetadata.keys) {
            final meta = _fieldMetadata[key] as Map<String, dynamic>?;
            print('  $key: required=${meta?['required']}, type=${meta?['type']}');
          }
          print('=== End Metadata Parse ===');
        }
      }
    } catch (e) {
      print('Error parsing field metadata: $e');
    }
  }
  
  void _organizeFieldsByPage() {
    _fieldsByPage = {};
    
    // Only use fields that are in the metadata (exclude leftover/default fields)
    // If metadata exists, use it as the source of truth
    final fieldList = <String>[];
    
    if (_fieldMetadata.isNotEmpty) {
      // Use metadata as source of truth - only include fields that are in metadata
      for (var fieldName in _fieldMetadata.keys) {
        final fieldMeta = _fieldMetadata[fieldName] as Map<String, dynamic>?;
        final fieldType = fieldMeta?['type'] as String? ?? 'text';
        // Include all fields in page organization, including static fields
        // this allows them to be rendered in the form flow as requested
        fieldList.add(fieldName);
      }
    } else if (_form?.formData != null) {
      // Fallback: if no metadata, use formData keys
      fieldList.addAll(_form!.formData!.keys);
    }
    
    // Debug: Print what we have
    print('=== Field Organization Debug ===');
    print('Total fields found: ${fieldList.length}');
    print('Fields from metadata: ${_fieldMetadata.keys.length}');
    print('Field names: ${fieldList.join(", ")}');
    
    // If no fields at all, return early
    if (fieldList.isEmpty) {
      print('WARNING: No fields found!');
      _totalPages = 1;
      return;
    }
    
    // Group fields by page number from metadata, preserving order
    final fieldsWithPages = <String, Map<String, dynamic>>{}; // Store both page and order
    final fieldsWithoutPages = <String>[];
    
    for (var fieldName in fieldList) {
      final fieldMeta = _fieldMetadata[fieldName] as Map<String, dynamic>?;
      if (fieldMeta != null && fieldMeta.containsKey('page')) {
        final page = (fieldMeta['page'] as num?)?.toInt() ?? 1;
        final order = (fieldMeta['order'] as num?)?.toInt() ?? 0;
        fieldsWithPages[fieldName] = {'page': page, 'order': order};
      } else {
        fieldsWithoutPages.add(fieldName);
      }
    }
    
    print('Fields with pages: ${fieldsWithPages.length}');
    print('Fields without pages: ${fieldsWithoutPages.length}');
    
    // Sort fields by order to preserve original sequence
    final sortedFields = fieldsWithPages.entries.toList()
      ..sort((a, b) {
        final orderA = a.value['order'] as int;
        final orderB = b.value['order'] as int;
        return orderA.compareTo(orderB);
      });
    
    // Organize fields with page numbers in order
    for (var entry in sortedFields) {
      final fieldName = entry.key;
      final page = entry.value['page'] as int;
      
      if (!_fieldsByPage.containsKey(page)) {
        _fieldsByPage[page] = [];
      }
      _fieldsByPage[page]!.add(fieldName);
    }
    
    // If no fields have page numbers in metadata, auto-organize into pages
    if (fieldsWithPages.isEmpty && fieldsWithoutPages.isNotEmpty) {
      // Auto-organize: 5-7 fields per page
      const fieldsPerPage = 6;
      int currentPage = 1;
      int fieldsInCurrentPage = 0;
      
      for (var fieldName in fieldsWithoutPages) {
        if (!_fieldsByPage.containsKey(currentPage)) {
          _fieldsByPage[currentPage] = [];
        }
        _fieldsByPage[currentPage]!.add(fieldName);
        fieldsInCurrentPage++;
        
        if (fieldsInCurrentPage >= fieldsPerPage) {
          currentPage++;
          fieldsInCurrentPage = 0;
        }
      }
    } else if (fieldsWithoutPages.isNotEmpty) {
      // Some fields have pages, some don't - add unassigned to page 1
      // But only if page 1 doesn't already exist or if it's empty
      if (!_fieldsByPage.containsKey(1)) {
        _fieldsByPage[1] = [];
      }
      for (var fieldName in fieldsWithoutPages) {
        // Only add if not already in page 1
        if (!_fieldsByPage[1]!.contains(fieldName)) {
          _fieldsByPage[1]!.add(fieldName);
        }
      }
    }
    
    // Calculate total pages
    if (_fieldsByPage.isNotEmpty) {
      _totalPages = _fieldsByPage.keys.reduce((a, b) => a > b ? a : b);
    } else {
      _totalPages = 1;
    }
    
    AppLoggerService().logScreenEvent('ConversationalFormScreen', 'Pages organized', 
      details: {'totalPages': _totalPages, 'fields': _fieldsByPage.values.expand((e) => e).length});
    
    // Ensure current page is valid
    if (_currentPage > _totalPages || _currentPage < 1) {
      _currentPage = 1;
    }
    
    // Debug: Print field organization
    print('Fields organized into $_totalPages pages:');
    for (var page in _fieldsByPage.keys.toList()..sort()) {
      print('  Page $page (${_fieldsByPage[page]!.length} fields): ${_fieldsByPage[page]!.join(", ")}');
    }
    print('Current page: $_currentPage');
    print('Current page fields: ${_getCurrentPageFields().join(", ")}');
    print('=== End Field Organization Debug ===');
  }
  
  List<String> _getCurrentPageFields() {
    return _fieldsByPage[_currentPage] ?? [];
  }
  
  Map<String, dynamic> _getCurrentFormData() {
    // Start with existing form data to preserve radio/checkbox/dropdown values
    final currentFormData = Map<String, dynamic>.from(_form?.formData ?? {});
    
    // Update form data with current field values from controllers (text fields)
    for (var entry in _fieldControllers.entries) {
      final fieldKey = entry.key;
      final fieldMeta = _fieldMetadata[fieldKey] as Map<String, dynamic>?;
      final fieldType = fieldMeta?['type'] as String? ?? 'text';
      
      // Update text-based fields from controllers
      if (fieldType == 'text' || fieldType == 'email' || fieldType == 'phone' || 
          fieldType == 'textarea' || fieldType == 'number' || fieldType == 'date') {
        final textValue = entry.value.text.trim();
        currentFormData[fieldKey] = textValue.isEmpty ? null : textValue;
      }
    }
    
    return currentFormData;
  }

  double _calculateProgress(Map<String, dynamic> formData) {
    // Get all fields that should be counted for progress (exclude static fields)
    final fieldsToCount = <String>[];
    
    // Get fields from formData
    if (formData.isNotEmpty) {
      for (var fieldName in formData.keys) {
        final fieldMeta = _fieldMetadata[fieldName] as Map<String, dynamic>?;
        final fieldType = fieldMeta?['type'] as String? ?? 'text';
        
        // Exclude static fields from progress calculation
        if (fieldType != 'static') {
          fieldsToCount.add(fieldName);
        }
      }
    }
    
    // If no fields to count, return 0
    if (fieldsToCount.isEmpty) {
      return 0.0;
    }
    
    // Count filled fields
    int filledCount = 0;
    for (var fieldName in fieldsToCount) {
      final fieldMeta = _fieldMetadata[fieldName] as Map<String, dynamic>?;
      final fieldType = fieldMeta?['type'] as String? ?? 'text';
      final fieldValue = formData[fieldName];
      
      bool isFilled = false;
      
      switch (fieldType) {
        case 'text':
        case 'email':
        case 'phone': // Added phone type
        case 'textarea':
          // Text-based fields: check if not null and not empty
          isFilled = fieldValue != null && 
                     fieldValue.toString().trim().isNotEmpty;
          break;
        case 'number':
        case 'date':
          // Number and date: check if not null
          isFilled = fieldValue != null;
          break;
        case 'radio':
        case 'dropdown':
        case 'select':
          // Single selection: check if not null
          isFilled = fieldValue != null;
          break;
        case 'checkbox':
          // Multiple selection: check if list is not empty
          if (fieldValue is List) {
            isFilled = fieldValue.isNotEmpty;
          } else {
            isFilled = false;
          }
          break;
        default:
          // For unknown types, consider filled if not null
          isFilled = fieldValue != null;
      }
      
      if (isFilled) {
        filledCount++;
      }
    }
    
    // Calculate progress as percentage
    return (filledCount / fieldsToCount.length) * 100.0;
  }
  
  Future<void> _saveFormData() async {
    if (_form == null || widget.formId == null) return;
    
    try {
      // Start with existing form data to preserve radio/checkbox/dropdown values
      final updatedFormData = Map<String, dynamic>.from(_form!.formData ?? {});
      
      // Update form data with current field values from controllers (text fields)
      for (var entry in _fieldControllers.entries) {
        final fieldKey = entry.key;
        final fieldMeta = _fieldMetadata[fieldKey] as Map<String, dynamic>?;
        final fieldType = fieldMeta?['type'] as String? ?? 'text';
        
        // Update text-based fields from controllers
        if (fieldType == 'text' || fieldType == 'email' || fieldType == 'phone' || 
            fieldType == 'textarea' || fieldType == 'number' || fieldType == 'date') {
          final textValue = entry.value.text.trim();
          updatedFormData[fieldKey] = textValue.isEmpty ? null : textValue;
        }
      }
      
      // Calculate progress based on filled fields
      final calculatedProgress = _calculateProgress(updatedFormData);
      
      // Update the form model with calculated progress
      // Preserve submittedAt if form was already submitted
      final updatedForm = FormModel(
        id: _form!.id,
        title: _form!.title,
        description: _form!.description,
        formData: updatedFormData,
        status: _form!.status,
        progress: calculatedProgress,
        createdAt: _form!.createdAt,
        updatedAt: DateTime.now(),
        submittedAt: _form!.submittedAt, // Preserve submittedAt if already set
        templateId: _form!.templateId,
        formType: _form!.formType,
      );
      
      // Save to database
      await _dbService.insertForm(updatedForm);
      
      if (mounted) {
        setState(() {
          _form = updatedForm;
        });
      }
    } catch (e) {
      print('Error saving form data: $e');
    }
  }
  
  Future<void> _changeFormLanguage(String newLang) async {
    if (newLang == 'en') {
      setState(() {
        _currentFormLanguage = 'en';
        _currentChatLanguage = 'en'; // Sync chat
        _translatedFieldLabels.clear(); // Clear cache
      });
      return;
    }

    setState(() {
      _isTranslatingForm = true;
    });

    try {
      // 1. Translate all Field Keys
      final Map<String, String> newLabels = {};
      final Map<String, String> newHints = {};
      
      // Get all unique field names
      final allFields = <String>{};
      if (_fieldMetadata.isNotEmpty) {
        allFields.addAll(_fieldMetadata.keys);
      } else if (_form?.formData != null) {
        allFields.addAll(_form!.formData!.keys);
      }
      
      // Batch translate (sequentially for now to avoid Azure rate limits if mocking)
      for (var key in allFields) {
        try {
          // Translate Label
          final labelTranslated = await _translationService.translate(
            text: _formatFieldLabel(key), // Translate the pretty label
            sourceLanguage: 'en',
            resultLanguage: newLang,
          );
          newLabels[key] = labelTranslated;

          // Translate Hint/Placeholder
          final hintText = 'Enter ${_formatFieldLabel(key)}'; 
          final hintTranslated = await _translationService.translate(
            text: hintText,
            sourceLanguage: 'en',
            resultLanguage: newLang,
          );
          newHints[key] = hintTranslated;
        } catch (e) {
          debugPrint('Failed to translate field $key: $e');
          // Fallback to English
          newLabels[key] = _formatFieldLabel(key);
          newHints[key] = 'Enter ${_formatFieldLabel(key)}';
        }
      }

      // Translate Options for Radio/Dropdown
      for (var key in allFields) {
        try {
          final fieldMeta = _fieldMetadata[key] as Map<String, dynamic>?;
          if (fieldMeta != null && fieldMeta.containsKey('options')) {
            final options = fieldMeta['options'] as List<dynamic>;
            for (var option in options) {
              final optText = option.toString();
              final optTranslated = await _translationService.translate(
                text: optText,
                sourceLanguage: 'en',
                resultLanguage: newLang,
              );
              newLabels['OPTION_$optText'] = optTranslated;
            }
          }
        } catch (e) {
           debugPrint('Failed to translate options for $key: $e');
        }
      }
      
      // Translate Common UI Elements with error handling
      try {
        newLabels['Submit'] = await _translationService.translate(text: 'Submit', resultLanguage: newLang);
        newLabels['Next'] = await _translationService.translate(text: 'Next', resultLanguage: newLang);
        newLabels['Clear'] = await _translationService.translate(text: 'Clear', resultLanguage: newLang);
      } catch (e) {
        debugPrint('Failed to translate UI elements: $e');
        newLabels['Submit'] = 'Submit';
        newLabels['Next'] = 'Next';
        newLabels['Clear'] = 'Clear';
      }

      setState(() {
        _translatedFieldLabels = newLabels;
        _translatedHints = newHints;
        _currentFormLanguage = newLang;
        _currentChatLanguage = newLang; // Sync chat with form
        _isTranslatingForm = false;
      });
      
      AppSnackBar.show(context, 'Form language changed to ${newLang.toUpperCase()}');
      
    } catch (e) {
      debugPrint('Form Translation Failed: $e');
      setState(() {
        _isTranslatingForm = false;
      });
      AppSnackBar.show(context, 'Failed to translate form. Please try again.', isError: true);
    }
  }

  /// Validate required fields on the current page only
  List<String> _validateCurrentPageRequiredFields() {
    final emptyRequiredFields = <String>[];
    final currentPageFields = _getCurrentPageFields();
    
    // Get all fields from metadata for current page only
    for (var fieldName in currentPageFields) {
      if (!_fieldMetadata.containsKey(fieldName)) continue;
      
      final fieldMeta = _fieldMetadata[fieldName] as Map<String, dynamic>?;
      final isRequired = fieldMeta?['required'] == true;
      final fieldType = fieldMeta?['type'] as String? ?? 'text';
      
      // Skip static fields
      if (fieldType == 'static') continue;
      
      if (isRequired) {
        // Check both formData and controller values
        var fieldValue = _form?.formData?[fieldName];
        
        // For text-based fields, check controller first (most up-to-date)
        if (fieldType == 'text' || fieldType == 'email' || fieldType == 'phone' || 
            fieldType == 'textarea' || fieldType == 'number' || fieldType == 'date') {
          if (_fieldControllers.containsKey(fieldName)) {
            final controller = _fieldControllers[fieldName]!;
            final controllerText = controller.text.trim();
            if (controllerText.isNotEmpty) {
              fieldValue = controllerText;
            } else {
              fieldValue = null;
            }
          }
        }
        
        bool isEmpty = false;
        
        switch (fieldType) {
          case 'text':
          case 'email':
          case 'phone':
          case 'textarea':
            if (fieldValue == null) {
              isEmpty = true;
            } else {
              final textValue = fieldValue.toString().trim();
              isEmpty = textValue.isEmpty;
            }
            break;
          case 'number':
          case 'date':
            isEmpty = fieldValue == null;
            break;
          case 'radio':
          case 'dropdown':
          case 'select':
            isEmpty = fieldValue == null;
            break;
          case 'checkbox':
            if (fieldValue is List) {
              isEmpty = fieldValue.isEmpty;
            } else {
              isEmpty = true;
            }
            break;
          default:
            isEmpty = fieldValue == null;
        }
        
        if (isEmpty) {
          emptyRequiredFields.add(fieldName);
        }
      }
    }
    
    return emptyRequiredFields;
  }

  List<String> _validateRequiredFields() {
    final emptyRequiredFields = <String>[];
    
    print('=== Validation Debug ===');
    print('Metadata keys: ${_fieldMetadata.keys.toList()}');
    print('FormData keys: ${_form?.formData?.keys.toList() ?? []}');
    
    // Get all fields from metadata
    for (var fieldName in _fieldMetadata.keys) {
      final fieldMeta = _fieldMetadata[fieldName] as Map<String, dynamic>?;
      final isRequired = fieldMeta?['required'] == true;
      final fieldType = fieldMeta?['type'] as String? ?? 'text';
      
      print('Field: $fieldName, Required: $isRequired, Type: $fieldType');
      
      // Skip static fields
      if (fieldType == 'static') continue;
      
      if (isRequired) {
        // Check both formData and controller values
        // Priority: controller value (most up-to-date) > formData value
        var fieldValue = _form?.formData?[fieldName];
        
        // For text-based fields, check controller first (most up-to-date)
        if (fieldType == 'text' || fieldType == 'email' || fieldType == 'phone' || 
            fieldType == 'textarea' || fieldType == 'number' || fieldType == 'date') {
          if (_fieldControllers.containsKey(fieldName)) {
            final controller = _fieldControllers[fieldName]!;
            final controllerText = controller.text.trim();
            if (controllerText.isNotEmpty) {
              fieldValue = controllerText;
            } else {
              // Controller is empty, so field is empty
              fieldValue = null;
            }
          }
        }
        
        bool isEmpty = false;
        
        switch (fieldType) {
          case 'text':
          case 'email':
          case 'phone': // Added phone type
          case 'textarea':
            // Text-based fields: check if null or empty
            if (fieldValue == null) {
              isEmpty = true;
            } else {
              final textValue = fieldValue.toString().trim();
              isEmpty = textValue.isEmpty;
            }
            break;
          case 'number':
          case 'date':
            // Number and date: check if null
            isEmpty = fieldValue == null;
            break;
          case 'radio':
          case 'dropdown':
          case 'select':
            // Single selection: check if null
            isEmpty = fieldValue == null;
            break;
          case 'checkbox':
            // Multiple selection: check if list is empty
            if (fieldValue is List) {
              isEmpty = fieldValue.isEmpty;
            } else {
              isEmpty = true;
            }
            break;
          default:
            isEmpty = fieldValue == null;
        }
        
        print('  Field $fieldName: value=$fieldValue, isEmpty=$isEmpty');
        
        if (isEmpty) {
          emptyRequiredFields.add(fieldName);
        }
      }
    }
    
    print('Empty required fields: $emptyRequiredFields');
    print('=== End Validation Debug ===');
    
    return emptyRequiredFields;
  }
  
  Future<void> _submitForm() async {
    // Prevent multiple submissions
    if (_isSubmitting) return;
    
    // Validate required fields first
    final emptyRequiredFields = _validateRequiredFields();
    
    if (emptyRequiredFields.isNotEmpty) {
      // Show error message
      if (mounted) {
        final fieldNames = emptyRequiredFields.map((name) {
          // Format field name for display
          return name.replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}')
              .replaceAll('_', ' ')
              .split(' ')
              .map((word) => word.isEmpty 
                  ? '' 
                  : word[0].toUpperCase() + word.substring(1).toLowerCase())
              .join(' ')
              .trim();
        }).join(', ');
        
        AppSnackBar.show(context, 'Please fill in all required fields: $fieldNames', isError: true);
        
        // Scroll to first empty required field
        if (emptyRequiredFields.isNotEmpty) {
          final firstEmptyField = emptyRequiredFields.first;
          final fieldFocusNode = _getFieldFocusNode(firstEmptyField);
          if (fieldFocusNode.canRequestFocus) {
            fieldFocusNode.requestFocus();
          }
        }
      }
      return;
    }
    
    setState(() {
      _isSubmitting = true;
    });
    
    // Save form data first
    await _saveFormData();
    
    if (_form == null || widget.formId == null) {
      setState(() {
        _isSubmitting = false;
      });
      return;
    }
    
    try {
      // Update form status to completed
      AppLoggerService().logFormAction('Form submission started', 
        formId: _form!.id,
        formTitle: _form!.title);
      
      final submittedForm = FormModel(
        id: _form!.id,
        title: _form!.title,
        description: _form!.description,
        formData: _form!.formData,
        status: 'completed',
        progress: 100.0,
        createdAt: _form!.createdAt,
        updatedAt: DateTime.now(),
        submittedAt: DateTime.now(),
        templateId: _form!.templateId,
        formType: _form!.formType,
      );
      
      // Save to database
      await _dbService.insertForm(submittedForm);
      
      AppLoggerService().logFormAction('Form submitted successfully', 
        formId: _form!.id,
        formTitle: _form!.title);
      
      if (mounted) {
        AppSnackBar.show(context, 'Form submitted successfully!');
        
        // Navigate back after a short delay
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            context.go('/dashboard');
          }
        });
      }
    } catch (e) {
      AppLoggerService().logError('Form submission', e);
      setState(() {
        _isSubmitting = false;
      });
      if (mounted) {
        AppSnackBar.show(context, 'Error submitting form: $e', isError: true);
      }
    }
  }

  @override
  void dispose() {
    AppLoggerService().logScreenEvent('ConversationalFormScreen', 'Disposed');
    _messageController.dispose();
    _messageFocusNode.dispose();
    _chatScrollController.dispose();
    for (var controller in _fieldControllers.values) {
      controller.dispose();
    }
    for (var focusNode in _fieldFocusNodes.values) {
      focusNode.dispose();
    }
    _voiceService.dispose();
    super.dispose();
  }

  TextEditingController _getFieldController(String fieldKey) {
    if (!_fieldControllers.containsKey(fieldKey)) {
      _fieldControllers[fieldKey] = TextEditingController();
      
      // Update progress display when field value changes
      _fieldControllers[fieldKey]!.addListener(() {
        final value = _fieldControllers[fieldKey]!.text;
        if (value.isNotEmpty) {
          final fieldMeta = _fieldMetadata[fieldKey];
          final fieldType = fieldMeta is Map<String, dynamic> 
              ? fieldMeta['type'] as String? ?? 'text' 
              : 'text';
          AppLoggerService().logFieldInteraction(fieldKey, 'Changed', 
            value: value.length > 50 ? '${value.substring(0, 50)}...' : value,
            fieldType: fieldType);
        }
        if (mounted) {
          setState(() {
            // Progress will be recalculated in build method
          });
        }
      });
      
      _fieldFocusNodes[fieldKey] = FocusNode()
        ..addListener(() {
          if (_fieldFocusNodes[fieldKey]!.hasFocus) {
            setState(() {
              _activeController = _fieldControllers[fieldKey];
            });
          }
        });
      
      // Save form data when field loses focus
      _fieldFocusNodes[fieldKey]!.addListener(() {
        if (!_fieldFocusNodes[fieldKey]!.hasFocus) {
          _saveFormData();
        }
      });
    }
    return _fieldControllers[fieldKey]!;
  }

  FocusNode _getFieldFocusNode(String fieldKey) {
    if (!_fieldFocusNodes.containsKey(fieldKey)) {
      _getFieldController(fieldKey); // This will create both
    }
    return _fieldFocusNodes[fieldKey]!;
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final userMessage = _messageController.text.trim();
    _messageController.clear();

    // Log user message
    AppLoggerService().logUserInteraction('Chat', details: 'User sent message: "$userMessage"');
    
    // 1. Display User Message immediately (in local language)
    setState(() {
      _messages.add({
        'text': userMessage,
        'isAI': false,
      });
    });

    try {
      // 2. Translate to English (if not already) for AI processing
      String englishUserMessage = userMessage;
      if (_currentChatLanguage != 'en') {
        englishUserMessage = await _translationService.translate(
          text: userMessage,
          resultLanguage: 'en',
          sourceLanguage: _currentChatLanguage,
        );
        debugPrint('[TRANSLATION] User available in English: $englishUserMessage');
      }
      
      // Update English History
      _englishConversationHistory.add({
        'text': englishUserMessage,
        'isAI': false,
      });

      // 3. Get AI Response using English Context
      final aiContext = {
        'formTitle': _formTitle,
        'userLanguage': _currentChatLanguage, // Pass language code to AI
      };
      
      // Use the hidden English history for best AI context
      final aiResponseEnglish = await _aiService.getResponse(
        englishUserMessage, 
        aiContext, 
        conversationHistory: _englishConversationHistory.sublist(
          0, _englishConversationHistory.length - 1 // Exclude current message as it's passed as arg
        )
      );
      
      // Add AI English response to hidden history
      _englishConversationHistory.add({
        'text': aiResponseEnglish,
        'isAI': true,
      });
      
      // 4. Translate AI Response back to Local Language (if needed)
      String displayAiResponse = aiResponseEnglish;
      if (_currentChatLanguage != 'en') {
        displayAiResponse = await _translationService.translate(
          text: aiResponseEnglish, 
          resultLanguage: _currentChatLanguage,
          sourceLanguage: 'en',
        );
        debugPrint('[TRANSLATION] AI available in $_currentChatLanguage: $displayAiResponse');
      }

      AppLoggerService().logUserInteraction('Chat', details: 'AI responded: "$displayAiResponse"');
      
      if (mounted) {
        setState(() {
          _messages.add({
            'text': displayAiResponse,
            'isAI': true,
          });
        });
      }
    } catch (e) {
      debugPrint('❌ ERROR: Future Form Assistant Error: $e');
      if (mounted) {
        AppSnackBar.show(context, 'Error: ${e.toString()}', isError: true);
      }
    }
    
    if (mounted) {
      // Scroll to bottom after adding message
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_chatScrollController.hasClients) {
          _chatScrollController.animateTo(
            _chatScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  // Helper method to get button color that matches the theme
  // This method is kept for backward compatibility but now returns the primary color
  Color _getButtonColor(Color primaryColor, Brightness brightness) {
    // Use the theme's primary color for buttons to match the app's color scheme
    return primaryColor;
  }

  Future<void> _startListening() async {
    if (_isListening) {
      await _voiceService.stopListening();
      setState(() => _isListening = false);
      return;
    }

    // Determine which controller to update based on focus
    // If no field is focused, focus on the first form field (fatherName)
    TextEditingController controllerToUpdate;
    if (_activeController != null) {
      controllerToUpdate = _activeController!;
    } else if (_fieldControllers.isNotEmpty) {
      // Focus on the first form field if no field is currently focused
      final firstFieldKey = _fieldControllers.keys.first;
      controllerToUpdate = _fieldControllers[firstFieldKey]!;
      _fieldFocusNodes[firstFieldKey]!.requestFocus();
      _activeController = controllerToUpdate;
    } else {
       // Fallback to message controller
      controllerToUpdate = _messageController;
      _messageFocusNode.requestFocus();
      _activeController = controllerToUpdate;
    }

    setState(() => _isListening = true);
    
    // Map language code to locale ID
    String localeId = 'en_US';
    // Use Form Language for voice input if enabled, or fallback to Chat Language
    // We want the voice input to match what the user is seeing/speaking
    final targetLang = _currentChatLanguage; 
    
    switch (targetLang) {
      case 'te': localeId = 'te_IN'; break;
      case 'hi': localeId = 'hi_IN'; break;
      case 'ta': localeId = 'ta_IN'; break;
      default: localeId = 'en_US';
    }
    
    await _voiceService.startListening(
      localeId: localeId,
      onPartialResult: (partialText) {
        // Update text in real-time as user speaks
        if (mounted) {
          setState(() {
            controllerToUpdate.text = partialText;
          });
        }
      },
      onResult: (result) {
        // Update the active controller with final result
        if (mounted) {
          setState(() {
            controllerToUpdate.text = result;
            _isListening = false;
          });
        }
      },
      onError: (error) {
        if (mounted) {
          AppSnackBar.show(context, 'Voice recognition error: $error', isError: true);
          setState(() => _isListening = false);
        }
      },
    );
  }

  Future<void> _performMagicFill() async {
    if (_form == null) return;
    
    setState(() {
      _isSubmitting = true; // Show loading state
    });
    
    try {
      final autofilledData = await _autofillService.autofillFormData(
        _form!.formData ?? {},
        _fieldMetadata,
      );
      
      int filledCount = 0;
      for (var entry in autofilledData.entries) {
        final key = entry.key;
        final newValue = entry.value;
        final oldValue = _form!.formData?[key];
        
        if ((oldValue == null || oldValue == '' || (oldValue is List && oldValue.isEmpty)) &&
            newValue != null && newValue != '' && !(newValue is List && newValue.isEmpty)) {
          
          final controller = _getFieldController(key);
          final fieldMeta = _fieldMetadata[key] as Map<String, dynamic>?;
          final fieldType = fieldMeta?['type'] as String? ?? 'text';
          
          if (fieldType != 'checkbox') {
            controller.text = newValue.toString();
          }
          _form!.formData![key] = newValue;
          filledCount++;
        }
      }
      
      await _saveFormData();
      
      if (mounted) {
        final currentTheme = Theme.of(context);
        AppSnackBar.show(context, filledCount > 0 
          ? 'Magic Fill complete! $filledCount fields populated.' 
          : 'No new fields to fill from your profile.');
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(context, 'Magic Fill error: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<bool> _onWillPop() async {
    // Don't show dialog if form is being submitted
    if (_isSubmitting) {
      return false;
    }
    
    // Check if form has unsaved changes
    bool hasUnsavedChanges = false;
    if (_form != null) {
      // Check if any field values have changed
      for (var entry in _fieldControllers.entries) {
        final fieldKey = entry.key;
        final currentValue = entry.value.text.trim();
        final savedValue = _form!.formData?[fieldKey]?.toString().trim() ?? '';
        if (currentValue != savedValue) {
          hasUnsavedChanges = true;
          break;
        }
      }
    }
    
    if (hasUnsavedChanges) {
      // Show dialog
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Exit Form?'),
          content: const Text('You have unsaved changes. What would you like to do?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                // Save & Exit
                await _saveFormData();
                if (context.mounted) {
                  Navigator.of(context).pop(true);
                }
              },
              child: const Text('Save & Exit'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Exit without saving'),
            ),
          ],
        ),
      );
      
      if (result == true && mounted) {
        // User chose to exit
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/dashboard');
        }
        return true;
      }
      return false; 
    }
    
    // No unsaved changes, allow navigation
    if (mounted) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/dashboard');
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          await _onWillPop();
        }
      },
      child: Stack(
        children: [
          Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    border: Border(
                      bottom: BorderSide(color: theme.dividerColor),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () async {
                          await _onWillPop();
                        },
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _formTitle ?? 'Form Filling',
                                    style: theme.textTheme.titleMedium,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (_isAnalyzing)
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _isAnalyzing 
                                  ? 'Analyzing form structure...' 
                                  : 'Page $_currentPage/$_totalPages • ${_calculateProgress(_getCurrentFormData()).toInt()}% Complete',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      // Form Language Selector
                      if (!_isTranslatingForm)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        height: 36,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _currentFormLanguage,
                            icon: const Icon(Icons.translate, size: 16),
                            isDense: true,
                            style: theme.textTheme.bodySmall,
                            onChanged: (String? newValue) {
                              if (newValue != null && newValue != _currentFormLanguage) {
                                _changeFormLanguage(newValue);
                              }
                            },
                            items: const [
                              DropdownMenuItem(value: 'en', child: Text('EN')),
                              DropdownMenuItem(value: 'te', child: Text('TE')),
                              DropdownMenuItem(value: 'hi', child: Text('HI')),
                              DropdownMenuItem(value: 'ta', child: Text('TA')),
                            ],
                          ),
                        ),
                      )
                      else
                        const Padding(
                          padding: EdgeInsets.only(right: 16.0),
                          child: SizedBox(
                            width: 20, 
                            height: 20, 
                            child: CircularProgressIndicator(strokeWidth: 2)
                          ),
                        ),

                      IconButton(
                        icon: const Icon(Icons.save_outlined),
                        onPressed: () async {
                          await _saveFormData();
                          if (mounted) {
                            AppSnackBar.show(context, 'Form saved successfully!');
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.auto_awesome, color: Colors.amber),
                        tooltip: 'Magic Fill',
                        onPressed: _performMagicFill,
                      ),
                      IconButton(
                        icon: const Icon(Icons.help_outline),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Help'),
                              content: const Text(
                                'Fill out the form fields as prompted. The AI assistant will guide you through each step. Use the chat interface at the bottom to ask questions or get help.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('OK'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                // Form Fields
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top-level instructions block removed as they are now rendered as fields
                        // Render fields for current page only
                        if (_getCurrentPageFields().isNotEmpty)
                          ...(_getCurrentPageFields().map((fieldKey) {
                            // Only render if field exists in metadata (to exclude leftover fields)
                            if (_fieldMetadata.isNotEmpty && !_fieldMetadata.containsKey(fieldKey)) {
                              return const SizedBox.shrink();
                            }
                            final fieldMeta = _fieldMetadata[fieldKey] as Map<String, dynamic>?;
                            final fieldType = fieldMeta?['type'] as String? ?? 'text';
                            // Render all field types, including static ones
                            return _buildFormField(fieldKey, theme);
                          }).toList())
                        else if (_fieldMetadata.isNotEmpty)
                          // Fallback: render all non-static fields from metadata if pagination failed
                          ...(_fieldMetadata.keys.map((fieldKey) {
                            return _buildFormField(fieldKey, theme);
                          }).toList())
                        else if (_form?.formData != null && _form!.formData!.isNotEmpty)
                          // Fallback: render all fields from formData (only if no metadata)
                          ...(_form!.formData!.keys.map((fieldKey) {
                            return _buildFormField(fieldKey, theme);
                          }).toList())
                        else
                          // Fallback: show empty state message
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.description_outlined,
                                    size: 64,
                                    color: theme.colorScheme.onSurface.withOpacity(0.3),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No form fields found',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Please check the form configuration',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 24),
                        // Navigation Buttons - Show if there are fields or multiple pages
                        if ((_form?.formData != null && _form!.formData!.isNotEmpty) || 
                            _getCurrentPageFields().isNotEmpty ||
                            _totalPages > 1)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              FilledButton.icon(
                                onPressed: _currentPage > 1
                                    ? () {
                                        AppLoggerService().logPageTransition(
                                          'Page $_currentPage', 
                                          'Page ${_currentPage - 1}',
                                          pageNumber: _currentPage - 1,
                                          totalPages: _totalPages,
                                        );
                                        setState(() {
                                          _currentPage--;
                                        });
                                      }
                                    : null,
                                icon: const Icon(Icons.arrow_back),
                                label: const Text('Previous'),
                                style: ButtonStyle(
                                  backgroundColor: MaterialStateProperty.resolveWith<Color>(
                                    (Set<MaterialState> states) {
                                      if (states.contains(MaterialState.disabled)) {
                                        return theme.colorScheme.surface.withOpacity(0.12);
                                      }
                                      // Use lighter grey for dark theme, primary color for other themes
                                      return theme.brightness == Brightness.dark
                                          ? const Color(0xFF333333) // Grey (20% white, 80% black) as requested
                                          : theme.colorScheme.primary;
                                    },
                                  ),
                                  foregroundColor: MaterialStateProperty.resolveWith<Color>(
                                    (Set<MaterialState> states) {
                                      if (states.contains(MaterialState.disabled)) {
                                        return theme.colorScheme.onSurface.withOpacity(0.38);
                                      }
                                      return Colors.white;
                                    },
                                  ),
                                  padding: MaterialStateProperty.all(
                                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  ),
                                ),
                              ),
                              FilledButton.icon(
                                onPressed: () async {
                                  if (_currentPage < _totalPages) {
                                    // Save current form data first to ensure we're validating latest values
                                    await _saveFormData();
                                    
                                    // Validate current page before moving to next
                                    final emptyRequiredFields = _validateCurrentPageRequiredFields();
                                    
                                    if (emptyRequiredFields.isNotEmpty) {
                                      // Show error message
                                      final fieldNames = emptyRequiredFields
                                          .map((name) => _formatFieldLabel(name))
                                          .join(', ');
                                      
                                      if (mounted) {
                                        AppSnackBar.show(context, 'Please fill in all required fields: $fieldNames', isError: true);
                                        
                                        // Scroll to first empty required field
                                        final firstEmptyField = emptyRequiredFields.first;
                                        final fieldFocusNode = _getFieldFocusNode(firstEmptyField);
                                        if (fieldFocusNode.canRequestFocus) {
                                          WidgetsBinding.instance.addPostFrameCallback((_) {
                                            if (mounted) {
                                              fieldFocusNode.requestFocus();
                                            }
                                          });
                                        }
                                      }
                                      return;
                                    }
                                    
                                    // All required fields filled, move to next page
                                    if (mounted) {
                                      AppLoggerService().logPageTransition(
                                        'Page $_currentPage', 
                                        'Page ${_currentPage + 1}',
                                        pageNumber: _currentPage + 1,
                                        totalPages: _totalPages,
                                      );
                                      setState(() {
                                        _currentPage++;
                                      });
                                    }
                                  } else {
                                    // Submit form (this already has validation)
                                    AppLoggerService().logFormAction('Submitting form', 
                                      formId: widget.formId,
                                      formTitle: _formTitle);
                                    _submitForm();
                                  }
                                },
                                icon: Icon(
                                  _currentPage == _totalPages ? Icons.check : Icons.arrow_forward,
                                ),
                                label: Text(
                                  _currentPage == _totalPages 
                                      ? (_translatedFieldLabels['Submit'] ?? 'Submit') 
                                      : (_translatedFieldLabels['Next'] ?? 'Next'),
                                ),
                                style: ButtonStyle(
                                  backgroundColor: MaterialStateProperty.resolveWith<Color>(
                                    (Set<MaterialState> states) {
                                      if (states.contains(MaterialState.disabled)) {
                                        return theme.colorScheme.surface.withOpacity(0.3);
                                      }
                                      // Use lighter grey for dark theme, primary color for other themes
                                      return theme.brightness == Brightness.dark
                                          ? const Color(0xFF333333) // Grey (20% white, 80% black) as requested
                                          : theme.colorScheme.primary;
                                    },
                                  ),
                                  foregroundColor: MaterialStateProperty.all(
                                    Colors.white,
                                  ),
                                  padding: MaterialStateProperty.all(
                                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // AI Assistant Button
                        FilledButton.icon(
                          onPressed: () {
                            setState(() {
                              _isChatOpen = true;
                            });
                          },
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Text('AI Assistant'),
                          style: ButtonStyle(
                            backgroundColor: MaterialStateProperty.resolveWith<Color>(
                              (Set<MaterialState> states) {
                                if (states.contains(MaterialState.disabled)) {
                                  return theme.colorScheme.surface.withOpacity(0.3);
                                }
                                // Use lighter grey for dark theme, primary color for other themes
                                return theme.brightness == Brightness.dark
                                    ? const Color(0xFF9E9E9E) // Light grey for better visibility in dark theme
                                    : theme.colorScheme.primary;
                              },
                            ),
                            foregroundColor: MaterialStateProperty.all(
                              Colors.white,
                            ),
                            padding: MaterialStateProperty.all(
                              const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // AI Chat Interface Overlay
        if (_isChatOpen)
          _buildChatInterface(context, theme),
      ],
    ),
    );
  }
  
  Widget _buildChatInterface(BuildContext context, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Chat Header with Back Button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  bottom: BorderSide(color: theme.dividerColor),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _isChatOpen = false;
                      });
                    },
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Close Chat',
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chat_bubble_outline),
                  const SizedBox(width: 8),
                  Expanded( // Use Expanded to avoid overflow with Dropdown
                    child: Text(
                      'AI Assistant',
                      style: theme.textTheme.titleLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Language Dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _currentChatLanguage,
                        icon: const Icon(Icons.translate, size: 20),
                        isDense: true,
                        style: theme.textTheme.bodyMedium,
                        borderRadius: BorderRadius.circular(16),
                        items: const [
                          DropdownMenuItem(value: 'en', child: Text('English')),
                          DropdownMenuItem(value: 'te', child: Text('Telugu')),
                          DropdownMenuItem(value: 'hi', child: Text('Hindi')),
                          DropdownMenuItem(value: 'ta', child: Text('Tamil')),
                        ],
                        onChanged: (String? newValue) {
                          if (newValue != null && newValue != _currentChatLanguage) {
                            setState(() {
                              _currentChatLanguage = newValue;
                            });
                            // Trigger a greeting in the new language
                            // We do this by simulating a "Hello" from the user in the new language context,
                            // or just directly adding a localized welcome message.
                            // For simplicity, we'll just let the UI update, but the user can say "Hi" to start.
                            
                            // Better experience: Send a hidden "Hi" to get a localized greeting? 
                            // Or just show a Snackbar "Language changed to..."
                            AppSnackBar.show(context, 'Conversation language set to ${newValue.toUpperCase()}');
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Chat Messages
            Expanded(
              child: Container(
                color: theme.scaffoldBackgroundColor,
                child: _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 64,
                              color: theme.colorScheme.onSurface.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Start a conversation with AI Assistant',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _chatScrollController,
                        padding: const EdgeInsets.all(16),
                        reverse: false,
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _ChatBubble(
                              text: message['text'] as String,
                              isAI: message['isAI'] as bool,
                            ),
                          );
                        },
                      ),
              ),
            ),
            // Input Area
            Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: 16 + MediaQuery.of(context).padding.bottom,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  top: BorderSide(color: theme.dividerColor),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      focusNode: _messageFocusNode,
                      style: TextStyle(
                        color: isDark 
                            ? Colors.white 
                            : theme.colorScheme.onSurface, // Text color matches theme
                      ),
                      decoration: InputDecoration(
                        hintText: 'Type your message...',
                        hintStyle: TextStyle(
                          color: isDark 
                              ? Colors.white.withOpacity(0.6) 
                              : theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(
                            color: isDark ? Colors.white.withOpacity(0.2) : theme.dividerColor,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(
                            color: isDark ? Colors.white.withOpacity(0.2) : theme.dividerColor,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(
                            color: theme.colorScheme.primary,
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: isDark 
                            ? const Color(0xFF333333) // 20% white, 80% black
                            : theme.colorScheme.surface,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isListening && _activeController == _messageController)
                              const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: Icon(Icons.mic, color: Colors.red, size: 20),
                              ),
                            IconButton(
                              icon: Icon(_isListening ? Icons.mic : Icons.mic_none, size: 20),
                              onPressed: _startListening,
                              color: _isListening ? Colors.red : theme.colorScheme.primary,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                      textInputAction: TextInputAction.send,
                      onTap: () {
                        setState(() {
                          _activeController = _messageController;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sendMessage,
                    icon: const Icon(Icons.send),
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.resolveWith<Color>(
                        (Set<MaterialState> states) {
                          if (states.contains(MaterialState.disabled)) {
                            return theme.colorScheme.surface.withOpacity(0.3);
                          }
                          // Use lighter grey for dark theme, primary color for other themes
                          return theme.brightness == Brightness.dark
                              ? const Color(0xFF333333) // Grey (20% white, 80% black) as requested
                              : theme.colorScheme.primary;
                        },
                      ),
                      foregroundColor: MaterialStateProperty.all(
                        Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFormField(String fieldKey, ThemeData theme) {
    final fieldMeta = _fieldMetadata[fieldKey] as Map<String, dynamic>?;
    final fieldType = fieldMeta?['type'] as String? ?? 'text';
    final isRequired = fieldMeta?['required'] == true;
    
    // Use the field name as-is from metadata, or format it if needed
    // TRANSLATION LOGIC:
    String fieldLabel = _formatFieldLabel(fieldKey);
    // If we have a translated label for this key, use it
    if (_currentFormLanguage != 'en' && _translatedFieldLabels.containsKey(fieldKey)) {
      fieldLabel = _translatedFieldLabels[fieldKey]!;
    }

    final description = fieldMeta?['description'] as String?;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Field Label with required asterisk
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: theme.textTheme.titleSmall,
                    children: [
                      TextSpan(text: fieldLabel),
                      if (isRequired)
                        TextSpan(
                          text: ' *',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: (theme.textTheme.titleSmall?.fontSize ?? 14) * 1.2,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Field Widget based on type
          _buildFieldWidget(fieldKey, fieldType, fieldMeta, theme),
        ],
      ),
    );
  }
  
  /// Build a clear button widget for form fields
  Widget? _buildClearButton(String fieldKey, String fieldType) {
    // Check if field has a value
    bool hasValue = false;
    
    if (fieldType == 'dropdown' || fieldType == 'select' || fieldType == 'radio') {
      // For dropdown/select/radio, check formData
      hasValue = _form?.formData?[fieldKey] != null;
    } else if (fieldType == 'date') {
      // For date, check both controller and formData
      hasValue = _form?.formData?[fieldKey] != null;
    } else {
      // For text fields, check controller
      final controller = _getFieldController(fieldKey);
      hasValue = controller.text.isNotEmpty;
    }
    
    // Don't show clear button if field is empty
    if (!hasValue) return null;
    
    return IconButton(
      icon: const Icon(Icons.clear, size: 20),
      onPressed: () {
        setState(() {
          final controller = _getFieldController(fieldKey);
          controller.clear();
          if (_form?.formData != null) {
            // Clear the field based on type
            switch (fieldType) {
              case 'checkbox':
                _form!.formData![fieldKey] = <String>[];
                break;
              case 'number':
              case 'date':
              case 'radio':
              case 'dropdown':
              case 'select':
                _form!.formData![fieldKey] = null;
                break;
              default:
                _form!.formData![fieldKey] = null;
            }
          }
        });
        _saveFormData();
      },
      tooltip: 'Clear',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildFieldWidget(
    String fieldKey,
    String fieldType,
    Map<String, dynamic>? fieldMeta,
    ThemeData theme,
  ) {
    switch (fieldType) {
      case 'static':
        final description = fieldMeta?['description'] as String? ?? '';
        if (description.isEmpty) return const SizedBox.shrink();
        
        return Container(
          margin: const EdgeInsets.only(top: 8, bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.dividerColor.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        );
      
      case 'radio':
        final options = (fieldMeta?['options'] as List<dynamic>?) ?? [];
        final currentValue = _form?.formData?[fieldKey];
        final hasSelection = currentValue != null;
        
        return Column(
          children: [
            ...options.map<Widget>((option) {
              final optionText = option.toString();
              final isSelected = currentValue == optionText;
              final displayOption = _currentFormLanguage != 'en' 
                  ? (_translatedFieldLabels['OPTION_$optionText'] ?? optionText)
                  : optionText;
              
              return RadioListTile<String>(
                title: Text(displayOption),

                value: optionText,
                groupValue: isSelected ? optionText : null,
                onChanged: (value) {
                  setState(() {
                    if (_form?.formData != null) {
                      _form!.formData![fieldKey] = value;
                    }
                  });
                  _saveFormData();
                },
                contentPadding: EdgeInsets.zero,
              );
            }).toList(),
            if (hasSelection)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      if (_form?.formData != null) {
                        _form!.formData![fieldKey] = null;
                      }
                    });
                    _saveFormData();
                  },
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Clear selection'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
          ],
        );
      
      case 'checkbox':
        final options = (fieldMeta?['options'] as List<dynamic>?) ?? [];
        final currentValues = (_form?.formData?[fieldKey] as List<dynamic>?) ?? [];
        final selectedValues = currentValues.map((e) => e.toString()).toSet();
        final hasSelection = selectedValues.isNotEmpty;
        
        return Column(
          children: [
            ...options.map<Widget>((option) {
              final optionText = option.toString();
              final isSelected = selectedValues.contains(optionText);
              
              return CheckboxListTile(
                title: Text(optionText),
                value: isSelected,
                onChanged: (value) {
                  setState(() {
                    if (_form?.formData != null) {
                      final currentList = List<String>.from(selectedValues);
                      if (value == true) {
                        if (!currentList.contains(optionText)) {
                          currentList.add(optionText);
                        }
                      } else {
                        currentList.remove(optionText);
                      }
                      _form!.formData![fieldKey] = currentList;
                    }
                  });
                  _saveFormData();
                },
                contentPadding: EdgeInsets.zero,
              );
            }).toList(),
            if (hasSelection)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      if (_form?.formData != null) {
                        _form!.formData![fieldKey] = <String>[];
                      }
                    });
                    _saveFormData();
                  },
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Clear all'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
          ],
        );
      
      case 'dropdown':
      case 'select':
        final isRequired = fieldMeta?['required'] == true;
        final isEmpty = _form?.formData?[fieldKey] == null;
        final showError = isRequired && isEmpty;
        final options = (fieldMeta?['options'] as List<dynamic>?) ?? [];
        final currentValue = _form?.formData?[fieldKey]?.toString();
        final clearButton = _buildClearButton(fieldKey, fieldType);
        
        return DropdownButtonFormField<String>(
          value: currentValue,
          isExpanded: true, // Prevent overflow by allowing dropdown to expand
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: showError 
                  ? const BorderSide(color: Colors.red, width: 2)
                  : BorderSide(color: theme.dividerColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: showError 
                  ? const BorderSide(color: Colors.red, width: 2)
                  : BorderSide(color: theme.dividerColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: showError ? Colors.red : theme.colorScheme.primary,
                width: 2,
              ),
            ),
            errorText: showError ? 'This field is required' : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            suffixIcon: clearButton != null
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: Center(child: clearButton),
                      ),
                      const SizedBox(width: 4),
                      const Padding(
                        padding: EdgeInsets.only(right: 12.0),
                        child: Icon(Icons.arrow_drop_down, size: 24),
                      ),
                    ],
                  )
                : const Padding(
                    padding: EdgeInsets.only(right: 12.0),
                    child: Icon(Icons.arrow_drop_down, size: 24),
                  ),
          ),
          items: options.map<DropdownMenuItem<String>>((option) {
            final optionText = option.toString();
            final displayOption = _currentFormLanguage != 'en' 
                ? (_translatedFieldLabels['OPTION_$optionText'] ?? optionText)
                : optionText;

            return DropdownMenuItem<String>(
              value: optionText,
              child: Text(
                displayOption,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
                softWrap: true,
              ),
            );
          }).toList(),
          selectedItemBuilder: (context) {
            // Custom builder for selected item to handle long text
            return options.map<Widget>((option) {
              final optionText = option.toString();
              final displayOption = _currentFormLanguage != 'en' 
                  ? (_translatedFieldLabels['OPTION_$optionText'] ?? optionText)
                  : optionText;
                  
              return Text(
                displayOption,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                ),
              );
            }).toList();
          },
          onChanged: (value) {
            setState(() {
              if (_form?.formData != null) {
                _form!.formData![fieldKey] = value;
                // Update controller text for clear button visibility
                _getFieldController(fieldKey).text = value ?? '';
              }
            });
            _saveFormData();
          },
        );
      
      case 'textarea':
        final isRequired = fieldMeta?['required'] == true;
        final isEmpty = _form?.formData?[fieldKey] == null || 
                       _form!.formData![fieldKey].toString().trim().isEmpty;
        final showError = isRequired && isEmpty;
        final controller = _getFieldController(fieldKey);
        final isListeningToThisField = _isListening && _activeController == controller;
        final clearButton = _buildClearButton(fieldKey, fieldType);
        
        return TextField(
          controller: controller,
          focusNode: _getFieldFocusNode(fieldKey),
          maxLines: 5,
          decoration: InputDecoration(
            hintText: _currentFormLanguage != 'en' && _translatedHints.containsKey(fieldKey)
                ? _translatedHints[fieldKey]
                : 'Enter ${_formatFieldLabel(fieldKey)}',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: showError 
                  ? const BorderSide(color: Colors.red, width: 2)
                  : BorderSide(color: theme.dividerColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: showError 
                  ? const BorderSide(color: Colors.red, width: 2)
                  : BorderSide(color: theme.dividerColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: showError ? Colors.red : theme.colorScheme.primary,
                width: 2,
              ),
            ),
            errorText: showError ? 'This field is required' : null,
            suffixIcon: isListeningToThisField
                ? const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Icon(Icons.mic, color: Colors.red),
                  )
                : clearButton,
          ),
          onChanged: (value) {
            if (_form?.formData != null) {
              final trimmedValue = value.trim();
              _form!.formData![fieldKey] = trimmedValue.isEmpty ? null : trimmedValue;
            }
            _saveFormData();
            // Trigger rebuild to update error state and clear button visibility
            setState(() {});
          },
        );
      
      case 'number':
        final isRequired = fieldMeta?['required'] == true;
        final isEmpty = _form?.formData?[fieldKey] == null;
        final showError = isRequired && isEmpty;
        final controller = _getFieldController(fieldKey);
        final isListeningToThisField = _isListening && _activeController == controller;
        final clearButton = _buildClearButton(fieldKey, fieldType);
        
        return TextField(
          controller: controller,
          focusNode: _getFieldFocusNode(fieldKey),
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: _currentFormLanguage != 'en' && _translatedHints.containsKey(fieldKey)
                ? _translatedHints[fieldKey]
                : 'Enter ${_formatFieldLabel(fieldKey)}',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: showError 
                  ? const BorderSide(color: Colors.red, width: 2)
                  : BorderSide(color: theme.dividerColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: showError 
                  ? const BorderSide(color: Colors.red, width: 2)
                  : BorderSide(color: theme.dividerColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: showError ? Colors.red : theme.colorScheme.primary,
                width: 2,
              ),
            ),
            errorText: showError ? 'This field is required' : null,
            suffixIcon: isListeningToThisField
                ? const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Icon(Icons.mic, color: Colors.red),
                  )
                : clearButton,
          ),
          onChanged: (value) {
            if (_form?.formData != null) {
              _form!.formData![fieldKey] = value.isEmpty ? null : num.tryParse(value);
            }
            _saveFormData();
            // Trigger rebuild to update error state and clear button visibility
            setState(() {});
          },
        );
      
      case 'date':
        final isRequired = fieldMeta?['required'] == true;
        final isEmpty = _form?.formData?[fieldKey] == null;
        final showError = isRequired && isEmpty;
        final controller = _getFieldController(fieldKey);
        final clearButton = _buildClearButton(fieldKey, fieldType);
        
        return TextField(
          controller: controller,
          focusNode: _getFieldFocusNode(fieldKey),
          readOnly: true,
          decoration: InputDecoration(
            hintText: 'Select ${fieldKey}',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: showError 
                  ? const BorderSide(color: Colors.red, width: 2)
                  : BorderSide(color: theme.dividerColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: showError 
                  ? const BorderSide(color: Colors.red, width: 2)
                  : BorderSide(color: theme.dividerColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: showError ? Colors.red : theme.colorScheme.primary,
                width: 2,
              ),
            ),
            errorText: showError ? 'This field is required' : null,
            suffixIcon: clearButton != null
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: Center(
                          child: IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              setState(() {
                                controller.clear();
                                if (_form?.formData != null) {
                                  _form!.formData![fieldKey] = null;
                                }
                              });
                              _saveFormData();
                            },
                            tooltip: 'Clear',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Padding(
                        padding: EdgeInsets.only(right: 12.0),
                        child: Icon(Icons.calendar_today, size: 24),
                      ),
                    ],
                  )
                : const Padding(
                    padding: EdgeInsets.only(right: 12.0),
                    child: Icon(Icons.calendar_today, size: 24),
                  ),
          ),
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(1900),
              lastDate: DateTime(2100),
            );
            if (date != null) {
              setState(() {
                controller.text = 
                    '${date.day}/${date.month}/${date.year}';
                if (_form?.formData != null) {
                  _form!.formData![fieldKey] = date.toIso8601String();
                }
              });
              _saveFormData();
            }
          },
        );
      
      case 'email':
        final isRequired = fieldMeta?['required'] == true;
        final isEmpty = _form?.formData?[fieldKey] == null || 
                       _form!.formData![fieldKey].toString().trim().isEmpty;
        final showError = isRequired && isEmpty;
        final controller = _getFieldController(fieldKey);
        final isListeningToThisField = _isListening && _activeController == controller;
        final clearButton = _buildClearButton(fieldKey, fieldType);
        
        return TextField(
          controller: controller,
          focusNode: _getFieldFocusNode(fieldKey),
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            hintText: 'Enter ${fieldKey}',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: showError 
                  ? const BorderSide(color: Colors.red, width: 2)
                  : BorderSide(color: theme.dividerColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: showError 
                  ? const BorderSide(color: Colors.red, width: 2)
                  : BorderSide(color: theme.dividerColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: showError ? Colors.red : theme.colorScheme.primary,
                width: 2,
              ),
            ),
            errorText: showError ? 'This field is required' : null,
            suffixIcon: isListeningToThisField
                ? const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Icon(Icons.mic, color: Colors.red),
                  )
                : clearButton,
          ),
          onChanged: (value) {
            if (_form?.formData != null) {
              final trimmedValue = value.trim();
              _form!.formData![fieldKey] = trimmedValue.isEmpty ? null : trimmedValue;
            }
            _saveFormData();
            // Trigger rebuild to update error state and clear button visibility
            setState(() {});
          },
        );
      
      case 'phone':
        final isRequired = fieldMeta?['required'] == true;
        final isEmpty = _form?.formData?[fieldKey] == null || 
                       _form!.formData![fieldKey].toString().trim().isEmpty;
        final showError = isRequired && isEmpty;
        final controller = _getFieldController(fieldKey);
        final isListeningToThisField = _isListening && _activeController == controller;
        final clearButton = _buildClearButton(fieldKey, fieldType);
        
        return TextField(
          controller: controller,
          focusNode: _getFieldFocusNode(fieldKey),
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            hintText: 'Enter ${fieldKey}',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: showError 
                  ? const BorderSide(color: Colors.red, width: 2)
                  : BorderSide(color: theme.dividerColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: showError 
                  ? const BorderSide(color: Colors.red, width: 2)
                  : BorderSide(color: theme.dividerColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: showError ? Colors.red : theme.colorScheme.primary,
                width: 2,
              ),
            ),
            errorText: showError ? 'This field is required' : null,
            suffixIcon: isListeningToThisField
                ? const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Icon(Icons.mic, color: Colors.red),
                  )
                : clearButton,
          ),
          onChanged: (value) {
            if (_form?.formData != null) {
              final trimmedValue = value.trim();
              _form!.formData![fieldKey] = trimmedValue.isEmpty ? null : trimmedValue;
            }
            _saveFormData();
            // Trigger rebuild to update error state and clear button visibility
            setState(() {});
          },
        );
      
      case 'file':
        final isRequired = fieldMeta?['required'] == true;
        final filePath = _form?.formData?[fieldKey] as String?;
        final isEmpty = filePath == null || filePath.isEmpty;
        final showError = isRequired && isEmpty;
        
        return InkWell(
          onTap: () async {
            try {
              final filePicker = FilePicker.platform;
              final result = await filePicker.pickFiles(
                type: FileType.any,
                allowMultiple: false,
              );
              
              if (result != null && result.files.single.path != null) {
                setState(() {
                  if (_form?.formData != null) {
                    _form!.formData![fieldKey] = result.files.single.path;
                  }
                });
                _saveFormData();
              }
            } catch (e) {
              if (mounted) {
                AppSnackBar.show(context, 'Error picking file: $e', isError: true);
              }
            }
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: showError ? Colors.red : theme.dividerColor,
                width: showError ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.attach_file,
                  color: showError ? Colors.red : theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        filePath != null 
                            ? filePath.split('/').last 
                            : 'Tap to upload file',
                        style: TextStyle(
                          color: filePath != null 
                              ? theme.colorScheme.onSurface 
                              : theme.colorScheme.onSurface.withOpacity(0.6),
                          fontWeight: filePath != null ? FontWeight.w500 : FontWeight.normal,
                        ),
                      ),
                      if (showError)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'This field is required',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (filePath != null)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      setState(() {
                        if (_form?.formData != null) {
                          _form!.formData![fieldKey] = null;
                        }
                      });
                      _saveFormData();
                    },
                    tooltip: 'Remove file',
                  ),
              ],
            ),
          ),
        );
      
      default: // text
        final isRequired = fieldMeta?['required'] == true;
        final isEmpty = _form?.formData?[fieldKey] == null || 
                       _form!.formData![fieldKey].toString().trim().isEmpty;
        final showError = isRequired && isEmpty;
        final controller = _getFieldController(fieldKey);
        final isListeningToThisField = _isListening && _activeController == controller;
        final clearButton = _buildClearButton(fieldKey, fieldType);
        
        return TextField(
          controller: controller,
          focusNode: _getFieldFocusNode(fieldKey),
          decoration: InputDecoration(
            hintText: 'Enter ${fieldKey}',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: showError 
                  ? const BorderSide(color: Colors.red, width: 2)
                  : BorderSide(color: theme.dividerColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: showError 
                  ? const BorderSide(color: Colors.red, width: 2)
                  : BorderSide(color: theme.dividerColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: showError ? Colors.red : theme.colorScheme.primary,
                width: 2,
              ),
            ),
            errorText: showError ? 'This field is required' : null,
            suffixIcon: isListeningToThisField
                ? const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Icon(Icons.mic, color: Colors.red),
                  )
                : clearButton,
          ),
          onChanged: (value) {
            if (_form?.formData != null) {
              final trimmedValue = value.trim();
              _form!.formData![fieldKey] = trimmedValue.isEmpty ? null : trimmedValue;
            }
            _saveFormData();
            // Trigger rebuild to update error state and clear button visibility
            setState(() {});
          },
        );
    }
  }
  
  String _formatFieldLabel(String fieldKey) {
    // Convert camelCase or snake_case to Title Case
    return fieldKey
        .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}')
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isEmpty 
            ? '' 
            : word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ')
        .trim();
  }
}

class _ChatBubble extends StatelessWidget {
  final String text;
  final bool isAI;

  const _ChatBubble({
    required this.text,
    required this.isAI,
  });

  // Helper function to convert markdown links to plain URLs
  // Converts [text](url) to just the URL so Linkify can detect it properly
  String _convertMarkdownLinks(String text) {
    // Pattern to match markdown links: [text](url)
    final markdownLinkPattern = RegExp(r'\[([^\]]+)\]\(([^)]+)\)');
    
    String processedText = text;
    
    // Replace all markdown links with just the clean URL
    // Linkify will automatically detect and make it clickable
    processedText = processedText.replaceAllMapped(markdownLinkPattern, (match) {
      final linkText = match.group(1) ?? '';
      final url = match.group(2) ?? '';
      // Clean the URL - remove any trailing characters that might cause issues
      String cleanUrl = url.trim();
      // Remove any trailing markdown characters, brackets, or punctuation
      cleanUrl = cleanUrl.replaceAll(RegExp(r'[)\]}\s]+$'), '');
      // Return format: linkText: cleanUrl
      // This ensures the URL is clearly separated and Linkify can detect it
      if (cleanUrl.isNotEmpty) {
        return '$linkText: $cleanUrl';
      }
      return linkText;
    });
    
    return processedText;
  }

  // Parse markdown and create TextSpans with formatting
  List<TextSpan> _parseMarkdown(String text, TextStyle baseStyle, TextStyle linkStyle, BuildContext context) {
    List<TextSpan> spans = [];
    
    // First, extract all markdown patterns and URLs with their positions
    List<_MarkdownElement> elements = [];
    
    // Find bold text: **text** or __text__
    final boldPattern = RegExp(r'\*\*([^*]+)\*\*|__([^_]+)__');
    for (final match in boldPattern.allMatches(text)) {
      final boldText = match.group(1) ?? match.group(2) ?? '';
      elements.add(_MarkdownElement(
        start: match.start,
        end: match.end,
        type: _MarkdownType.bold,
        content: boldText,
      ));
    }
    
    // Find URLs: http:// or https://
    final urlPattern = RegExp(r'https?://[^\s\)\]\}]+');
    for (final match in urlPattern.allMatches(text)) {
      final url = match.group(0)!;
      elements.add(_MarkdownElement(
        start: match.start,
        end: match.end,
        type: _MarkdownType.url,
        content: url,
      ));
    }
    
    // Sort elements by position
    elements.sort((a, b) => a.start.compareTo(b.start));
    
    // Remove overlapping elements (prioritize URLs, then bold)
    List<_MarkdownElement> filteredElements = [];
    for (final element in elements) {
      bool shouldAdd = true;
      
      // Check if this element overlaps with any existing element
      for (int i = filteredElements.length - 1; i >= 0; i--) {
        final existing = filteredElements[i];
        
        // Check for overlap
        if (!(element.end <= existing.start || element.start >= existing.end)) {
          // They overlap
          // Prioritize URLs over bold
          if (element.type == _MarkdownType.url && existing.type == _MarkdownType.bold) {
            // Replace bold with URL
            filteredElements.removeAt(i);
          } else if (element.type == _MarkdownType.bold && existing.type == _MarkdownType.url) {
            // Don't add bold if URL already exists
            shouldAdd = false;
            break;
          } else {
            // Same type or both are bold/url - keep the first one
            shouldAdd = false;
            break;
          }
        }
      }
      
      if (shouldAdd) {
        filteredElements.add(element);
      }
    }
    
    // Re-sort after filtering (in case we removed elements)
    filteredElements.sort((a, b) => a.start.compareTo(b.start));
    
    // Build TextSpans
    int currentIndex = 0;
    for (final element in filteredElements) {
      // Add text before this element
      if (element.start > currentIndex) {
        final beforeText = text.substring(currentIndex, element.start);
        spans.add(TextSpan(text: beforeText, style: baseStyle));
      }
      
      // Add the formatted element
      if (element.type == _MarkdownType.bold) {
        spans.add(TextSpan(
          text: element.content,
          style: baseStyle.copyWith(fontWeight: FontWeight.bold),
        ));
      } else if (element.type == _MarkdownType.url) {
        spans.add(TextSpan(
          text: element.content,
          style: linkStyle,
          recognizer: TapGestureRecognizer()
            ..onTap = () => _openUrl(context, element.content),
        ));
      }
      
      currentIndex = element.end;
    }
    
    // Add remaining text
    if (currentIndex < text.length) {
      spans.add(TextSpan(text: text.substring(currentIndex), style: baseStyle));
    }
    
    return spans.isEmpty ? [TextSpan(text: text, style: baseStyle)] : spans;
  }

  // Helper to open URLs
  void _openUrl(BuildContext context, String url) async {
    // Clean the URL thoroughly
    String cleanUrl = url.trim();
    
    // Remove any trailing markdown characters or malformed parts
    cleanUrl = cleanUrl.replaceAll(RegExp(r'\]\([^)]*\)\s*$'), '');
    cleanUrl = cleanUrl.replaceAll(RegExp(r'[)\]}\s]+$'), '');
    cleanUrl = cleanUrl.replaceAll(RegExp(r'^\s*[(\[]+'), '');
    
    // Extract URL from malformed strings
    final urlPattern = RegExp(r'https?://[^\s\)\]\}]+');
    final urlMatch = urlPattern.firstMatch(cleanUrl);
    if (urlMatch != null) {
      cleanUrl = urlMatch.group(0)!;
    }
    
    cleanUrl = cleanUrl.trim();
    
    // Validate URL format
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      if (context.mounted) {
        AppSnackBar.show(context, 'Invalid URL format: $cleanUrl', isError: true);
      }
      return;
    }
    
    try {
      final uri = Uri.parse(cleanUrl);
      debugPrint('Attempting to launch URL: $cleanUrl');
      
      // Try to launch the URL with externalApplication mode (opens in browser)
      try {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        
        if (!launched) {
          debugPrint('launchUrl returned false');
          // Try alternative modes as fallback
          try {
            await launchUrl(uri, mode: LaunchMode.platformDefault);
          } catch (e2) {
            debugPrint('platformDefault also failed: $e2');
            throw Exception('Could not launch URL');
          }
        }
      } catch (e) {
        debugPrint('externalApplication failed: $e');
        // Try platformDefault as fallback
        try {
          await launchUrl(uri, mode: LaunchMode.platformDefault);
        } catch (e2) {
          debugPrint('All launch modes failed: $e2');
          if (context.mounted) {
            AppSnackBar.show(context, 'Could not open $cleanUrl', isError: true);
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('Error parsing or launching URL: $e');
      if (context.mounted) {
        AppSnackBar.show(context, 'Error opening URL: ${e.toString()}', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Determine colors based on theme
    // AI messages: lighter background that's more visible
    // User messages: 20% white and 80% black (Color(0xFF333333)) as requested
    final aiMessageColor = isDark
        ? theme.colorScheme.primary.withOpacity(0.25) // Lighter for dark theme - more visible
        : theme.colorScheme.primary.withOpacity(0.1);
    final aiMessageTextColor = theme.colorScheme.onSurface;
    
    // User messages: 20% white and 80% black (Color(0xFF333333))
    final userMessageColor = isDark
        ? const Color(0xFF333333) // 20% white, 80% black
        : theme.colorScheme.primary;
    
    final userMessageTextColor = Colors.white; // White text for good contrast on dark background

    // Text style for the message
    final textStyle = TextStyle(
      color: isAI ? aiMessageTextColor : userMessageTextColor,
    );

    // Link style
    final linkStyle = textStyle.copyWith(
      color: isAI 
          ? theme.colorScheme.primary 
          : Colors.lightBlueAccent,
      decoration: TextDecoration.underline,
    );

    // Pre-process text to convert markdown links to plain URLs
    final processedText = _convertMarkdownLinks(text);

    // Parse markdown and create TextSpans
    final textSpans = _parseMarkdown(processedText, textStyle, linkStyle, context);

    return Align(
      alignment: isAI ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isAI ? aiMessageColor : userMessageColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: RichText(
          text: TextSpan(children: textSpans),
        ),
      ),
    );
  }
}

// Helper classes for markdown parsing
enum _MarkdownType { bold, url }

class _MarkdownElement {
  final int start;
  final int end;
  final _MarkdownType type;
  final String content;
  
  _MarkdownElement({
    required this.start,
    required this.end,
    required this.type,
    required this.content,
  });
}

