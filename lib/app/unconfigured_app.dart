import 'package:flutter/material.dart';

import 'theme/app_theme.dart';

/// Boots only when the build shipped without Supabase credentials (missing
/// secrets.env at build time). Shows an actionable message instead of crashing
/// or hanging on a blank splash.
class UnconfiguredApp extends StatelessWidget {
  const UnconfiguredApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_outlined, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'Crystal Messenger is not connected',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'This build has no backend credentials. Rebuild it with '
                    'your Supabase URL + anon key:\n\n'
                    '1. Copy secrets.env.example to secrets.env\n'
                    '2. Fill in your project values\n'
                    '3. Run tools/build_release.ps1\n\n'
                    'Credentials are injected at build time and never stored '
                    'in the source repository.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
