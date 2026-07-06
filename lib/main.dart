import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'firebase_options.dart';
import 'providers/providers.dart';
import 'services/hive_service.dart';
import 'services/sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveService.init();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase init failed (app will work offline): $e');
  }

  runApp(
    ProviderScope(
      overrides: [
        syncServiceProvider.overrideWith((ref) {
          final service = SyncService(
            ref.watch(hiveServiceProvider),
            ref.watch(firebaseServiceProvider),
          );
          try {
            service.init();
          } catch (e) {
            debugPrint('SyncService init failed: $e');
          }
          return service;
        }),
      ],
      child: const RunovaDiaryApp(),
    ),
  );
}
