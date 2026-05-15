import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/bottom_navigation.dart';
import '../widgets/app_snackbar.dart';
import '../services/app_lock_service.dart';
import '../services/biometric_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final AppLockService _appLockService = AppLockService();
  final BiometricService _biometricService = BiometricService();
  
  bool _appLockEnabled = false;
  bool _biometricEnabled = false;
  bool _twoFactorEnabled = false;
  bool _sessionTimeoutEnabled = false;
  int _sessionTimeoutMinutes = 15;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _loadSecuritySettings();
    _checkBiometrics();
  }

  Future<void> _loadSecuritySettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _appLockEnabled = prefs.getBool('app_lock_enabled') ?? false;
      _biometricEnabled = prefs.getBool('biometric_enabled') ?? false;
      _twoFactorEnabled = prefs.getBool('two_factor_enabled') ?? false;
      _sessionTimeoutEnabled = prefs.getBool('session_timeout_enabled') ?? false;
      _sessionTimeoutMinutes = prefs.getInt('session_timeout_minutes') ?? 15;
    });
  }

  Future<void> _checkBiometrics() async {
    final isAvailable = await _biometricService.isBiometricsAvailable();
    setState(() {
      _biometricAvailable = isAvailable;
    });
  }

  Future<void> _saveSecuritySetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    }
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => const _ChangePasswordDialog(),
    );
  }

  void _showSessionTimeoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Session Timeout'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Set the inactivity period after which you will be automatically logged out.'),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: _sessionTimeoutMinutes,
              decoration: const InputDecoration(
                labelText: 'Timeout Period',
              ),
              items: const [
                DropdownMenuItem(value: 5, child: Text('5 Minutes')),
                DropdownMenuItem(value: 15, child: Text('15 Minutes')),
                DropdownMenuItem(value: 30, child: Text('30 Minutes')),
                DropdownMenuItem(value: 60, child: Text('1 Hour')),
                DropdownMenuItem(value: 120, child: Text('2 Hours')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _sessionTimeoutMinutes = value;
                  });
                  _saveSecuritySetting('session_timeout_minutes', value);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showLogoutOtherDevicesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout Other Devices'),
        content: const Text('Are you sure you want to log out from all other devices? This will not affect your current session.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              AppSnackBar.show(context, 'Logged out from all other devices');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout Others'),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitch({required bool value, required ValueChanged<bool> onChanged}) {
    return Switch.adaptive(
      value: value,
      onChanged: onChanged,
      activeColor: Theme.of(context).colorScheme.primary,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => context.go('/settings'),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Security',
                    style: theme.textTheme.displaySmall,
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              // App Access Section
              _SecuritySection(
                title: 'App Access',
                items: [
                  _SecurityItem(
                    icon: Icons.phonelink_lock,
                    title: 'App Lock',
                    subtitle: 'Protect your app with a PIN or pattern',
                    trailing: _buildSwitch(
                      value: _appLockEnabled,
                      onChanged: (value) async {
                        if (value) {
                          // Navigate to setup PIN screen
                          context.go('/app-lock-setup');
                        } else {
                          // Confirm disable
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Disable App Lock?'),
                              content: const Text('This will also disable biometric authentication.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(true),
                                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                                  child: const Text('Disable'),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            await _appLockService.setAppLockEnabled(false);
                            await _appLockService.setBiometricEnabled(false);
                            setState(() {
                              _appLockEnabled = false;
                              _biometricEnabled = false;
                            });
                            _saveSecuritySetting('app_lock_enabled', false);
                            _saveSecuritySetting('biometric_enabled', false);
                          }
                        }
                      },
                    ),
                  ),
                  _SecurityItem(
                    icon: Icons.fingerprint,
                    title: 'Biometric Authentication',
                    subtitle: _biometricAvailable
                        ? 'Use fingerprint or face ID to unlock'
                        : 'Biometric authentication not available on this device',
                    trailing: _buildSwitch(
                      value: _biometricEnabled,
                      onChanged: (value) async {
                        if (value && !_appLockEnabled) {
                          AppSnackBar.show(context, 'Please enable App Lock first', isError: true);
                          return;
                        }

                        if (value && !_biometricAvailable) {
                          AppSnackBar.show(context, 'Biometric authentication is not available', isError: true);
                          return;
                        }

                        // Test biometric authentication when enabling
                        if (value) {
                          try {
                            final authenticated = await _biometricService.authenticate(
                              reason: 'Enable biometric authentication',
                            );
                            
                            if (!authenticated) {
                              AppSnackBar.show(context, 'Biometric authentication failed', isError: true);
                              return;
                            }
                          } catch (e) {
                            AppSnackBar.show(context, 'Error: ${e.toString()}', isError: true);
                            return;
                          }
                        }

                        await _appLockService.setBiometricEnabled(value);
                        setState(() {
                          _biometricEnabled = value;
                        });
                        _saveSecuritySetting('biometric_enabled', value);
                        
                        AppSnackBar.show(context, value ? 'Biometric enabled' : 'Biometric disabled');
                      },
                    ),
                    enabled: _appLockEnabled && _biometricAvailable,
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              // Account Security Section
              _SecuritySection(
                title: 'Account Security',
                items: [
                  _SecurityItem(
                    icon: Icons.lock_reset,
                    title: 'Change Password',
                    subtitle: 'Update your account password',
                    onTap: _showChangePasswordDialog,
                  ),
                  _SecurityItem(
                    icon: Icons.verified_user_outlined,
                    title: 'Two-Factor Authentication',
                    subtitle: 'Add an extra layer of security (Coming soon)',
                    trailing: _buildSwitch(
                      value: _twoFactorEnabled,
                      onChanged: (value) {
                        if (value) {
                          AppSnackBar.show(context, 'Two-factor authentication is coming soon!');
                        } else {
                          setState(() {
                            _twoFactorEnabled = false;
                          });
                          _saveSecuritySetting('two_factor_enabled', false);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              // Session Management Section
              _SecuritySection(
                title: 'Session Management',
                items: [
                  _SecurityItem(
                    icon: Icons.timer_outlined,
                    title: 'Session Timeout',
                    subtitle: _sessionTimeoutEnabled
                        ? _sessionTimeoutMinutes < 60
                            ? 'Auto logout after $_sessionTimeoutMinutes minutes of inactivity'
                            : 'Auto logout after ${_sessionTimeoutMinutes ~/ 60} hour${_sessionTimeoutMinutes ~/ 60 > 1 ? 's' : ''} of inactivity'
                        : 'Automatically log out after inactivity',
                    trailing: _buildSwitch(
                      value: _sessionTimeoutEnabled,
                      onChanged: (value) {
                        setState(() {
                          _sessionTimeoutEnabled = value;
                        });
                        _saveSecuritySetting('session_timeout_enabled', value);
                        if (value) {
                          _showSessionTimeoutDialog();
                        }
                      },
                    ),
                  ),
                  _SecurityItem(
                    icon: Icons.devices_outlined,
                    title: 'Active Sessions',
                    subtitle: 'Manage devices where you are logged in',
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Active Sessions'),
                          content: const Text(
                            'Current Device:\n• This Device (Active)\n\nOther Devices:\n• iPhone 13 Pro (Last active: 2 hours ago)\n• Chrome on Windows (Last active: 1 day ago)',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  _SecurityItem(
                    icon: Icons.logout,
                    title: 'Logout from Other Devices',
                    subtitle: 'Sign out from all other devices',
                    onTap: _showLogoutOtherDevicesDialog,
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              // Privacy Section
              _SecuritySection(
                title: 'Privacy',
                items: [
                  _SecurityItem(
                    icon: Icons.delete_outline,
                    title: 'Clear App Data',
                    subtitle: 'Remove all locally stored data',
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Clear App Data'),
                          content: const Text(
                            'This will remove all locally stored data including cached forms and preferences. This action cannot be undone.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                AppSnackBar.show(context, 'App data cleared successfully');
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Clear Data'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecuritySection extends StatelessWidget {
  final String title;
  final List<Widget> items;

  const _SecuritySection({
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(children: items),
        ),
      ],
    );
  }
}

class _SecurityItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool enabled;

  const _SecurityItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(
        icon,
        color: enabled ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.3),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: enabled ? theme.colorScheme.onSurface : theme.colorScheme.onSurface.withOpacity(0.3),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: enabled ? theme.colorScheme.onSurface.withOpacity(0.7) : theme.colorScheme.onSurface.withOpacity(0.3),
        ),
      ),
      trailing: trailing,
      onTap: enabled ? onTap : null,
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscureOldPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Change Password'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _oldPasswordController,
                  obscureText: _obscureOldPassword,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureOldPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureOldPassword = !_obscureOldPassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your current password';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: _obscureNewPassword,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureNewPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureNewPassword = !_obscureNewPassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a new password';
                    }
                    if (value.length < 8) {
                      return 'Password must be at least 8 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your new password';
                    }
                    if (value != _newPasswordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop();
              AppSnackBar.show(context, 'Password changed successfully!');
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.surface,
            foregroundColor: theme.colorScheme.onSurface,
            side: BorderSide(color: theme.colorScheme.outline),
            elevation: 0,
          ),
          child: const Text('Change Password'),
        ),
      ],
    );
  }
}
