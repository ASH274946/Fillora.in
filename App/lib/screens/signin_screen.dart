import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../services/app_logger_service.dart';
import '../widgets/app_snackbar.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                // Logo
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 80,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'Welcome Back',
                  style: theme.textTheme.displaySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in to continue to Fillora',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                // Email Field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                // Password Field
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                // Forgot Password
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) {
                          final emailController = TextEditingController(text: _emailController.text);
                          return AlertDialog(
                            title: const Text('Reset Password'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Enter your email to receive a password reset link.'),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: emailController,
                                  decoration: const InputDecoration(
                                    labelText: 'Email',
                                    prefixIcon: Icon(Icons.email_outlined),
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  AppSnackBar.show(context, 'Password reset email sent!');
                                },
                                child: const Text('Send'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    child: const Text('Forgot Password?'),
                  ),
                ),
                const SizedBox(height: 32),
                // Login Button
                FilledButton(
                  onPressed: _isLoading ? null : () async {
                    if (_formKey.currentState!.validate()) {
                      setState(() => _isLoading = true);
                      AppLoggerService().logAuth('Email sign-in attempted', provider: 'email');
                      try {
                        final result = await _authService.signInWithEmail(
                          _emailController.text.trim(),
                          _passwordController.text,
                        );
                        
                        if (!mounted) return;
                        
                        if (result['success'] == true) {
                          AppLoggerService().logAuth('Email sign-in successful', provider: 'email', success: true);
                          AppSnackBar.show(context, 'Signed in successfully!');
                          await Future.delayed(const Duration(milliseconds: 500));
                          if (mounted) {
                            context.go('/dashboard');
                          }
                        } else {
                          AppLoggerService().logAuth('Email sign-in failed', provider: 'email', success: false);
                          AppSnackBar.show(context, 'Error: ${result['error'] ?? 'Sign in failed'}', isError: true);
                        }
                      } catch (e) {
                        AppLoggerService().logError('Email sign-in', e);
                        if (!mounted) return;
                        AppSnackBar.show(context, 'Error: ${e.toString()}', isError: true);
                      } finally {
                        if (mounted) {
                          setState(() => _isLoading = false);
                        } 
                      }
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.brightness == Brightness.dark
                        ? theme.colorScheme.surface
                        : theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Sign In',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
                const SizedBox(height: 16),
                // Sign Up Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        "Don't have an account? ",
                        style: theme.textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/signup'),
                      child: const Text('Sign Up'),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                // Social Login
                Row(
                  children: [
                    Expanded(
                      child: Divider(color: theme.dividerColor),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'OR',
                        style: theme.textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      child: Divider(color: theme.dividerColor),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _SocialButton(
                      icon: Icons.g_mobiledata,
                      onTap: _isLoading ? null : () async {
                        await _handleGoogleSignIn();
                      },
                    ),
                    const SizedBox(width: 16),
                    _SocialButton(
                      icon: Icons.facebook,
                      onTap: _isLoading ? null : () async {
                        await _handleFacebookSignIn();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    AppLoggerService().logAuth('Google sign-in attempted', provider: 'google');
    try {
      final result = await _authService.signInWithGoogle();
      if (!mounted) return;

      if (result != null && result['success'] == true) {
        AppLoggerService().logAuth('Google sign-in successful', provider: 'google', success: true);
        AppSnackBar.show(context, 'Signed in with Google successfully!');
        context.go('/dashboard');
      } else if (result != null) {
        AppLoggerService().logAuth('Google sign-in failed', provider: 'google', success: false);
        AppSnackBar.show(context, 'Error: ${result['error'] ?? 'Sign in failed'}', isError: true);
      } else {
        AppLoggerService().logAuth('Google sign-in cancelled', provider: 'google');
      }
    } catch (e) {
      AppLoggerService().logError('Google sign-in', e);
      if (!mounted) return;
      AppSnackBar.show(context, 'Error: ${e.toString()}', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleFacebookSignIn() async {
    setState(() => _isLoading = true);
    AppLoggerService().logAuth('Facebook sign-in attempted', provider: 'facebook');
    try {
      final result = await _authService.signInWithFacebook();
      if (!mounted) return;

      if (result != null && result['success'] == true) {
        AppLoggerService().logAuth('Facebook sign-in successful', provider: 'facebook', success: true);
        AppSnackBar.show(context, 'Signed in with Facebook successfully!');
        context.go('/dashboard');
      } else if (result != null) {
        AppLoggerService().logAuth('Facebook sign-in failed', provider: 'facebook', success: false);
        AppSnackBar.show(context, 'Error: ${result['error'] ?? 'Sign in failed'}', isError: true);
      } else {
        AppLoggerService().logAuth('Facebook sign-in cancelled', provider: 'facebook');
      }
    } catch (e) {
      AppLoggerService().logError('Facebook sign-in', e);
      if (!mounted) return;
      AppSnackBar.show(context, 'Error: ${e.toString()}', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _SocialButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: theme.dividerColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 32),
      ),
    );
  }
}
