import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/controllers/auth_controller.dart';
import '../../dashboard/presentation/admin_dashboard_screen.dart';
import '../../customers/presentation/customer_list_screen.dart';
import '../../customers/presentation/sync_screen.dart';
import '../../settings/presentation/profile_screen.dart';
import '../../users/presentation/user_management_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider).value;
    final profile = authState?.profile;

    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isAdmin = profile.isAdmin;
    final tabs = _buildTabs(isAdmin);

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: _buildDestinations(isAdmin),
      ),
    );
  }

  List<Widget> _buildTabs(bool isAdmin) {
    if (isAdmin) {
      return const [
        AdminDashboardScreen(),
        UserManagementScreen(),
        CustomerListScreen(),
        SyncScreen(),
        ProfileScreen(),
      ];
    }
    return const [CustomerListScreen(), SyncScreen(), ProfileScreen()];
  }

  List<NavigationDestination> _buildDestinations(bool isAdmin) {
    if (isAdmin) {
      return const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          label: 'Dashboard',
        ),
        NavigationDestination(
          icon: Icon(Icons.groups_2_outlined),
          label: 'Users',
        ),
        NavigationDestination(
          icon: Icon(Icons.list_alt_outlined),
          label: 'Customers',
        ),
        NavigationDestination(icon: Icon(Icons.sync), label: 'Sync'),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          label: 'Profile',
        ),
      ];
    }
    return const [
      NavigationDestination(
        icon: Icon(Icons.list_alt_outlined),
        label: 'Customers',
      ),
      NavigationDestination(icon: Icon(Icons.sync), label: 'Sync'),
      NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
    ];
  }
}
