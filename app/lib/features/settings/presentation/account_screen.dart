import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/dialogs.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final _nameController = TextEditingController();
  bool _initialised = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final error = Validators.name(_nameController.text);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    setState(() => _saving = true);
    try {
      final updated = await ref.read(apiProvider).updateMe(name: _nameController.text.trim());
      await ref.read(authControllerProvider.notifier).applyUser(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name updated')));
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePassword() async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change password'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: currentController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Current password'),
                validator: (value) => (value ?? '').isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: newController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password'),
                validator: Validators.password,
              ),
              TextFormField(
                controller: confirmController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm password'),
                validator: (value) => Validators.confirmPassword(value, newController.text),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) Navigator.of(context).pop(true);
            },
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (submitted != true) return;

    try {
      await ref.read(apiProvider).changePassword(
            currentPassword: currentController.text,
            newPassword: newController.text,
            confirmation: confirmController.text,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password changed. Please sign in again.')),
        );
        await ref.read(authControllerProvider.notifier).signOut(notifyServer: false);
        if (mounted) context.go('/login');
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await confirmDeleteAccount(context);
    if (!confirmed || !mounted) return;

    final passwordController = TextEditingController();
    final confirmedWithPassword = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm your password'),
        content: TextField(
          controller: passwordController,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Password'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );

    if (confirmedWithPassword != true) return;

    try {
      await ref.read(apiProvider).deleteAccount(passwordController.text);
      await ref.read(authControllerProvider.notifier).signOut(notifyServer: false);
      if (mounted) context.go('/');
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    final text = Theme.of(context).textTheme;
    final user = ref.watch(authControllerProvider).user;

    if (!_initialised && user != null) {
      _nameController.text = user.name;
      _initialised = true;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            initialValue: user?.email ?? '',
            readOnly: true,
            decoration: const InputDecoration(
              labelText: 'Email',
              helperText: 'Contact support to change your email',
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            initialValue: user?.timezone ?? '',
            readOnly: true,
            decoration: const InputDecoration(
              labelText: 'Timezone',
              helperText: 'Updated automatically from this device',
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _saveName,
            child: const Text('Save changes'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: _changePassword, child: const Text('Change password')),
          const SizedBox(height: 28),
          Text('Danger zone', style: text.titleMedium?.copyWith(color: palette.error)),
          const SizedBox(height: 6),
          Text(
            'Deleting your account removes your birthdays, reminders, device registrations and photos.',
            style: text.bodySmall,
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _deleteAccount,
            style: OutlinedButton.styleFrom(foregroundColor: palette.error),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
  }
}
