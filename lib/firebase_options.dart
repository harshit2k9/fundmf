import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase project configuration.
///
/// Replace this file with the generated output of:
///
/// ```sh
/// flutterfire configure --project=fundmf
/// ```
///
/// The placeholders below keep the project compiling; `main()` catches the
/// resulting initialisation error and shows the setup checklist instead of
/// crashing. Never commit real web API keys you consider sensitive — Firebase
/// web keys are public identifiers, but the OAuth refresh token used by the
/// Cloud Function must only ever live in Secret Manager.
abstract final class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
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
        // Desktop targets are not part of this release; use web config so the
        // app still boots for local UI work.
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyD5sPxWoDCm0NBPq-lRTKrnVa37NEnAyZQ',
    appId: '1:961928659142:web:cd92bc6d9002c81d0817c7',
    messagingSenderId: '961928659142',
    projectId: 'fundmf-mf',
    authDomain: 'fundmf-mf.firebaseapp.com',
    storageBucket: 'fundmf-mf.firebasestorage.app',
    measurementId: 'G-K8BGDMV3Y0',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBuiGyZnc9Ci4tkb3dC8LqbD5SGA1Atqy8',
    appId: '1:961928659142:android:9bb8e0803138ef2f0817c7',
    messagingSenderId: '961928659142',
    projectId: 'fundmf-mf',
    storageBucket: 'fundmf-mf.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAAWjSJCeYdXdmlcx24iLWwrDPTbwldq-M',
    appId: '1:961928659142:ios:f9dd825ba11c73090817c7',
    messagingSenderId: '961928659142',
    projectId: 'fundmf-mf',
    storageBucket: 'fundmf-mf.firebasestorage.app',
    iosBundleId: 'com.fundmf.fundmf',
  );
}
