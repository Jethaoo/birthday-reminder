import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Reusable confirmation dialog matching the approved copy.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
  String cancelLabel = 'Cancel',
  bool destructive = true,
}) async {
  final palette = paletteOf(context);

  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      content: Text(message, style: Theme.of(context).textTheme.bodyMedium),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(foregroundColor: palette.textSecondary),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: destructive ? palette.error : palette.primary,
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 20),
          ),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );

  return result ?? false;
}

Future<bool> confirmDeleteBirthday(BuildContext context, String name) => showConfirmDialog(
      context,
      title: 'Delete birthday?',
      message: "Are you sure you want to delete $name's birthday? This action cannot be undone.",
      confirmLabel: 'Delete',
    );

Future<bool> confirmLogout(BuildContext context) => showConfirmDialog(
      context,
      title: 'Log out?',
      message: 'You will need to sign in again to see your birthdays.',
      confirmLabel: 'Log out',
      destructive: false,
    );

Future<bool> confirmDeleteAccount(BuildContext context) => showConfirmDialog(
      context,
      title: 'Delete account?',
      message:
          'This permanently removes your account, birthdays, reminders, device registrations and uploaded photos.',
      confirmLabel: 'Delete account',
    );
