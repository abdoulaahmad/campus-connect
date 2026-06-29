import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_theme.dart';
import 'core/router/app_router.dart';

/// Root application widget for CampusConnect AUS.
///
/// Upgraded to [ConsumerWidget] in Sprint 2 to read the [routerProvider]
/// from Riverpod. This is required because [GoRouter] is now a Riverpod
/// provider that wires in the [RouterNotifier] refresh mechanism.
///
/// Remains deliberately thin — no business logic, no state.
class CampusConnectApp extends ConsumerWidget {
  const CampusConnectApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch routerProvider so the widget rebuilds if the router is ever
    // replaced (unlikely, but keeps the binding correct).
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'CampusConnect AUS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: router,
    );
  }
}
