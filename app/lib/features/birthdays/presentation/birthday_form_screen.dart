import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/models/birthday.dart';
import '../../../shared/models/reminder.dart';
import '../../../shared/widgets/person_avatar.dart';
import '../../../shared/widgets/states.dart';
import '../birthday_providers.dart';
import '../../settings/settings_providers.dart';
import 'reminder_editor.dart';

const _relationships = <String>['Family', 'Friend', 'Colleague', 'Other'];

class BirthdayFormScreen extends ConsumerStatefulWidget {
  const BirthdayFormScreen({super.key, this.birthdayId});

  /// Null when creating a new birthday.
  final String? birthdayId;

  @override
  ConsumerState<BirthdayFormScreen> createState() => _BirthdayFormScreenState();
}

class _BirthdayFormScreenState extends ConsumerState<BirthdayFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _yearController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _notesController = TextEditingController();
  final _giftController = TextEditingController();

  int? _month;
  int? _day;
  String? _relationship;
  List<String> _giftIdeas = [];
  List<Reminder> _reminders = [];
  String? _photoUrl;
  bool _remindersEnabled = false;
  bool _saving = false;
  bool _uploadingPhoto = false;
  bool _loadedExisting = false;
  Birthday? _existing;

  bool get _isEditing => widget.birthdayId != null;

  @override
  void dispose() {
    _nameController.dispose();
    _yearController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _notesController.dispose();
    _giftController.dispose();
    super.dispose();
  }

  void _hydrate(Birthday birthday) {
    _existing = birthday;
    _nameController.text = birthday.name;
    _month = birthday.birthdayMonth;
    _day = birthday.birthdayDay;
    _yearController.text = birthday.birthYear?.toString() ?? '';
    _relationship = birthday.relationship;
    _phoneController.text = birthday.phone ?? '';
    _emailController.text = birthday.email ?? '';
    _notesController.text = birthday.notes ?? '';
    _giftIdeas = List.of(birthday.giftIdeas);
    _reminders = List.of(birthday.reminders);
    _photoUrl = birthday.photoUrl;
    _remindersEnabled = birthday.reminders.isNotEmpty;
    _loadedExisting = true;
  }

  Future<void> _pickBirthday() async {
    final palette = paletteOf(context);
    var month = _month ?? 1;
    var day = _day ?? 1;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final maxDay = DateTime(2024, month + 1, 0).day;
          if (day > maxDay) day = maxDay;

          return AlertDialog(
            title: const Text('Birthday'),
            content: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: month,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Month'),
                    items: [
                      for (var index = 1; index <= 12; index += 1)
                        DropdownMenuItem(value: index, child: Text(monthName(index))),
                    ],
                    onChanged: (value) => setDialogState(() => month = value ?? month),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: day,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Day'),
                    items: [
                      for (var index = 1; index <= maxDay; index += 1)
                        DropdownMenuItem(value: index, child: Text('$index')),
                    ],
                    onChanged: (value) => setDialogState(() => day = value ?? day),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(foregroundColor: palette.textSecondary),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                child: const Text('Set'),
              ),
            ],
          );
        },
      ),
    );

    if (result == true) {
      setState(() {
        _month = month;
        _day = day;
      });
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 2400, imageQuality: 92);
    if (picked == null) return;

    setState(() => _uploadingPhoto = true);
    try {
      final raw = await picked.readAsBytes();
      // Compress before upload so the request stays small on mobile data.
      Uint8List bytes = raw;
      try {
        final compressed = await FlutterImageCompress.compressWithList(
          raw,
          minWidth: 1024,
          minHeight: 1024,
          quality: 78,
        );
        if (compressed.isNotEmpty) bytes = compressed;
      } catch (_) {
        // Fall back to the original bytes when compression is unavailable.
      }

      final url = await ref.read(apiProvider).uploadPhoto(bytes: bytes, filename: picked.name);
      if (mounted) setState(() => _photoUrl = url);
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _addDefaultReminder() async {
    final settings = await ref.read(settingsProvider.future);
    setState(() {
      _reminders = [
        ..._reminders.where((reminder) => reminder.daysBefore != settings.defaultDaysBefore),
        Reminder(
          id: 'new-${settings.defaultDaysBefore}',
          daysBefore: settings.defaultDaysBefore,
          reminderTime: settings.defaultReminderTime,
          enabled: true,
        ),
      ];
    });
  }

  void _addGiftIdea() {
    final value = _giftController.text.trim();
    if (value.isEmpty) return;
    setState(() {
      _giftIdeas = [..._giftIdeas, value];
      _giftController.clear();
    });
  }

  Birthday _buildBirthday() => Birthday(
        id: _existing?.id ?? '',
        name: _nameController.text.trim(),
        birthdayMonth: _month!,
        birthdayDay: _day!,
        birthYear: int.tryParse(_yearController.text.trim()),
        relationship: (_relationship == null || _relationship!.isEmpty) ? null : _relationship,
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        photoUrl: _photoUrl,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        giftIdeas: _giftIdeas,
        reminders: _remindersEnabled ? _reminders : const [],
        nextOccurrence: DateTime.now(),
        daysUntil: 0,
      );

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_month == null || _day == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick the birthday date.')),
      );
      return;
    }
    if (_remindersEnabled && _reminders.isEmpty) {
      await _addDefaultReminder();
    }

    setState(() => _saving = true);
    final actions = ref.read(birthdayActionsProvider);

    try {
      final birthday = _buildBirthday();
      final saved = _isEditing ? await actions.update(birthday) : await actions.create(birthday);
      if (!mounted) return;
      context.go('/birthdays/${saved.id}');
    } on ApiException catch (error) {
      if (!mounted) return;

      final existingId = error.details?['existingBirthdayId'] as String?;
      if (error.code == ApiErrorCode.conflict && existingId != null) {
        final update = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(_nameController.text.trim()),
            content: const Text('This birthday already exists. Update the existing entry instead?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                child: const Text('Update existing'),
              ),
            ],
          ),
        );

        if (update == true) {
          try {
            final merged = _buildBirthday().copyWith();
            final saved = await actions.update(
              Birthday(
                id: existingId,
                name: merged.name,
                birthdayMonth: merged.birthdayMonth,
                birthdayDay: merged.birthdayDay,
                birthYear: merged.birthYear,
                relationship: merged.relationship,
                phone: merged.phone,
                email: merged.email,
                photoUrl: merged.photoUrl,
                notes: merged.notes,
                giftIdeas: merged.giftIdeas,
                reminders: merged.reminders,
                nextOccurrence: DateTime.now(),
                daysUntil: 0,
              ),
            );
            if (mounted) context.go('/birthdays/${saved.id}');
            return;
          } on ApiException catch (retryError) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(retryError.message)));
            }
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    final text = Theme.of(context).textTheme;

    if (_isEditing && !_loadedExisting) {
      final detail = ref.watch(birthdayDetailProvider(widget.birthdayId!));
      return Scaffold(
        appBar: AppBar(title: const Text('Edit birthday')),
        body: detail.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.screenPadding),
            child: LoadingSkeletonList(rows: 4, height: 64),
          ),
          error: (error, _) => ErrorView(
            message: error is ApiException ? error.message : 'Could not load this birthday.',
            onRetry: () => ref.invalidate(birthdayDetailProvider(widget.birthdayId!)),
          ),
          data: (birthday) {
            _hydrate(birthday);
            return const SizedBox.shrink();
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit birthday' : 'Add birthday')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            8,
            AppSpacing.screenPadding,
            40,
          ),
          children: [
            Center(
              child: Column(
                children: [
                  PersonAvatar(
                    initials: _nameController.text.trim().isEmpty
                        ? '?'
                        : _nameController.text.trim().substring(0, 1).toUpperCase(),
                    colorSeed: _nameController.text.length,
                    size: 84,
                    photoUrl: _photoUrl,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton.icon(
                        onPressed: _uploadingPhoto ? null : _pickPhoto,
                        icon: _uploadingPhoto
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.photo_camera_outlined, size: 18),
                        label: Text(_photoUrl == null ? 'Add photo' : 'Change photo'),
                      ),
                      if (_photoUrl != null)
                        TextButton(
                          onPressed: () => setState(() => _photoUrl = null),
                          style: TextButton.styleFrom(foregroundColor: palette.error),
                          child: const Text('Remove'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name *', hintText: 'Sarah Tan'),
              validator: Validators.name,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: _pickBirthday,
              borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Birthday *'),
                child: Text(
                  _month == null || _day == null
                      ? 'Select month and day'
                      : '$_day ${monthName(_month!)}',
                  style: text.bodyLarge?.copyWith(
                    color: _month == null ? palette.textSecondary : palette.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '29 February birthdays are celebrated on 28 February in non-leap years.',
              style: text.bodySmall?.copyWith(color: palette.textSecondary),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _yearController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Birth year (optional)',
                hintText: '2000',
              ),
              validator: Validators.birthYear,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _relationship,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Relationship'),
              items: [
                const DropdownMenuItem<String>(value: null, child: Text('None')),
                for (final relationship in _relationships)
                  DropdownMenuItem(value: relationship, child: Text(relationship)),
              ],
              onChanged: (value) => setState(() => _relationship = value),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone'),
              validator: Validators.phone,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (value) => Validators.email(value, required: false),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _notesController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'Likes travelling, allergic to nuts...',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 22),
            Text('Gift ideas', style: text.titleSmall),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _giftController,
                    decoration: const InputDecoration(hintText: 'Add a gift idea'),
                    onSubmitted: (_) => _addGiftIdea(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _addGiftIdea,
                  icon: const Icon(Icons.add),
                  tooltip: 'Add gift idea',
                  style: IconButton.styleFrom(backgroundColor: palette.primary, foregroundColor: palette.onPrimary),
                ),
              ],
            ),
            if (_giftIdeas.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final idea in _giftIdeas)
                    Chip(
                      label: Text(idea),
                      onDeleted: () => setState(
                        () => _giftIdeas = _giftIdeas.where((entry) => entry != idea).toList(),
                      ),
                      deleteIcon: const Icon(Icons.close, size: 16),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 22),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _remindersEnabled,
              onChanged: (value) async {
                setState(() => _remindersEnabled = value);
                if (value && _reminders.isEmpty) await _addDefaultReminder();
              },
              title: Text('Enable reminders', style: text.titleSmall),
              subtitle: Text(
                'Push notifications before the birthday, sent in your timezone.',
                style: text.bodySmall,
              ),
            ),
            if (_remindersEnabled) ...[
              const SizedBox(height: 6),
              for (final reminder in _reminders)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(reminder.label),
                    subtitle: Text(formatReminderTime(reminder.reminderTime)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: reminder.enabled,
                          onChanged: (value) => setState(() {
                            _reminders = _reminders
                                .map((entry) => entry.id == reminder.id
                                    ? entry.copyWith(enabled: value)
                                    : entry)
                                .toList();
                          }),
                        ),
                        IconButton(
                          tooltip: 'Remove reminder',
                          onPressed: () => setState(
                            () => _reminders = _reminders
                                .where((entry) => entry.id != reminder.id)
                                .toList(),
                          ),
                          icon: Icon(Icons.delete_outline, color: palette.error),
                        ),
                      ],
                    ),
                    onTap: () async {
                      final parts = reminder.reminderTime.split(':');
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(
                          hour: int.tryParse(parts.first) ?? 9,
                          minute: int.tryParse(parts.last) ?? 0,
                        ),
                      );
                      if (picked == null) return;
                      setState(() {
                        _reminders = _reminders
                            .map((entry) => entry.id == reminder.id
                                ? entry.copyWith(
                                    reminderTime: toReminderTimeValue(picked.hour, picked.minute),
                                  )
                                : entry)
                            .toList();
                      });
                    },
                  ),
                ),
              OutlinedButton.icon(
                onPressed: () async {
                  final created = await showAddReminderDialog(context, existing: _reminders);
                  if (created != null) setState(() => _reminders = [..._reminders, created]);
                },
                icon: const Icon(Icons.add_alarm_outlined, size: 18),
                label: const Text('Add another reminder'),
              ),
            ],
            const SizedBox(height: 26),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_isEditing ? 'Save changes' : 'Save birthday'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => context.push('/contacts'),
              icon: const Icon(Icons.contacts_outlined, size: 18),
              label: const Text('Import from contacts'),
            ),
          ],
        ),
      ),
    );
  }
}
