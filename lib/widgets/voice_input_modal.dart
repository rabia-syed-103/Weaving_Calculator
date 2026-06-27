/// voice_input_modal.dart
/// -----------------------------------------------------------------------
/// Step 19 — Voice input modal. Opens as a bottom sheet when the user
/// taps the FAB mic button on InputScreen. Walks through a reduced set
/// of fields in sequence, shows a live transcript AND a directly-
/// editable input for the current field, and lets the user confirm,
/// skip, or re-speak each value.
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
/// FIELD LIST — REDUCED SCOPE:
/// Voice input now only covers these 15 fields, in this order. Every
/// other field that used to be in the voice sequence (Shrinkage%,
/// Wastage%, Commission%, Packing/Freight cost, Off Grade%, Off Grade
/// Recovery, Loom RPM/Efficiency, Pick Insertion, Widths Per Loom,
/// Number Of Looms, Total Order) is NOT removed from the app — it still
/// exists and is still editable on the main input screen exactly as
/// before. It's just no longer reachable through this voice modal.
///   1. Input Inflow     (text)
///   2. Target Price     (number)
///   3. Warp Blend        (radio: Cotton/Ctn, Pv, Pc, Cvc, Pp, Viscose)
///   4. Ply               (radio: 1 / 2 / Other free-text)
///   5. Warp Count        (number)
///   6. Weft Count        (number)
///   7. Ends Per Inch     (number)
///   8. Picks Per Inch    (number)
///   9. Width             (number)
///  10. Weave             (text)
///  11. Selvedge          (text)
///  12. Writing           (text)
///  13. Warp Yarn Rate    (number)
///  14. Weft Yarn Rate    (number)
///  15. Input Per Pick    (number)
///
/// WARP BLEND — voice-driven radio, auto-selected on a confident match:
/// Warp Blend used to be skipped entirely because it was a dropdown.
/// It's now a first-class voice field. The label set is intentionally
/// identical in English and Urdu mode (Cotton/Ctn, Pv, Pc, Cvc, Pp,
/// Viscose) since these are industry abbreviations, not translatable
/// words. A small fuzzy matcher (_WarpBlendMatcher) maps the spoken
/// transcript to one of the six codes. On CONFIRM, if the transcript
/// matches one of them with reasonable confidence, that radio is
/// auto-selected immediately — no extra tap needed. If nothing matches,
/// no radio is pre-selected and the person just taps one manually; the
/// radios are always tappable regardless of voice, same as every other
/// field staying manually editable (see EVERY FIELD STAYS EDITABLE).
///
/// PLY — voice-driven radio with a free-text escape hatch:
/// Ply is overwhelmingly 1 or 2 in practice, so it's two big radio
/// options for fast entry, but other values are not discarded — a
/// third "Other" slot holds a small text field for anything else (e.g.
/// 3-ply). On CONFIRM: a parsed "1" or "2" selects that radio directly;
/// any other parsed number selects the Other radio and fills its text
/// field with that number, so it's visible and still editable.
///
/// EVERY FIELD STAYS EDITABLE:
/// Previously, confirming a field's voice transcript wrote a final
/// value into the controller and moved on — there was no way to see or
/// correct that value without leaving the voice flow. Now each field
/// card always shows a live, directly-editable input (a TextField for
/// text/numeric fields, or a radio group for Warp Blend/Ply) bound to
/// the SAME controller voice writes into. Speaking a value fills the
/// field; the person can also just tap into it and type/correct it by
/// hand at any point — before speaking, after speaking, or instead of
/// speaking — without that being a separate mode. Confirm/Skip just
/// move the sequence forward; they don't lock or finalize anything (the
/// value is already live in the controller the moment it's typed or
/// recognized, exactly like the rest of the input screen).
///
/// STEP 20 — SHARED YARN RATE UNIT TOGGLE (per lb / per 10 lb):
/// Warp Yarn Rate (step 13) and Weft Yarn Rate (step 14) write into the
/// SAME _controllers['warpYarnRate']/['weftYarnRate'] that InputScreen
/// itself reads, and InputScreen now resolves both of those through a
/// SINGLE shared per-lb/per-10lb unit toggle (see input_screen.dart's
/// STEP 20 doc comment) rather than two independent ones. Without this
/// modal being aware of that, speaking/typing a number here would write
/// it ambiguously — e.g. saying "12" for Warp Yarn Rate means something
/// 10x different depending on which unit the screen is currently set
/// to, and this modal had no way to show that or let the person flip it.
///
/// Fixed by threading the EXACT SAME yarnRateUnit value through to this
/// modal, the same way Warp Blend is threaded through (see
/// warpBlendValue/onWarpBlendChanged below): yarnRateUnit is the
/// CURRENT shared unit, onYarnRateUnitChanged is called the instant the
/// person flips the chip toggle inside this modal. There's only ever
/// ONE value live for the whole screen+modal — flipping it in either
/// place updates both immediately, exactly mirroring InputScreen's own
/// _setYarnRateUnit() conversion logic, including converting whatever
/// numbers are CURRENTLY in both the warpYarnRate and weftYarnRate
/// controllers together (so the real-world rate the person meant
/// doesn't change just because the unit label did). The two sides don't
/// call each other's conversion method directly, though — this modal
/// does its own conversion, then InputScreen is just told the new unit
/// via a separate sync-only callback, so the actual /10-or-*10 math
/// never runs twice for one flip; see this State class's own
/// _setYarnRateUnit() doc comment for the exact mechanism. The toggle
/// itself is shown on BOTH the Warp Yarn Rate and Weft Yarn Rate steps
/// (steps 13 and 14) since they're two separate stops in the sequence —
/// whichever one the
/// person is currently on, they can see and flip the one shared unit.
///
/// NO MORE "DIDN'T CATCH THAT" RETRY HINT:
/// A previous version showed a small red "Didn't catch that — try
/// again" hint under the transcript box whenever a recoverable engine
/// error or an empty result happened. Removed per request — since the
/// field is always directly editable now anyway, an empty transcript
/// is self-evident from the field just being empty, and doesn't need a
/// separate scolding message. The underlying recoverable-error handling
/// itself is unchanged (still doesn't lock the modal), only the visible
/// hint text is gone.
///
/// HOLD-TO-TALK — uses Listener instead of GestureDetector:
/// GestureDetector's onTapDown/onTapUp/onTapCancel are TAP gesture
/// callbacks that go through Flutter's gesture arena — a layer that
/// waits briefly to disambiguate a tap from a drag/long-press before
/// firing. Wrong for "press and hold", especially when the widget tree
/// rebuilds mid-gesture (which happens here every time a field is
/// skipped/confirmed). Listener receives raw PointerDown/Up/Cancel
/// events directly — no arena, no disambiguation delay.
///
/// WARM-UP DELAY FOR SHORT WORDS:
/// On most Android/iOS devices the recognizer takes roughly 200-400ms
/// to actually start capturing audio after listen() is called, so very
/// short utterances spoken right at that boundary can get their leading
/// edge clipped. A 250ms delay runs between starting the listening
/// session and signalling "go ahead and speak" so the user doesn't
/// start talking into a half-started engine.
///
/// SINGLE-WORD RECOGNITION — release grace wait, tuned from live device
/// logs (this is the actual fix, not just the warm-up delay):
/// Reported symptom: a single isolated digit ("1", "2", "5"...) spoken
/// alone was never captured, while two-syllable utterances always
/// worked. Live debug logging on-device showed the real shape of the
/// problem: calling _speech.stop() while the engine is still scoring a
/// short utterance makes the engine abandon that recognition rather
/// than finish it, and the eventual callback comes back empty. So
/// _onPointerUp no longer calls stop() immediately on release. Instead
/// it waits (polling in short steps, up to ~700ms) for an actual FINAL
/// result to arrive on its own — only if none shows up in that window
/// does it fall back to calling stop() itself. A short additional
/// "settle" delay after stop() gives any trailing callbacks room to
/// land before the busy-guard is released, which is what prevented the
/// next listen() session from colliding with a previous one that
/// hadn't fully torn down yet (seen live as error_client).
///
/// ERROR HANDLING — recoverable vs fatal:
/// Every error speech_to_text reports comes through one onError
/// callback, but they are NOT all the same severity. error_speech_
/// timeout / error_no_match / error_busy / error_client are routine,
/// expected, recoverable conditions (confirmed via live debug logging,
/// not just docs) — they just reset listening state silently so the
/// user can immediately press and try again. Only genuinely fatal
/// errors (hardware/permission related) show the dead-end "Microphone
/// not available" screen.
///
/// ENGINE SINGLETON:
/// SpeechToText is created and initialize()'d exactly ONCE per app
/// session via the VoiceEngine singleton below, not once per modal
/// open. Re-creating/re-initializing per modal open was confirmed (live
/// debug logging) to cause "listening starts, shows for about a
/// second, then silently stops" on the second and later opens, because
/// the native recognizer session from the previous open hadn't fully
/// released before a brand new instance tried to initialize.
///
/// BUSY GUARD:
/// Any stop()/listen() call sets _busy true and is awaited fully before
/// clearing it, and the mic button (and Skip/Confirm) ignore taps while
/// _busy is true. This serializes every engine interaction instead of
/// letting overlapping calls race and desync speech_to_text's internal
/// state. The error path also unconditionally clears _busy/_warmingUp/
/// _isListening, since a mid-flight error is exactly the case most
/// likely to leave one of those flags stuck true otherwise.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'warp_blend_options.dart';
import 'yarn_rate_unit.dart';

