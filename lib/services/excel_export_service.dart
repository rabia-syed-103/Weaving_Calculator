/// excel_export_service.dart
/// -----------------------------------------------------------------------
/// Builds a .xlsx file from a HistoryEntry (InputModel + OutputModel)
/// that mirrors the layout of the original Costing_InFlow_PerPick.xlsm
/// "Costing" sheet — same 5 column groups (Fabric Specification,
/// Additional Yarn, Fabric Cost, Production, Cover Factor), same row
/// order, same labels. Unlike the original, every cell here is a plain
/// VALUE (not a live formula) — this is a snapshot/export, not a
/// re-editable spreadsheet, since the values already came from
/// CalculationEngine.
///
/// SETUP STEPS:
///
/// 1. Add to pubspec.yaml:
///      dependencies:
///        excel: ^4.0.6
///        path_provider: ^2.1.4
///    Then `flutter pub get`.
///
/// 2. Call ExcelExportService.export(entry) — returns the saved file's
///    path (written to the app's temp directory, ready to hand to
///    share_plus). See whatsapp_share_service.dart for the next step.
///
/// LAYOUT REFERENCE (mirrors the Excel file's cell coordinates exactly,
/// so anyone cross-checking against the original .xlsm can match rows
/// 1-to-1 by label):
///   A/B  — Fabric Specification (user inputs)
///   D/E  — Additional Yarn (user inputs)
///   G/H  — Fabric Cost (calculated)
///   J/K  — Production / Completion / Yarn Requirement (calculated)
///   M/N  — Cover Factor / Reed Space / Tape Length (calculated)
library;

import 'dart:io';
import 'package:excel/excel.dart' as xl;
import 'package:path_provider/path_provider.dart';
import '../models/history_entry_model.dart';

