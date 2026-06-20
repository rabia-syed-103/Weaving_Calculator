/// history_screen.dart
/// -----------------------------------------------------------------------
/// History screen STUB — Sara's Step 8 builds the navigation entry point
/// only. Real local-storage history (Hive save/load, "tap to reload",
/// delete entry) is Step 16-18 per the phase plan, not part of Step 8.
///
/// HANDOFF NOTE: once Hive storage exists for saved calculations
/// (InputModel + OutputModel + timestamp), replace the empty-state body
/// below with a ListView of saved entries, same visual pattern as
/// HeadlineBanner / InputFieldCard for consistency.
library;
import 'main_nav_shell.dart';

import 'package:flutter/material.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: 'Open menu',
          onPressed: () => scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('History'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.history_outlined,
                size: 48,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 12),
              Text(
                'No saved calculations yet',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Every calculation you run will be saved here '
                'automatically, with the option to reload it.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
