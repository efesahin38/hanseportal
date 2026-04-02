import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAA92x8zSUZ25Q9Xa43BVmExR32EtgELIY',
    appId: '1:764722344385:android:9127c187929a0e61cdbf40',
    messagingSenderId: '764722344385',
    projectId: 'ekrempdks',
    storageBucket: 'ekrempdks.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCilquscn7FQVXZ399uiRWYFUxtjCfv_XY',
    appId: '1:764722344385:ios:bdd92e6974a0b23dcdbf40',
    messagingSenderId: '764722344385',
    projectId: 'ekrempdks',
    storageBucket: 'ekrempdks.firebasestorage.app',
    iosBundleId: 'com.ekrem.mobile',
  );
}
