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
/// SINGLE-WORD RECOGNITION — listenMode.dictation:
/// This is a contributing fix for short words being missed (the
/// warm-up delay alone does not fully solve it). speech_to_text exposes
/// a `listenMode` that controls how the underlying platform recognizer
/// is configured:
///   - ListenMode.confirmation (the package default if you don't set
///     it) is tuned for short yes/no-style command phrases and is more
///     aggressive about deciding "nothing useful was said" quickly.
///   - ListenMode.dictation is tuned for free-form speech and is more
///     forgiving of a single isolated word with silence on either side.
/// Switched to ListenMode.dictation below.
///
/// SINGLE-WORD RECOGNITION — release grace delay (the actual fix):
/// Reported symptom: a single isolated digit ("1", "2", "5"...) spoken
/// alone is never captured — the transcript stays empty — but saying
/// the same digit twice ("one one") works every time, and is
/// transcribed straight to "11" by the recognizer itself.
///
/// Root cause: this is NOT a recognition-quality problem, it's a
/// timing problem in THIS widget. _onPointerUp calls _speech.stop()
/// the instant the finger lifts. For a single short syllable, the
/// finger lifts almost immediately after the word is spoken — often
/// before the recognizer has finished turning its in-flight partial
/// result into a confident final one. stop() cuts the engine off mid-
/// process, and what comes back is an empty, low-confidence final
/// result (matches the documented platform behavior: a final result
/// with confidence -1.0 and empty recognizedWords is what the engine
/// emits when a session is torn down before it finishes scoring what
/// it heard). A two-syllable utterance survives because the natural
/// time it takes to say it gives the engine enough headroom before the
/// hold is released.
///
/// Fixed with a short grace delay (350ms) inserted at the START of
/// _onPointerUp, before stop() is called. This does NOT make the UI
/// feel slow — the engine is still actively listening during that
/// window (partialResults keep flowing into _transcript exactly as
/// before), it just delays the moment stop() is issued so a trailing
/// single word has time to finalize. If a later partial result arrives
/// during the grace delay, it preempts the delay immediately rather
/// than waiting out the full 350ms unnecessarily.
///
/// ERROR HANDLING — recoverable vs fatal, and the permanent-lock bug:
/// Every error speech_to_text reports comes through one onError
/// callback, but they are NOT all the same severity:
///   - error_speech_timeout / error_no_match / error_busy are routine,
///     expected, recoverable conditions — Android's native
///     SpeechRecognizer enforces its own short "didn't hear anything
///     yet" timeout internally and WILL fire this if the engine starts
///     listening but doesn't detect audio within its own internal
///     window. Critically, pauseFor/listenFor (the durations this
///     widget passes in) do NOT override that internal Android timeout
///     — see the package docs: pauseFor is documented as being ignored
///     on Android, which enforces its own (much shorter) pause/timeout
///     behavior regardless of what's requested. So even with
///     listenFor/pauseFor set to 2 minutes, Android can still decide on
///     its own that "too much silence has passed" and emit
///     error_speech_timeout while the user is still holding the button.
///   - error_audio_error / error_client / permission-related errors are
///     genuinely fatal — something is actually broken and retrying
///     won't help.
/// The previous version treated ALL errors as fatal: onError always set
/// _initError, and the UI permanently locks into a "Microphone Not
/// available" dead-end screen the instant _initError is non-null, with
/// no path back except closing the whole modal. That's why one routine
/// timeout on field 3 could brick the rest of the session even though
/// the mic hardware and permissions were completely fine.
/// Fixed by classifying errors: recoverable ones just reset the
/// listening state (with a small inline "didn't catch that" hint) so
/// the user can immediately press and try again; only genuinely fatal
/// errors show the dead-end screen.
///
/// BUSY GUARD — mic getting permanently stuck after rapid skips/errors:
/// Any stop()/listen() call sets _busy true and is awaited fully before
/// clearing it, and the mic button (and Skip/Confirm) ignore taps while
/// _busy is true. This serializes every engine interaction instead of
/// letting overlapping calls race and desync speech_to_text's internal
/// state. The error path now ALSO guarantees _busy/_warmingUp/
/// _isListening are reset in a finally-equivalent block, since a
/// mid-flight error is exactly the case most likely to leave one of
/// those flags stuck true (which is what made the mic stop responding
/// to presses at all, not just stop showing transcripts).
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';

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
// ERROR CLASSIFICATION
// =========================================================================
//
// speech_to_text reports every engine-level problem through the same
// onError callback, tagged with a string errorMsg. Not all of them mean
// the same thing, and treating them identically is what caused the
// "one timeout bricks the whole modal" bug. This list is the set of
// codes that are routine/expected and should just let the user try
// again, not show a dead-end "Microphone Not available" screen.
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
//                         asynchronously finishing its teardown
//                         (trailing onResult/onStatus callbacks were
//                         observed arriving after stop() had already
//                         returned). It's a collision between sessions,
//                         not a broken mic — confirmed by the same
//                         physical mic immediately working again on the
//                         very next attempt once given enough settle
//                         time. See the post-stop settle delay in
//                         _onPointerUp.
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

