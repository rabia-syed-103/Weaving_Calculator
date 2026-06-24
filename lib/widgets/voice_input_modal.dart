/// voice_input_modal.dart
/// -----------------------------------------------------------------------
/// Step 19 — Voice input modal. Opens as a bottom sheet when the user
/// taps the FAB mic button on InputScreen. Walks through every field in
/// sequence (numeric fields first, text fields at the end), shows a live
/// transcript, and lets the user confirm, skip, or re-speak each value.
///
/// PACKAGE SETUP (pubspec.yaml):
///   dependencies:
///     speech_to_text: ^7.0.0
///   Then `flutter pub get`.
///
/// ANDROID — add to android/app/src/main/AndroidManifest.xml
/// (inside the <manifest> tag, NOT inside <application>):
///   <uses-permission android:name="android.permission.RECORD_AUDIO"/>
///
/// iOS — add to ios/Runner/Info.plist:
///   <key>NSMicrophoneUsageDescription</key>
///   <string>Used to fill in the costing form by voice</string>
///   <key>NSSpeechRecognitionUsageDescription</key>
///   <string>Used to fill in the costing form by voice</string>
///
/// FIELD ORDER:
/// Numeric fields first (in the same visual order as the screen), then
/// text fields. Warp Blend is a dropdown so it is intentionally SKIPPED
/// — the user must set it manually via the dropdown before or after
/// voice input. A hint in the UI tells them this.
///
/// HOLD-TO-TALK (changed from auto-listen):
/// Previously the mic auto-started listening the moment a new field
/// appeared, and ran for up to 15 seconds or until a 3-second pause.
/// That gave the user little control over exactly when the mic was
/// live, and made it hard to tell when it had stopped. Per direct
/// instruction, this now works like WhatsApp's voice-note button:
/// press and HOLD the mic to talk, release to stop. No auto-listen, no
/// timeout — listening is only ever active while the button is held
/// down. See _MicButton / _onMicDown / _onMicUp below.
///
/// SPOKEN NUMBER-WORD PARSING:
/// The on-device speech engine sometimes transcribes numbers as words
/// rather than digits (e.g. "twenty five hundred" instead of "2500"),
/// and digit-by-digit cleanup alone turns that into garbage — stripping
/// non-numeric characters from "twenty five hundred" doesn't recover
/// 2500. _parseSpokenNumber() below walks the transcript word-by-word
/// (English or Urdu, matching whichever language is active) and
/// accumulates a value using standard long-form number rules — same
/// approach as how "two thousand three hundred and fifty" or its Urdu
/// equivalent ("دو ہزار تین سو پچاس") gets read aloud. If the
/// transcript is already digits (e.g. the engine output "2500"
/// directly), parsing short-circuits to a plain double.tryParse so
/// nothing is lost or changed for the common case.
///
/// HOW IT WORKS:
/// 1. User taps the FAB → showModalBottomSheet() opens this widget.
/// 2. The modal shows the field name and waits — nothing is recorded
///    until the user presses and holds the mic button.
/// 3. While held, live transcript updates in real time.
/// 4. On release, the transcript is finalized. User taps CONFIRM to
///    write it into the matching controller and move to the next
///    field, or holds the mic again to re-record before confirming.
/// 5. SKIP moves to the next field without changing the current value.
/// 6. After the last field, the modal shows a "Done" button that
///    closes it.
library;

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

/// One field in the voice-fill sequence.
class _VoiceField {
  final String key;
  final String labelEn;
  final String labelUr;
  final bool isText; // false = numeric, true = text

  const _VoiceField(this.key, this.labelEn, this.labelUr, {this.isText = false});
}

