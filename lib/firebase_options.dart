import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBWKys0UDfToRQVQ4KCVJ6kp0wLFfbz4Tk',
    appId: '1:184273620099:web:c1b2fb337556adf158dfb6',
    messagingSenderId: '184273620099',
    projectId: 'assetto-7cad8',
    authDomain: 'assetto-7cad8.firebaseapp.com',
    storageBucket: 'assetto-7cad8.firebasestorage.app',
    databaseURL:
        'https://assetto-7cad8-default-rtdb.asia-southeast1.firebasedatabase.app',
    measurementId: 'G-T57Y47R3YR',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA5Xxjg1PeuH2noYmgOWSi85Rr0nzkldfY',
    appId: '1:184273620099:android:1f425a1374733bc058dfb6',
    messagingSenderId: '184273620099',
    projectId: 'assetto-7cad8',
    storageBucket: 'assetto-7cad8.firebasestorage.app',
    databaseURL:
        'https://assetto-7cad8-default-rtdb.asia-southeast1.firebasedatabase.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBWKys0UDfToRQVQ4KCVJ6kp0wLFfbz4Tk',
    appId: '1:184273620099:web:c1b2fb337556adf158dfb6',
    messagingSenderId: '184273620099',
    projectId: 'assetto-7cad8',
    storageBucket: 'assetto-7cad8.firebasestorage.app',
    databaseURL:
        'https://assetto-7cad8-default-rtdb.asia-southeast1.firebasedatabase.app',
  );
}
