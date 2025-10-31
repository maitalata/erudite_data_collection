import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/controllers/auth_controller.dart';
import '../customers/data/customer_repository.dart';

final profilesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) async {
    final remote = ref.watch(customerRemoteServiceProvider);
    final authState = ref.watch(authControllerProvider).value;
    if (authState?.profile?.isAdmin != true) {
      return const [];
    }
    return remote.fetchAllProfiles();
  },
);