/// All fields in order. Warp Blend (dropdown) and Sizing Cost / Kg
/// (auto-lookup, editable separately) are intentionally excluded.
const List<_VoiceField> _kVoiceFields = [
  // Inflow & Target
  _VoiceField('inputInflow', 'Input Inflow', 'انپٹ ان فلو'),
  _VoiceField('targetPrice', 'Target Price', 'ٹارگٹ پرائس'),
  // Fabric Specification — numeric
  _VoiceField('ply', 'Ply', 'پلائی'),
  _VoiceField('warpCount', 'Warp Count', 'وارپ کاؤنٹ'),
  _VoiceField('weftCount', 'Weft Count', 'ویفٹ کاؤنٹ'),
  _VoiceField('endsPerInch', 'Ends Per Inch', 'اینڈز پر انچ'),
  _VoiceField('picksPerInch', 'Picks Per Inch', 'پکس پر انچ'),
  _VoiceField('width', 'Width', 'چوڑائی'),
  // Shrinkage & Wastage
  _VoiceField('warpShrinkagePct', 'Warp Shrinkage Percent', 'وارپ شرنکیج فیصد'),
  _VoiceField('weftShrinkagePct', 'Weft Shrinkage Percent', 'ویفٹ شرنکیج فیصد'),
  _VoiceField('warpWastagePct', 'Warp Wastage Percent', 'وارپ ضیاع فیصد'),
  _VoiceField('weftWastagePct', 'Weft Wastage Percent', 'ویفٹ ضیاع فیصد'),
  // Rates & Costing
  _VoiceField('warpYarnRate', 'Warp Yarn Rate', 'وارپ یارن ریٹ'),
  _VoiceField('weftYarnRate', 'Weft Yarn Rate', 'ویفٹ یارن ریٹ'),
  _VoiceField('commissionPct', 'Commission Percent', 'کمیشن فیصد'),
  _VoiceField('inputPerPick', 'Input Per Pick', 'انپٹ پر پک'),
  _VoiceField('packingCost', 'Packing Cost', 'پیکنگ لاگت'),
  _VoiceField('freightCost', 'Freight Cost', 'فریٹ لاگت'),
  // Off Grade
  _VoiceField('offGradePct', 'Off Grade Percent', 'آف گریڈ فیصد'),
  _VoiceField('offGradeRecovery', 'Off Grade Recovery', 'آف گریڈ ریکوری'),
  // Loom & Production
  _VoiceField('loomRpm', 'Loom RPM', 'لوم آر پی ایم'),
  _VoiceField('loomEfficiencyPct', 'Loom Efficiency Percent', 'لوم افیشنسی فیصد'),
  _VoiceField('pickInsertion', 'Pick Insertion', 'پک انسرشن'),
  _VoiceField('widthsPerLoom', 'Widths Per Loom', 'چوڑائی فی لوم'),
  _VoiceField('numberOfLooms', 'Number Of Looms', 'لومز کی تعداد'),
  _VoiceField('totalOrder', 'Total Order', 'کل آرڈر'),
  // Text fields last
  _VoiceField('weave', 'Weave', 'ویو', isText: true),
  _VoiceField('selvedge', 'Selvedge', 'سیلویج', isText: true),
  _VoiceField('writing', 'Writing', 'تحریر', isText: true),
];

enum VoiceLang { english, urdu }

extension on VoiceLang {
  String get localeId => this == VoiceLang.english ? 'en_US' : 'ur_PK';
}

// =========================================================================
// SPOKEN NUMBER-WORD PARSING
// =========================================================================
//
// Implements standard long-form number reading rules for English and
// Urdu, so a transcript like "twenty five hundred" or "تین سو پچاس"
// resolves to the number a person actually meant (2500 / 350) instead
// of getting mangled by naive digit-stripping.
//
// ALGORITHM (same idea behind how both languages are spoken aloud):
// Walk the words left to right, keeping a running `current` (the
// number being built for the current "group") and a running `total`
// (groups already closed out by a big multiplier like hundred/thousand).
//   - A units/teens/tens word ADDS into `current`
//     ("twenty" -> current=20, then "five" -> current=25)
//   - "hundred" MULTIPLIES current by 100 and keeps accumulating
//     ("twenty five" -> current=25, then "hundred" -> current=2500)
//   - "thousand"/"hundred thousand" etc. closes out current into total
//     at that scale, then resets current to 0 for whatever comes next
//   - A decimal word ("point"/"دشمہ") switches into a digit-by-digit
//     fractional reading: "sixty point five" -> 60 then ".5"
// This mirrors exactly how "twenty five hundred" is meant (2500), and
// "two thousand three hundred" is meant (2300), without hardcoding
// every possible phrase.
class _SpokenNumberParser {
  static const Map<String, int> _enUnits = {
    'zero': 0, 'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5,
    'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10,
    'eleven': 11, 'twelve': 12, 'thirteen': 13, 'fourteen': 14,
    'fifteen': 15, 'sixteen': 16, 'seventeen': 17, 'eighteen': 18,
    'nineteen': 19,
  };
  static const Map<String, int> _enTens = {
    'twenty': 20, 'thirty': 30, 'forty': 40, 'fifty': 50,
    'sixty': 60, 'seventy': 70, 'eighty': 80, 'ninety': 90,
  };
  static const Map<String, int> _enScales = {
    'hundred': 100, 'thousand': 1000, 'lakh': 100000, 'million': 1000000,
    'crore': 10000000,
  };