/// ENGINE SINGLETON — fixes "mic stops working after closing and
/// reopening the modal":
///
/// The previous version created `final SpeechToText _speech =
/// SpeechToText()` directly inside _VoiceInputModalState, and called
/// `_speech.initialize()` in initState(). That means every time the
/// bottom sheet was opened, a BRAND NEW SpeechToText instance was
/// created and a BRAND NEW initialize() call was made — and every time
/// it was closed, dispose() called stop() on that instance and threw
/// it away.
///
/// This directly contradicts how the package is meant to be used. The
/// official docs are explicit about it: initialize() is meant to run
/// ONCE per app session, and warn that "there should be only one
/// instance of the plugin per application" — repeated initialize()
/// calls are documented as unreliable for resetting callbacks, and in
/// practice (confirmed by multiple reports of this exact symptom)
/// re-initializing a second time can leave the native Android
/// recognizer session in a half-torn-down state from the previous
/// instance, which is consistent with "listening starts, shows for
/// about a second, then silently stops with no error" — the new
/// session collides with the old one before Android has fully
/// released it.
///
/// Fixed by moving the SpeechToText instance and its one-time
/// initialize() into this singleton, which lives for the lifetime of
/// the app process, not the lifetime of the modal widget. The modal
/// now calls VoiceEngine.ensureInitialized() in initState() instead of
/// creating+initializing its own instance — the first call actually
/// initializes the engine, every call after that (including on the
/// next time the modal is opened) reuses the already-initialized
/// instance and returns immediately.
class VoiceEngine {
  VoiceEngine._();
  static final VoiceEngine instance = VoiceEngine._();

  final SpeechToText speech = SpeechToText();

  bool _initialized = false;
  bool _available = false;
  bool get available => _available;

  // The modal's current onStatus/onError handlers. Re-pointed every
  // time a modal attaches (see attach()) since speech_to_text only
  // lets you set these once via initialize() — see class doc comment.
  // Calls are forwarded here instead, so each new modal instance still
  // gets live status/error callbacks despite initialize() only really
  // running the first time.
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
  /// after ensureInitialized(), and cleared in dispose() so a modal
  /// that's gone doesn't keep receiving callbacks (and so it doesn't
  /// call setState() after being unmounted).
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

class VoiceInputModal extends StatefulWidget {
  /// The controllers map from InputScreen — same keys as _controllers.
  final Map<String, TextEditingController> controllers;

  const VoiceInputModal({super.key, required this.controllers});

  @override
  State<VoiceInputModal> createState() => _VoiceInputModalState();
}

class _VoiceInputModalState extends State<VoiceInputModal> {
  // Shared, app-lifetime engine instance — see the VoiceEngine class
  // doc comment for why this replaced a per-modal SpeechToText().
  SpeechToText get _speech => VoiceEngine.instance.speech;

  bool _speechAvailable = false;

  // Fatal init/hardware/permission problem — shows the permanent
  // dead-end screen. Distinct from _retryHint below, which is for
  // routine recoverable errors that should NOT lock the modal.
  String? _initError;

  // Set briefly when a RECOVERABLE error (timeout / no-match / busy)
  // happens mid-session. Shown as a small inline hint near the
  // transcript box ("Didn't catch that — try again") instead of
  // replacing the whole modal. Cleared automatically on the next
  // press of the mic.
  String? _retryHint;

  // Driven by speech_to_text's onStatus callback — the only reliable
  // source of truth for whether the mic is live right now.
  bool _isListening = false;

