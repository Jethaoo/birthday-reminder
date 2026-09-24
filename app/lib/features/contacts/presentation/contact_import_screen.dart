import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/models/birthday.dart';
import '../../../shared/widgets/states.dart';
import '../../birthdays/birthday_providers.dart';

/// A contact that has a birthday event, ready to be imported.
typedef ContactCandidate = ({Contact contact, Event birthday});

/// Imports birthdays from the device contacts.
///
/// Only the contacts the user selects are ever sent to the server, and the
/// full address book is never uploaded.
class ContactImportScreen extends ConsumerStatefulWidget {
  const ContactImportScreen({super.key});

  @override
  ConsumerState<ContactImportScreen> createState() => _ContactImportScreenState();
}

class _ContactImportScreenState extends ConsumerState<ContactImportScreen> {
  bool _loading = true;
  bool _permissionDenied = false;
  bool _importing = false;
  List<ContactCandidate> _candidates = [];
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadContacts());
  }

  Future<void> _loadContacts() async {
    setState(() => _loading = true);
    try {
      final granted = await FlutterContacts.requestPermission(readonly: true);
      if (!granted) {
        setState(() {
          _permissionDenied = true;
          _loading = false;
        });
        return;
      }

      final contacts = await FlutterContacts.getContacts(withProperties: true);
      final candidates = <ContactCandidate>[];
      for (final contact in contacts) {
        if (contact.displayName.isEmpty) continue;
        for (final event in contact.events) {
          if (event.label == EventLabel.birthday) {
            candidates.add((contact: contact, birthday: event));
            break;
          }
        }
      }
      candidates.sort((a, b) => a.contact.displayName.compareTo(b.contact.displayName));

      setState(() {
        _candidates = candidates;
        _loading = false;
      });
    } catch (error) {
      setState(() {
        _permissionDenied = true;
        _loading = false;
      });
    }
  }

  Future<void> _import() async {
    final selected = _candidates.where((entry) => _selected.contains(entry.contact.id)).toList();
    if (selected.isEmpty) return;

    setState(() => _importing = true);
    final actions = ref.read(birthdayActionsProvider);
    var imported = 0;
    var duplicates = 0;
    var failed = 0;

    for (final entry in selected) {
      final birthday = entry.birthday;
      try {
        await actions.create(
          Birthday(
            id: '',
            name: entry.contact.displayName,
            birthdayMonth: birthday.month,
            birthdayDay: birthday.day,
            birthYear: (birthday.year ?? 0) > 1900 ? birthday.year : null,
            nextOccurrence: DateTime.now(),
            daysUntil: 0,
          ),
        );
        imported += 1;
      } on ApiException catch (error) {
        if (error.code == ApiErrorCode.conflict) {
          duplicates += 1;
        } else {
          failed += 1;
        }
      }
    }

    if (!mounted) return;
    setState(() => _importing = false);

    final parts = <String>[
      '$imported imported',
      if (duplicates > 0) '$duplicates already saved',
      if (failed > 0) '$failed failed',
    ];
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(parts.join(' · '))));
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Import birthdays')),
      body: _loading
          ? const Padding(
              padding: EdgeInsets.all(AppSpacing.screenPadding),
              child: LoadingSkeletonList(rows: 5, height: 64),
            )
          : _permissionDenied
              ? EmptyState(
                  emoji: '🔒',
                  title: 'Contact access needed',
                  message:
                      'Allow contact access to find birthdays. Only the contacts you pick are saved to your account.',
                  action: FilledButton(
                    onPressed: _loadContacts,
                    child: const Text('Allow access'),
                  ),
                )
              : _candidates.isEmpty
                  ? const EmptyState(
                      emoji: '📇',
                      title: 'No birthdays in contacts',
                      message: 'None of your contacts have a birthday saved.',
                    )
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.screenPadding,
                            12,
                            AppSpacing.screenPadding,
                            0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${_selected.length} selected', style: text.titleSmall),
                              TextButton(
                                onPressed: () => setState(() {
                                  if (_selected.length == _candidates.length) {
                                    _selected.clear();
                                  } else {
                                    _selected
                                      ..clear()
                                      ..addAll(_candidates.map((entry) => entry.contact.id));
                                  }
                                }),
                                child: Text(
                                  _selected.length == _candidates.length ? 'Clear all' : 'Select all',
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.all(AppSpacing.screenPadding),
                            itemCount: _candidates.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final entry = _candidates[index];
                              final selected = _selected.contains(entry.contact.id);
                              return Card(
                                child: CheckboxListTile(
                                  value: selected,
                                  onChanged: (value) => setState(() {
                                    if (value ?? false) {
                                      _selected.add(entry.contact.id);
                                    } else {
                                      _selected.remove(entry.contact.id);
                                    }
                                  }),
                                  title: Text(entry.contact.displayName),
                                  subtitle: Text(
                                    longDate(DateTime(2000, entry.birthday.month, entry.birthday.day)),
                                  ),
                                  controlAffinity: ListTileControlAffinity.trailing,
                                ),
                              );
                            },
                          ),
                        ),
                        SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.screenPadding,
                              0,
                              AppSpacing.screenPadding,
                              16,
                            ),
                            child: FilledButton(
                              onPressed: _selected.isEmpty || _importing ? null : _import,
                              style: FilledButton.styleFrom(backgroundColor: palette.primary),
                              child: _importing
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Text('Import ${_selected.length} birthday(s)'),
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }
}