  // Urdu number words. Coverage focuses on the common spoken forms for
  // costing-sheet-sized numbers (units, tens, hundred/thousand/lakh)
  // rather than exhaustively listing every irregular teen (Urdu's
  // 11-99 range is mostly irregular compound words, e.g. اکیس=21,
  // بائیس=22 — these are listed individually below rather than
  // algorithmically derived, since Urdu doesn't compose them the way
  // English builds "twenty" + "one").
  static const Map<String, int> _urUnits = {
    'صفر': 0, 'ایک': 1, 'دو': 2, 'تین': 3, 'چار': 4, 'پانچ': 5,
    'چھ': 6, 'سات': 7, 'آٹھ': 8, 'نو': 9, 'دس': 10,
    'گیارہ': 11, 'بارہ': 12, 'تیرہ': 13, 'چودہ': 14, 'پندرہ': 15,
    'سولہ': 16, 'سترہ': 17, 'اٹھارہ': 18, 'انیس': 19, 'بیس': 20,
    'اکیس': 21, 'بائیس': 22, 'تئیس': 23, 'چوبیس': 24, 'پچیس': 25,
    'چھببیس': 26, 'ستائیس': 27, 'اٹھائیس': 28, 'انتیس': 29, 'تیس': 30,
    'اکتیس': 31, 'بتیس': 32, 'تینتیس': 33, 'چونتیس': 34, 'پینتیس': 35,
    'چھتیس': 36, 'سینتیس': 37, 'اڑتیس': 38, 'انتالیس': 39, 'چالیس': 40,
    'اکتالیس': 41, 'بیالیس': 42, 'تینتالیس': 43, 'چوالیس': 44, 'پینتالیس': 45,
    'چھیالیس': 46, 'سینتالیس': 47, 'اڑتالیس': 48, 'انچاس': 49, 'پچاس': 50,
    'اکیاون': 51, 'باون': 52, 'تریپن': 53, 'چون': 54, 'پچپن': 55,
    'چھپن': 56, 'سترپن': 57, 'اٹھاون': 58, 'انسٹھ': 59, 'ساٹھ': 60,
    'اکسٹھ': 61, 'باسٹھ': 62, 'تریسٹھ': 63, 'چونسٹھ': 64, 'پینسٹھ': 65,
    'چھیاسٹھ': 66, 'سڑسٹھ': 67, 'اڑسٹھ': 68, 'انہتر': 69, 'ستر': 70,
    'اکہتر': 71, 'بہتر': 72, 'تہتر': 73, 'چوہتر': 74, 'پچہتر': 75,
    'چھہتر': 76, 'ستتر': 77, 'اٹھہتر': 78, 'اناسی': 79, 'اسی': 80,
    'اکیاسی': 81, 'بیاسی': 82, 'تراسی': 83, 'چوراسی': 84, 'پچاسی': 85,
    'چھیاسی': 86, 'ستاسی': 87, 'اٹھاسی': 88, 'نواسی': 89, 'نوے': 90,
    'اکانوے': 91, 'بانوے': 92, 'ترانوے': 93, 'چورانوے': 94, 'پچانوے': 95,
    'چھیانوے': 96, 'ستانوے': 97, 'اٹھانوے': 98, 'ننانوے': 99,
  };
  static const Map<String, int> _urScales = {
    'سو': 100, 'ہزار': 1000, 'لاکھ': 100000, 'کروڑ': 10000000,
  };

  /// Parses a spoken-number transcript into a double, or null if it
  /// can't be confidently parsed. Tries plain digit parsing first (the
  /// common case — most engines transcribe numbers as digits already),
  /// then falls back to English word-parsing, then Urdu word-parsing.
  static double? parse(String raw, VoiceLang lang) {
    final cleaned = _cleanDigitsOnly(raw);
    final direct = double.tryParse(cleaned);
    if (direct != null) return direct;

    return lang == VoiceLang.urdu ? _parseUrdu(raw) : _parseEnglish(raw);
  }

