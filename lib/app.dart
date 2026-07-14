import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class RunovaDiaryApp extends ConsumerStatefulWidget {
  const RunovaDiaryApp({super.key});

  @override
  ConsumerState<RunovaDiaryApp> createState() => _RunovaDiaryAppState();
}

class _RunovaDiaryAppState extends ConsumerState<RunovaDiaryApp> {
  @override
  void initState() {
    super.initState();
    _listenForShareIntents();
  }

  void _listenForShareIntents() {
    ReceiveSharingIntent.instance.getMediaStream().listen((files) {
      if (files.isEmpty) return;
      final path = files.first.path;
      if (path.isEmpty) return;
      ReceiveSharingIntent.instance.reset();
      if (!mounted) return;
      context.go('/share-handler', extra: path);
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Runova Diary',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
