import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers.dart';
import '../domain/profile.dart';
import '../../customers/data/remote/customer_remote_service.dart';

class AuthRepository {
  AuthRepository(this._supabase, this._remoteService);

  final SupabaseClient _supabase;
  final CustomerRemoteService _remoteService;

  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  Session? get currentSession => _supabase.auth.currentSession;

  Future<Profile?> fetchCurrentProfile() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;
    final data = await _remoteService.fetchProfile(userId);
    if (data == null) return null;
    return Profile.fromMap(data);
  }

  Future<(Session, Profile)> signIn(String email, String password) async {
    final response = await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
    final session = response.session;
    if (session == null) {
      throw const AppAuthException('Missing session after sign-in');
    }
    final profileData = await _remoteService.fetchProfile(session.user.id);
    if (profileData == null) {
      throw const AppAuthException('Profile record not found');
    }
    return (session, Profile.fromMap(profileData));
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  Future<Profile?> refreshProfile(String userId) async {
    final data = await _remoteService.fetchProfile(userId);
    if (data == null) return null;
    return Profile.fromMap(data);
  }
}

class AppAuthException implements Exception {
  const AppAuthException(this.message);
  final String message;

  @override
  String toString() => 'AppAuthException: $message';
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final supabase = ref.watch(supabaseProvider);
  final remote = CustomerRemoteService(supabase);
  return AuthRepository(supabase, remote);
});
