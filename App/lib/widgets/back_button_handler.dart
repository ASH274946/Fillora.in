import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../services/app_logger_service.dart';

class BackButtonHandler extends StatelessWidget {
  final Widget child;
  static const MethodChannel _channel = MethodChannel('fillora.app/background');

  const BackButtonHandler({
    super.key,
    required this.child,
  });

  static Future<void> _handleBackButton(BuildContext context) async {
    final router = GoRouter.of(context);

    String currentLocation;
    String? queryParam;
    try {
      final uri = router.routerDelegate.currentConfiguration.uri;
      currentLocation = uri.path;
      queryParam = uri.queryParameters['from'];
    } catch (e) {
      currentLocation = router.routerDelegate.currentConfiguration.uri.toString();
      if (currentLocation.contains('?')) {
        currentLocation = currentLocation.split('?').first;
      }
      queryParam = null;
    }

    AppLoggerService().logUserInteraction('Back button pressed',
      details: 'From: $currentLocation');

    // Let GoRouter handle the back stack when possible
    if (router.canPop()) {
      router.pop();
      return;
    }

    String? targetRoute;

    if (currentLocation == '/dashboard') {
      // Dashboard: move to background instead of closing
      AppLoggerService().logAppLifecycle('App moving to background');
      try {
        await _channel.invokeMethod('moveToBackground');
      } catch (e) {
        debugPrint('Method channel error: $e');
        SystemNavigator.pop();
      }
      return;
    } else if (currentLocation == '/onboarding' ||
               currentLocation == '/signin' ||
               currentLocation == '/signup') {
      AppLoggerService().logAppLifecycle('App closing');
      SystemNavigator.pop();
      return;
    } else if (currentLocation == '/conversational-form' ||
               currentLocation == '/review') {
      if (queryParam == 'templates') {
        targetRoute = '/templates';
      } else if (queryParam == 'form-selection' || queryParam == 'url') {
        targetRoute = '/form-selection';
      } else if (queryParam == 'history') {
        targetRoute = '/history';
      } else if (queryParam == 'dashboard') {
        targetRoute = '/dashboard';
      } else {
        targetRoute = '/document-upload';
      }
    } else if (currentLocation == '/form-selection') {
      targetRoute = '/templates';
    } else if (currentLocation == '/document-upload') {
      targetRoute = '/form-selection';
    } else {
      // Shell tab routes (templates, history, settings) and anything else: go to dashboard
      targetRoute = '/dashboard';
    }

    if (targetRoute != null) {
      AppLoggerService().logNavigation(currentLocation, targetRoute);
      router.go(targetRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Wrap the child with PopScope to intercept back button
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          await _handleBackButton(context);
        }
      },
      child: child,
    );
  }
}
