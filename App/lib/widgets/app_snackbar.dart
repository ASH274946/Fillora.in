import 'dart:ui';
import 'package:flutter/material.dart';

class AppSnackBar {
  static void show(BuildContext context, String message, {bool isError = false}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 96), // Positioned just above the nav bar
        content: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: (isError 
                    ? theme.colorScheme.error 
                    : theme.colorScheme.surface).withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: (isError 
                      ? theme.colorScheme.error 
                      : theme.colorScheme.onSurface).withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                    color: isError 
                        ? Colors.white 
                        : (isDark ? Colors.white : theme.colorScheme.primary),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: TextStyle(
                        color: isError 
                            ? Colors.white 
                            : (isDark ? Colors.white : Colors.black87),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
