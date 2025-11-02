import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/controllers/auth_controller.dart';
import '../../auth/domain/profile.dart';
import '../../customers/data/customer_repository.dart';
import '../providers.dart';

class UserManagementScreen extends ConsumerWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider).value;
    final session = authState?.session;
    final currentProfile = authState?.profile;
    final profilesAsync = ref.watch(profilesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Manage users')),
      floatingActionButton: session == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (_) =>
                      AddUserDialog(rootContext: context, session: session),
                );
              },
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Add user'),
            ),
      body: profilesAsync.when(
        data: (profiles) {
          if (profiles.isEmpty) {
            return const Center(
              child: Text('No users available or insufficient permissions.'),
            );
          }

          final rawProfilesById = <String, Map<String, dynamic>>{
            for (final map in profiles) map['id'] as String: map,
          };

          final orderedProfiles = profiles.map(Profile.fromMap).toList()
            ..sort((a, b) => a.fullName.compareTo(b.fullName));

          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: orderedProfiles.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final profile = orderedProfiles[index];
              final isSelf = profile.id == currentProfile?.id;
              final raw =
                  rawProfilesById[profile.id] ?? const <String, dynamic>{};
              final email = (raw['email'] as String?) ?? '';

              final initialsSource = profile.fullName.isNotEmpty
                  ? profile.fullName
                  : (profile.role.isNotEmpty ? profile.role : email);

              return ListTile(
                selected: isSelf,
                selectedTileColor: Theme.of(
                  context,
                ).colorScheme.primary.withOpacity(0.08),
                leading: CircleAvatar(
                  child: Text(
                    initialsSource.isEmpty
                        ? '?'
                        : initialsSource.substring(0, 1).toUpperCase(),
                  ),
                ),
                title: Text(
                  profile.fullName.isEmpty ? email : profile.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  'Email: ${email.isEmpty ? '-' : email}\nRole: ${profile.role} - Status: ${profile.status}',
                ),
                trailing: PopupMenuButton<_UserAction>(
                  onSelected: (action) => _handleUserAction(
                    context,
                    ref,
                    session,
                    profile,
                    action,
                    isSelf: isSelf,
                  ),
                  itemBuilder: (context) {
                    final canPromote = profile.role != 'admin';
                    final canDemote = profile.role != 'collector';
                    final canDeactivate = profile.status == 'active';
                    final canActivate = profile.status != 'active';

                    return [
                      if (canActivate)
                        const PopupMenuItem(
                          value: _UserAction.activateCollector,
                          child: Text('Activate as collector'),
                        ),
                      if (canDeactivate)
                        PopupMenuItem(
                          value: _UserAction.deactivate,
                          enabled: !isSelf,
                          child: const Text('Mark as inactive'),
                        ),
                      if (canPromote)
                        const PopupMenuItem(
                          value: _UserAction.makeAdmin,
                          child: Text('Make administrator'),
                        ),
                      if (canDemote)
                        PopupMenuItem(
                          value: _UserAction.makeCollector,
                          enabled: !isSelf,
                          child: const Text('Make collector'),
                        ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: _UserAction.setPassword,
                        child: Text('Set password...'),
                      ),
                    ];
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text('Could not load users: $error')),
      ),
    );
  }

  Future<void> _handleUserAction(
    BuildContext context,
    WidgetRef ref,
    Session? session,
    Profile target,
    _UserAction action, {
    required bool isSelf,
  }) async {
    if (session == null) return;

    if (action == _UserAction.setPassword) {
      await showDialog<void>(
        context: context,
        builder: (_) => SetPasswordDialog(
          rootContext: context,
          session: session,
          userId: target.id,
          fullName: target.fullName,
        ),
      );
      return;
    }

    String newRole = target.role;
    String newStatus = target.status;

    switch (action) {
      case _UserAction.activateCollector:
        newRole = 'collector';
        newStatus = 'active';
        break;
      case _UserAction.deactivate:
        newStatus = 'inactive';
        break;
      case _UserAction.makeAdmin:
        newRole = 'admin';
        break;
      case _UserAction.makeCollector:
        newRole = 'collector';
        break;
      case _UserAction.setPassword:
        break;
    }

    if (isSelf && newRole != target.role) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot change your own role here.')),
      );
      return;
    }

    final remote = ref.read(customerRemoteServiceProvider);

    try {
      await remote.updateUserRoleStatus(
        accessToken: session.accessToken,
        targetUserId: target.id,
        role: newRole,
        status: newStatus,
      );
      ref.invalidate(profilesProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Updated ${target.fullName.isEmpty ? (target.role == 'admin' ? 'administrator' : 'user') : target.fullName}.',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Update failed: $error')));
    }
  }
}

enum _UserAction {
  activateCollector,
  deactivate,
  makeAdmin,
  makeCollector,
  setPassword,
}

class AddUserDialog extends ConsumerStatefulWidget {
  const AddUserDialog({
    required this.rootContext,
    required this.session,
    super.key,
  });

  final BuildContext rootContext;
  final Session session;

