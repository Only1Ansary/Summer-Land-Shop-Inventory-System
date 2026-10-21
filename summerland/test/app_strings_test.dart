import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:summerland/localization/app_strings.dart';

void main() {
  test('English returns the key unchanged', () {
    final strings = AppStrings(const Locale('en'));

    expect(strings.translate('Sale Invoices'), 'Sale Invoices');
    expect(strings.translate('Total: {0}', ['EGP 5']), 'Total: EGP 5');
  });

  test('Arabic translates known keys', () {
    final strings = AppStrings(const Locale('ar'));

    expect(strings.isArabic, isTrue);
    expect(strings.translate('Sale Invoices'), isNot('Sale Invoices'));
    expect(strings.translate('Sale Invoices'), 'فواتير البيع');
  });

  test('Arabic substitutes positional placeholders', () {
    final strings = AppStrings(const Locale('ar'));

    expect(strings.translate('Sale Invoice #{0}', [42]), contains('42'));
  });

  test('untranslated keys fall back to the English original', () {
    final strings = AppStrings(const Locale('ar'));

    expect(
      strings.translate('Some string that has no translation yet'),
      'Some string that has no translation yet',
    );
  });
}