  /// Strips common spoken punctuation/units around an ALREADY-numeric
  /// transcript (e.g. "60.5 percent" -> "60.5"). Does not attempt to
  /// convert words — that's handled separately by _parseEnglish /
  /// _parseUrdu when this returns something unparsable.
  static String _cleanDigitsOnly(String raw) {
    var s = raw
        .toLowerCase()
        .replaceAll('point', '.')
        .replaceAll('دشمہ', '.')
        .replaceAll('dot', '.')
        .replaceAll(',', '')
        .trim();
    s = s.replaceAll(RegExp(r'[^\d.\-]'), '');
    final parts = s.split('.');
    if (parts.length > 2) {
      s = '${parts[0]}.${parts.sublist(1).join('')}';
    }
    return s;
  }

  static double? _parseEnglish(String raw) {
    final words = raw
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z\s.]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return null;

    // Split off a decimal part if "point"/"." appears.
    final pointIndex = words.indexWhere((w) => w == 'point' || w == '.');
    List<String> wholeWords = words;
    List<String> fractionWords = [];
    if (pointIndex != -1) {
      wholeWords = words.sublist(0, pointIndex);
      fractionWords = words.sublist(pointIndex + 1);
    }

    final whole = _accumulateEnglish(wholeWords);
    if (whole == null) return null;

    if (fractionWords.isEmpty) return whole.toDouble();

    // Fractional part is read digit-by-digit ("point five" -> ".5",
    // "point one two" -> ".12") rather than as its own grouped number.
    final digits = StringBuffer();
    for (final w in fractionWords) {
      final d = _enUnits[w];
      if (d == null || d > 9) return whole.toDouble(); // bail gracefully
      digits.write(d);
    }
    if (digits.isEmpty) return whole.toDouble();
    return double.tryParse('$whole.$digits') ?? whole.toDouble();
  }

  static int? _accumulateEnglish(List<String> words) {
    if (words.isEmpty) return null;
    int total = 0;
    int current = 0;
    bool sawAnything = false;

    for (final w in words) {
      if (w == 'and') continue; // "two hundred and fifty" — skip filler
      if (_enUnits.containsKey(w)) {
        current += _enUnits[w]!;
        sawAnything = true;
      } else if (_enTens.containsKey(w)) {
        current += _enTens[w]!;
        sawAnything = true;
      } else if (w == 'hundred') {
        current = (current == 0 ? 1 : current) * 100;
        sawAnything = true;
      } else if (_enScales.containsKey(w)) {
        final scale = _enScales[w]!;
        current = (current == 0 ? 1 : current) * scale;
        total += current;
        current = 0;
        sawAnything = true;
      } else {
        // Unknown word in the middle of a number phrase — treat as a
        // hard stop rather than guessing.
        return sawAnything ? total + current : null;
      }
    }
    return sawAnything ? total + current : null;
  }

  static double? _parseUrdu(String raw) {
    // Urdu script — split on whitespace, keep only word characters.
    final words = raw
        .split(RegExp(r'\s+'))
        .map((w) => w.trim())
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return null;

    final pointIndex = words.indexWhere((w) => w == 'دشمہ' || w == 'اعشاریہ');
    List<String> wholeWords = words;
    List<String> fractionWords = [];
    if (pointIndex != -1) {
      wholeWords = words.sublist(0, pointIndex);
      fractionWords = words.sublist(pointIndex + 1);
    }

    final whole = _accumulateUrdu(wholeWords);
    if (whole == null) return null;

    if (fractionWords.isEmpty) return whole.toDouble();

    final digits = StringBuffer();
    for (final w in fractionWords) {
      final d = _urUnits[w];
      if (d == null || d > 9) return whole.toDouble();
      digits.write(d);
    }
    if (digits.isEmpty) return whole.toDouble();
    return double.tryParse('$whole.$digits') ?? whole.toDouble();
  }

  static int? _accumulateUrdu(List<String> words) {
    if (words.isEmpty) return null;
    int total = 0;
    int current = 0;
    bool sawAnything = false;

    for (final w in words) {
      if (w == 'اور') continue; // "اور" = "and" — filler
      if (_urUnits.containsKey(w)) {
        current += _urUnits[w]!;
        sawAnything = true;
      } else if (_urScales.containsKey(w)) {
        final scale = _urScales[w]!;
        current = (current == 0 ? 1 : current) * scale;
        total += current;
        current = 0;
        sawAnything = true;
      } else {
        return sawAnything ? total + current : null;
      }
    }
    return sawAnything ? total + current : null;
  }
}

