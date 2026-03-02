// File generated manually based on Firebase project info
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return ios;
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyClmumtobWi9BVJgz5smHqTJfpZ0UN-HRw',
    appId: '1:120519944306:android:b66b41cd78640a870cbaeb',
    messagingSenderId: '120519944306',
    projectId: 'minton-smash-cv-app',
    storageBucket: 'minton-smash-cv-app.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCHYHMqMsgaUvM7-s1YhWnd-NfyOy1Rqms',
    appId: '1:120519944306:ios:44f3910425a4427b0cbaeb',
    messagingSenderId: '120519944306',
    projectId: 'minton-smash-cv-app',
    storageBucket: 'minton-smash-cv-app.firebasestorage.app',
    iosBundleId: 'com.dckwon.mintonSmash',
  );
}
