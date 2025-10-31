import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/controllers/auth_controller.dart';
import 'data/customer_repository.dart';
import 'domain/customer.dart';

final customerListProvider = FutureProvider.autoDispose<List<Customer>>((
  ref,
) async {
  final repo = ref.watch(customerRepositoryProvider);
  final authState = ref.watch(authControllerProvider);
  final profile = authState.value?.profile;
  if (profile == null) {
    return const [];
  }
  return repo.loadCustomers(profile);
});

final unsyncedCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final repo = ref.watch(customerRepositoryProvider);
  final authState = ref.watch(authControllerProvider);
  final profile = authState.value?.profile;
  if (profile == null) {
    return 0;
  }
  return repo.unsyncedCount(profile);
});
