/// history_screen.dart
/// -----------------------------------------------------------------------
/// Real History screen — Sara's Step 16. Lists every saved calculation
/// (HistoryEntry = InputModel + OutputModel + timestamp) from
/// HistoryRepository, newest first, as cards matching the original
/// project mockup style (fabric blend, date, rate, width badges).
///
/// SCOPE NOTE: this screen reads + deletes entries (delete included here
/// since it was trivial alongside the read logic). "Tap to reload" —
/// loading a card's InputModel back into the Costing form — is still
/// Rabia's Step 17 and is NOT implemented here; tapping a card currently
/// does nothing. Look for the TODO in _HistoryCard's onTap.
library;

import 'package:flutter/material.dart';
import 'main_nav_shell.dart';
import '../models/history_entry_model.dart';
import '../services/history_repository.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

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

  const _HistoryCard({required this.entry, required this.onDelete});

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

    // Matches the original mockup's card title style: blend + weave +
    // count, e.g. "PC 80/20 Plain 40x40".
    final title =
        '${input.warpBlend} ${input.weave} ${input.warpCount.toStringAsFixed(0)}x${input.weftCount.toStringAsFixed(0)}';

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // TODO (Rabia, Step 17): reload `entry.input` back into the
          // Costing form when tapped. Not implemented yet — tapping a
          // card currently does nothing except show the delete icon.
        },
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
                    text:
                    '${output.greyFabricRate.toStringAsFixed(2)} PKR/mtr',
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(width: 8),
                  _Badge(
                    text: '${input.width.toStringAsFixed(0)}" width',
                    colorScheme: colorScheme,
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

  const _Badge({required this.text, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}