import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';

// ─── Global bouncing scroll physics ───
class _BouncingScrollBehavior extends ScrollBehavior {
  const _BouncingScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child; // No glow — just bounce
  }
}

class SecureTrackApp extends ConsumerWidget {
  const SecureTrackApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final theme = AppTheme();
    final themeMode = ref.watch(themeModeProvider);

    // Resolve actual brightness for AnimatedTheme
    final brightness = themeMode == ThemeMode.dark
        ? Brightness.dark
        : themeMode == ThemeMode.light
        ? Brightness.light
        : MediaQuery.platformBrightnessOf(context);
    final resolvedTheme = brightness == Brightness.dark
        ? theme.dark
        : theme.light;

    return ScrollConfiguration(
      behavior: const _BouncingScrollBehavior(),
      child: AnimatedTheme(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        data: resolvedTheme,
        child: MaterialApp.router(
          title: 'SecureTrack',
          debugShowCheckedModeBanner: false,
          theme: theme.light,
          darkTheme: theme.dark,
          themeMode: themeMode,
          routerConfig: router,
        ),
      ),
    );
  }
}
