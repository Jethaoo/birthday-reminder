import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/api/birthday_reminder_api.dart';
import '../../../core/providers.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../../shared/widgets/person_avatar.dart';
import '../../photos/photo_editor.dart';
import '../../photos/photo_providers.dart';
import '../../photos/presentation/photo_viewer_screen.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final _nameController = TextEditingController();
  bool _initialised = false;
  bool _saving = false;
  bool _savingPhoto = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final error = Validators.name(_nameController.text);
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    setState(() => _saving = true);
    try {
      final updated = await ref
          .read(apiProvider)
          .updateMe(name: _nameController.text.trim());
      await ref.read(authControllerProvider.notifier).applyUser(updated);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Name updated')));
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickProfilePhoto() async {
    if (_savingPhoto) return;
    setState(() => _savingPhoto = true);
    try {
      // The stored photo is the square the avatar shows: it is cropped before
      // anything reaches the network.
      final bytes = await ref.read(photoEditorProvider).pickAndCrop(context);
      if (bytes == null) return;
      await _applyProfilePhoto(bytes);
    } on PhotoUnavailableException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _savingPhoto = false);
    }
  }

  Future<void> _applyProfilePhoto(Uint8List bytes) async {
    final api = ref.read(apiProvider);
    final auth = ref.read(authControllerProvider.notifier);
    if (!mounted) return;
    setState(() => _savingPhoto = true);
    String? uploadedUrl;
    var linked = false;
    try {
      uploadedUrl = await api.uploadPhoto(bytes: bytes, filename: 'avatar.jpg');
      final updated = await api.updateProfilePhoto(uploadedUrl);
      // Once the profile points at the object it must not be deleted, even if
      // storing the session afterwards fails.
      linked = true;
      await auth.applyUser(updated);
      _showMessage('Profile photo updated');
    } on ApiException catch (error) {
      if (!linked) await _discardUploadedPhoto(api, uploadedUrl);
      // Retry re-uploads the same crop instead of cropping again.
      _showMessage(error.message, retry: () => _applyProfilePhoto(bytes));
    } catch (_) {
      if (!linked) await _discardUploadedPhoto(api, uploadedUrl);
      _showMessage(
        "Couldn't update your profile photo.",
        retry: () => _applyProfilePhoto(bytes),
      );
    } finally {
      if (mounted) setState(() => _savingPhoto = false);
    }
  }

  /// A failed profile update must not leave an orphaned R2 object behind.
  Future<void> _discardUploadedPhoto(
    BirthdayReminderApi api,
    String? uploadedUrl,
  ) async {
    if (uploadedUrl == null) return;
    try {
      await api.deletePhoto(uploadedUrl);
    } catch (_) {
      // The next profile-photo change can leave this orphan for cleanup.
    }
  }

  void _showMessage(String message, {VoidCallback? retry}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: retry == null
            ? null
            : SnackBarAction(label: 'Retry', onPressed: retry),
      ),
    );
  }

  Future<void> _removeProfilePhoto() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Remove profile photo?',
      message: 'Your initials will be shown instead.',
      confirmLabel: 'Remove',
      destructive: false,
    );
    if (!confirmed || !mounted) return;

    setState(() => _savingPhoto = true);
    try {
      final updated = await ref.read(apiProvider).updateProfilePhoto(null);
      await ref.read(authControllerProvider.notifier).applyUser(updated);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile photo removed')));
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _savingPhoto = false);
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
                decoration: const InputDecoration(
                  labelText: 'Current password',
                ),
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
                decoration: const InputDecoration(
                  labelText: 'Confirm password',
                ),
                validator: (value) =>
                    Validators.confirmPassword(value, newController.text),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(context).pop(true);
              }
            },
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (submitted != true) return;

    try {
      await ref
          .read(apiProvider)
          .changePassword(
            currentPassword: currentController.text,
            newPassword: newController.text,
            confirmation: confirmController.text,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password changed. Please sign in again.'),
          ),
        );
        await ref
            .read(authControllerProvider.notifier)
            .signOut(notifyServer: false);
        if (mounted) context.go('/login');
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
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
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
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
      await ref
          .read(authControllerProvider.notifier)
          .signOut(notifyServer: false);
      if (mounted) context.go('/');
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
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
          Center(
            child: Column(
              children: [
                GestureDetector(
                  // A saved photo opens full screen; without one the avatar is
                  // another way to start adding it.
                  onTap: _savingPhoto
                      ? null
                      : user?.photoUrl == null
                      ? _pickProfilePhoto
                      : () => PhotoViewerScreen.show(
                          context,
                          user!.photoUrl!,
                          label: user.name,
                        ),
                  child: PersonAvatar(
                    initials: user?.initials ?? '?',
                    colorSeed: (user?.name ?? '?').codeUnits.fold<int>(
                      0,
                      (sum, unit) => sum + unit,
                    ),
                    size: 96,
                    photoUrl: user?.photoUrl,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _savingPhoto ? null : _pickProfilePhoto,
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: Text(
                        user?.photoUrl == null ? 'Add photo' : 'Change photo',
                      ),
                    ),
                    if (user?.photoUrl != null)
                      TextButton.icon(
                        onPressed: _savingPhoto ? null : _removeProfilePhoto,
                        style: TextButton.styleFrom(
                          foregroundColor: palette.error,
                        ),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Remove'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
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
          const SizedBox(height: 14),
          if (user?.hasBirthday == true)
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Your birthday',
                helperText: 'Set once and cannot be changed.',
              ),
              child: Text(
                '${longDate(DateTime(2000, user!.birthdayMonth!, user.birthdayDay!))}'
                '${user.birthYear == null ? '' : ' · Born ${user.birthYear}'}',
              ),
            ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _saveName,
            child: const Text('Save changes'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: _changePassword,
            child: const Text('Change password'),
          ),
          const SizedBox(height: 28),
          Text(
            'Danger zone',
            style: text.titleMedium?.copyWith(color: palette.error),
          ),
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
