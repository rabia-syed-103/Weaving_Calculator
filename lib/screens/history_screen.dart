/// history_screen.dart
/// -----------------------------------------------------------------------
/// History screen — lists every saved calculation (HistoryEntry =
/// InputModel + OutputModel + timestamp) from HistoryRepository, newest
/// first, as cards.
///
/// Step 17 (tap to reload) is now implemented: tapping a card calls
/// CostingProvider.requestReload(entry.input), then switches the bottom
/// nav to the Costing tab (index 0) via the onReload callback passed in
/// from MainNavShell. InputScreen's didChangeDependencies() picks up the
/// pending reload from CostingProvider and fills all its controllers.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'main_nav_shell.dart';
import '../models/history_entry_model.dart';
import '../services/history_repository.dart';
import '../theme/costing_provider.dart';

class HistoryScreen extends StatefulWidget {
  /// Called after a reload is requested — switches the bottom nav back
  /// to the Costing tab so the user can see their loaded values.
  /// Provided by MainNavShell.
  final VoidCallback? onReload;

  const HistoryScreen({super.key, this.onReload});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late List<HistoryEntry> _entries;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  void _loadEntries() {
    setState(() {
      _entries = HistoryRepository.instance.getAll();
    });
  }

  Future<void> _deleteEntry(HistoryEntry entry) async {
    await HistoryRepository.instance.delete(entry.id);
    if (!mounted) return;
    _loadEntries();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Deleted from History')),
    );
  }

  void _reloadEntry(HistoryEntry entry) {
    context.read<CostingProvider>().requestReload(entry.input);
    widget.onReload?.call();
  }

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
        actions: [
          if (_entries.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: _loadEntries,
            ),
        ],
      ),
      body: _entries.isEmpty
          ? _EmptyState(colorScheme: colorScheme)
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _entries.length,
        itemBuilder: (context, index) {
          final entry = _entries[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _HistoryCard(
              entry: entry,
              onDelete: () => _deleteEntry(entry),
              onReload: () => _reloadEntry(entry),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final ColorScheme colorScheme;
  const _EmptyState({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Center(
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
              'Tap the save icon on the Outputs screen '
                  'to keep a calculation here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final HistoryEntry entry;
  final VoidCallback onDelete;
  final VoidCallback onReload;

  const _HistoryCard({
    required this.entry,
    required this.onDelete,
    required this.onReload,
  });

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final input = entry.input;
    final output = entry.output;

    final title =
        '${input.warpBlend} ${input.weave} ${input.warpCount.toStringAsFixed(0)}x${input.weftCount.toStringAsFixed(0)}';

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onReload,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    _formatDate(entry.savedAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: onDelete,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _Badge(
                    text: '${output.greyFabricRate.toStringAsFixed(2)} PKR/mtr',
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(width: 8),
                  _Badge(
                    text: '${input.width.toStringAsFixed(0)}" width',
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(width: 8),
                  _Badge(
                    text: 'Tap to reload',
                    colorScheme: colorScheme,
                    subtle: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final ColorScheme colorScheme;
  final bool subtle;

  const _Badge({
    required this.text,
    required this.colorScheme,
    this.subtle = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: subtle
            ? colorScheme.surfaceContainerLow
            : colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: subtle
              ? colorScheme.onSurfaceVariant
              : colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}