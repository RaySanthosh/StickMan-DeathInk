// Placeholder Firebase options.
//
// Run `flutterfire configure` to replace this file with real project values.
// Until then FirebaseService detects the placeholder apiKey and keeps the
// game fully offline.
import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => const FirebaseOptions(
        apiKey: 'PLACEHOLDER',
        appId: '1:000000000000:android:placeholder',
        messagingSenderId: '000000000000',
        projectId: 'placeholder',
      );
}
