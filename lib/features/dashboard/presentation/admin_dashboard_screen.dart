import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/controllers/auth_controller.dart';
import '../../customers/providers.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unsynced = ref.watch(unsyncedCountProvider);
    final customers = ref.watch(customerListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Admin overview')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.people_outline),
              title: const Text('Users'),
              subtitle: Consumer(
                builder: (context, ref, _) {
                  final authState = ref.watch(authControllerProvider).value;
                  return Text(
                    'Logged in as: ${authState?.profile?.fullName ?? 'Unknown'}',
                  );
                },
              ),
            ),
          ),
          Card(
            child: unsynced.when(
              data: (count) => ListTile(
                leading: const Icon(Icons.cloud_sync),
                title: const Text('Pending sync records'),
                subtitle: Text('$count records awaiting sync'),
              ),
              loading: () => const ListTile(
                title: Text('Checking sync status...'),
                trailing: CircularProgressIndicator(),
              ),
              error: (error, stack) => ListTile(
                title: const Text('Unable to fetch sync status'),
                subtitle: Text(error.toString()),
              ),
            ),
          ),
          customers.when(
            data: (list) => Card(
              child: ListTile(
                leading: const Icon(Icons.list_alt),
                title: const Text('Total customers (local cache)'),
                subtitle: Text('${list.length} records'),
              ),
            ),
            loading: () => const Card(
              child: ListTile(
                title: Text('Loading customer cache...'),
                trailing: CircularProgressIndicator(),
              ),
            ),
            error: (error, stack) => Card(
              child: ListTile(
                title: const Text('Failed to load cache'),
                subtitle: Text(error.toString()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
