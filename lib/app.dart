import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';

class SecureTrackApp extends ConsumerWidget {
  const SecureTrackApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final theme = AppTheme();
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'SecureTrack',
      debugShowCheckedModeBanner: false,
      theme: theme.light,
      darkTheme: theme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}

