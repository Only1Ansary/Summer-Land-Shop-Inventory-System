import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:summerland/ui/barcode_view.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) {
    return tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  }

  testWidgets('draws a scannable barcode from the typed numbers', (
    tester,
  ) async {
    await pump(tester, const BarcodeView('201781'));

    expect(find.byType(BarcodeWidget), findsOneWidget);
    expect(find.text('201781'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders internal codes like SHOP-00000012', (tester) async {
    await pump(tester, const BarcodeView('SHOP-00000012'));

    expect(find.byType(BarcodeWidget), findsOneWidget);
    expect(find.text('SHOP-00000012'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('can hide the text where the screen already shows it', (
    tester,
  ) async {
    await pump(tester, const BarcodeView('201781', showText: false));

    expect(find.byType(BarcodeWidget), findsOneWidget);
    expect(find.text('201781'), findsNothing);
  });

  testWidgets('an empty barcode draws nothing', (tester) async {
    await pump(tester, const BarcodeView('   '));

    expect(find.byType(BarcodeWidget), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
