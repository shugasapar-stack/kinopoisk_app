import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCp61lFyXBKpSF82bUBe1cg3Fw0kwgFaLI',
    appId: '1:650839756862:android:d180265b1cdef563f9016f',
    messagingSenderId: '650839756862',
    projectId: 'copyapp-7d466',
    authDomain: 'copyapp-7d466.firebaseapp.com',
    storageBucket: 'copyapp-7d466.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCp61lFyXBKpSF82bUBe1cg3Fw0kwgFaLI',
    appId: '1:650839756862:android:d180265b1cdef563f9016f',
    messagingSenderId: '650839756862',
    projectId: 'copyapp-7d466',
    storageBucket: 'copyapp-7d466.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCp61lFyXBKpSF82bUBe1cg3Fw0kwgFaLI',
    appId: '1:650839756862:android:d180265b1cdef563f9016f',
    messagingSenderId: '650839756862',
    projectId: 'copyapp-7d466',
    storageBucket: 'copyapp-7d466.firebasestorage.app',
    iosBundleId: 'com.sapargali.shugila.cineverse',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCp61lFyXBKpSF82bUBe1cg3Fw0kwgFaLI',
    appId: '1:650839756862:android:d180265b1cdef563f9016f',
    messagingSenderId: '650839756862',
    projectId: 'copyapp-7d466',
    storageBucket: 'copyapp-7d466.firebasestorage.app',
    iosBundleId: 'com.sapargali.shugila.cineverse',
  );
}
