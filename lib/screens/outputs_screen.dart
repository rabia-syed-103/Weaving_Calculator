/// outputs_screen.dart
/// -----------------------------------------------------------------------
/// Rabia's Step 9 — the REAL 4-tab Output screen, replacing
/// outputs_placeholder_screen.dart. Tabs: Fabric Cost, Yarn Weight,
/// Production & Requirements, Cover Factor — exactly the order from the
/// project manual / SidebarDrawer (outputsSubTab 0..3).
///
/// HANDOFF NOTE FOR SARA (Step 10 / Phase 4 wiring):
/// This screen currently takes `output` as a constructor parameter and
/// has no way to see live data from InputScreen — same state-lifting
/// gap flagged in outputs_placeholder_screen.dart. Until that shared
/// OutputModel state exists (Provider/ChangeNotifier set from
/// InputScreen._recalculate()), this screen is wired to a single
/// hardcoded example OutputModel (see main_nav_shell.dart change below)
/// purely so the 4 tabs render and can be visually checked. Swap the
/// hardcoded value for the live one as soon as that shared state lands
/// — search for "TODO(wiring)" below.
///
/// `initialSubTab` lets the sidebar drawer open this screen directly on
/// one of the 4 sub-tabs (e.g. tapping "Cover factor" in the drawer
/// jumps straight to that tab) — wires up the outputsSubTab parameter
/// that SidebarDrawer.onNavigate already passes, previously ignored by
/// the placeholder.
library;

import 'package:flutter/material.dart';
import 'main_nav_shell.dart';
import '../models/output_model.dart';
import '../widgets/headline_banner.dart';
import 'fabric_cost_tab.dart';
import 'yarn_weight_tab.dart';
import 'production_tab.dart';
import 'cover_factor_tab.dart';

class OutputsScreen extends StatefulWidget {
  final OutputModel output;
  final int initialSubTab;

  const OutputsScreen({
    super.key,
    required this.output,
    this.initialSubTab = 0,
  });

  @override
  State<OutputsScreen> createState() => _OutputsScreenState();
}

class _OutputsScreenState extends State<OutputsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialSubTab,
    );
  }

  @override
  void didUpdateWidget(OutputsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the drawer requests a different sub-tab while this screen is
    // already alive (IndexedStack keeps it in memory), jump to it.
    if (widget.initialSubTab != oldWidget.initialSubTab) {
      _tabController.animateTo(widget.initialSubTab);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: 'Open menu',
          onPressed: () => scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('Outputs'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Fabric Cost'),
            Tab(text: 'Yarn Weight'),
            Tab(text: 'Production'),
            Tab(text: 'Cover Factor'),
          ],
        ),
      ),
      body: Column(
        children: [
          HeadlineBanner(
            greyFabricRate: widget.output.greyFabricRate,
            loomInFlow: widget.output.loomInFlow,
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                FabricCostTab(output: widget.output),
                YarnWeightTab(output: widget.output),
                ProductionTab(output: widget.output),
                CoverFactorTab(output: widget.output),
              ],
            ),
          ),
        ],
      ),
    );
  }
}