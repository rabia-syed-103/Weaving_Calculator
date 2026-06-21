/// main_nav_shell.dart
/// -----------------------------------------------------------------------
/// Bottom navigation shell — wraps the 4 main screens (Costing, Outputs,
/// History, Settings) behind a BottomNavigationBar, AND owns the
/// SidebarDrawer so it's reachable from any tab via the hamburger icon,
/// not just from InputScreen's own AppBar.
///
/// CHANGE FROM PREVIOUS VERSION: OutputsPlaceholderScreen is replaced by
/// the real OutputsScreen (Rabia's Step 9). The drawer's outputsSubTab
/// parameter — previously ignored with a TODO — now actually selects
/// the right tab (Fabric Cost / Yarn Weight / Production / Cover
/// Factor) by passing it through as OutputsScreen.initialSubTab.
///
/// TODO(wiring) — Phase 4: OutputsScreen still takes a hardcoded example
/// OutputModel below (`_exampleOutput`) because there's no shared
/// OutputModel state yet — that gap is flagged in outputs_screen.dart's
/// header comment. Once InputScreen's calculation result is lifted into
/// a Provider/ChangeNotifier, replace `_exampleOutput` with the live
/// value from that provider instead of building the screen list here
/// with a fixed const.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/costing_provider.dart';
import 'input_screen.dart';
import 'outputs_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import '../widgets/sidebar_drawer.dart';

final scaffoldKey = GlobalKey<ScaffoldState>();

class MainNavShell extends StatefulWidget {
  const MainNavShell({super.key});

  @override
  State<MainNavShell> createState() => _MainNavShellState();
}

class _MainNavShellState extends State<MainNavShell> {
  int _currentIndex = 0;
  int _outputsSubTab = 0;

  void _handleDrawerNavigate(DrawerDestination destination, {int? outputsSubTab}) {
    setState(() {
      switch (destination) {
        case DrawerDestination.costing:
          _currentIndex = 0;
        case DrawerDestination.outputs:
          _currentIndex = 1;
          if (outputsSubTab != null) _outputsSubTab = outputsSubTab;
        case DrawerDestination.history:
          _currentIndex = 2;
        case DrawerDestination.settings:
          _currentIndex = 3;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final liveOutput = context.watch<CostingProvider>().output;

    final screens = [
      const InputScreen(),
      liveOutput == null
          ? const _NoCalculationYet()
          : OutputsScreen(
              output: liveOutput,
              initialSubTab: _outputsSubTab,
            ),
      const HistoryScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      key: scaffoldKey,
      drawer: SidebarDrawer(onNavigate: _handleDrawerNavigate),
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calculate_outlined),
            selectedIcon: Icon(Icons.calculate),
            label: 'Costing',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Outputs',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
/// Shown in the Outputs tab when no calculation has run yet — i.e. the
/// Costing form is empty or incomplete, so CostingProvider.output is
/// still null. Mirrors the empty-state style used elsewhere in the app
/// (HistoryScreen's "no saved calculations" state).
class _NoCalculationYet extends StatelessWidget {
  const _NoCalculationYet();

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
      body: Center(
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
                'No calculation yet',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Fill in the Costing form to see results here.',
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
