/// outputs_placeholder_screen.dart
/// -----------------------------------------------------------------------
/// STAND-IN for Rabia's Step 9 (the real 4-tab Output screen: Fabric Cost,
/// Yarn Weight, Production & Requirements, Cover Factor). This exists so
/// the bottom nav bar (Sara's Step 8) has somewhere real to navigate to
/// and can be tested end-to-end before Step 9 is built.
///
/// HANDOFF NOTE FOR RABIA (Step 9):
/// Replace the body of this screen with the real TabBar/TabBarView of
/// output sections from the project manual Section 3.2. Reuse
/// HeadlineBanner exactly like InputScreen does — it's already pinned
/// here as a placeholder using zeros.
///
/// IMPORTANT — state lifting needed: this screen currently has no way to
/// see the live OutputModel that InputScreen calculates, because that
/// state is local to InputScreen's _InputScreenState (_greyFabricRate /
/// _loomInFlow / etc). Before wiring real numbers in here, that output
/// state needs to move up into a shared place both screens can read —
/// e.g. a Provider/ChangeNotifier holding the latest OutputModel, set
/// from InputScreen._recalculate() instead of local setState. Flagging
/// this now so it isn't a surprise during Phase 4 integration.
library;
import 'main_nav_shell.dart';

import 'package:flutter/material.dart';
import '../widgets/headline_banner.dart';

class OutputsPlaceholderScreen extends StatelessWidget {
  const OutputsPlaceholderScreen({super.key});

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
        title: const Text('Outputs'),
      ),
      body: Column(
        children: [
          const HeadlineBanner(
            greyFabricRate: 0,
            loomInFlow: 0,
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.bar_chart_outlined,
                      size: 48,
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Output tabs coming soon',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Fabric Cost, Yarn Weight, Production and '
                      'Cover Factor will appear here as tabs.',
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
          ),
        ],
      ),
    );
  }
}
