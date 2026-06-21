/// share_service.dart
/// -----------------------------------------------------------------------
/// Opens the phone's native share sheet (WhatsApp, email, Drive, etc. —
/// whatever the user has installed) with the exported Excel file
/// attached. Uses share_plus, which is the standard Flutter package for
/// this — it does NOT target WhatsApp specifically, it hands the file to
/// the OS share sheet and the user picks where it goes (per direct
/// instruction: generic share, not a WhatsApp-only deep link).
///
/// SETUP STEPS:
///
/// 1. Add to pubspec.yaml:
///      dependencies:
///        share_plus: ^10.1.2
///    Then `flutter pub get`.
///
/// 2. No platform-specific permissions needed for sharing a file you
///    already created in the app's own temp directory — share_plus
///    handles the platform share intent/UIActivityViewController
///    internally.
///
/// API NOTE: this uses Share.shareXFiles(...), the API for share_plus
/// v10.x (the version pinned in this project's pubspec.yaml). Newer
/// share_plus versions (12+) replaced this with
/// SharePlus.instance.share(ShareParams(...)) — do NOT switch to that
/// syntax unless pubspec.yaml's share_plus constraint is also bumped to
/// ^12.0.0 or higher, or this will fail to compile again.
///
/// USAGE — call this from the share icon's onPressed:
///   await ShareService.shareCostingSheet(historyEntry);
library;

import 'package:share_plus/share_plus.dart';
import '../models/history_entry_model.dart';
import 'excel_export_service.dart';

class ShareService {
  /// Builds the Excel snapshot for [entry] and opens the share sheet.
  static Future<void> shareCostingSheet(HistoryEntry entry) async {
    final filePath = await ExcelExportService.export(entry);

    await Share.shareXFiles(
      [XFile(filePath)],
      text: 'SadeedTex Fabric Costing — Grey Fabric Rate: '
          '${entry.output.greyFabricRate.toStringAsFixed(2)} PKR/mtr',
      subject: 'SadeedTex Costing Sheet',
    );
  }
}