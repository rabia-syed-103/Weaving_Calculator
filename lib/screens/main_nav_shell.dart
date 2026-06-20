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
import 'input_screen.dart';
import 'outputs_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import '../models/output_model.dart';
import '../widgets/sidebar_drawer.dart';

final scaffoldKey = GlobalKey<ScaffoldState>();

// TODO(wiring): placeholder so OutputsScreen has something to render
// before Phase 4 wires it to InputScreen's live calculation result.
// Delete once the shared OutputModel provider exists.
final OutputModel _exampleOutput = OutputModel(
  greyFabricRate: 251.70,
  loomInFlow: 29909.87,
  yarnWarpCost: 106.19,
  yarnWeftCost: 83.49,
  totalYarnCost: 189.68,
  sizingCostPerMtr: 4.31,
  weavingCost: 59.47,
  offGradePct: 0.05,
  commissionCost: 2.49,
  warpWeightShrinkageWastage: 0.1609,
  weftWeightShrinkageWastage: 0.1265,
  additionalWarpWeightShrinkageWastage: 0,
  additionalWeftWeightShrinkageWastage: 0,
  warpWeightOnlyShrinkage: 0.1553,
  weftWeightOnlyShrinkage: 0.1309,
  additionalWarpWeightOnlyShrinkage: 0,
  additionalWeftWeightOnlyShrinkage: 0,
  warpKgPerMtr: 0.0704,
  totalPicks: 86,
  perDayPerLoomProduction: 568.42,
  dailyProductionAllLooms: 2842.09,
  daysRequiredForCompletion: 17.59,
  completionDate: DateTime(2026, 7, 9),
  warpBagsRequired: 8045,
  secondWarpBagsRequired: 0,
  weftBagsRequired: 6325,
  secondWeftBagsRequired: 0,
  coverFactorWarp: 13.17,
  coverFactorSecondWarp: 0,
  coverFactorWeft: 11.10,
  coverFactorSecondWeft: 0,
  totalCoverFactor: 24.27,
  reedSpaceInches: 64.69,
  tapeLengthMtr: 104.30,
  wtGramsPerMetre: 0.1257,
  container20ftMtrs: 103443,
  container40ftMtrs: 206885,
);

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
    // Built inline (not as a const list) because OutputsScreen now needs
    // _outputsSubTab, which changes at runtime via the drawer.
    final screens = [
      const InputScreen(),
      OutputsScreen(
        output: _exampleOutput,
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