  @override
  ConsumerState<AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends ConsumerState<AddUserDialog> {
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String _role = 'collector';
  String _status = 'inactive';
  bool _sendInvite = true;
  bool _setPassword = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Invite new user'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (email.isEmpty) {
                      return 'Email is required';
                    }
                    if (!email.contains('@')) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full name (optional)',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const [
                    DropdownMenuItem(
                      value: 'collector',
                      child: Text('Data collector'),
                    ),
                    DropdownMenuItem(
                      value: 'admin',
                      child: Text('Administrator'),
                    ),
                  ],
                  onChanged: _isSubmitting
                      ? null
                      : (value) => setState(() => _role = value ?? 'collector'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(
                      value: 'inactive',
                      child: Text('Inactive (invite pending)'),
                    ),
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                  ],
                  onChanged: _isSubmitting
                      ? null
                      : (value) =>
                            setState(() => _status = value ?? 'inactive'),
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  value: _sendInvite,
                  onChanged: _isSubmitting
                      ? null
                      : (value) => setState(() {
                          _sendInvite = value;
                          if (!value) {
                            _setPassword = true;
                          }
                        }),
                  title: const Text('Send invite email'),
                  subtitle: const Text(
                    'Supabase will email the user to finish setup.',
                  ),
                ),
                const SizedBox(height: 8),
                Builder(
                  builder: (context) {
                    final mustSetPassword = !_sendInvite;
                    final effectiveSetPassword =
                        mustSetPassword || _setPassword;
                    return SwitchListTile.adaptive(
                      value: effectiveSetPassword,
                      onChanged: (_isSubmitting || mustSetPassword)
                          ? null
                          : (value) {
                              setState(() {
                                _setPassword = value;
                                if (!value) {
                                  _passwordController.clear();
                                  _confirmController.clear();
                                }
                              });
                            },
                      title: const Text('Set temporary password now'),
                      subtitle: mustSetPassword
                          ? const Text(
                              'Required when invite email is disabled.',
                            )
                          : const Text(
                              'Provide a password so the user can log in immediately.',
                            ),
                    );
                  },
                ),
                Builder(
                  builder: (context) {
                    final mustSetPassword = !_sendInvite;
                    final effectiveSetPassword =
                        mustSetPassword || _setPassword;
                    if (!effectiveSetPassword) {
                      return const SizedBox.shrink();
                    }
                    return Column(
                      children: [
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                          ),
                          validator: (value) {
                            final pwd = value?.trim() ?? '';
                            if (!(mustSetPassword || _setPassword)) return null;
                            if (pwd.length < 8) {
                              return 'Password must be at least 8 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _confirmController,
                          obscureText: _obscureConfirm,
                          decoration: InputDecoration(
                            labelText: 'Confirm password',
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirm
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () => setState(
                                () => _obscureConfirm = !_obscureConfirm,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (!(mustSetPassword || _setPassword)) return null;
                            if (value?.trim() !=
                                _passwordController.text.trim()) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save user'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    final remote = ref.read(customerRemoteServiceProvider);
    final email = _emailController.text.trim();
    final fullName = _nameController.text.trim();
    final mustSetPassword = !_sendInvite;
    final shouldAttachPassword = mustSetPassword || _setPassword;
    final password = shouldAttachPassword
        ? _passwordController.text.trim()
        : null;

    try {
      await remote.createUser(
        accessToken: widget.session.accessToken,
        email: email,
        fullName: fullName.isEmpty ? null : fullName,
        role: _role,
        status: _status,
        sendInvite: _sendInvite,
        password: password,
      );

      ref.invalidate(profilesProvider);

      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(
        widget.rootContext,
      ).showSnackBar(SnackBar(content: Text('User saved: $email')));
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(
        widget.rootContext,
      ).showSnackBar(SnackBar(content: Text('User creation failed: $error')));
    }
  }
}

class SetPasswordDialog extends ConsumerStatefulWidget {
  const SetPasswordDialog({
    required this.rootContext,
    required this.session,
    required this.userId,
    this.fullName,
    super.key,
  });

  final BuildContext rootContext;
  final Session session;
  final String userId;
  final String? fullName;

  @override
  ConsumerState<SetPasswordDialog> createState() => _SetPasswordDialogState();
}

class _SetPasswordDialogState extends ConsumerState<SetPasswordDialog> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _sendInvite = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = (widget.fullName == null || widget.fullName!.isEmpty)
        ? 'Set password'
        : 'Set password for ${widget.fullName}';

    return AlertDialog(
      title: Text(title),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'New password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (value) {
                    final pwd = value?.trim() ?? '';
                    if (pwd.length < 8) {
                      return 'Password must be at least 8 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmController,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirm password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  validator: (value) {
                    if (value?.trim() != _passwordController.text.trim()) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  value: _sendInvite,
                  onChanged: _isSubmitting
                      ? null
                      : (value) => setState(() => _sendInvite = value),
                  title: const Text('Email user about this change'),
                  subtitle: const Text(
                    'Sends a fresh invite link after updating the password.',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save password'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    final remote = ref.read(customerRemoteServiceProvider);

    try {
      await remote.updateUserPassword(
        accessToken: widget.session.accessToken,
        userId: widget.userId,
        password: _passwordController.text.trim(),
        sendInvite: _sendInvite,
      );

      ref.invalidate(profilesProvider);

      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(widget.rootContext).showSnackBar(
        const SnackBar(content: Text('Password updated successfully')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(
        widget.rootContext,
      ).showSnackBar(SnackBar(content: Text('Password update failed: $error')));
    }
  }
}
