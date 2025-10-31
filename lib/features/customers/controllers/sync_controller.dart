import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/controllers/auth_controller.dart';
import '../../auth/domain/profile.dart';
import '../data/customer_repository.dart';
import '../providers.dart';

final syncControllerProvider = Provider<SyncController>((ref) {
  final repo = ref.watch(customerRepositoryProvider);
  final authState = ref.watch(authControllerProvider);
  final profile = authState.value?.profile;
  if (profile == null) {
    throw StateError('Cannot sync without profile');
  }
  return SyncController(repository: repo, profile: profile, ref: ref);
});

class SyncController {
  SyncController({
    required this.repository,
    required this.profile,
    required this.ref,
  });

  final CustomerRepository repository;
  final Profile profile;
  final Ref ref;

  Future<void> sync() async {
    await repository.syncNow(profile);
    ref.invalidate(customerListProvider);
    ref.invalidate(unsyncedCountProvider);
  }
}
