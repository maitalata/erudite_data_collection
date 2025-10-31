import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/controllers/auth_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider).value;
    final profile = authState?.profile;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: profile == null
          ? const Center(child: Text('No profile data'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(
                    profile.fullName.isEmpty
                        ? 'Unknown user'
                        : profile.fullName,
                  ),
                  subtitle: Text(profile.id),
                ),
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: Text('Role: ${profile.role}'),
                ),
                ListTile(
                  leading: const Icon(Icons.toggle_on_outlined),
                  title: Text('Status: ${profile.status}'),
                ),
                ListTile(
                  leading: const Icon(Icons.access_time),
                  title: Text('Last updated'),
                  subtitle: Text(profile.updatedAt.toLocal().toString()),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () async {
                    await ref.read(authControllerProvider.notifier).signOut();
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign out'),
                ),
              ],
            ),
    );
  }
}
