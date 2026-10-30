import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/validators.dart';

/// Required once for every account. The server rejects any later change.
class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() =>
      _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _yearController = TextEditingController();
  int? _month;
  int? _day;
  bool _saving = false;

  @override
  void dispose() {
    _yearController.dispose();
    super.dispose();
  }

  void _selectMonth(int? month) {
    setState(() {
      _month = month;
      final maxDay = month == null ? 31 : DateTime(2024, month + 1, 0).day;
      if ((_day ?? 0) > maxDay) _day = maxDay;
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_month == null || _day == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose your birthday date.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final user = await ref
          .read(apiProvider)
          .setMyBirthday(
            birthdayMonth: _month!,
            birthdayDay: _day!,
            birthYear: int.tryParse(_yearController.text.trim()),
          );
      await ref.read(authControllerProvider.notifier).applyUser(user);
      if (mounted) context.go('/home');
    } on ApiException catch (error) {
      if (error.code == ApiErrorCode.conflict) {
        await ref.read(authControllerProvider.notifier).refreshUser();
        if (mounted) context.go('/home');
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    final text = Theme.of(context).textTheme;
    final maxDay = _month == null ? 31 : DateTime(2024, _month! + 1, 0).day;

    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            children: [
              const SizedBox(height: 24),
              Container(
                width: 68,
                height: 68,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: palette.softPink,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Text('🎂', style: TextStyle(fontSize: 32)),
              ),
              const SizedBox(height: 24),
              Text(
                'Add your birthday',
                style: text.displaySmall?.copyWith(fontSize: 32),
              ),
              const SizedBox(height: 10),
              Text(
                'Your birthday personalizes your profile and can only be set once.',
                style: text.bodyLarge?.copyWith(color: palette.textSecondary),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<int>(
                      initialValue: _month,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Month'),
                      items: [
                        for (var month = 1; month <= 12; month += 1)
                          DropdownMenuItem(
                            value: month,
                            child: Text(monthName(month)),
                          ),
                      ],
                      onChanged: _selectMonth,
                      validator: (value) =>
                          value == null ? 'Choose a month.' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<int>(
                      key: ValueKey(_month),
                      initialValue: _day,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Day'),
                      items: [
                        for (var day = 1; day <= maxDay; day += 1)
                          DropdownMenuItem(value: day, child: Text('$day')),
                      ],
                      onChanged: (value) => setState(() => _day = value),
                      validator: (value) =>
                          value == null ? 'Choose a day.' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _yearController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Birth year (optional)',
                  helperText:
                      'Leave empty if you prefer not to share your age.',
                ),
                validator: Validators.birthYear,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: palette.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 20,
                      color: palette.textSecondary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Choose carefully. To keep your profile date stable, it cannot be changed after you confirm it.',
                        style: text.bodySmall?.copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save my birthday'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
