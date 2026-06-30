import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  User? _user;
  bool _isLoading = false;
  String? _error;

  AuthProvider() {
    _init();
  }

  void _init() {
    developer.log('Initializing AuthProvider', name: 'AuthProvider');
    _authService.authStateChanges.listen(
      (User? user) {
        developer.log('Auth state changed: ${user?.uid ?? 'null'}',
            name: 'AuthProvider');
        _user = user;
        notifyListeners();
      },
      onError: (error, stackTrace) {
        developer.log('Error in auth state stream: $error\n$stackTrace',
            name: 'AuthProvider');
        _error = error.toString();
        notifyListeners();
      },
    );
  }

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;

  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      developer.log('Starting Google Sign-In from provider',
          name: 'AuthProvider');
      final result = await _authService.signInWithGoogle();
      _isLoading = false;
      notifyListeners();

      if (result == null) {
        developer.log('Google Sign-In returned null result',
            name: 'AuthProvider');
        return false;
      }

      developer.log('Google Sign-In successful in provider',
          name: 'AuthProvider');
      return true;
    } catch (e, stackTrace) {
      developer.log('Error in signInWithGoogle: $e\n$stackTrace',
          name: 'AuthProvider');
      _isLoading = false;
      _error = _formatSignInError(e);
      notifyListeners();
      return false;
    }
  }

  String _formatSignInError(Object error) {
    final message = error.toString();
    if (message.contains('origin_mismatch') ||
        message.contains('Authorization Error')) {
      return 'Google Sign-In blocked: your site URL is not registered in '
          'Google Cloud Console. Add your app URL under Authorized JavaScript '
          'origins for the Web OAuth client (see Firebase/Google Cloud setup).';
    }
    if (error is FirebaseAuthException) {
      return error.message ?? error.code;
    }
    return message;
  }

  Future<void> signOut() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      developer.log('Starting sign out from provider', name: 'AuthProvider');
      await _authService.signOut();
      _isLoading = false;
      notifyListeners();
      developer.log('Sign out successful in provider', name: 'AuthProvider');
    } catch (e, stackTrace) {
      developer.log('Error in signOut: $e\n$stackTrace', name: 'AuthProvider');
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
    }
  }
}