// =========================================================================
// FIELD MODEL
// =========================================================================

enum _FieldKind { text, number, warpBlend, ply }

/// One field in the voice-fill sequence.
class _VoiceField {
  final String key;
  final String labelEn;
  final String labelUr;
  final _FieldKind kind;

  const _VoiceField(
      this.key, this.labelEn, this.labelUr, {this.kind = _FieldKind.number});
}

/// The reduced 15-field voice sequence. See the FIELD LIST — REDUCED
/// SCOPE doc comment above for why these specific 15 and this order.
const List<_VoiceField> _kVoiceFields = [
  _VoiceField('inputInflow', 'Input Inflow', 'انپٹ ان فلو', kind: _FieldKind.text),
  _VoiceField('targetPrice', 'Target Price', 'ٹارگٹ پرائس'),
  _VoiceField('warpBlend', 'Warp Blend', 'وارپ بلینڈ', kind: _FieldKind.warpBlend),
  _VoiceField('ply', 'Ply', 'پلائی', kind: _FieldKind.ply),
  _VoiceField('warpCount', 'Warp Count', 'وارپ کاؤنٹ'),
  _VoiceField('weftCount', 'Weft Count', 'ویفٹ کاؤنٹ'),
  _VoiceField('endsPerInch', 'Ends Per Inch', 'اینڈز پر انچ'),
  _VoiceField('picksPerInch', 'Picks Per Inch', 'پکس پر انچ'),
  _VoiceField('width', 'Width', 'چوڑائی'),
  _VoiceField('weave', 'Weave', 'ویو', kind: _FieldKind.text),
  _VoiceField('selvedge', 'Selvedge', 'سیلویج', kind: _FieldKind.text),
  _VoiceField('writing', 'Writing', 'تحریر', kind: _FieldKind.text),
  _VoiceField('warpYarnRate', 'Warp Yarn Rate', 'وارپ یارن ریٹ'),
  _VoiceField('weftYarnRate', 'Weft Yarn Rate', 'ویفٹ یارن ریٹ'),
  _VoiceField('inputPerPick', 'Input Per Pick', 'انپٹ پر پک'),
];

