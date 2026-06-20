/// main_nav_shell.dart
/// -----------------------------------------------------------------------
/// Bottom navigation shell — wraps the 4 main screens (Costing, Outputs,
/// History, Settings) behind a BottomNavigationBar, AND owns the
/// SidebarDrawer so it's reachable from any tab via the hamburger icon,
/// not just from InputScreen's own AppBar.
///
/// This replaces the earlier 3-tab version. Settings is now its own
/// bottom-nav destination (matching the original project mockup) in
/// addition to being reachable from the sidebar drawer — both paths lead
/// to the same SettingsScreen.
library;

import 'package:flutter/material.dart';
import 'input_screen.dart';
import 'outputs_placeholder_screen.dart';
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

  // IndexedStack keeps all 4 screens alive in memory rather than rebuilding
  // them on every tab switch — important here because InputScreen holds
  // live form state (31 controllers) that shouldn't reset just because the
  // user tapped over to another tab and back.
  final List<Widget> _screens = const [
    InputScreen(),
    OutputsPlaceholderScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  void _handleDrawerNavigate(DrawerDestination destination, {int? outputsSubTab}) {
    setState(() {
      switch (destination) {
        case DrawerDestination.costing:
          _currentIndex = 0;
        case DrawerDestination.outputs:
          _currentIndex = 1;
          // TODO: once Rabia's Step 9 tabbed Outputs screen exists, pass
          // outputsSubTab through to select the right tab (Fabric Cost /
          // Yarn Weight / Production / Cover Factor). Ignored for now
          // since OutputsPlaceholderScreen has no tabs yet.
          break;
        case DrawerDestination.history:
          _currentIndex = 2;
        case DrawerDestination.settings:
          _currentIndex = 3;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      drawer: SidebarDrawer(onNavigate: _handleDrawerNavigate),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
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