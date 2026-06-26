/// pdf_export_service.dart
/// -----------------------------------------------------------------------
/// Builds a .pdf snapshot from a HistoryEntry (InputModel + OutputModel)
/// covering the same data as ExcelExportService but in a clean, readable
/// PDF layout — suitable for WhatsApp, email, or printing.
///
/// Layout:
///   - Header: TrendTex branding + fabric spec title + date
///   - Section 1: Fabric Inputs (all Section A fields)
///   - Section 2: Fabric Cost outputs
///   - Section 3: Yarn Weight outputs
///   - Section 4: Production & Requirements outputs
///   - Section 5: Cover Factor, Reed Space, Tape Length outputs
///   - Footer: Grey Fabric Rate + Loom In Flow highlighted
///
/// USAGE — same pattern as ExcelExportService:
///   final pdfPath = await PdfExportService.export(entry);
///   // then pass to share_plus as an XFile alongside the xlsx
library;

import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import '../models/history_entry_model.dart';

class PdfExportService {
  static Future<String> export(HistoryEntry entry) async {
    final input = entry.input;
    final output = entry.output;
    final pdf = pw.Document();

    // Brand colors matching the app's green theme
    const brandGreen = PdfColor.fromInt(0xFF1a5c3a);
    const lightGreen = PdfColor.fromInt(0xFFe8f5ee);
    const headerText = PdfColors.white;

    pw.Widget _sectionHeader(String title) => pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      color: brandGreen,
      child: pw.Text(
        title,
        style: pw.TextStyle(
          color: headerText,
          fontWeight: pw.FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );

    pw.Widget _row(String label, String value, {bool highlight = false}) =>
        pw.Container(
          color: highlight ? lightGreen : PdfColors.white,
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: pw.Row(
            children: [
              pw.Expanded(
                flex: 3,
                child: pw.Text(label,
                    style: const pw.TextStyle(fontSize: 9)),
              ),
              pw.Expanded(
                flex: 2,
                child: pw.Text(
                  value,
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: highlight
                        ? pw.FontWeight.bold
                        : pw.FontWeight.normal,
                  ),
                  textAlign: pw.TextAlign.right,
                ),
              ),
            ],
          ),
        );

    pw.Widget _divider() => pw.Divider(
      height: 0.5,
      color: PdfColors.grey300,
    );

    String _date(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              color: brandGreen,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'TrendTex — Fabric Costing Sheet',
                    style: pw.TextStyle(
                      color: headerText,
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    '${input.warpBlend}  ${input.weave}  '
                        '${input.warpCount.toStringAsFixed(0)}×${input.weftCount.toStringAsFixed(0)} Ne  '
                        '${input.width.toStringAsFixed(0)}" width',
                    style: const pw.TextStyle(
                      color: headerText,
                      fontSize: 10,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Generated: ${_date(entry.savedAt)}',
                    style: const pw.TextStyle(
                      color: headerText,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
          ],
        ),
        build: (_) => [
          // Headline outputs — most important, shown first
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(10),
            color: lightGreen,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                pw.Column(children: [
                  pw.Text('GREY FABRIC RATE',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  pw.Text(
                    '${output.greyFabricRate.toStringAsFixed(2)} PKR/mtr',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 13,
                        color: brandGreen),
                  ),
                ]),
                pw.Column(children: [
                  pw.Text('LOOM IN FLOW',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  pw.Text(
                    '${output.loomInFlow.toStringAsFixed(0)} PKR/day',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 13,
                        color: brandGreen),
                  ),
                ]),
              ],
            ),
          ),
          pw.SizedBox(height: 12),

          // Section 1: Fabric Inputs
          _sectionHeader('A.  Fabric Specification — User Inputs'),
          _row('Warp Blend', input.warpBlend),
          _divider(),
          _row('Ply', input.ply.toStringAsFixed(0)),
          _divider(),
          _row('Warp Count (Ne)', input.warpCount.toStringAsFixed(0)),
          _divider(),
          _row('Weft Count (Ne)', input.weftCount.toStringAsFixed(0)),
          _divider(),
          _row('Ends Per Inch', input.endsPerInch.toStringAsFixed(0)),
          _divider(),
          _row('Picks Per Inch', input.picksPerInch.toStringAsFixed(0)),
          _divider(),
          _row('Width', '${input.width.toStringAsFixed(0)}"'),
          _divider(),
          _row('Weave', input.weave),
          _divider(),
          _row('Warp Shrinkage %', '${input.warpShrinkagePct}%'),
          _divider(),
          _row('Weft Shrinkage %', '${input.weftShrinkagePct}%'),
          _divider(),
          _row('Warp Wastage %', '${input.warpWastagePct}%'),
          _divider(),
          _row('Weft Wastage %', '${input.weftWastagePct}%'),
          _divider(),
          _row('Warp Yarn Rate', input.warpYarnRate.toStringAsFixed(2)),
          _divider(),
          _row('Weft Yarn Rate', input.weftYarnRate.toStringAsFixed(2)),
          _divider(),
          _row('Sizing Cost Per Kg', input.sizingCostPerKg.toStringAsFixed(2)),
          _divider(),
          _row('Commission %', '${input.commissionPct}%'),
          _divider(),
          _row('Off Grade %', '${input.offGradePct}%'),
          _divider(),
          _row('Loom RPM', input.loomRpm.toStringAsFixed(0)),
          _divider(),
          _row('Loom Efficiency %', '${input.loomEfficiencyPct}%'),
          _divider(),
          _row('No. of Looms', input.numberOfLooms.toStringAsFixed(0)),
          _divider(),
          _row('Total Order', input.totalOrder.toStringAsFixed(0)),
          _divider(),
          _row('Packing Cost', input.packingCost.toStringAsFixed(2)),
          _divider(),
          _row('Freight Cost', input.freightCost.toStringAsFixed(2)),
          pw.SizedBox(height: 10),

          // Section 2: Fabric Cost
          _sectionHeader('B.  Fabric Cost'),
          _row('Yarn Warp Cost', output.yarnWarpCost.toStringAsFixed(2)),
          _divider(),
          _row('Yarn Weft Cost', output.yarnWeftCost.toStringAsFixed(2)),
          _divider(),
          _row('Total Yarn Cost', output.totalYarnCost.toStringAsFixed(2),
              highlight: true),
          _divider(),
          _row('Sizing Cost Per Mtr', output.sizingCostPerMtr.toStringAsFixed(4)),
          _divider(),
          _row('Weaving Cost', output.weavingCost.toStringAsFixed(4)),
          _divider(),
          _row('Off Grade Cost', output.offGradePct.toStringAsFixed(2)),
          _divider(),
          _row('Commission Cost', output.commissionCost.toStringAsFixed(4)),
          pw.SizedBox(height: 10),

          // Section 3: Yarn Weight
          _sectionHeader('C.  Yarn Weight'),
          _row('Warp Weight (S+W)',
              output.warpWeightShrinkageWastage.toStringAsFixed(4)),
          _divider(),
          _row('Weft Weight (S+W)',
              output.weftWeightShrinkageWastage.toStringAsFixed(4)),
          _divider(),
          _row('Warp Weight (Only Shrinkage)',
              output.warpWeightOnlyShrinkage.toStringAsFixed(5)),
          _divider(),
          _row('Weft Weight (Only Shrinkage)',
              output.weftWeightOnlyShrinkage.toStringAsFixed(5)),
          _divider(),
          _row('Warp KG/Mtr', output.warpKgPerMtr.toStringAsFixed(6)),
          pw.SizedBox(height: 10),

          // Section 4: Production
          _sectionHeader('D.  Production & Requirements'),
          _row('Per Day Per Loom Production',
              '${output.perDayPerLoomProduction.toStringAsFixed(2)} m/day'),
          _divider(),
          _row('Daily Production (All Looms)',
              '${output.dailyProductionAllLooms.toStringAsFixed(2)} m/day'),
          _divider(),
          _row('Days Required for Completion',
              output.daysRequiredForCompletion.toStringAsFixed(2)),
          _divider(),
          _row('Completion Date',
              '${output.completionDate.day}/${output.completionDate.month}/${output.completionDate.year}'),
          _divider(),
          _row('Warp Bags Required',
              output.warpBagsRequired.toStringAsFixed(0)),
          _divider(),
          _row('Weft Bags Required',
              output.weftBagsRequired.toStringAsFixed(0)),
          pw.SizedBox(height: 10),

          // Section 5: Cover Factor
          _sectionHeader('E.  Cover Factor, Reed Space & Tape Length'),
          _row('Cover Factor — Warp',
              output.coverFactorWarp.toStringAsFixed(2)),
          _divider(),
          _row('Cover Factor — Weft',
              output.coverFactorWeft.toStringAsFixed(2)),
          _divider(),
          _row('Total Cover Factor',
              output.totalCoverFactor.toStringAsFixed(2)),
          _divider(),
          _row('Reed Space (inches)',
              output.reedSpaceInches.toStringAsFixed(2)),
          _divider(),
          _row('Tape Length (m)', output.tapeLengthMtr.toStringAsFixed(2)),
          _divider(),
          _row('Wt Grams per Metre',
              output.wtGramsPerMetre.toStringAsFixed(4)),
          _divider(),
          _row('Container — 20ft (Mtrs)',
              output.container20ftMtrs.toStringAsFixed(0)),
          _divider(),
          _row('Container — 40ft (Mtrs)',
              output.container40ftMtrs.toStringAsFixed(0)),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final fileName = 'TrendTex_Costing_${entry.id}.pdf';
    final filePath = '${dir.path}/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save(), flush: true);

    return filePath;
  }
}