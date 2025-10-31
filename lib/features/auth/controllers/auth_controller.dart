import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/logger.dart';
import '../data/auth_repository.dart';
import '../domain/profile.dart';

class AuthStateData {
  const AuthStateData({required this.session, required this.profile});

  final Session? session;
  final Profile? profile;

  bool get isAuthenticated => session != null && profile != null;
}

class AuthController extends StateNotifier<AsyncValue<AuthStateData>> {
  AuthController(this._authRepository, this._logger)
    : super(const AsyncValue.loading()) {
    _init();
  }

  final AuthRepository _authRepository;
  final Logger _logger;
  StreamSubscription<AuthState>? _subscription;

  Future<void> _init() async {
    try {
      final session = _authRepository.currentSession;
      final profile = await _authRepository.fetchCurrentProfile();
      if (session != null && profile != null && profile.isActive) {
        state = AsyncValue.data(
          AuthStateData(session: session, profile: profile),
        );
      } else {
        state = const AsyncValue.data(
          AuthStateData(session: null, profile: null),
        );
      }
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
    }

    _subscription = _authRepository.authStateChanges.listen((event) async {
      final session = event.session;
      if (session == null) {
        state = const AsyncValue.data(
          AuthStateData(session: null, profile: null),
        );
        return;
      }

      try {
        final profile = await _authRepository.refreshProfile(session.user.id);
        state = AsyncValue.data(
          AuthStateData(session: session, profile: profile),
        );
      } catch (error, stack) {
        _logger.e('Failed to refresh profile', error: error, stackTrace: stack);
        state = AsyncValue.data(AuthStateData(session: session, profile: null));
      }
    });
  }

  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final (session, profile) = await _authRepository.signIn(email, password);
      if (!profile.isActive) {
        throw const AppAuthException('Account is not active yet');
      }
      state = AsyncValue.data(
        AuthStateData(session: session, profile: profile),
      );
    } on AppAuthException catch (error, stack) {
      state = AsyncValue.error(error, stack); // Later handled by UI
    } catch (error, stack) {
      _logger.e('Sign-in failed', error: error, stackTrace: stack);
      state = AsyncValue.error(error, stack);
    }
  }

  Future<void> signOut() async {
    await _authRepository.signOut();
    state = const AsyncValue.data(AuthStateData(session: null, profile: null));
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<AuthStateData>>((ref) {
      final authRepository = ref.watch(authRepositoryProvider);
      final logger = ref.watch(loggerProvider);
      return AuthController(authRepository, logger);
    });