class VoiceInputModal extends StatefulWidget {
  /// The controllers map from InputScreen — same keys as _controllers.
  final Map<String, TextEditingController> controllers;

  const VoiceInputModal({super.key, required this.controllers});

  @override
  State<VoiceInputModal> createState() => _VoiceInputModalState();
}

class _VoiceInputModalState extends State<VoiceInputModal> {
  final SpeechToText _speech = SpeechToText();

  bool _speechAvailable = false;
  String? _initError;

  // Driven by speech_to_text's onStatus callback, which reports the
  // engine's ACTUAL state ("listening" / "notListening" / "done") —
  // this is the only reliable source of truth for whether the mic is
  // live right now (the listen() Future itself only confirms the
  // request was accepted, not that listening is ongoing).
  bool _isListening = false;

  String _transcript = '';

  int _fieldIndex = 0; // current position in _kVoiceFields
  bool _done = false;

  VoiceLang _lang = VoiceLang.english;
  bool _urduAvailable = false;
  bool _checkingLocales = true;

  _VoiceField get _currentField => _kVoiceFields[_fieldIndex];

  bool get _isUrdu => _lang == VoiceLang.urdu;

  String get _fieldLabel =>
      _isUrdu ? _currentField.labelUr : _currentField.labelEn;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onStatus: _handleStatus,
        onError: (error) {
          if (mounted) {
            setState(() {
              _isListening = false;
              _initError = error.errorMsg;
            });
          }
        },
      );

      if (mounted) setState(() => _speechAvailable = available);

      if (available) {
        await _checkUrduAvailable();
      } else if (mounted) {
        setState(() => _checkingLocales = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _initError = e.toString();
          _checkingLocales = false;
        });
      }
    }
  }

  void _handleStatus(String status) {
    if (!mounted) return;
    setState(() {
      _isListening = status == 'listening';
    });
  }

  /// Looks through the device's installed speech recognition locales
  /// for an Urdu one. Falls back to English-only if none is found,
  /// rather than letting the user pick Urdu and then silently getting
  /// English recognition (or an error) on every listen() call. As
  /// discussed, this stays device-dependent for now — no cloud
  /// fallback — so on devices without an Urdu speech pack installed,
  /// the Urdu option is disabled with an explanatory note rather than
  /// pretending to support it.
  Future<void> _checkUrduAvailable() async {
    try {
      final locales = await _speech.locales();
      final hasUrdu = locales.any((l) => l.localeId.toLowerCase().startsWith('ur'));
      if (mounted) {
        setState(() {
          _urduAvailable = hasUrdu;
          _checkingLocales = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _urduAvailable = false;
          _checkingLocales = false;
        });
      }
    }
  }

  void _setLang(VoiceLang lang) {
    if (_lang == lang) return;
    setState(() {
      _lang = lang;
      _transcript = '';
    });
  }

  /// HOLD-TO-TALK — press down.
  /// Starts a fresh listening session for the current field. Any
  /// previous transcript for this field is cleared, since holding the
  /// mic again means "let me re-record this".
  Future<void> _onMicDown() async {
    if (!_speechAvailable || _done || _isListening) return;

    setState(() => _transcript = '');

    // NOTE: don't set _isListening here — onStatus('listening') fires
    // on its own once the engine actually starts, and is the single
    // source of truth for this flag (see field doc comment above).
    await _speech.listen(
      onResult: _handleResult,
      localeId: _lang.localeId,
      // No listenFor/pauseFor timeout — listening is bounded entirely
      // by how long the user holds the button (_onMicUp calls stop()),
      // matching the press-and-hold voice-note pattern directly.
      listenFor: const Duration(minutes: 2), // generous ceiling, not a real timeout
      pauseFor: const Duration(minutes: 2),  // disable Android's pause-based auto-stop
      cancelOnError: false,
      partialResults: true,
    );
  }

  /// HOLD-TO-TALK — release.
  /// Stops listening; whatever transcript has accumulated stays on
  /// screen for the user to Confirm or hold-to-retry.
  Future<void> _onMicUp() async {
    if (!_isListening) return;
    await _speech.stop();
  }

  void _handleResult(SpeechRecognitionResult result) {
    if (!mounted) return;
    setState(() => _transcript = result.recognizedWords);
  }

  /// Confirms the current transcript as the value for the current field,
  /// writes it into the controller, then advances to the next field.
  void _confirm() {
    final raw = _transcript.trim();
    if (raw.isEmpty) return; // nothing to confirm

    final field = _currentField;
    if (!field.isText) {
      final value = _SpokenNumberParser.parse(raw, _lang);
      if (value != null) {
        widget.controllers[field.key]?.text = _formatForField(value);
      }
      // If parse fails, don't write anything — let the user re-record.
    } else {
      // Text field — write the raw transcript as-is.
      widget.controllers[field.key]?.text = raw;
    }

    _advance();
  }

  /// Skips the current field (leaves its controller unchanged).
  void _skip() => _advance();

  void _advance() {
    _speech.stop();
    if (_fieldIndex >= _kVoiceFields.length - 1) {
      setState(() {
        _done = true;
      });
    } else {
      setState(() {
        _fieldIndex++;
        _transcript = '';
      });
    }
  }

  String _formatForField(double value) {
    // Show integers without a decimal point, decimals up to 6 places.
    if (value == value.roundToDouble()) return value.toInt().toString();
    var s = value.toStringAsFixed(6);
    s = s.replaceFirst(RegExp(r'0+$'), '');
    s = s.replaceFirst(RegExp(r'\.$'), '');
    return s;
  }

  // ---------------------------------------------------------------------
  // Small bilingual label helper for this modal's own static UI text —
  // NOT for field names (those come from _VoiceField.labelEn/labelUr).
  // ---------------------------------------------------------------------
  String _t(String en, String ur) => _isUrdu ? ur : en;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            if (!_checkingLocales)
              _LanguageToggle(
                current: _lang,
                urduAvailable: _urduAvailable,
                enabled: _initError == null && !_done,
                onChanged: _setLang,
              ),
            const SizedBox(height: 16),

            if (_initError != null) ...[
              Icon(Icons.mic_off, size: 40, color: colorScheme.error),
              const SizedBox(height: 12),
              Text(
                _t('Microphone not available', 'مائیکروفون دستیاب نہیں'),
                style: TextStyle(fontWeight: FontWeight.w600,
                    color: colorScheme.error),
              ),
              const SizedBox(height: 6),
              Text(
                _initError!,
                style: TextStyle(fontSize: 12,
                    color: colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(_t('Close', 'بند کریں')),
              ),
            ] else if (_done) ...[
              Icon(Icons.check_circle_outline,
                  size: 48, color: colorScheme.primary),
              const SizedBox(height: 12),
              Text(_t('All fields done!', 'تمام فیلڈز مکمل!'),
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                _t(
                  'Warp Blend must be set manually from the dropdown.',
                  'وارپ بلینڈ ڈراپ ڈاؤن سے خود سیٹ کرنا ہوگا۔',
                ),
                style: TextStyle(fontSize: 12,
                    color: colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(_t('Done', 'مکمل')),
              ),
            ] else ...[
              // Progress
              Text(
                _t(
                  'Field ${_fieldIndex + 1} of ${_kVoiceFields.length}',
                  'فیلڈ ${_fieldIndex + 1} از ${_kVoiceFields.length}',
                ),
                style: TextStyle(
                    fontSize: 12, color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: (_fieldIndex + 1) / _kVoiceFields.length,
                borderRadius: BorderRadius.circular(2),
              ),
              const SizedBox(height: 20),

              // Current field name
              Text(
                _fieldLabel,
                textDirection: _isUrdu ? TextDirection.rtl : TextDirection.ltr,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                _currentField.isText
                    ? _t('Hold the mic and say the text value', 'مائیک دبا کر متن بولیں')
                    : _t('Hold the mic and say the number', 'مائیک دبا کر نمبر بولیں'),
                style: TextStyle(fontSize: 12,
                    color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),

              // Live transcript box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _isListening
                        ? colorScheme.primary
                        : colorScheme.outlineVariant,
                    width: _isListening ? 1.5 : 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _transcript.isEmpty
                            ? (_isListening
                            ? _t('Listening…', 'سن رہا ہے…')
                            : _t('Hold the mic button below', 'نیچے مائیک کا بٹن دبائیں'))
                            : _transcript,
                        textDirection:
                        _isUrdu ? TextDirection.rtl : TextDirection.ltr,
                        style: TextStyle(
                          fontSize: 16,
                          color: _transcript.isEmpty
                              ? colorScheme.onSurfaceVariant
                              : colorScheme.onSurface,
                          fontStyle: _transcript.isEmpty
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                      ),
                    ),
                    if (_isListening)
                      Icon(Icons.graphic_eq, color: colorScheme.primary),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Hold-to-talk mic button — large, centered, press-and-hold.
              Center(
                child: _MicButton(
                  isListening: _isListening,
                  onDown: _onMicDown,
                  onUp: _onMicUp,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isListening
                    ? _t('Release to stop', 'چھوڑنے پر رک جائے گا')
                    : _t('Press and hold to talk', 'بولنے کے لیے دبا کر رکھیں'),
                style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),

              // Action buttons — Skip / Confirm. Re-record is just
              // holding the mic again, so there's no separate button
              // for it anymore.
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _skip,
                      child: Text(_t('Skip', 'چھوڑیں')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: _transcript.trim().isEmpty ? null : _confirm,
                      child: Text(_t('Confirm', 'تصدیق')),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              Text(
                _t(
                  'Note: Warp Blend is set from the dropdown, not by voice.',
                  'نوٹ: وارپ بلینڈ ڈراپ ڈاؤن سے سیٹ ہوتا ہے، آواز سے نہیں۔',
                ),
                style: TextStyle(
                    fontSize: 11, color: colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Large press-and-hold mic button, WhatsApp-voice-note style.
/// GestureDetector's onTapDown/onTapUp/onTapCancel map directly onto
/// "press" / "release" / "release outside the button" — onTapCancel
/// matters because if the user's finger slides off the button while
/// held, that should still stop listening, the same way letting go of
/// a real voice-note button anywhere stops the recording.
class _MicButton extends StatelessWidget {
  final bool isListening;
  final VoidCallback onDown;
  final VoidCallback onUp;

  const _MicButton({
    required this.isListening,
    required this.onDown,
    required this.onUp,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTapDown: (_) => onDown(),
      onTapUp: (_) => onUp(),
      onTapCancel: onUp,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: isListening ? 84 : 72,
        height: isListening ? 84 : 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isListening ? colorScheme.error : colorScheme.primary,
          boxShadow: isListening
              ? [
            BoxShadow(
              color: colorScheme.error.withValues(alpha: 0.3),
              blurRadius: 16,
              spreadRadius: 4,
            ),
          ]
              : null,
        ),
        child: Icon(
          isListening ? Icons.graphic_eq : Icons.mic,
          color: isListening ? colorScheme.onError : colorScheme.onPrimary,
          size: 32,
        ),
      ),
    );
  }
}

/// English / Urdu segmented toggle shown at the top of the modal.
class _LanguageToggle extends StatelessWidget {
  final VoiceLang current;
  final bool urduAvailable;
  final bool enabled;
  final ValueChanged<VoiceLang> onChanged;

  const _LanguageToggle({
    required this.current,
    required this.urduAvailable,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LangChip(
              label: 'English',
              selected: current == VoiceLang.english,
              enabled: enabled,
              onTap: () => onChanged(VoiceLang.english),
            ),
            const SizedBox(width: 8),
            _LangChip(
              label: 'اردو',
              selected: current == VoiceLang.urdu,
              enabled: enabled && urduAvailable,
              onTap: () => onChanged(VoiceLang.urdu),
            ),
          ],
        ),
        if (!urduAvailable) ...[
          const SizedBox(height: 6),
          Text(
            'Urdu speech recognition isn\'t installed on this device.',
            style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class _LangChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _LangChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? colorScheme.primary : colorScheme.outlineVariant,
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: enabled
                ? (selected ? colorScheme.primary : colorScheme.onSurface)
                : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}