class ExcelExportService {
  /// Builds the workbook and writes it to a temp file. Returns the full
  /// file path, ready to pass to share_plus.
  static Future<String> export(HistoryEntry entry) async {
    final input = entry.input;
    final output = entry.output;

    final workbook = xl.Excel.createExcel();
    final sheetName = 'Costing';
    final sheet = workbook[sheetName];
    // The excel package creates a default 'Sheet1' alongside any sheet
    // you reference by name — remove it so the file only has our sheet.
    if (workbook.sheets.containsKey('Sheet1') && sheetName != 'Sheet1') {
      workbook.delete('Sheet1');
    }

    final headerStyle = xl.CellStyle(
      bold: true,
      backgroundColorHex: xl.ExcelColor.fromHexString('FF1F4E5C'),
      fontColorHex: xl.ExcelColor.fromHexString('FFFFFFFF'),
    );
    final sectionStyle = xl.CellStyle(
      bold: true,
      backgroundColorHex: xl.ExcelColor.fromHexString('FFDCE9EC'),
    );
    final labelStyle = xl.CellStyle(bold: false);
    final highlightStyle = xl.CellStyle(
      bold: true,
      backgroundColorHex: xl.ExcelColor.fromHexString('FFF4D35E'),
    );

    void setCell(String colLetter, int row, dynamic value, {xl.CellStyle? style}) {
      final cell = sheet.cell(xl.CellIndex.indexByString('$colLetter$row'));
      if (value is num) {
        cell.value = xl.DoubleCellValue(value.toDouble());
      } else {
        cell.value = xl.TextCellValue(value.toString());
      }
      if (style != null) cell.cellStyle = style;
    }

    // ---------------------------------------------------------------
    // Row 1 — section headers
    // ---------------------------------------------------------------
    setCell('A', 1, 'A.  Fabric Specification - User Inputs', style: sectionStyle);
    setCell('D', 1, 'A.1  Additional Yarn - User Inputs', style: sectionStyle);
    setCell('G', 1, 'B.  Fabric Cost - Yarn - Sizing - Weaving - Other', style: sectionStyle);
    setCell('J', 1, 'C.  Production - Completion - Yarn Requirement', style: sectionStyle);
    setCell('M', 1, 'D.  Cover Factor, Reed Space, Tape Length', style: sectionStyle);

    // Row 2 — column headers
    for (final pair in [['A', 'B'], ['D', 'E'], ['G', 'H'], ['J', 'K'], ['M', 'N']]) {
      setCell(pair[0], 2, 'Parameter', style: headerStyle);
      setCell(pair[1], 2, 'Value', style: headerStyle);
    }

    // ---------------------------------------------------------------
    // Column A/B — Fabric Specification (user inputs)
    // ---------------------------------------------------------------
    final fabricSpecRows = <List<dynamic>>[
      ['Warp Blend', input.warpBlend],
      ['Ply', input.ply],
      ['Warp Count (Ne)', input.warpCount],
      ['Weft Count (Ne)', input.weftCount],
      ['Ends Per Inch', input.endsPerInch],
      ['Picks Per Inch', input.picksPerInch],
      ['Width', input.width],
      ['Weave', input.weave],
      ['Selvedge', input.selvedge],
      ['Writing', input.writing],
      ['Warp Shrinkage', input.warpShrinkagePct],
      ['Weft Shrinkage', input.weftShrinkagePct],
      ['Warp Wastage', input.warpWastagePct],
      ['Weft Wastage', input.weftWastagePct],
      ['Warp Yarn Rate', input.warpYarnRate],
      ['Weft Yarn Rate', input.weftYarnRate],
      ['Sizing Cost Per Kg', input.sizingCostPerKg],
      ['Input Per Pick', input.inputPerPick],
      ['Input Inflow', input.inputInflow],
      ['Target Price', input.targetPrice],
      ['Commission %', input.commissionPct],
      ['Off Grade %', input.offGradePct],
      ['Off Grade Recovery', input.offGradeRecovery],
      ['Loom RPM', input.loomRpm],
      ['Loom Efficiency (%)', input.loomEfficiencyPct],
      ['Pick Insertion', input.pickInsertion],
      ['No. of Widths per Loom', input.widthsPerLoom],
      ['No. of Looms', input.numberOfLooms],
      ['Total Order', input.totalOrder],
      ['Packing Cost', input.packingCost],
      ['Freight Cost', input.freightCost],
    ];
    var r = 3;
    for (final row in fabricSpecRows) {
      setCell('A', r, row[0], style: labelStyle);
      setCell('B', r, row[1]);
      r++;
    }

    // ---------------------------------------------------------------
    // Column D/E — Additional Yarn (user inputs, optional)
    // ---------------------------------------------------------------
    final additionalYarnRows = <List<dynamic>>[
      ['Additional Warp Count (Ne)', input.additionalWarpCount],
      ['Additional Weft Count (Ne)', input.additionalWeftCount],
      ['Additional Ends Per Inch', input.additionalEndsPerInch],
      ['Additional Picks Per Inch', input.additionalPicksPerInch],
      ['Additional Warp Shrinkage', input.additionalWarpShrinkagePct],
      ['Additional Weft Shrinkage', input.additionalWeftShrinkagePct],
      ['Additional Warp Wastage', input.additionalWarpWastagePct],
      ['Additional Weft Wastage', input.additionalWeftWastagePct],
      ['Additional Warp Yarn Rate', input.additionalWarpYarnRate],
      ['Additional Weft Yarn Rate', input.additionalWeftYarnRate],
    ];
    r = 3;
    for (final row in additionalYarnRows) {
      setCell('D', r, row[0], style: labelStyle);
      setCell('E', r, row[1] ?? 0);
      r++;
    }

    // ---------------------------------------------------------------
    // Column G/H — Fabric Cost (calculated)
    // ---------------------------------------------------------------
    final fabricCostRows = <List<dynamic>>[
      ['Yarn Warp Cost', output.yarnWarpCost],
      ['Yarn Weft Cost', output.yarnWeftCost],
      ['Total Yarn Cost', output.totalYarnCost],
      ['Sizing Cost Per Mtr', output.sizingCostPerMtr],
      ['Weaving Cost', output.weavingCost],
      ['Off Grade %', output.offGradePct],
      ['Packing Cost', input.packingCost],
      ['Freight Cost', input.freightCost],
      ['Commission Cost', output.commissionCost],
    ];
    r = 3;
    for (final row in fabricCostRows) {
      setCell('G', r, row[0], style: labelStyle);
      setCell('H', r, row[1]);
      r++;
    }
    setCell('G', 19, 'GREY FABRIC RATE', style: highlightStyle);
    setCell('H', 19, output.greyFabricRate, style: highlightStyle);
    setCell('G', 20, 'LOOM IN FLOW', style: highlightStyle);
    setCell('H', 20, output.loomInFlow, style: highlightStyle);

    // ---------------------------------------------------------------
    // Column J/K — Production, Completion, Yarn Requirement (calculated)
    // ---------------------------------------------------------------
    final productionRows = <List<dynamic>>[
      ['Per Day Per Loom Production', output.perDayPerLoomProduction],
      ['Daily Production', output.dailyProductionAllLooms],
      ['Days Required for Completion', output.daysRequiredForCompletion],
      ['Completion Date', _formatDate(output.completionDate)],
      ['Warp Bags Required', output.warpBagsRequired],
      ['2nd Warp Bags Required', output.secondWarpBagsRequired],
      ['Weft Bags Required', output.weftBagsRequired],
      ['2nd Weft Bags Required', output.secondWeftBagsRequired],
    ];
    r = 3;
    for (final row in productionRows) {
      setCell('J', r, row[0], style: labelStyle);
      if (row[1] is String) {
        setCell('K', r, row[1]);
      } else {
        setCell('K', r, row[1]);
      }
      r++;
    }

    // ---------------------------------------------------------------
    // Column M/N — Cover Factor, Reed Space, Tape Length (calculated)
    // ---------------------------------------------------------------
    final coverFactorRows = <List<dynamic>>[
      ['Cover Factor – Warp', output.coverFactorWarp],
      ['Cover Factor – 2nd Warp', output.coverFactorSecondWarp],
      ['Cover Factor – Weft', output.coverFactorWeft],
      ['Cover Factor – 2nd Weft', output.coverFactorSecondWeft],
      ['Total Cover Factor', output.totalCoverFactor],
      ['Reed Space (inches)', output.reedSpaceInches],
      ['Tape Length (m)', output.tapeLengthMtr],
      ['Wt Grams per Metre', output.wtGramsPerMetre],
      ['Container – 20ft (Mtrs)', output.container20ftMtrs],
      ['Container – 40ft (Mtrs)', output.container40ftMtrs],
    ];
    r = 3;
    for (final row in coverFactorRows) {
      setCell('M', r, row[0], style: labelStyle);
      setCell('N', r, row[1]);
      r++;
    }

    // ---------------------------------------------------------------
    // Total Picks + Yarn Weight breakdown (rows 31-42 in the original)
    // ---------------------------------------------------------------
    setCell('A', 31, 'Total Picks', style: labelStyle);
    setCell('B', 31, output.totalPicks);

    setCell('A', 32, 'Yarn Weight (Shrinkage + Wastage)', style: sectionStyle);
    final shrinkWasteRows = <List<dynamic>>[
      ['Warp Weight', output.warpWeightShrinkageWastage],
      ['Weft Weight', output.weftWeightShrinkageWastage],
      ['Additional Warp Weight', output.additionalWarpWeightShrinkageWastage],
      ['Additional Weft Weight', output.additionalWeftWeightShrinkageWastage],
    ];
    r = 33;
    for (final row in shrinkWasteRows) {
      setCell('A', r, row[0], style: labelStyle);
      setCell('B', r, row[1]);
      r++;
    }

    setCell('A', 37, 'Yarn Weight (Only Shrinkage)', style: sectionStyle);
    final onlyShrinkRows = <List<dynamic>>[
      ['Warp Weight', output.warpWeightOnlyShrinkage],
      ['Weft Weight', output.weftWeightOnlyShrinkage],
      ['Additional Warp Weight', output.additionalWarpWeightOnlyShrinkage],
      ['Additional Weft Weight', output.additionalWeftWeightOnlyShrinkage],
    ];
    r = 38;
    for (final row in onlyShrinkRows) {
      setCell('A', r, row[0], style: labelStyle);
      setCell('B', r, row[1]);
      r++;
    }

    setCell('A', 42, 'Warp KG/Mtr', style: labelStyle);
    setCell('B', 42, output.warpKgPerMtr);

    // ---------------------------------------------------------------
    // Footer — when this snapshot was generated
    // ---------------------------------------------------------------
    setCell('A', 44, 'Generated by SadeedTex app on ${_formatDate(entry.savedAt)}');

    // ---------------------------------------------------------------
    // Column widths — wide enough for the longest labels in each group
    // ---------------------------------------------------------------
    sheet.setColumnWidth(0, 28); // A
    sheet.setColumnWidth(1, 14); // B
    sheet.setColumnWidth(3, 26); // D
    sheet.setColumnWidth(4, 14); // E
    sheet.setColumnWidth(6, 18); // G
    sheet.setColumnWidth(7, 14); // H
    sheet.setColumnWidth(9, 26); // J
    sheet.setColumnWidth(10, 16); // K
    sheet.setColumnWidth(12, 24); // M
    sheet.setColumnWidth(13, 14); // N

    // ---------------------------------------------------------------
    // Write to a temp file
    // ---------------------------------------------------------------
    final bytes = workbook.encode();
    if (bytes == null) {
      throw Exception('Failed to encode Excel file');
    }

    final dir = await getTemporaryDirectory();
    final fileName = 'SadeedTex_Costing_${entry.id}.xlsx';
    final filePath = '${dir.path}/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);

    return filePath;
  }

  static String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}