  // True while the engine is "warming up" — the brief window between
  // listen() being called and the warm-up delay finishing, during
  // which the UI shows a distinct visual state so the user knows to
  // wait a beat before speaking. See _onPointerDown.
  bool _warmingUp = false;

  // BUSY GUARD — true for the entire duration of any stop()/listen()
  // call this widget makes, from the moment it's invoked until it (and
  // any warm-up delay) fully completes. The mic button and Skip/Confirm
  // ignore input while this is true, which prevents overlapping engine
  // calls from racing each other. Also force-cleared whenever onError
  // fires, since a mid-flight error is the case most likely to leave
  // this stuck true otherwise (see class-level doc comment).
  bool _busy = false;

  String _transcript = '';

  // Bumped every time _handleResult fires with a non-empty transcript.
  // Used by _onPointerUp's grace delay to detect "a new result just
  // came in, so the engine made more progress — stop waiting and
  // finalize now" instead of always waiting out the full grace window.
  int _resultRevision = 0;

  // Set true the instant a FINAL (not partial) result arrives from the
  // engine. _onPointerUp's grace wait polls this instead of just "any
  // result happened" — see the live-debug-log-driven rewrite of
  // _onPointerUp for why waiting specifically for a final result (and
  // only falling back to calling stop() ourselves if one never shows
  // up in time) is what actually fixes single-word loss, vs. the
  // earlier version which waited for any result and then called
  // stop() regardless.
  bool _gotFinalResult = false;

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
    // Route the shared engine's callbacks to THIS modal instance while
    // it's on screen. Must happen before ensureInitialized() so that
    // even on the very first app-wide initialize() call, onStatus/
    // onError already have somewhere to go.
    VoiceEngine.instance.attach(onStatus: _handleStatus, onError: _handleError);
    _initSpeech();
  }

  @override
  void dispose() {
    // Stop any in-flight listening session, but do NOT tear down or
    // replace the shared engine instance itself — see the VoiceEngine
    // class doc comment for why re-creating/re-initializing per modal
    // open is exactly what caused "mic stops responding after closing
    // and reopening the modal." detach() so this now-dead State stops
    // receiving callbacks (and can't call setState() after unmount).
    _speech.stop();
    VoiceEngine.instance.detach();
    super.dispose();
  }

