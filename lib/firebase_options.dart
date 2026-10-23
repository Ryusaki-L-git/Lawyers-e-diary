import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAlvBHarcu63kgGO-AJf-qU49n25rD5gUw',
    appId: '1:571288974875:android:4aeb978e158894aabfeabe',
    messagingSenderId: '571288974875',
    projectId: 'lawyer-s-e-diary',
    storageBucket: 'lawyer-s-e-diary.firebasestorage.app',
    iosBundleId: 'com.example.lawyersE_diary',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAlvBHarcu63kgGO-AJf-qU49n25rD5gUw',
    appId: '1:571288974875:ios:4aeb978e158894aabfeabe',
    messagingSenderId: '571288974875',
    projectId: 'lawyer-s-e-diary',
    storageBucket: 'lawyer-s-e-diary.firebasestorage.app',
    iosBundleId: 'com.example.lawyersE_diary',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAlvBHarcu63kgGO-AJf-qU49n25rD5gUw',
    appId: '1:571288974875:ios:4aeb978e158894aabfeabe',
    messagingSenderId: '571288974875',
    projectId: 'lawyer-s-e-diary',
    storageBucket: 'lawyer-s-e-diary.firebasestorage.app',
    iosBundleId: 'com.example.lawyersE_diary',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAlvBHarcu63kgGO-AJf-qU49n25rD5gUw',
    appId: '1:571288974875:web:4aeb978e158894aabfeabe',
    messagingSenderId: '571288974875',
    projectId: 'lawyer-s-e-diary',
    storageBucket: 'lawyer-s-e-diary.firebasestorage.app',
    iosBundleId: 'com.example.lawyersE_diary',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAlvBHarcu63kgGO-AJf-qU49n25rD5gUw',
    appId: '1:571288974875:web:4aeb978e158894aabfeabe',
    messagingSenderId: '571288974875',
    projectId: 'lawyer-s-e-diary',
    storageBucket: 'lawyer-s-e-diary.firebasestorage.app',
    iosBundleId: 'com.example.lawyersE_diary',
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'AIzaSyAlvBHarcu63kgGO-AJf-qU49n25rD5gUw',
    appId: '1:571288974875:web:4aeb978e158894aabfeabe',
    messagingSenderId: '571288974875',
    projectId: 'lawyer-s-e-diary',
    storageBucket: 'lawyer-s-e-diary.firebasestorage.app',
    iosBundleId: 'com.example.lawyersE_diary',
  );

  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.linux:
        return linux;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }
}