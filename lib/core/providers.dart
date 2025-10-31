import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'constants/env.dart';
import 'database/local_database.dart';
import 'logger.dart';

final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final localDatabaseProvider = Provider<LocalDatabase>((ref) {
  throw UnimplementedError('LocalDatabase must be overridden in bootstrap');
});

final connectivityProvider = StreamProvider<ConnectivityResult>((ref) {
  final connectivity = Connectivity();
  return connectivity.onConnectivityChanged.map((results) {
    if (results.isEmpty) {
      return ConnectivityResult.none;
    }
    return results.first;
  });
});

final loggerStateProvider = Provider<Logger>(
  (ref) => ref.watch(loggerProvider),
);

class AppConfig {
  const AppConfig._();

  static const supabaseUrl = AppEnv.supabaseUrl;
  static const supabaseAnonKey = AppEnv.supabaseAnonKey;
}
