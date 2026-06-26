/// share_service.dart
/// -----------------------------------------------------------------------
/// Opens the phone's native share sheet with BOTH the Excel (.xlsx) and
/// PDF (.pdf) costing snapshots attached — user picks where they go
/// (WhatsApp, email, Drive, etc.).
///
/// UPDATED from single-file Excel-only to dual-file Excel + PDF:
///   - Excel (.xlsx): editable-style snapshot, same layout as the
///     original Costing_InFlow_PerPick.xlsm (built by ExcelExportService)
///   - PDF (.pdf): clean, printable summary (built by PdfExportService)
///
/// Both files are built in parallel via Future.wait() to keep it fast.
///
/// API NOTE: uses Share.shareXFiles(...) from share_plus v10.x.
/// Do NOT switch to SharePlus.instance.share(ShareParams(...)) unless
/// pubspec.yaml's share_plus constraint is bumped to ^12.0.0+.
library;

import 'package:share_plus/share_plus.dart';
import '../models/history_entry_model.dart';
import 'excel_export_service.dart';
import 'pdf_export_service.dart';

class ShareService {
  /// Builds both the Excel and PDF snapshots for [entry] in parallel,
  /// then opens the share sheet with both files attached.
  static Future<void> shareCostingSheet(HistoryEntry entry) async {
    // Export both formats in parallel — no reason to wait for one
    // before starting the other since they're independent.
    final results = await Future.wait([
      ExcelExportService.export(entry),
      PdfExportService.export(entry),
    ]);

    final xlsxPath = results[0];
    final pdfPath = results[1];

    await Share.shareXFiles(
      [XFile(xlsxPath), XFile(pdfPath)],
      text: 'TrendTex Fabric Costing — Grey Fabric Rate: '
          '${entry.output.greyFabricRate.toStringAsFixed(2)} PKR/mtr',
      subject: 'TrendTex Costing Sheet',
    );
  }
}