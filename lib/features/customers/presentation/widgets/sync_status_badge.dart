import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/sync_controller.dart';
import '../../providers.dart';

class SyncStatusBadge extends ConsumerWidget {
  const SyncStatusBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unsyncedAsync = ref.watch(unsyncedCountProvider);
    final bool isLoading = unsyncedAsync.isLoading;
    final unsynced = unsyncedAsync.valueOrNull ?? 0;

    return IconButton(
      onPressed: isLoading
          ? null
          : () async {
              final syncController = ref.read(syncControllerProvider);
              try {
                await syncController.sync();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sync completed.')),
                  );
                }
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Sync failed: $error')),
                  );
                }
              }
            },
      icon: Badge.count(
        count: unsynced,
        isLabelVisible: unsynced > 0,
        child: const Icon(Icons.sync),
      ),
      tooltip: 'Unsynced records: $unsynced',
    );
  }
}
