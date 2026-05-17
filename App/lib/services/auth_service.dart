import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );
  
  final _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // Get current user
  GoogleSignInAccount? get currentGoogleUser => _googleSignIn.currentUser;
  
  // Check if user is signed in
  bool get isSignedIn => _googleSignIn.currentUser != null;

  /// Sign in with Google
  Future<Map<String, dynamic>?> signInWithGoogle() async {
    try {
      print('Starting Google Sign-In...');
      
      // Try to sign out first if there's a cached account to avoid conflicts
      try {
        await _googleSignIn.signOut();
        print('Signed out from previous Google account');
      } catch (e) {
        print('Note: Could not sign out (might not be signed in): $e');
      }

      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      
      if (account == null) {
        print('User cancelled Google Sign-In');
        return null; // User cancelled
      }

      print('Google account selected: ${account.email}');
      print('Getting authentication tokens...');

      final GoogleSignInAuthentication auth = await account.authentication;
      
      print('Authentication tokens received');
      print('Saving user data...');
      
      // Save user data
      await _saveUserData({
        'provider': 'google',
        'id': account.id,
        'email': account.email ?? '',
        'name': account.displayName ?? '',
        'photoUrl': account.photoUrl,
        'idToken': auth.idToken,
        'accessToken': auth.accessToken,
      });

      print('User data saved successfully');
      print('Verifying authentication state...');
      
      // Verify authentication was saved
      final isAuth = await isAuthenticated();
      print('Authentication state: $isAuth');

      return {
        'success': true,
        'provider': 'google',
        'user': {
          'id': account.id,
          'email': account.email ?? '',
          'name': account.displayName ?? '',
          'photoUrl': account.photoUrl,
        },
        'idToken': auth.idToken,
        'accessToken': auth.accessToken,
      };
    } catch (e, stackTrace) {
      print('Error signing in with Google: $e');
      print('Stack trace: $stackTrace');
      
      // Provide more helpful error messages
      String errorMessage = e.toString();
      if (errorMessage.contains('DEVELOPER_ERROR')) {
        errorMessage = 'Google Sign-In configuration error. Please check your Google Cloud Console settings and SHA-1 certificate.';
      } else if (errorMessage.contains('SIGN_IN_REQUIRED')) {
        errorMessage = 'Please sign in with your Google account.';
      } else if (errorMessage.contains('network')) {
        errorMessage = 'Network error. Please check your internet connection.';
      }
      
      return {
        'success': false,
        'error': errorMessage,
      };
    }
  }

  /// Sign in with Facebook
  Future<Map<String, dynamic>?> signInWithFacebook() async {
    try {
      // Trigger the sign-in flow
      final LoginResult result = await FacebookAuth.instance.login(
        permissions: ['email', 'public_profile'],
      );

      if (result.status == LoginStatus.success) {
        // Get the access token
        final AccessToken accessToken = result.accessToken!;
        
        // Get user data
        final userData = await FacebookAuth.instance.getUserData(
          fields: 'email,name,picture.width(200)',
        );

        // Save user data
        await _saveUserData({
          'provider': 'facebook',
          'id': userData['id'],
          'email': userData['email'],
          'name': userData['name'],
          'photoUrl': userData['picture']?['data']?['url'],
          'accessToken': accessToken.tokenString,
        });

        return {
          'success': true,
          'provider': 'facebook',
          'user': {
            'id': userData['id'],
            'email': userData['email'],
            'name': userData['name'],
            'photoUrl': userData['picture']?['data']?['url'],
          },
          'accessToken': accessToken.tokenString,
        };
      } else if (result.status == LoginStatus.cancelled) {
        return null; // User cancelled
      } else {
        return {
          'success': false,
          'error': result.message ?? 'Facebook login failed',
        };
      }
    } catch (e) {
      print('Error signing in with Facebook: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      // Sign out from Google
      if (_googleSignIn.currentUser != null) {
        await _googleSignIn.signOut();
      }

      // Sign out from Facebook
      await FacebookAuth.instance.logOut();

      // Clear saved user data
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_data');
      await prefs.remove('auth_provider');
      await prefs.setBool('is_signed_in', false);
      
      // Clear secure storage
      await _secureStorage.deleteAll();
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  /// Get current user data
  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataJson = prefs.getString('user_data');
      if (userDataJson != null) {
        final Map<String, dynamic> userData = json.decode(userDataJson);
        
        // Enrich with tokens from secure storage
        final accessToken = await _secureStorage.read(key: 'access_token');
        final idToken = await _secureStorage.read(key: 'id_token');
        
        if (accessToken != null) userData['accessToken'] = accessToken;
        if (idToken != null) userData['idToken'] = idToken;
        
        return userData;
      }
      
      // If no saved data but Google user is signed in, get from Google
      if (_googleSignIn.currentUser != null) {
        final account = _googleSignIn.currentUser!;
        final auth = await account.authentication;
        return {
          'provider': 'google',
          'id': account.id,
          'email': account.email ?? '',
          'name': account.displayName ?? '',
          'photoUrl': account.photoUrl,
          'idToken': auth.idToken,
          'accessToken': auth.accessToken,
        };
      }
      
      return null;
    } catch (e) {
      print('Error getting current user: $e');
      return null;
    }
  }

  /// Save user data locally
  Future<void> _saveUserData(Map<String, dynamic> userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_provider', userData['provider'] ?? '');
      // SECURITY: Extract sensitive tokens and save to secure storage
      if (userData.containsKey('accessToken')) {
        await _secureStorage.write(key: 'access_token', value: userData['accessToken']);
      }
      if (userData.containsKey('idToken')) {
        await _secureStorage.write(key: 'id_token', value: userData['idToken']);
      }
      
      // Create a copy without sensitive tokens for plain preferences
      final safeUserData = Map<String, dynamic>.from(userData);
      safeUserData.remove('accessToken');
      safeUserData.remove('idToken');
      
      // Save non-sensitive user data as JSON
      final userDataJson = json.encode(safeUserData);
      await prefs.setString('user_data', userDataJson);
      
      // Mark as authenticated
      await prefs.setBool('is_signed_in', true);
      
      // Save member since date if not already set
      if (!prefs.containsKey('member_since')) {
        await prefs.setString('member_since', DateTime.now().toIso8601String());
      }
    } catch (e) {
      print('Error saving user data: $e');
    }
  }
  
  /// Update user profile data
  Future<void> updateUserProfile(Map<String, dynamic> updates) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataJson = prefs.getString('user_data');
      
      Map<String, dynamic> currentUser;
      if (userDataJson != null) {
        currentUser = json.decode(userDataJson) as Map<String, dynamic>;
      } else {
        // If no user data exists, create a new one
        currentUser = {
          'provider': 'email',
          'id': '',
          'email': '',
          'name': '',
        };
      }
      
      // Update with new values
      currentUser.addAll(updates);
      
      // Save updated user data using _saveUserData to ensure proper auth state
      await _saveUserData(currentUser);
    } catch (e) {
      print('Error updating user profile: $e');
      rethrow;
    }
  }

  /// Sign in with email/password (basic implementation for demo)
  Future<Map<String, dynamic>> signInWithEmail(String email, String password) async {
    try {
      // Basic email sign-in - just save user data locally
      // In production, this would validate against a backend
      await _saveUserData({
        'provider': 'email',
        'id': email.hashCode.toString(),
        'email': email.trim(),
        'name': email.trim().split('@').first,
      });

      return {
        'success': true,
        'provider': 'email',
        'user': {
          'email': email.trim(),
          'name': email.trim().split('@').first,
        },
      };
    } catch (e) {
      print('Error signing in with email: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isSignedIn = prefs.getBool('is_signed_in') ?? false;
      
      // Also check if Google user is signed in (for consistency)
      final googleUser = _googleSignIn.currentUser;
      
      // Return true if either local auth or Google auth is active
      return isSignedIn || googleUser != null;
    } catch (e) {
      print('Error checking authentication: $e');
      return false;
    }
  }
}

