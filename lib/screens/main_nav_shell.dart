/// main_nav_shell.dart
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/costing_provider.dart';
import 'input_screen.dart';
import 'outputs_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import '../widgets/sidebar_drawer.dart';
import '../models/history_entry_model.dart';
import '../services/history_repository.dart';

final scaffoldKey = GlobalKey<ScaffoldState>();

class MainNavShell extends StatefulWidget {
  const MainNavShell({super.key});

  @override
  State<MainNavShell> createState() => _MainNavShellState();
}

class _MainNavShellState extends State<MainNavShell> {
  int _currentIndex = 0;
  int _outputsSubTab = 0;
  int _historyRefreshKey = 0;

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
          _historyRefreshKey++;
        case DrawerDestination.settings:
          _currentIndex = 3;
      }
    });
  }

  /// Called by HistoryScreen after requestReload() — switches to Costing
  /// tab so the user immediately sees their reloaded values.
  void _switchToCosting() {
    setState(() => _currentIndex = 0);
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
        onSave: () => _saveToHistory(context),
      ),
      HistoryScreen(
        key: ValueKey(_historyRefreshKey),
        onReload: _switchToCosting,
      ),
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
          setState(() {
            _currentIndex = index;
            if (index == 2) _historyRefreshKey++;
          });
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

  Future<void> _saveToHistory(BuildContext context) async {
    final costingProvider = context.read<CostingProvider>();
    final input = costingProvider.lastInput;
    final output = costingProvider.output;
    if (input == null || output == null) return;

    await HistoryRepository.instance.save(
      HistoryEntry.now(input: input, output: output),
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved to History')),
    );
  }
}

class _NoCalculationYet extends StatelessWidget {
  const _NoCalculationYet();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
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
              Icon(Icons.bar_chart_outlined, size: 48,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
              const SizedBox(height: 12),
              Text('No calculation yet',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500,
                      color: colorScheme.onSurfaceVariant)),
              const SizedBox(height: 6),
              Text('Fill in the Costing form to see results here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12,
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7))),
            ],
          ),
        ),
      ),
    );
  }
}