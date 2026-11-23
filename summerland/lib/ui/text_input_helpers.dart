import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;

/// Returns the initial autofocus value for a text field.
///
/// Android never autofocuses text inputs, so the on-screen keyboard stays
/// closed until the user taps a field. Windows keeps its existing behavior.
/// This does not affect explicit `FocusNode.requestFocus()` calls.
bool textFieldAutofocus([bool requested = false]) =>
    requested && defaultTargetPlatform != TargetPlatform.android;