enum VoiceLang { english, urdu }

extension on VoiceLang {
  String get localeId => this == VoiceLang.english ? 'en_US' : 'ur_PK';
}

// =========================================================================
// WARP BLEND — fixed option set, identical labels in both languages
// =========================================================================
//
// IMPORTANT: this does NOT redeclare its own option list. The
// authoritative list is `kWarpBlendOptions` in warp_blend_options.dart
// (currently ['Ctn', 'Pc', 'Pv', 'Pp', 'Cvc', 'Viscose']), imported by
// BOTH this file and input_screen.dart. Reusing that single shared
// import instead of two separate local lists is required, not just
// tidier — two lists with different spellings (an earlier draft of
// this file used 'Cotton' instead of 'Ctn') is exactly what caused the
// modal to write a value the InputScreen dropdown's `items` list
// didn't recognize, which throws at runtime (DropdownButton requires
// `value` to either be null or exactly match one of its `items`).
class _WarpBlendMatcher {
  // Each option maps to a set of spoken forms (including common spoken/
  // spelled-out variants) that should resolve to that option being
  // auto-selected on confirm. Keys here MUST exactly match the strings
  // in warp_blend_options.dart's kWarpBlendOptions — see the class doc
  // comment above for why a mismatch breaks the dropdown.
  static const Map<String, List<String>> _aliases = {
    'Ctn': ['cotton', 'ctn', 'سی ٹی این', 'کاٹن'],
    'Pc': ['pc', 'پی سی'],
    'Pv': ['pv', 'پی وی'],
    'Pp': ['pp', 'پی پی'],
    'Cvc': ['cvc', 'سی وی سی'],
    'Viscose': ['viscose', 'وسکوز'],
  };

  /// Returns the matching option (one of kWarpBlendOptions' values), or
  /// null if the transcript doesn't confidently match any of them.
  static String? match(String raw) {
    final cleaned = raw.toLowerCase().trim();
    if (cleaned.isEmpty) return null;
    for (final entry in _aliases.entries) {
      for (final alias in entry.value) {
        if (cleaned == alias || cleaned.contains(alias)) {
          return entry.key;
        }
      }
    }
    return null;
  }
}

// =========================================================================
// ERROR CLASSIFICATION
// =========================================================================
//
// speech_to_text reports every engine-level problem through the same
// onError callback, tagged with a string errorMsg. Not all of them mean
// the same thing, and treating them identically caused the "one timeout
// bricks the whole modal" bug in an earlier version. This list is the
// set of codes that are routine/expected and should just silently reset
// listening state, not show a dead-end "Microphone Not available"
// screen.
//
// error_speech_timeout : Android's native SpeechRecognizer didn't
//                         detect audio within ITS OWN internal timeout
//                         window (independent of listenFor/pauseFor,
//                         which Android ignores). Means "didn't hear
//                         you in time", not "mic is broken".
// error_no_match        : Engine heard audio but couldn't match it to
//                         anything. Means "didn't understand that".
// error_busy             : Engine was still tearing down a previous
//                         session. Means "try again in a moment".
// error_client            : Confirmed via live debug logging (not just
//                         docs) to fire when a new listen() session
//                         starts while the PREVIOUS session is still
//                         asynchronously finishing its teardown. It's a
//                         collision between sessions, not a broken mic.
const Set<String> _kRecoverableErrors = {
  'error_speech_timeout',
  'error_no_match',
  'error_busy',
  'error_client',
};

