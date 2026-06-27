/// yarn_rate_unit.dart
/// -----------------------------------------------------------------------
/// Shared enum for the Warp/Weft Yarn Rate unit toggle (per lb / per 10
/// lb) — see the STEP 20 doc comment in input_screen.dart for the full
/// story of what this controls and why.
///
/// Pulled into its own tiny file (instead of just living inside
/// input_screen.dart, where it originated) so that voice_input_modal.dart
/// can import it too without creating a circular import (input_screen.dart
/// imports voice_input_modal.dart to open it as a bottom sheet, so
/// voice_input_modal.dart can't import input_screen.dart back).
///
/// There is exactly ONE YarnRateUnit value live at a time for the whole
/// screen — both the main InputScreen toggle and the matching toggle
/// inside VoiceInputModal read and write the SAME value (threaded
/// through via InputScreen's _yarnRateUnit field + _setYarnRateUnit(),
/// passed into VoiceInputModal as yarnRateUnit/onYarnRateUnitChanged —
/// exactly mirroring how Warp Blend is threaded through as
/// warpBlendValue/onWarpBlendChanged). Flipping the toggle in either
/// place updates both immediately; there's no separate "modal copy" of
/// this setting to drift out of sync.
library;

enum YarnRateUnit { perLb, perTenLb }