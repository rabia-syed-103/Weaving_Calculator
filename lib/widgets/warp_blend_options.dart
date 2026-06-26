/// warp_blend_options.dart
/// -----------------------------------------------------------------------
/// Single source of truth for the Warp Blend code list. Both
/// input_screen.dart (the dropdown) and voice_input_modal.dart (the
/// voice-driven chip group) import this SAME list rather than each
/// declaring their own — two separate lists with different spellings
/// (e.g. one using 'Cotton', the other 'Ctn') was the original cause of
/// "voice modal selects a value the InputScreen dropdown doesn't
/// recognize", which throws at runtime since DropdownButton requires
/// its `value` to either be null or exactly match one of its `items`.
///
/// Putting this in its own tiny file (rather than importing
/// input_screen.dart from voice_input_modal.dart, or vice versa) avoids
/// a circular import between the two — input_screen.dart already
/// imports voice_input_modal.dart to use VoiceInputModal, so the
/// dependency only needs to flow one way.
library;

const List<String> kWarpBlendOptions = ['Ctn', 'Pc', 'Pv', 'Pp', 'Cvc', 'Viscose'];