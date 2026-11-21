import 'package:flutter/material.dart' show BuildContext, IconData, Icons;

import '../localization/app_strings.dart';

/// Values must match the backend `PaymentMethod` enum.
const int paymentMethodCash = 0;
const int paymentMethodVisa = 1;
const int paymentMethodInstaPay = 2;
const int paymentMethodVCash = 3;

const List<int> paymentMethodValues = [
  paymentMethodCash,
  paymentMethodVisa,
  paymentMethodInstaPay,
  paymentMethodVCash,
];

String paymentMethodLabel(BuildContext context, int method) {
  switch (method) {
    case paymentMethodVisa:
      return context.tr('Visa');
    case paymentMethodInstaPay:
      return context.tr('InstaPay');
    case paymentMethodVCash:
      return context.tr('VCash');
    case paymentMethodCash:
    default:
      return context.tr('Cash');
  }
}

IconData paymentMethodIcon(int method) {
  switch (method) {
    case paymentMethodVisa:
    case paymentMethodInstaPay:
    case paymentMethodVCash:
      return Icons.account_balance_wallet_outlined;
    case paymentMethodCash:
    default:
      return Icons.payments_outlined;
  }
}
