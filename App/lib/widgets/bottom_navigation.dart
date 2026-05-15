import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/app_logger_service.dart';

class BottomNavigation extends StatelessWidget {
  final String? currentRoute;
  final StatefulNavigationShell? navigationShell;

  const BottomNavigation({
    super.key,
    this.currentRoute,
    this.navigationShell,
  });

  void _onTap(BuildContext context, int index) {
    if (navigationShell != null) {
      navigationShell!.goBranch(
        index,
        initialLocation: index == navigationShell!.currentIndex,
      );
    } else {
      // Fallback for non-shell navigation
      switch (index) {
        case 0:
          context.go('/dashboard');
          break;
        case 1:
          context.go('/templates');
          break;
        case 2:
          context.go('/history');
          break;
        case 3:
          context.go('/settings');
          break;
      }
    }
  }

  int _getCurrentIndex() {
    if (navigationShell != null) {
      return navigationShell!.currentIndex;
    }
    
    if (currentRoute == '/dashboard') return 0;
    if (currentRoute == '/templates') return 1;
    if (currentRoute == '/history') return 2;
    if (currentRoute == '/settings' || (currentRoute?.startsWith('/settings') ?? false)) return 3;
    
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final currentIndex = _getCurrentIndex();

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: bottomPadding > 0 ? bottomPadding + 8 : 20,
      ),
      child: Row(
        children: [
          // Main Navigation Pill
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(40),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  height: 70,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(
                      color: theme.colorScheme.onSurface.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _NavItem(
                        icon: Icons.home_rounded,
                        label: 'Home',
                        isActive: currentIndex == 0,
                        onTap: () => _onTap(context, 0),
                      ),
                      _NavItem(
                        icon: Icons.description_rounded,
                        label: 'Templates',
                        isActive: currentIndex == 1,
                        onTap: () => _onTap(context, 1),
                      ),
                      _NavItem(
                        icon: Icons.history_rounded,
                        label: 'History',
                        isActive: currentIndex == 2,
                        onTap: () => _onTap(context, 2),
                      ),
                      _NavItem(
                        icon: Icons.settings_rounded,
                        label: 'Settings',
                        isActive: currentIndex == 3,
                        onTap: () => _onTap(context, 3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Start New Form Button (Square on the right)
          _NewFormButton(
            onTap: () {
              AppLoggerService().logUserInteraction('FAB', details: 'New form');
              context.push('/form-selection');
            },
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (isActive) {
      // Pill style for active item
      return GestureDetector(
        onTap: onTap,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark 
                ? Colors.black 
                : theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Icon only style for inactive items
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Icon(
          icon,
          color: theme.colorScheme.onSurface.withOpacity(0.7),
          size: 22,
        ),
      ),
    );
  }
}

class _NewFormButton extends StatelessWidget {
  final VoidCallback onTap;

  const _NewFormButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withOpacity(0.7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.colorScheme.onSurface.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Icon(
              Icons.add_rounded,
              color: theme.colorScheme.onSurface,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}
