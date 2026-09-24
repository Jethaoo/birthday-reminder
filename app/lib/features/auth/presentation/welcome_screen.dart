import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: palette.softPink,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Text('🎂', style: TextStyle(fontSize: 34)),
              ),
              const SizedBox(height: 28),
              Text('Remember Every\nBirthday', style: text.displaySmall?.copyWith(fontSize: 36)),
              const SizedBox(height: 12),
              Text(
                'Never forget an important birthday again. Save the dates, get reminders before the day and keep gift ideas in one place.',
                style: text.bodyLarge?.copyWith(color: palette.textSecondary),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => context.go('/register'),
                child: const Text('Get started'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.go('/login'),
                child: const Text('Sign in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