// =========================================================================
// SPOKEN NUMBER-WORD PARSING
// =========================================================================
//
// Implements standard long-form number reading rules for English and
// Urdu, so a transcript like "twenty five hundred" or "تین سو پچاس"
// resolves to the number a person actually meant (2500 / 350) instead
// of getting mangled by naive digit-stripping.
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

    final digits = StringBuffer();
    for (final w in fractionWords) {
      final d = _enUnits[w];
      if (d == null || d > 9) return whole.toDouble();
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
      if (w == 'and') continue;
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
        return sawAnything ? total + current : null;
      }
    }
    return sawAnything ? total + current : null;
  }

  static double? _parseUrdu(String raw) {
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
      if (w == 'اور') continue;
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

// =========================================================================
// ENGINE SINGLETON
// =========================================================================
//
// SpeechToText + its one-time initialize() live here, for the lifetime
// of the app process — NOT recreated per modal open. See the class-
// level doc comment "ENGINE SINGLETON" above for why.
class VoiceEngine {
  VoiceEngine._();
  static final VoiceEngine instance = VoiceEngine._();

  final SpeechToText speech = SpeechToText();

  bool _initialized = false;
  bool _available = false;
  bool get available => _available;

  // The modal's current onStatus/onError handlers. Re-pointed every
  // time a modal attaches (see attach()) since speech_to_text only
  // lets you set these once via initialize(). Calls are forwarded here
  // instead, so each new modal instance still gets live status/error
  // callbacks despite initialize() only really running the first time.
  void Function(String status)? _onStatus;
  void Function(SpeechRecognitionError error)? _onError;

  /// Call from the modal's initState(). Initializes the underlying
  /// engine only on the very first call for the whole app session;
  /// every subsequent call (i.e. every time the modal is reopened)
  /// just returns the cached availability instantly.
  Future<bool> ensureInitialized() async {
    if (_initialized) return _available;
    _initialized = true;
    try {
      _available = await speech.initialize(
        onStatus: (status) => _onStatus?.call(status),
        onError: (error) => _onError?.call(error),
      );
    } catch (_) {
      _available = false;
    }
    return _available;
  }

  /// Points the engine's callbacks at whichever modal instance is
  /// currently on screen. Called from the modal's initState() right
  /// after ensureInitialized(), and cleared in dispose().
  void attach({
    required void Function(String status) onStatus,
    required void Function(SpeechRecognitionError error) onError,
  }) {
    _onStatus = onStatus;
    _onError = onError;
  }

  void detach() {
    _onStatus = null;
    _onError = null;
  }
}

// =========================================================================
// MODAL WIDGET
// =========================================================================

class VoiceInputModal extends StatefulWidget {
  /// The controllers map from InputScreen — same keys as _controllers.
  /// Covers every voice field EXCEPT warpBlend — see warpBlendValue/
  /// onWarpBlendChanged below for why that one's handled separately.
  final Map<String, TextEditingController> controllers;

  /// InputScreen's Warp Blend is a plain `String? _warpBlend` state
  /// field, NOT a TextEditingController (it backs a DropdownButton,
  /// which manages its own value rather than reading/writing a
  /// controller). Earlier versions of this modal assumed every field
  /// — including warpBlend — lived in the controllers map, which meant
  /// selecting a Warp Blend chip in the modal wrote into a throwaway
  /// controller that InputScreen never looked at: the chip highlighted
  /// correctly inside the modal, but the value never reached the real
  /// form (and the dropdown back on InputScreen stayed unset).
  ///
  /// Fixed by passing Warp Blend in and out through a plain value +
  /// callback instead, exactly mirroring how the DropdownButton itself
  /// talks to InputScreen's state:
  ///   warpBlendValue      — the CURRENT _warpBlend value (so the modal
  ///                         can show the correct chip as selected if
  ///                         it's reopened after already being set).
  ///   onWarpBlendChanged  — called the instant voice matches a blend
  ///                         or the user taps a chip; the same callback
  ///                         signature as DropdownButton.onChanged, so
  ///                         InputScreen can pass its existing
  ///                         onChanged handler straight through.
  final String? warpBlendValue;
  final ValueChanged<String?> onWarpBlendChanged;

  /// STEP 20 — same threading pattern as warpBlendValue/
  /// onWarpBlendChanged above, but for the shared Warp/Weft Yarn Rate
  /// unit toggle (per lb / per 10 lb). See this file's STEP 20 doc
  /// comment for the full story.
  ///   yarnRateUnit          — the CURRENT shared unit (InputScreen's
  ///                           _yarnRateUnit), so this modal's toggle
  ///                           always shows the same selection as the
  ///                           main screen's, never an independent copy.
  ///   onYarnRateUnitChanged — called AFTER this modal has already
  ///                           converted both warpYarnRate/weftYarnRate
  ///                           controllers itself (see this State
  ///                           class's own _setYarnRateUnit()). This is
  ///                           NOT InputScreen's _setYarnRateUnit passed
  ///                           straight through — that would convert the
  ///                           already-converted numbers a second time.
  ///                           InputScreen instead passes a separate
  ///                           sync-only callback
  ///                           (_syncYarnRateUnitFromModal) that just
  ///                           records the new unit and recalculates,
  ///                           so the actual /10-or-*10 math happens in
  ///                           exactly one place per toggle flip,
  ///                           regardless of whether the flip happened
  ///                           here or on the main screen.
  final YarnRateUnit yarnRateUnit;
  final ValueChanged<YarnRateUnit> onYarnRateUnitChanged;

  const VoiceInputModal({
    super.key,
    required this.controllers,
    required this.warpBlendValue,
    required this.onWarpBlendChanged,
    required this.yarnRateUnit,
    required this.onYarnRateUnitChanged,
  });

  @override
  State<VoiceInputModal> createState() => _VoiceInputModalState();
}

class _VoiceInputModalState extends State<VoiceInputModal> {
  // Shared, app-lifetime engine instance — see the VoiceEngine class
  // doc comment for why this replaced a per-modal SpeechToText().
  SpeechToText get _speech => VoiceEngine.instance.speech;

  bool _speechAvailable = false;

  // Fatal init/hardware/permission problem — shows the permanent
  // dead-end screen. Recoverable engine errors (see _kRecoverableErrors)
  // do NOT set this — they're silently absorbed instead (no visible
  // hint anymore, per request).
  String? _initError;

  // Driven by speech_to_text's onStatus callback — the only reliable
  // source of truth for whether the mic is live right now.
  bool _isListening = false;

  // True while the engine is "warming up" — the brief window between
  // listen() being called and the warm-up delay finishing, during
  // which the UI shows a distinct visual state so the user knows to
  // wait a beat before speaking. See _onPointerDown.
  bool _warmingUp = false;

  // BUSY GUARD — true for the entire duration of any stop()/listen()
  // call this widget makes. The mic button and Skip/Confirm ignore
  // input while this is true, which prevents overlapping engine calls
  // from racing each other. Also force-cleared whenever onError fires.
  bool _busy = false;

  // Live transcript for the CURRENT field. This is purely a display of
  // what voice most recently produced — the actual value lives in the
  // field's TextEditingController (see EVERY FIELD STAYS EDITABLE),
  // which the person can also edit directly regardless of this.
  String _transcript = '';

  // Set true the instant a FINAL (not partial) result arrives from the
  // engine during the current listen() session. _onPointerUp's grace
  // wait polls this — see the class-level "SINGLE-WORD RECOGNITION" doc
  // comment for why waiting specifically for a final result (rather
  // than calling stop() immediately, or waiting for any result) is what
  // actually fixes short isolated words being lost.
  bool _gotFinalResult = false;

  int _fieldIndex = 0; // current position in _kVoiceFields
  bool _done = false;

  VoiceLang _lang = VoiceLang.english;
  bool _urduAvailable = false;
  bool _checkingLocales = true;

  // STEP 20 — local mirror of the shared yarn-rate unit, seeded from
  // widget.yarnRateUnit. Mirrors the SAME pattern as _lang (a plain
  // enum field the build method reads directly), NOT the warpBlend
  // proxy-controller pattern below — there's no TextEditingController
  // involved here, just a small enum, so a plain field + setState is
  // enough. Every change still gets forwarded to
  // widget.onYarnRateUnitChanged so InputScreen's copy stays in sync —
  // see _setYarnRateUnit() below.
  late YarnRateUnit _yarnRateUnit = widget.yarnRateUnit;

  // Free-text controller backing the Ply field's "Other" slot. Kept
  // separate from widget.controllers['ply'] (which always holds the
  // single source of truth for Ply's value) so the text field has
  // something stable to bind to even while "1" or "2" is selected.
  final TextEditingController _plyOtherController = TextEditingController();

  // PROXY CONTROLLER for Warp Blend. InputScreen's Warp Blend is a
  // plain `String? _warpBlend` field + callback (it backs a
  // DropdownButton, not a TextEditingController) — see the
  // VoiceInputModal class doc comment "warpBlendValue/
  // onWarpBlendChanged" for the full explanation. Every other field in
  // this modal (_FieldEditor, _applyTranscriptToField, etc.) is written
  // generically against "the current field's controller", so rather
  // than special-casing warpBlend through all of that code, this proxy
  // controller stands in for it: seeded from widget.warpBlendValue,
  // and any change to it (from a chip tap or a voice match) is
  // forwarded straight to widget.onWarpBlendChanged via the listener
  // added in initState(). _currentController below returns this proxy
  // whenever the current field is warpBlend, and the real per-field
  // controller from widget.controllers for every other field.
  late final TextEditingController _warpBlendProxyController =
  TextEditingController(text: widget.warpBlendValue ?? '');

  _VoiceField get _currentField => _kVoiceFields[_fieldIndex];

  bool get _isUrdu => _lang == VoiceLang.urdu;

  String get _fieldLabel =>
      _isUrdu ? _currentField.labelUr : _currentField.labelEn;

  TextEditingController get _currentController {
    if (_currentField.kind == _FieldKind.warpBlend) {
      return _warpBlendProxyController;
    }
    return widget.controllers[_currentField.key] ??
        (widget.controllers[_currentField.key] = TextEditingController());
  }

  /// STEP 20 — true when the current step is either Warp Yarn Rate or
  /// Weft Yarn Rate, i.e. the two steps that should show the shared
  /// per-lb/per-10lb toggle. Both steps show it (not just one) since
  /// they're two separate stops in the sequence and the person might
  /// land on either one first.
  bool get _showYarnRateToggle =>
      _currentField.key == 'warpYarnRate' || _currentField.key == 'weftYarnRate';

  @override
  void initState() {
    super.initState();
    // Route the shared engine's callbacks to THIS modal instance while
    // it's on screen. Must happen before ensureInitialized() so that
    // even on the very first app-wide initialize() call, onStatus/
    // onError already have somewhere to go.
    VoiceEngine.instance.attach(onStatus: _handleStatus, onError: _handleError);
    _initSpeech();

    // Forward every change on the Warp Blend proxy controller straight
    // to InputScreen's real onChanged handler — this is what actually
    // gets the value out of the modal and into _warpBlend, fixing the
    // "chip highlights but the form never sees it" bug.
    _warpBlendProxyController.addListener(() {
      final value = _warpBlendProxyController.text;
      widget.onWarpBlendChanged(value.isEmpty ? null : value);
    });

    // Seed the Ply "Other" text field from whatever the controller
    // already holds, in case the modal is reopened with Ply already
    // set to something outside 1/2 from a previous session.
    final existingPly = widget.controllers['ply']?.text.trim();
    if (existingPly != null && existingPly != '1' && existingPly != '2') {
      _plyOtherController.text = existingPly;
    }
  }

  @override
  void dispose() {
    // Stop any in-flight listening session, but do NOT tear down or
    // replace the shared engine instance itself — see the VoiceEngine
    // class doc comment.
    _speech.stop();
    VoiceEngine.instance.detach();
    _plyOtherController.dispose();
    _warpBlendProxyController.dispose();
    super.dispose();
  }

  /// Uses VoiceEngine.ensureInitialized() instead of calling
  /// _speech.initialize() directly — on the first modal open this runs
  /// the real initialize() once; on every later open it just returns
  /// the already-known availability immediately.
  Future<void> _initSpeech() async {
    try {
      final available = await VoiceEngine.instance.ensureInitialized();

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

  /// Single entry point for every engine-level error. Recoverable codes
  /// (_kRecoverableErrors) just silently reset listening state so the
  /// user can immediately try again — no visible hint text anymore, per
  /// request. Only genuinely fatal errors set _initError and show the
  /// dead-end screen.
  ///
  /// Unconditionally clears _busy/_isListening/_warmingUp regardless of
  /// severity — an error happening mid-listen is exactly the scenario
  /// where those flags are most likely to be left stuck true otherwise.
  void _handleError(SpeechRecognitionError error) {
    if (!mounted) return;

    final isRecoverable = _kRecoverableErrors.contains(error.errorMsg);

    setState(() {
      _isListening = false;
      _warmingUp = false;
      _busy = false;
      if (!isRecoverable) {
        _initError = error.errorMsg;
      }
    });
  }

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
    if (_lang == lang || _busy) return;
    setState(() {
      _lang = lang;
      _transcript = '';
    });
  }

  /// STEP 20 — flips the SHARED unit for both Warp and Weft Yarn Rate,
  /// converting the CURRENTLY DISPLAYED number in BOTH
  /// widget.controllers['warpYarnRate'] and ['weftYarnRate'] together —
  /// this is a deliberate line-for-line mirror of InputScreen's own
  /// _setYarnRateUnit(), operating on the exact same controllers (since
  /// widget.controllers IS InputScreen's _controllers map, passed by
  /// reference). After converting, forwards the new unit to
  /// widget.onYarnRateUnitChanged.
  ///
  /// IMPORTANT: widget.onYarnRateUnitChanged is NOT InputScreen's
  /// _setYarnRateUnit — that would re-run the same /10-or-*10 math on
  /// numbers this method just finished converting, silently corrupting
  /// both rates. InputScreen instead passes a separate, sync-only
  /// callback (_syncYarnRateUnitFromModal) that just records the new
  /// unit and recalculates. So the actual conversion math happens
  /// exactly once per flip — here, when the flip originates in this
  /// modal — never twice.
  void _setYarnRateUnit(YarnRateUnit unit) {
    if (unit == _yarnRateUnit) return;
    final warpController = widget.controllers['warpYarnRate'];
    final weftController = widget.controllers['weftYarnRate'];
    final warpCurrent =
    warpController == null ? null : double.tryParse(warpController.text.trim());
    final weftCurrent =
    weftController == null ? null : double.tryParse(weftController.text.trim());
    setState(() {
      if (warpController != null && warpCurrent != null) {
        final converted =
        unit == YarnRateUnit.perLb ? warpCurrent / 10 : warpCurrent * 10;
        warpController.text = _formatForField(converted);
      }
      if (weftController != null && weftCurrent != null) {
        final converted =
        unit == YarnRateUnit.perLb ? weftCurrent / 10 : weftCurrent * 10;
        weftController.text = _formatForField(converted);
      }
      _yarnRateUnit = unit;
    });
    widget.onYarnRateUnitChanged(unit);
  }

  /// HOLD-TO-TALK — press down. Called from a Listener's onPointerDown,
  /// not a GestureDetector tap callback — see the class-level "HOLD-TO-
  /// TALK" doc comment for why that distinction matters.
  Future<void> _onPointerDown() async {
    if (!_speechAvailable || _done || _busy || _isListening) return;

    setState(() {
      _busy = true;
      _warmingUp = true;
      _transcript = '';
      _gotFinalResult = false;
    });

    try {
      await _speech.listen(
        onResult: _handleResult,
        localeId: _lang.localeId,
        listenMode: ListenMode.dictation,
        // No real timeout — bounded entirely by how long the button is
        // held (onPointerUp decides when to actually stop). These are
        // generous ceilings so Android/iOS don't impose their own short
        // default — though Android still enforces its OWN internal
        // speech-timeout independently of these values regardless; see
        // _kRecoverableErrors for how that's absorbed.
        listenFor: const Duration(minutes: 2),
        pauseFor: const Duration(minutes: 2),
        cancelOnError: false,
        partialResults: true,
      );
      await Future.delayed(const Duration(milliseconds: 250));
    } finally {
      if (mounted) {
        setState(() {
          _warmingUp = false;
          _busy = false;
        });
      }
    }
  }

  /// HOLD-TO-TALK — release. See the class-level "SINGLE-WORD
  /// RECOGNITION" doc comment for the full story: waits for an actual
  /// final result (up to ~700ms) before calling stop() at all, since
  /// calling stop() while the engine is still scoring a short utterance
  /// was confirmed (via live device logs) to make it abandon that
  /// recognition instead of finishing it.
  Future<void> _onPointerUp() async {
    if (!_isListening && !_warmingUp) return;

    setState(() => _busy = true);
    try {
      _gotFinalResult = false;
      const graceWindow = Duration(milliseconds: 700);
      const pollStep = Duration(milliseconds: 40);
      var waited = Duration.zero;

      while (waited < graceWindow && !_gotFinalResult && mounted) {
        await Future.delayed(pollStep);
        waited += pollStep;
      }

      if (!_gotFinalResult) {
        await _speech.stop();
        // POST-STOP SETTLE — gives any trailing callbacks room to land
        // before the busy guard is released, so the next listen()
        // doesn't collide with a session that hasn't fully torn down
        // yet (seen live as error_client when this wasn't here).
        await Future.delayed(const Duration(milliseconds: 200));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _handleResult(SpeechRecognitionResult result) {
    if (result.finalResult) {
      _gotFinalResult = true;
    }
    if (!mounted) return;
    setState(() {
      // Only overwrite the transcript with an empty final result if we
      // didn't already have something better — a late, empty final
      // result landing after a good partial already arrived should not
      // erase that partial.
      if (result.recognizedWords.trim().isNotEmpty || _transcript.isEmpty) {
        _transcript = result.recognizedWords;
      }
    });
    _applyTranscriptToField(result.recognizedWords);
  }

  /// Writes the live transcript straight into the current field's
  /// controller (and, for warpBlend/ply, into the matching radio
  /// selection) as results stream in — not just on Confirm. This is
  /// what makes the field "fill live while speaking" rather than only
  /// updating once at the end. The person can still type over any of
  /// this by hand at any time; nothing here is a one-way lock.
  ///
  /// STEP 20 note: for warpYarnRate/weftYarnRate specifically, the
  /// number written here is taken to be ALREADY in whichever unit
  /// _yarnRateUnit currently is — exactly like typing it by hand into
  /// the matching field on the main screen would be. Nothing here
  /// converts it; conversion only ever happens in _setYarnRateUnit()
  /// when the toggle itself is flipped, same division of responsibility
  /// as InputScreen.
  void _applyTranscriptToField(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return;

    final field = _currentField;
    switch (field.kind) {
      case _FieldKind.text:
        _currentController.text = text;
        break;
      case _FieldKind.number:
        final value = _SpokenNumberParser.parse(text, _lang);
        if (value != null) {
          _currentController.text = _formatForField(value);
        }
        break;
      case _FieldKind.warpBlend:
        final matched = _WarpBlendMatcher.match(text);
        if (matched != null) {
          setState(() => _currentController.text = matched);
        }
        break;
      case _FieldKind.ply:
        final value = _SpokenNumberParser.parse(text, _lang);
        if (value != null) {
          final asInt = value.round();
          setState(() {
            if (asInt == 1 || asInt == 2) {
              _currentController.text = asInt.toString();
            } else {
              _currentController.text = 'other';
              _plyOtherController.text = _formatForField(value);
            }
          });
        }
        break;
    }
  }

  /// Moves to the next field. Both Skip and Confirm do the same thing
  /// now that every field is always live-editable — there's no
  /// separate "commit" step, the controller already holds whatever was
  /// spoken or typed. Confirm/Skip are purely sequence navigation.
  Future<void> _advance() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (_isListening || _warmingUp) {
        await _speech.stop();
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _warmingUp = false;
          if (_fieldIndex >= _kVoiceFields.length - 1) {
            _done = true;
          } else {
            _fieldIndex++;
            _transcript = '';
          }
        });
      }
    }
  }

  String _formatForField(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    var s = value.toStringAsFixed(6);
    s = s.replaceFirst(RegExp(r'0+$'), '');
    s = s.replaceFirst(RegExp(r'\.$'), '');
    return s;
  }

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
                enabled: _initError == null && !_done && !_busy,
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
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(_t('Done', 'مکمل')),
              ),
            ] else ...[
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

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _fieldLabel,
                      textDirection: _isUrdu ? TextDirection.rtl : TextDirection.ltr,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  // STEP 20 — shared per-lb/per-10lb toggle, shown only
                  // on the Warp Yarn Rate / Weft Yarn Rate steps. Same
                  // chip styling as InputScreen's own toggle, and reads/
                  // writes the exact same shared unit — see
                  // _showYarnRateToggle and _setYarnRateUnit() above.
                  if (_showYarnRateToggle)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _unitChip(
                          label: 'per lb',
                          selected: _yarnRateUnit == YarnRateUnit.perLb,
                          onTap: () => _setYarnRateUnit(YarnRateUnit.perLb),
                          colorScheme: colorScheme,
                        ),
                        const SizedBox(width: 6),
                        _unitChip(
                          label: 'per 10 lb',
                          selected: _yarnRateUnit == YarnRateUnit.perTenLb,
                          onTap: () => _setYarnRateUnit(YarnRateUnit.perTenLb),
                          colorScheme: colorScheme,
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _t('Hold the mic and speak, or type below', 'مائیک دبا کر بولیں، یا نیچے ٹائپ کریں'),
                style: TextStyle(fontSize: 12,
                    color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),

              // Live transcript readout — purely informational, shows
              // what voice most recently heard. The editable field
              // below it (for text/number) or the radio group (for
              // warpBlend/ply) is the actual source of truth.
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
                            ? (_warmingUp
                            ? _t('Get ready…', 'تیار ہو جائیں…')
                            : _isListening
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
                    if (_isListening || _warmingUp)
                      Icon(Icons.graphic_eq, color: colorScheme.primary),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // EVERY FIELD STAYS EDITABLE — the actual input for the
              // current field. Text/number fields get a plain TextField
              // bound to the controller; warpBlend/ply get a radio
              // group. Either way this is the single source of truth
              // the person can always tap into and correct by hand.
              _FieldEditor(
                field: _currentField,
                controller: _currentController,
                plyOtherController: _plyOtherController,
                isUrdu: _isUrdu,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 24),

              Center(
                child: _MicButton(
                  isListening: _isListening,
                  isWarmingUp: _warmingUp,
                  enabled: !_busy || _isListening || _warmingUp,
                  onDown: _onPointerDown,
                  onUp: _onPointerUp,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _warmingUp
                    ? _t('Starting…', 'شروع ہو رہا ہے…')
                    : _isListening
                    ? _t('Release to stop', 'چھوڑنے پر رک جائے گا')
                    : _t('Press and hold to talk', 'بولنے کے لیے دبا کر رکھیں'),
                style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : _advance,
                      child: Text(_t('Skip', 'چھوڑیں')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy ? null : _advance,
                      child: Text(_t('Next', 'آگے')),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// STEP 20 — same chip styling as InputScreen's own _unitChip(), kept
  /// as a private copy here rather than shared/exported, since it's a
  /// trivial 20-line presentational widget and sharing it would mean
  /// adding yet another file to the import graph for no real benefit.
  Widget _unitChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? colorScheme.primaryContainer : colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? colorScheme.primary : colorScheme.outlineVariant,
            width: selected ? 1.2 : 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// =========================================================================
// FIELD EDITOR — the always-editable input for the current field
// =========================================================================

class _FieldEditor extends StatelessWidget {
  final _VoiceField field;
  final TextEditingController controller;
  final TextEditingController plyOtherController;
  final bool isUrdu;
  final VoidCallback onChanged;

  const _FieldEditor({
    required this.field,
    required this.controller,
    required this.plyOtherController,
    required this.isUrdu,
    required this.onChanged,
  });

  String _t(String en, String ur) => isUrdu ? ur : en;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    switch (field.kind) {
      case _FieldKind.text:
      case _FieldKind.number:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 6, left: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_outlined,
                      size: 13, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    _t('Or type here', 'یا یہاں ٹائپ کریں'),
                    style: TextStyle(
                        fontSize: 11, color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            TextField(
              controller: controller,
              keyboardType: field.kind == _FieldKind.number
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.text,
              textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                filled: true,
                fillColor: colorScheme.surfaceContainerLow,
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                hintText: _t('Type or speak the value', 'ٹائپ کریں یا بولیں'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
                ),
              ),
              onChanged: (_) => onChanged(),
            ),
          ],
        );

      case _FieldKind.warpBlend:
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kWarpBlendOptions.map((option) {
            final selected = controller.text == option;
            return ChoiceChip(
              label: Text(option),
              selected: selected,
              onSelected: (_) {
                controller.text = option;
                onChanged();
              },
            );
          }).toList(),
        );

      case _FieldKind.ply:
        final current = controller.text;
        final isOther = current != '1' && current != '2';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('1'),
                  selected: current == '1',
                  onSelected: (_) {
                    controller.text = '1';
                    onChanged();
                  },
                ),
                ChoiceChip(
                  label: const Text('2'),
                  selected: current == '2',
                  onSelected: (_) {
                    controller.text = '2';
                    onChanged();
                  },
                ),
                ChoiceChip(
                  label: Text(_t('Other', 'دیگر')),
                  selected: isOther && current.isNotEmpty,
                  onSelected: (_) {
                    controller.text = plyOtherController.text.isEmpty
                        ? 'other'
                        : plyOtherController.text;
                    onChanged();
                  },
                ),
              ],
            ),
            if (isOther) ...[
              const SizedBox(height: 10),
              TextField(
                controller: plyOtherController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  hintText: _t('Enter Ply value', 'پلائی کی ویلیو درج کریں'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant, width: 0.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant, width: 0.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                    BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5),
                  ),
                ),
                onChanged: (value) {
                  controller.text = value;
                  onChanged();
                },
              ),
            ],
          ],
        );
    }
  }
}

