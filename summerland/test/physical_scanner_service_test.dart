import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:summerland/services/physical_scanner_service.dart';

/// A clock the tests move by hand, so burst timing is deterministic.
class _Clock {
  DateTime now = DateTime(2026);

  void advance(Duration duration) => now = now.add(duration);
}

KeyDownEvent _character(String value) {
  return KeyDownEvent(
    physicalKey: PhysicalKeyboardKey.keyA,
    logicalKey: LogicalKeyboardKey.keyA,
    character: value,
    timeStamp: Duration.zero,
  );
}

const KeyDownEvent _enter = KeyDownEvent(
  physicalKey: PhysicalKeyboardKey.enter,
  logicalKey: LogicalKeyboardKey.enter,
  timeStamp: Duration.zero,
);

/// Types [barcode] at scanner speed, optionally ending with Enter.
void _scan(
  PhysicalScannerService service,
  _Clock clock,
  String barcode, {
  bool withEnter = true,
}) {
  for (final character in barcode.split('')) {
    service.handleKeyEvent(_character(character));
    clock.advance(const Duration(milliseconds: 6));
  }

  if (withEnter) service.handleKeyEvent(_enter);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Clock clock;
  late PhysicalScannerService service;
  late List<String> scans;

  setUp(() {
    clock = _Clock();
    service = PhysicalScannerService(clock: () => clock.now);
    service.attach(shouldCapture: () => true);

    scans = [];
    service.scans.listen(scans.add);
  });

  tearDown(() => service.detach());

  test('reports a fast burst finished with Enter', () async {
    _scan(service, clock, '6201100117017');

    await pumpEventQueue();

    expect(scans, ['6201100117017']);
    expect(service.isConnected, isTrue);
  });

  test('consumes the Enter that finishes a scan', () async {
    for (final character in '6201100117017'.split('')) {
      service.handleKeyEvent(_character(character));
      clock.advance(const Duration(milliseconds: 6));
    }

    expect(service.handleKeyEvent(_enter), isTrue);

    await pumpEventQueue();

    expect(scans, ['6201100117017']);
  });

  test('ignores typing at human speed', () async {
    for (final character in 'hello'.split('')) {
      service.handleKeyEvent(_character(character));
      clock.advance(const Duration(milliseconds: 120));
    }

    // Enter still belongs to the form when the burst was not a scan.
    expect(service.handleKeyEvent(_enter), isFalse);

    await pumpEventQueue();

    expect(scans, isEmpty);
    expect(service.isConnected, isFalse);
  });

  test('ignores bursts that are too short to be a barcode', () async {
    _scan(service, clock, '12');

    await pumpEventQueue();

    expect(scans, isEmpty);
    expect(service.isConnected, isFalse);
  });

  test('ignores input while capture is disabled', () async {
    service.detach();
    service.attach(shouldCapture: () => false);

    _scan(service, clock, '6201100117017');

    await pumpEventQueue();

    expect(scans, isEmpty);
    expect(service.isConnected, isFalse);
  });

  test('accepts a fast burst that has no Enter suffix', () async {
    _scan(service, clock, '6201100117017', withEnter: false);

    // Give the quiet-period timer time to fire.
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(scans, ['6201100117017']);
    expect(service.isConnected, isTrue);
  });

  testWidgets('removes the scanned characters from the focused field', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'old');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TextField(controller: controller)),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();

    final restoresValue = PhysicalScannerService(clock: () => clock.now);
    restoresValue.attach(shouldCapture: () => true);
    addTearDown(restoresValue.detach);

    final restoredScans = <String>[];
    restoresValue.scans.listen(restoredScans.add);

    // Mimic the platform inserting each character into the focused field.
    for (final character in '123456'.split('')) {
      restoresValue.handleKeyEvent(_character(character));
      controller.text += character;
      clock.advance(const Duration(milliseconds: 6));
    }

    expect(restoresValue.handleKeyEvent(_enter), isTrue);

    await tester.pump();

    expect(controller.text, 'old');
    expect(restoredScans, ['123456']);
  });
}
