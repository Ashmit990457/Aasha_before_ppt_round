import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'data/local/database/app_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Start local storage independently; a local DB failure must not prevent Firebase startup.
  unawaited(
    LocalDatabase.instance.initialize().catchError((error, stackTrace) {
      debugPrint('Local database initialization failed: $error');
    }),
  );

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const DisasterConnectApp());
}
