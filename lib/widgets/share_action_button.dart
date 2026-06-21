/// share_action_button.dart
/// -----------------------------------------------------------------------
/// The share icon that sits in every screen's AppBar (next to "SadeedTex"
/// title / actions), per direct instruction. Reads the latest calculation
/// from CostingProvider — if nothing has been calculated yet, the button
/// is disabled (greyed out) rather than crashing or sharing empty/zero
/// data.
///
/// Drop this into any Scaffold's AppBar.actions: [ShareActionButton()].
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/history_entry_model.dart';
import '../models/input_model.dart';
import '../models/output_model.dart';
import '../services/share_service.dart';
import '../theme/costing_provider.dart';

class ShareActionButton extends StatefulWidget {
  const ShareActionButton({super.key});

  @override
  State<ShareActionButton> createState() => _ShareActionButtonState();
}

class _ShareActionButtonState extends State<ShareActionButton> {
  bool _isSharing = false;

  @override
  Widget build(BuildContext context) {
    final costingProvider = context.watch<CostingProvider>();
    final output = costingProvider.output;
    final input = costingProvider.lastInput;

    final canShare = output != null && input != null && !_isSharing;

    return IconButton(
      icon: _isSharing
          ? const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      )
          : const Icon(Icons.share_outlined),
      tooltip: 'Share Costing Sheet',
      onPressed: canShare ? () => _handleShare(input, output) : null,
    );
  }

  Future<void> _handleShare(InputModel input, OutputModel output) async {
    setState(() => _isSharing = true);
    try {
      final entry = HistoryEntry.now(input: input, output: output);
      await ShareService.shareCostingSheet(entry);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create the share file: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }
}