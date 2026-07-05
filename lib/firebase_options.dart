import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return android;
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDKPSsRup2SgN04pfx7_Ae0PqkCR7z34ro',
    appId: '1:136502856672:android:6c0b4280f23b6615267985',
    messagingSenderId: '136502856672',
    projectId: 'runova-diary',
    storageBucket: 'runova-diary.firebasestorage.app',
  );
}
