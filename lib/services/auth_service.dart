import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:developer' as developer;

/// Web OAuth client ID from Firebase/Google Cloud (client_type 3).
const kGoogleWebClientId =
    '184273620099-l4h235ihfir7vhis48afpctsg9gidaii.apps.googleusercontent.com';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: const ['email', 'profile'],
    clientId: kIsWeb ? kGoogleWebClientId : null,
  );

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential?> signInWithGoogle() async {
    try {
      developer.log('Starting Google Sign-In process', name: 'AuthService');

      if (kIsWeb) {
        return _signInWithGoogleWeb();
      }

      return _signInWithGoogleMobile();
    } catch (e, stackTrace) {
      developer.log('Error signing in with Google: $e\n$stackTrace',
          name: 'AuthService');
      if (e is FirebaseAuthException) {
        developer.log('Firebase Auth Error Code: ${e.code}',
            name: 'AuthService');
        developer.log('Firebase Auth Error Message: ${e.message}',
            name: 'AuthService');
      }
      if (!kIsWeb) {
        try {
          await _googleSignIn.signOut();
        } catch (signOutError) {
          developer.log('Error signing out after failure: $signOutError',
              name: 'AuthService');
        }
      }
      rethrow;
    }
  }

  Future<UserCredential> _signInWithGoogleWeb() async {
    final provider = GoogleAuthProvider();
    provider.setCustomParameters({'prompt': 'select_account'});

    developer.log('Using Firebase signInWithPopup on web', name: 'AuthService');
    final userCredential = await _auth.signInWithPopup(provider);
    developer.log(
      'Firebase web sign-in successful: ${userCredential.user?.uid}',
      name: 'AuthService',
    );
    return userCredential;
  }

  Future<UserCredential?> _signInWithGoogleMobile() async {
    if (await _googleSignIn.isSignedIn()) {
      developer.log('User already signed in, signing out first',
          name: 'AuthService');
      await _googleSignIn.signOut();
    }

    developer.log('Attempting to trigger Google Sign-In flow',
        name: 'AuthService');
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

    if (googleUser == null) {
      developer.log('Google Sign-In cancelled by user', name: 'AuthService');
      return null;
    }

    developer.log(
      'Google Sign-In successful, user email: ${googleUser.email}',
      name: 'AuthService',
    );

    try {
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      developer.log(
        'Firebase sign-in successful: ${userCredential.user?.uid}',
        name: 'AuthService',
      );
      return userCredential;
    } catch (e, stackTrace) {
      developer.log('Error during Google authentication: $e\n$stackTrace',
          name: 'AuthService');
      await _googleSignIn.signOut();
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      developer.log('Starting sign out process', name: 'AuthService');
      if (kIsWeb) {
        await _auth.signOut();
      } else {
        await Future.wait([
          _googleSignIn.signOut(),
          _auth.signOut(),
        ]);
      }
      developer.log('Sign out successful', name: 'AuthService');
    } catch (e, stackTrace) {
      developer.log('Error signing out: $e\n$stackTrace', name: 'AuthService');
      rethrow;
    }
  }
}
