import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => android;

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDao7BidLoQ3tFFIBtj5wG9GuB_aI3mukA',
    appId: '1:1030335934733:android:7129d5c6695da91f1b8044',
    messagingSenderId: '1030335934733',
    projectId: 'diary-app-a5772',
    storageBucket: 'diary-app-a5772.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDao7BidLoQ3tFFIBtj5wG9GuB_aI3mukA',
    appId: '1:1030335934733:ios:YOUR_IOS_APP_ID',
    messagingSenderId: '1030335934733',
    projectId: 'diary-app-a5772',
    storageBucket: 'diary-app-a5772.firebasestorage.app',
    iosBundleId: 'com.example.diaryApp',
  );
}