/// Large press-and-hold mic button. Uses Listener (raw pointer events)
/// instead of GestureDetector's tap callbacks — see the class-level doc
/// comment in _VoiceInputModalState for exactly why that distinction
/// fixed the "mic press not registering" bug. onPointerCancel is wired
/// the same as onPointerUp so that a finger sliding off the button
/// still stops listening, the same way releasing a real voice-note
/// button anywhere stops the recording.
class _MicButton extends StatelessWidget {
  final bool isListening;
  final bool isWarmingUp;
  final bool enabled;
  final Future<void> Function() onDown;
  final Future<void> Function() onUp;

  const _MicButton({
    required this.isListening,
    required this.isWarmingUp,
    required this.enabled,
    required this.onDown,
    required this.onUp,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final active = isListening || isWarmingUp;

    return Listener(
      onPointerDown: enabled ? (_) => onDown() : null,
      onPointerUp: enabled ? (_) => onUp() : null,
      onPointerCancel: enabled ? (_) => onUp() : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: active ? 84 : 72,
        height: active ? 84 : 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isWarmingUp
              ? colorScheme.tertiary
              : isListening
              ? colorScheme.error
              : (enabled ? colorScheme.primary : colorScheme.outlineVariant),
          boxShadow: active
              ? [
            BoxShadow(
              color: (isListening ? colorScheme.error : colorScheme.tertiary)
                  .withValues(alpha: 0.3),
              blurRadius: 16,
              spreadRadius: 4,
            ),
          ]
              : null,
        ),
        child: Icon(
          isWarmingUp
              ? Icons.hourglass_top
              : isListening
              ? Icons.graphic_eq
              : Icons.mic,
          color: active ? colorScheme.onError : colorScheme.onPrimary,
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