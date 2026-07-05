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
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    ProviderScope(
      overrides: [
        syncServiceProvider.overrideWith((ref) {
          final service = SyncService(
            ref.watch(hiveServiceProvider),
            ref.watch(firebaseServiceProvider),
          );
          service.init();
          return service;
        }),
      ],
      child: const RunovaDiaryApp(),
    ),
  );
}