  /// Uses VoiceEngine.ensureInitialized() instead of calling
  /// _speech.initialize() directly — on the first modal open this runs
  /// the real initialize() once; on every later open (including after
  /// fully closing and reopening the modal) it just returns the
  /// already-known availability immediately, without touching the
  /// native recognizer session at all. See the VoiceEngine class doc
  /// comment for the full story.
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
    // ignore: avoid_print
    print('[VOICE-DEBUG] onStatus: $status');
    if (!mounted) return;
    setState(() {
      _isListening = status == 'listening';
    });
  }

  /// Single entry point for every engine-level error, called both
  /// during the initial speech.initialize() and during any listen()
  /// session. The critical fix here vs. the previous version: this no
  /// longer unconditionally sets _initError (which permanently locks
  /// the modal into the dead-end screen). Routine/expected errors are
  /// classified via _kRecoverableErrors and just reset listening state
  /// with a small retry hint; only genuinely fatal errors set
  /// _initError.
  ///
  /// Also unconditionally clears _busy/_isListening/_warmingUp — an
  /// error happening mid-listen is exactly the scenario where those
  /// flags are most likely to be left stuck true by a race between the
  /// error path and whatever _onPointerDown/_onPointerUp/_advance call
  /// happened to be in flight, which is what made the mic stop
  /// responding to ANY press at all (not just stop producing text).
  void _handleError(SpeechRecognitionError error) {
    // ignore: avoid_print
    print('[VOICE-DEBUG] onError: ${error.errorMsg} permanent=${error.permanent}');
    if (!mounted) return;

    final isRecoverable = _kRecoverableErrors.contains(error.errorMsg);

    setState(() {
      _isListening = false;
      _warmingUp = false;
      _busy = false;

      if (isRecoverable) {
        _retryHint = error.errorMsg == 'error_no_match'
            ? _t('Didn\'t catch that — try again', 'سمجھ نہیں آیا — دوبارہ کوشش کریں')
            : _t('Didn\'t hear you in time — try again', 'وقت پر آواز نہیں آئی — دوبارہ کوشش کریں');
      } else {
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

  /// HOLD-TO-TALK — press down. Called from a Listener's onPointerDown,
  /// not a GestureDetector tap callback — see the class-level doc
  /// comment "HOLD-TO-TALK" for why that distinction matters.
  ///
  /// Guarded by _busy so a press that lands while a previous stop() is
  /// still finishing is ignored instead of racing it.
  ///
  /// listenMode is explicitly set to ListenMode.dictation — see the
  /// class-level doc comment "SINGLE-WORD RECOGNITION" for why this
  /// (not just the warm-up delay) is the actual fix for short isolated
  /// words being missed.
  ///
  /// After listen() starts, a 250ms warm-up delay runs before
  /// _warmingUp clears. The user can still speak during this window
  /// (the engine IS recording), but the UI distinguishes "still
  /// warming up" from "fully listening" so very short words spoken
  /// right at press-down aren't the first thing said to a
  /// half-started engine.
  Future<void> _onPointerDown() async {
    if (!_speechAvailable || _done || _busy || _isListening) return;

    setState(() {
      _busy = true;
      _warmingUp = true;
      _transcript = '';
      _retryHint = null;
      _resultRevision = 0;
      _gotFinalResult = false;
    });

    try {
      // ignore: avoid_print
      print('[VOICE-DEBUG] listen() starting, locale=${_lang.localeId}');
      await _speech.listen(
        onResult: _handleResult,
        localeId: _lang.localeId,
        listenMode: ListenMode.dictation,
        // No real timeout — bounded entirely by how long the button is
        // held (onPointerUp calls stop()). These are generous ceilings
        // so Android/iOS don't impose their own short default — though
        // note Android still enforces its OWN internal speech-timeout
        // independently of these values; that's handled via
        // _handleError + _kRecoverableErrors instead, since it can't be
        // configured away.
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

  /// HOLD-TO-TALK — release. THIS is the actual fix for single isolated
  /// digits/words being missed — see "SINGLE-WORD RECOGNITION — release
  /// grace delay" in the class-level doc comment for the full
  /// explanation. Short version: calling stop() the instant the finger
  /// lifts can cut the engine off before it finishes turning a short
  /// utterance's partial result into a confident final one, which comes
  /// back as an empty transcript. So instead of stopping immediately,
  /// this waits a short grace window (350ms) first — UNLESS a new
  /// partial result arrives during that window, in which case it stops
  /// waiting immediately and proceeds to stop() right away, since a
  /// fresh result means the engine already made the progress we were
  /// waiting for. Either way _busy stays true for the whole window so
  /// Skip/Confirm/mic can't race a stop() that hasn't happened yet.
  Future<void> _onPointerUp() async {
    if (!_isListening && !_warmingUp) return;
    // ignore: avoid_print
    print('[VOICE-DEBUG] onPointerUp: transcript="$_transcript"');

    setState(() => _busy = true);
    try {
      // GRACE WAIT v2 — based on live debug logs, the previous 350ms
      // wait-then-stop() approach was not the problem's actual shape.
      // What the logs showed:
      //   - For a single short word, stop() returns BEFORE the
      //     engine's real onResult ever fires.
      //   - The onResult that eventually arrives (after stop() has
      //     already returned) comes back empty (confidence -1.0) —
      //     i.e. calling stop() while the engine is mid-recognition
      //     for a short utterance causes it to abandon/discard that
      //     recognition rather than letting it finish.
      // So waiting BEFORE calling stop() helps, but only if we wait
      // long enough for the engine's real final result to land BEFORE
      // stop() is ever invoked — not just "long enough that something,
      // even an empty placeholder, came back." This now waits for an
      // actual final result (_gotFinalResult flag, set in
      // _handleResult) for up to 700ms, polling in short steps so a
      // final result short-circuits the wait immediately. Only if NO
      // final result shows up in that whole window do we fall back to
      // calling stop() ourselves — at that point the engine is well
      // past where a real short-word recognition would have landed,
      // so there's nothing left to lose by stopping.
      _gotFinalResult = false;
      const graceWindow = Duration(milliseconds: 700);
      const pollStep = Duration(milliseconds: 40);
      var waited = Duration.zero;

      while (waited < graceWindow && !_gotFinalResult && mounted) {
        await Future.delayed(pollStep);
        waited += pollStep;
      }
      // ignore: avoid_print
      print('[VOICE-DEBUG] grace wait done, waited=${waited.inMilliseconds}ms '
          'gotFinal=$_gotFinalResult transcript="$_transcript"');

      if (!_gotFinalResult) {
        // ignore: avoid_print
        print('[VOICE-DEBUG] no final result arrived — calling stop()');
        await _speech.stop();
        // ignore: avoid_print
        print('[VOICE-DEBUG] stop() returned, transcript="$_transcript"');

        // POST-STOP SETTLE — the live debug log showed onResult/onStatus
        // callbacks still arriving AFTER stop() had already returned
        // (e.g. "stop() returned" followed later by onStatus: done and
        // an onError). Clearing _busy immediately at that point lets a
        // fast next press start a new listen() session while the
        // previous one is still asynchronously tearing down — which is
        // exactly what produced error_client / error_speech_timeout on
        // the very next attempt in the log. This short delay gives
        // those trailing callbacks room to land before the busy guard
        // is released, so the next listen() doesn't collide with a
        // session that technically hasn't finished shutting down yet.
        await Future.delayed(const Duration(milliseconds: 200));
      }

      // SILENT-EMPTY-RESULT CASE: sometimes the engine produces no
      // result at all for a very short isolated word — not an error,
      // not even an empty final result callback, just nothing. Without
      // this, the user has no idea anything went wrong: the box just
      // keeps showing the generic "Hold the mic..." placeholder, which
      // looks identical to "you never pressed the mic" rather than
      // "you spoke and it wasn't caught". This surfaces that
      // distinction with the same small inline hint _handleError uses
      // for recoverable errors, so the user knows to just try again.
      if (mounted && _transcript.trim().isEmpty) {
        setState(() {
          _retryHint = _t(
            'Didn\'t catch that — try again, holding a beat longer',
            'سمجھ نہیں آیا — دوبارہ کوشش کریں، ذرا دیر تک دبائیں',
          );
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _handleResult(SpeechRecognitionResult result) {
    // ignore: avoid_print
    print('[VOICE-DEBUG] onResult: words="${result.recognizedWords}" '
        'confidence=${result.confidence} final=${result.finalResult}');
    if (result.finalResult) {
      _gotFinalResult = true;
    }
    if (!mounted) return;
    setState(() {
      // Only overwrite the transcript with an empty final result if we
      // didn't already have something better. A late, empty final
      // result landing after a good partial already arrived should not
      // erase that partial — see the live debug log, where exactly this
      // sequence (good partial, then empty final) is a real
      // possibility once the engine is winding down.
      if (result.recognizedWords.trim().isNotEmpty || _transcript.isEmpty) {
        _transcript = result.recognizedWords;
      }
      if (result.recognizedWords.trim().isNotEmpty) {
        _resultRevision++;
      }
    });
  }

  /// Confirms the current transcript as the value for the current field,
  /// writes it into the controller, then advances to the next field.
  void _confirm() {
    if (_busy) return;
    final raw = _transcript.trim();
    if (raw.isEmpty) return;

    final field = _currentField;
    if (!field.isText) {
      final value = _SpokenNumberParser.parse(raw, _lang);
      if (value != null) {
        widget.controllers[field.key]?.text = _formatForField(value);
      }
    } else {
      widget.controllers[field.key]?.text = raw;
    }

    _advance();
  }

  /// Skips the current field (leaves its controller unchanged).
  void _skip() {
    if (_busy) return;
    _advance();
  }

  /// Advances to the next field. Fully awaits stop() before allowing
  /// the next field's listen() to be triggered — guarded by _busy the
  /// same way press/release are, which is what prevents rapid
  /// skip-skip-skip from leaving the engine in a desynced state.
  Future<void> _advance() async {
    setState(() {
      _busy = true;
      _retryHint = null;
    });
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

              // Inline hint for routine recoverable errors (timeout /
              // no-match / busy). Distinct from the fatal _initError
              // screen above — this never blocks the modal, it just
              // tells the user the last attempt didn't register and to
              // try the mic again.
              if (_retryHint != null) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline, size: 14, color: colorScheme.error),
                    const SizedBox(width: 4),
                    Text(
                      _retryHint!,
                      style: TextStyle(fontSize: 12, color: colorScheme.error),
                    ),
                  ],
                ),
              ],
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
                      onPressed: _busy ? null : _skip,
                      child: Text(_t('Skip', 'چھوڑیں')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: (_busy || _transcript.trim().isEmpty) ? null : _confirm,
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