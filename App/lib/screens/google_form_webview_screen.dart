import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:async';
import 'dart:convert';
import '../services/debug_log_service.dart';
import '../services/app_logger_service.dart';
import '../services/auth_service.dart';

/// Screen that opens Google Form in a WebView to allow user to sign in
/// and then extracts the form HTML for processing
class GoogleFormWebViewScreen extends StatefulWidget {
  final String formUrl;
  
  const GoogleFormWebViewScreen({
    super.key,
    required this.formUrl,
  });

  @override
  State<GoogleFormWebViewScreen> createState() => _GoogleFormWebViewScreenState();
}

class _GoogleFormWebViewScreenState extends State<GoogleFormWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _errorMessage;
  String? _extractedHtml;
  final Completer<String?> _htmlCompleter = Completer<String?>();
  Timer? _urlCheckTimer;
  bool _isExtracting = false;
  String _loadingMessage = 'Fetching form...';
  String? _userEmail;
  String? _accessToken;

  @override
  void initState() {
    super.initState();
    AppLoggerService().logScreenEvent('GoogleFormWebViewScreen', 'Initialized', 
      details: {'formUrl': widget.formUrl});
    
    _initializeUserData();
    _initializeWebView();
    _startUrlCheckTimer();
  }

  Future<void> _initializeUserData() async {
    try {
      final authService = AuthService();
      final userData = await authService.getCurrentUser();
      if (userData != null && mounted) {
        setState(() {
          _userEmail = userData['email'];
          _accessToken = userData['accessToken'];
        });
        DebugLogService().info('WebView: Initialized with user email: $_userEmail');
        
        // Reload with headers and login hints if we have them
        if (_accessToken != null || _userEmail != null) {
          final urlWithHint = _addLoginHint(widget.formUrl, _userEmail);
          
          final headers = <String, String>{};
          // SECURITY: Only send Authorization header to trusted Google domains
          if (_accessToken != null && _isTrustedGoogleDomain(urlWithHint)) {
            headers['Authorization'] = 'Bearer $_accessToken';
            DebugLogService().info('WebView: Sending auth header to trusted domain');
          } else if (_accessToken != null) {
            DebugLogService().warning('WebView: NOT sending auth header to untrusted domain: $urlWithHint');
          }
          
          _controller.loadRequest(
            Uri.parse(urlWithHint),
            headers: headers,
          );
        }
      }
    } catch (e) {
      DebugLogService().error('Error getting user data for WebView: $e');
    }
  }

  String _addLoginHint(String url, String? email) {
    if (email == null || email.isEmpty) return url;
    try {
      final uri = Uri.parse(url);
      final params = Map<String, String>.from(uri.queryParameters);
      
      // Add Google-specific login hints
      params['login_hint'] = email;
      params['Email'] = email;
      // authuser=email is often used by Google for multi-account sessions
      params['authuser'] = email;
      
      return uri.replace(queryParameters: params).toString();
    } catch (e) {
      return url;
    }
  }

  @override
  void dispose() {
    _urlCheckTimer?.cancel();
    super.dispose();
  }

  /// Start a periodic timer to check if we've navigated to the form page
  /// This helps catch cases where onPageFinished doesn't fire or we're on a security page
  void _startUrlCheckTimer() {
    _urlCheckTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (_extractedHtml != null || !mounted) {
        timer.cancel();
        return;
      }
      
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      try {
        final currentUrl = await _controller.currentUrl();
        if (currentUrl != null && _isFormPage(currentUrl) && mounted) {
          DebugLogService().info('URL check timer: Detected form page, extracting...');
          timer.cancel();
          if (mounted) {
            await _extractFormHtml();
          }
        }
      } catch (e) {
        // Ignore errors during URL check
        if (!mounted) {
          timer.cancel();
        }
      }
    });
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            final isForm = _isFormPage(url);
            setState(() {
              // Only show full loading overlay for form pages or if we're already extracting
              _isLoading = isForm || _isExtracting;
              _errorMessage = null; 
              _loadingMessage = isForm ? 'Fetching form...' : 'Loading...';
            });
            DebugLogService().info('WebView: Page started loading - $url (isForm: $isForm)');
            AppLoggerService().logRouteChange('WebView: $url');
          },
          onPageFinished: (String url) async {
            setState(() {
              _loadingMessage = 'Form fetched - extracting form to make you work easy';
            });
            DebugLogService().info('WebView: Page finished loading - $url');
            AppLoggerService().logRouteChange('WebView finished: $url');
            
            // Wait a bit for dynamic content to load
            await Future.delayed(const Duration(seconds: 2));
            
            // Check for "prompt expired" or error pages
            try {
              final pageText = await _controller.runJavaScriptReturningResult('document.body.innerText');
              if (pageText != null) {
                final text = pageText.toString().toLowerCase();
                if (text.contains('prompt has expired') || 
                    text.contains('this prompt has expired') ||
                    text.contains('session expired')) {
                  DebugLogService().warning('Detected expired prompt - user may need to retry');
                  // Don't show error, just log it - user can reload
                }
              }
            } catch (e) {
              // Ignore errors checking page content
            }
            
            // Check if we're on the actual form page (not sign-in, security checkup, or password change pages)
            if (_isFormPage(url)) {
              DebugLogService().info('Detected form page, starting extraction...');
              setState(() {
                _loadingMessage = 'Form fetched - extracting form to make you work easy';
              });
              // Wait a bit more for the form to fully render and JavaScript to initialize
              await Future.delayed(const Duration(seconds: 3));
              // Automatically extract the form HTML if not already done
              if (!_htmlCompleter.isCompleted && !_isExtracting) {
                await _extractFormHtml();
              }
            } else if (_isSecurityOrAccountPage(url)) {
              // We're on a security checkup, password change, or account selection page
              // These pages should eventually redirect to the form, so we just wait
              DebugLogService().info('WebView: On security/account page, waiting for redirect to form...');
              setState(() {
                _isLoading = false; // Allow user to interact with security pages
                _loadingMessage = 'Authenticating...';
              });
            } else if (url.contains('accounts.google.com') || url.contains('signin')) {
              // We're on a sign-in page, wait for user to complete sign-in
              DebugLogService().info('WebView: On sign-in page, waiting for user action...');
              
              // Try to inject email if we have it and it's not already filled
              if (_userEmail != null && url.contains('identifier')) {
                _controller.runJavaScript('''
                  (function() {
                    const emailInput = document.querySelector('input[type="email"]');
                    if (emailInput && !emailInput.value) {
                      emailInput.value = '$_userEmail';
                      // Try to click next
                      const nextButton = document.querySelector('#identifierNext');
                      if (nextButton) nextButton.click();
                    }
                  })();
                ''');
              }
              
              setState(() {
                _isLoading = false; // IMPORTANT: Allow user to interact with sign-in page
                _loadingMessage = 'Signing in...';
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            DebugLogService().error('WebView error: ${error.description} (code: ${error.errorCode})');
            AppLoggerService().logError('WebView resource error', Exception('${error.description} (code: ${error.errorCode})'));
            
            // Some error codes are recoverable or expected during navigation
            // -2: ERROR_HOST_LOOKUP (DNS failure)
            // -6: ERROR_CONNECT (connection failure)
            // -8: ERROR_TIMEOUT
            // -14: ERROR_PROXY_AUTHENTICATION_REQUIRED
            // -1: ERR_FAILED (generic failure, often occurs when app goes to background)
            // Only show critical errors immediately, and be lenient with network errors
            if (error.errorCode == -2 || error.errorCode == -6 || error.errorCode == -8 || error.errorCode == -1) {
              // Network errors or generic failures - might be temporary (e.g., app went to background)
              // Wait a bit and check if page is still loading
              Future.delayed(const Duration(seconds: 2), () async {
                if (mounted && _errorMessage == null && _extractedHtml == null) {
                  // Check if we can still access the current URL (page might have loaded)
                  try {
                    final currentUrl = await _controller.currentUrl();
                    if (currentUrl != null && currentUrl.isNotEmpty) {
                      // Page is accessible, might have been a transient error
                      DebugLogService().info('Page is accessible after error, continuing...');
                      return;
                    }
                  } catch (e) {
                    // Can't access URL, show error
                  }
                  
                  // Only show error if page is truly not accessible
                  if (mounted) {
                    setState(() {
                      _errorMessage = 'Network error: ${error.description}\n\nPlease check your internet connection and try again.';
                      _isLoading = false;
                    });
                  }
                }
              });
            } else {
              // Other errors - show immediately
              if (mounted) {
                setState(() {
                  _errorMessage = 'Failed to load page: ${error.description}';
                  _isLoading = false;
                });
              }
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            DebugLogService().info('WebView: Navigation requested to ${request.url}');
            // Allow all navigation
            return NavigationDecision.navigate;
          },
        ),
      )
      ..addJavaScriptChannel(
        'HtmlExtractor',
        onMessageReceived: (JavaScriptMessage message) {
          final html = message.message;
          if (html.isNotEmpty && !_htmlCompleter.isCompleted && mounted) {
            DebugLogService().info('Received HTML via JavaScriptChannel (${html.length} chars)');
            if (mounted) {
              setState(() {
                _extractedHtml = html;
                _isExtracting = false;
                _isLoading = false;
                _loadingMessage = 'Form extracted successfully!';
              });
            }
            _urlCheckTimer?.cancel();
            _htmlCompleter.complete(html);
            // Automatically close the WebView and return the HTML immediately
            if (mounted) {
              Navigator.of(context).pop(html);
            }
          }
        },
      );
    
    // Load the URL
    _controller.loadRequest(Uri.parse(widget.formUrl));
  }

  Future<void> _extractFormHtml() async {
    if (_isExtracting) {
      DebugLogService().info('Extraction already in progress, skipping...');
      return;
    }
    
    try {
      setState(() {
        _isExtracting = true;
        _loadingMessage = 'Form fetched - extracting form to make you work easy';
      });
      
      // Wait a bit for the page to fully render and any dynamic content to load
      await Future.delayed(const Duration(seconds: 2));
      
      // First, check if we're actually on a form page
      final currentUrl = await _controller.currentUrl();
      if (currentUrl == null || !_isFormPage(currentUrl)) {
        DebugLogService().warning('Not on form page yet (current URL: $currentUrl), not extracting HTML');
        setState(() {
          _isExtracting = false;
        });
        return;
      }
      
      DebugLogService().info('Starting HTML extraction from form page: $currentUrl');
      
      // Wait for page to be fully loaded and JavaScript to execute
      // Check multiple times to ensure dynamic content is loaded
      bool hasFormContent = false;
      for (int attempt = 0; attempt < 5; attempt++) {
        final contentCheck = await _controller.runJavaScriptReturningResult('''
          (function() {
            if (!document.body) return false;
            
            // Check for Google Forms specific selectors
            const hasGoogleFormContent = (
              document.querySelector('.freebirdFormviewerViewFormContentWrapper') !== null ||
              document.querySelector('[data-viewid]') !== null ||
              document.querySelector('.freebirdFormviewerViewItemsItemItem') !== null ||
              document.querySelector('form[action*="forms"]') !== null ||
              document.querySelector('.freebirdFormviewerViewNavigationNavigateButton') !== null ||
              document.querySelector('.freebirdFormviewerViewItemsItemItemTitle') !== null ||
              document.querySelector('[data-params]') !== null
            );
            
            // Check for Google Forms data in script tags
            const hasFormData = (function() {
              const scripts = document.querySelectorAll('script');
              for (let i = 0; i < scripts.length; i++) {
                if (scripts[i].innerHTML && scripts[i].innerHTML.includes('FB_PUBLIC_LOAD_DATA')) {
                  return true;
                }
              }
              return false;
            })();
            
            // Check for generic form indicators
            const hasGenericForm = (
              document.querySelector('form') !== null ||
              document.querySelector('[role="form"]') !== null
            );
            
            // Check page title for form indicators
            const title = document.title.toLowerCase();
            const hasFormTitle = title.includes('form') || title.includes('survey') || title.includes('questionnaire');
            
            return hasGoogleFormContent || hasFormData || (hasGenericForm && hasFormTitle);
          })();
        ''');
        
        if (contentCheck != null && contentCheck.toString().toLowerCase() == 'true') {
          hasFormContent = true;
          DebugLogService().info('Form content detected on attempt ${attempt + 1}');
          break;
        }
        
        if (attempt < 4) {
          DebugLogService().info('Form content not yet detected, waiting... (attempt ${attempt + 1}/5)');
          await Future.delayed(const Duration(seconds: 2));
        }
      }
      
      if (!hasFormContent) {
        DebugLogService().warning('Form content not detected after multiple attempts, proceeding anyway...');
      }
      
      // Additional wait to ensure all JavaScript has executed and DOM is ready
      await Future.delayed(const Duration(seconds: 2));
      
      // Use JavaScriptChannel to extract HTML (more reliable for large HTML)
      // First, check if the channel is available
      final channelCheck = await _controller.runJavaScriptReturningResult('''
        (function() {
          return typeof HtmlExtractor !== 'undefined';
        })();
      ''');
      
      if (channelCheck != null && channelCheck.toString().toLowerCase() == 'true') {
        DebugLogService().info('JavaScriptChannel is available, using it for extraction...');
        // Inject JavaScript that sends HTML via the channel
        await _controller.runJavaScript('''
          (function() {
            try {
              // Extract the essential parts of the form
              // First, look for the Google Forms data variable
              let formData = "";
              const scripts = document.querySelectorAll('script');
              for (let i = 0; i < scripts.length; i++) {
                if (scripts[i].innerHTML && scripts[i].innerHTML.includes('FB_PUBLIC_LOAD_DATA')) {
                  formData = scripts[i].innerHTML;
                  break;
                }
              }

              // Create a simplified version of the body
              const bodyClone = document.body.cloneNode(true);
              
              // Remove non-essential heavy tags
              const tagsToRemove = ['svg', 'iframe', 'noscript', 'canvas', 'video', 'audio', 'footer', 'nav'];
              tagsToRemove.forEach(tag => {
                const elements = bodyClone.querySelectorAll(tag);
                elements.forEach(el => el.remove());
              });
              
              // Remove comments and hidden elements to save space
              const iterator = document.createNodeIterator(bodyClone, NodeFilter.SHOW_COMMENT, null, false);
              let node;
              while (node = iterator.nextNode()) {
                node.parentNode.removeChild(node);
              }

              const cleanHtml = "<!-- GOOGLE_FORM_DATA_START -->" + formData + "<!-- GOOGLE_FORM_DATA_END -->" + bodyClone.innerHTML;
              
              if (cleanHtml && cleanHtml.length > 100) {
                console.log('Sending cleaned HTML via JavaScriptChannel, length: ' + cleanHtml.length);
                HtmlExtractor.postMessage(cleanHtml);
              } else {
                // Fallback to basic outerHTML if cleaning failed
                HtmlExtractor.postMessage(document.documentElement.outerHTML);
              }
            } catch(e) {
              console.error('HTML extraction error: ' + e.message);
              // Final fallback
              try { HtmlExtractor.postMessage(document.documentElement.outerHTML); } catch(e2) {}
            }
          })();
        ''');
        
        // Wait a bit for the JavaScriptChannel message to be received
        // The HTML will be set via the channel callback
        await Future.delayed(const Duration(seconds: 3));
      } else {
        DebugLogService().warning('JavaScriptChannel not available, using fallback method...');
      }
      
      // If HTML wasn't received via channel, try fallback method
      if (_extractedHtml == null) {
        DebugLogService().warning('HTML not received via channel, trying fallback method...');
        // Fallback: Try to get HTML using base64 encoding to avoid string length issues
        final htmlBase64 = await _controller.runJavaScriptReturningResult('''
          (function() {
            try {
              const html = document.documentElement.outerHTML;
              return btoa(html);
            } catch(e) {
              return '';
            }
          })();
        ''');
        
        if (htmlBase64 != null && htmlBase64.toString().isNotEmpty) {
          try {
            // Decode base64
            final htmlBytes = base64Decode(htmlBase64.toString().replaceAll('"', '').replaceAll("'", ''));
            final htmlString = utf8.decode(htmlBytes);
            
            if (htmlString.length > 100 && htmlString.contains('<html')) {
              if (mounted) {
                setState(() {
                  _extractedHtml = htmlString;
                  _isExtracting = false;
                });
              }
              
              DebugLogService().success('Successfully extracted HTML via fallback method (${htmlString.length} chars)');
              AppLoggerService().logFormAction('Form HTML extracted from WebView (fallback)', 
                details: {'htmlLength': htmlString.length});
              
              if (!_htmlCompleter.isCompleted) {
                _urlCheckTimer?.cancel();
                _htmlCompleter.complete(htmlString);
                Future.delayed(const Duration(milliseconds: 800), () {
                  if (mounted) {
                    Navigator.of(context).pop(htmlString);
                  }
                });
              }
            }
          } catch (e) {
            DebugLogService().error('Error decoding base64 HTML: $e');
          }
        }
      }
      
      if (_extractedHtml == null) {
        DebugLogService().error('Failed to extract HTML - all methods failed');
        if (mounted) {
          setState(() {
            _isExtracting = false;
          });
        }
      }
    } catch (e, stackTrace) {
      DebugLogService().error('Error extracting HTML: $e');
      AppLoggerService().logError('HTML extraction error', e);
      if (mounted) {
        setState(() {
          _isExtracting = false;
        });
      }
      if (!_htmlCompleter.isCompleted) {
        _htmlCompleter.completeError(e);
      }
    }
  }

  Future<String?> getExtractedHtml() => _htmlCompleter.future;

  /// Verify if the URL is a trusted Google Forms page
  bool _isFormPage(String url) {
    try {
      final uri = Uri.parse(url);
      // Strict host check to prevent bypasses like attacker.com/docs.google.com/forms
      final host = uri.host.toLowerCase();
      if (host != 'docs.google.com' && host != 'forms.gle') {
        return false;
      }
      
      // Must NOT be an accounts/sign-in page
      if (url.contains('accounts.google.com') || 
          url.contains('signin') || 
          url.contains('ServiceLogin') ||
          url.contains('InteractiveLogin')) {
        return false;
      }
      
      // Check for security/account pages
      if (_isSecurityOrAccountPage(url)) {
        return false;
      }
      
      // Should contain viewform or edit in the path
      return url.contains('/viewform') || url.contains('/edit');
    } catch (e) {
      return false;
    }
  }

  /// Verify if the host is a trusted Google domain for sending tokens
  bool _isTrustedGoogleDomain(String url) {
    try {
      final uri = Uri.parse(url);
      final host = uri.host.toLowerCase();
      // Only send tokens to official Google domains
      return host == 'docs.google.com' || 
             host == 'accounts.google.com' || 
             host.endsWith('.google.com');
    } catch (e) {
      return false;
    }
  }

  /// Check if the current URL is a security or account management page
  bool _isSecurityOrAccountPage(String url) {
    return url.contains('security') || 
           url.contains('changepassword') || 
           url.contains('speedbump') ||
           url.contains('CheckCook') ||
           url.contains('challenge') ||
           url.contains('myaccount.google.com');
  }

  /// Check if the current URL is a password challenge page
  bool _isPasswordPage(String url) {
    return url.contains('challenge/pwd') || url.contains('password');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSignInOrSecurity = _controller.currentUrl().then((url) => url != null && !_isFormPage(url)).catchError((_) => true);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_isFormPage(widget.formUrl) ? 'Analyzing Form' : 'Sign in to Google'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (!_htmlCompleter.isCompleted) {
              _htmlCompleter.complete(null);
            }
            Navigator.of(context).pop();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _errorMessage = null;
                _extractedHtml = null;
                _isLoading = true;
                _loadingMessage = 'Fetching form...';
              });
              _controller.reload();
            },
            tooltip: 'Retry',
          ),
        ],
      ),
      body: Stack(
        children: [
          // WebView is visible when not extracting and not showing error
          WebViewWidget(controller: _controller),
          
          // Loading overlay - only shown when explicitly loading or extracting
          if (_isLoading || _isExtracting)
            Container(
              width: double.infinity,
              height: double.infinity,
              color: theme.scaffoldBackgroundColor.withOpacity(0.9),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        _loadingMessage,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (_isExtracting) ...[
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'Analyzing form structure...',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
          // Helper overlay for sign-in (if not on form page and not loading)
          FutureBuilder<String?>(
            future: _controller.currentUrl(),
            builder: (context, snapshot) {
              final url = snapshot.data;
              if (url != null && !_isFormPage(url) && !_isLoading && !_isExtracting && _errorMessage == null) {
                final isPasswordPage = _isPasswordPage(url);
                return Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: isPasswordPage ? Colors.amber.shade100 : theme.colorScheme.primaryContainer,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: Row(
                      children: [
                        Icon(
                          isPasswordPage ? Icons.security : Icons.lock_outline, 
                          size: 16, 
                          color: isPasswordPage ? Colors.amber.shade900 : theme.colorScheme.onPrimaryContainer
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isPasswordPage 
                              ? 'Google requires your password for security. You will only need to do this once.'
                              : 'Please sign in to access this restricted Google Form.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isPasswordPage ? Colors.amber.shade900 : theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),

          if (_errorMessage != null)
            Container(
              color: theme.scaffoldBackgroundColor,
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () {
                        setState(() {
                          _errorMessage = null;
                          _isLoading = true;
                        });
                        _controller.reload();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF333333),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

