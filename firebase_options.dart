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
      case TargetPlatform.windows:
        return windows;
      default:
        throw UnsupportedError(
          'Platform not configured for Firebase. Use Web (Chrome) for SIH demo.',
        );
    }
  }

  /// 🔥 WEB (Primary)
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDfCWT-u7_HLU8GzeiXhIP37RHgK3Z2glY',
    appId: '1:309205287648:web:0e7b01596825a334b08685',
    messagingSenderId: '309205287648',
    projectId: 'civicfix-sih25031',
    authDomain: 'civicfix-sih25031.firebaseapp.com',
    storageBucket: 'civicfix-sih25031.firebasestorage.app',
    measurementId: 'G-J7TK75Z6VY',
  );

  /// 📱 ANDROID
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDfCWT-u7_HLU8GzeiXhIP37RHgK3Z2glY',
    appId: '1:309205287648:android:PLACEHOLDER',
    messagingSenderId: '309205287648',
    projectId: 'civicfix-sih25031',
    storageBucket: 'civicfix-sih25031.appspot.com',
  );

  /// 🍎 iOS
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDfCWT-u7_HLU8GzeiXhIP37RHgK3Z2glY',
    appId: '1:309205287648:ios:PLACEHOLDER',
    messagingSenderId: '309205287648',
    projectId: 'civicfix-sih25031',
    storageBucket: 'civicfix-sih25031.appspot.com',
    iosBundleId: 'com.example.jharkhand_civicfix',
  );

  /// 🪟 Windows
  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDfCWT-u7_HLU8GzeiXhIP37RHgK3Z2glY',
    appId: '1:309205287648:windows:PLACEHOLDER',
    messagingSenderId: '309205287648',
    projectId: 'civicfix-sih25031',
    storageBucket: 'civicfix-sih25031.appspot.com',
  );
}