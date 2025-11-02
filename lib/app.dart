import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/auth/controllers/auth_controller.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/home/presentation/home_shell.dart';

final _routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(authControllerProvider.notifier);

  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomeShell(),
      ),
    ],
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final isLoading = authState.isLoading;
      final authData = authState.valueOrNull;
      final isAuthenticated = authData?.isAuthenticated == true;
      final headingToLogin = state.matchedLocation == '/login';

      if (isLoading) {
        return null;
      }

      if (!isAuthenticated) {
        return headingToLogin ? null : '/login';
      }

      if (headingToLogin && isAuthenticated) {
        return '/';
      }

      return null;
    },
    refreshListenable: _RouterRefresh(authNotifier.stream),
  );
});

class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

class EruditeApp extends ConsumerWidget {
  const EruditeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(_routerProvider);

    return MaterialApp.router(
      title: 'Erudite Data Collection',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
