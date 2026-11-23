import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter_test/flutter_test.dart';

import 'package:summerland/ui/text_input_helpers.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('Android never autofocuses text inputs', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    expect(textFieldAutofocus(true), isFalse);
    expect(textFieldAutofocus(false), isFalse);
  });

  test('Windows keeps the requested autofocus behavior', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;

    expect(textFieldAutofocus(true), isTrue);
    expect(textFieldAutofocus(false), isFalse);
  });
}
