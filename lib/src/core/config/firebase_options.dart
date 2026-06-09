import 'package:firebase_core/firebase_core.dart';

import 'app_config.dart';

FirebaseOptions? firebaseOptionsFromConfig() {
  final apiKey = AppConfig.firebaseApiKey;
  final appId = AppConfig.firebaseAppId;
  final messagingSenderId = AppConfig.firebaseMessagingSenderId;
  final projectId = AppConfig.firebaseProjectId;
  final storageBucket = AppConfig.firebaseStorageBucket;

  if (apiKey.isEmpty ||
      appId.isEmpty ||
      messagingSenderId.isEmpty ||
      projectId.isEmpty) {
    return null;
  }

  return FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: messagingSenderId,
    projectId: projectId,
    storageBucket: storageBucket.isEmpty ? null : storageBucket,
    iosBundleId: AppConfig.firebaseIosBundleId.isEmpty
        ? null
        : AppConfig.firebaseIosBundleId,
  );
}
