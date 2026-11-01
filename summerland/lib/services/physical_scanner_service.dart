import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Reads barcodes from physical scanners that connect as keyboards (HID).
///
/// A keyboard-wedge scanner "types" the barcode far faster than a person can,
/// then usually presses Enter or Tab to finish. This service watches the
/// hardware key stream while a screen attaches it, groups those fast bursts
/// and emits the value on [scans]. Slow, human typing never becomes a scan.
///
/// It is not possible to ask the operating system whether such a scanner is
/// plugged in, so [isConnected] means "a scanner has already been seen in this
/// app session". It turns true on the first accepted scan and stays true, which
/// lets a screen show the user that a scanner is working.
///
/// The service deliberately does not swallow the scanned characters: they go
/// to whatever field has focus like normal typing, and the field's previous
/// value is restored right before the scan is emitted. That keeps the keyboard
/// usable for typing and still lets a scan arrive while a text field is
/// focused.
class PhysicalScannerService extends ChangeNotifier {
  PhysicalScannerService({DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  /// The app-wide instance used by the sale screen.
  static final PhysicalScannerService instance = PhysicalScannerService();

  /// Two characters further apart than this belong to different bursts.
  static const Duration _maxCharacterGap = Duration(milliseconds: 40);

  /// How long to wait after the last character before a burst without an
  /// Enter/Tab terminator can be accepted.
  static const Duration _settleDelay = Duration(milliseconds: 120);

  /// Shorter values are far more likely to be a stray key press than a
  /// barcode; internal barcodes in the app are much longer than this.
  static const int _minLength = 4;

  /// Guards against a stuck key filling the buffer forever.
  static const int _maxLength = 128;

  final DateTime Function() _now;
  final StreamController<String> _scans = StreamController<String>.broadcast();

  final StringBuffer _buffer = StringBuffer();
  DateTime? _burstStartedAt;
  DateTime? _lastCharacterAt;
  Timer? _settleTimer;

  KeyEventCallback? _handler;
  bool Function()? _shouldCapture;

  TextEditingController? _focusedController;
  TextEditingValue? _focusedValue;

  bool _isConnected = false;

  /// Whether a physical scanner has already been seen in this session.
  bool get isConnected => _isConnected;

  /// Barcodes read from the physical scanner.
  Stream<String> get scans => _scans.stream;

  /// Starts listening for scanner keystrokes.
  ///
  /// [shouldCapture] is consulted for every key event so the owning screen can
  /// ignore input while it is covered by another route (for example a dialog
  /// or the camera scanner).
  void attach({required bool Function() shouldCapture}) {
    detach();

    _shouldCapture = shouldCapture;
    _handler = _handleKeyEvent;
    HardwareKeyboard.instance.addHandler(_handler!);
  }

  /// Stops listening. Safe to call even when [attach] was never called.
  void detach() {
    final handler = _handler;

    if (handler != null) {
      HardwareKeyboard.instance.removeHandler(handler);
    }

    _handler = null;
    _shouldCapture = null;
    _discardBurst();
  }

  /// Clears the remembered connection state. Intended for tests.
  @visibleForTesting
  void resetForTest() {
    _isConnected = false;
    _discardBurst();
  }

  /// Processes one hardware key event. Public for tests; normally called by
  /// [HardwareKeyboard].
  @visibleForTesting
  bool handleKeyEvent(KeyEvent event) => _handleKeyEvent(event);

  bool _handleKeyEvent(KeyEvent event) {
    // Repeats are ignored: a held-down key produces them and would otherwise
    // look like a very fast burst.
    if (event is! KeyDownEvent) return false;

    if (_shouldCapture?.call() != true) {
      _discardBurst();
      return false;
    }

    // Enter and Tab finish a scan. They are only swallowed when the buffered
    // characters really look like a scan, so a person submitting a form keeps
    // the normal behaviour.
    if (_isTerminator(event.logicalKey)) {
      return _finishBurst();
    }

    final character = _characterFor(event);
    if (character == null) return false;

    _addCharacter(character);
    return false;
  }

  static bool _isTerminator(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.tab;
  }

  /// The character a key produces, falling back to its label on platforms
  /// that do not fill in [KeyEvent.character].
  static String? _characterFor(KeyEvent event) {
    final character = event.character;

    if (character != null && character.isNotEmpty) {
      final first = character.codeUnitAt(0);

      return first < 0x20 ? null : character;
    }

    final label = event.logicalKey.keyLabel;

    if (label.length == 1 && label.codeUnitAt(0) >= 0x20) return label;

    return null;
  }

  void _addCharacter(String character) {
    final now = _now();
    final last = _lastCharacterAt;

    if (last != null && now.difference(last) > _maxCharacterGap) {
      // Too slow to be the same scan. Whatever was buffered was typed by a
      // person and must stay in the field.
      _discardBurst();
    }

    if (_buffer.isEmpty) {
      _burstStartedAt = now;
      _captureFocusedValue();
    }

    _buffer.write(character);
    _lastCharacterAt = now;

    if (_buffer.length > _maxLength) {
      _discardBurst();
      return;
    }

    // Some scanners are configured without a suffix; accept the burst after a
    // short quiet period.
    _settleTimer?.cancel();
    _settleTimer = Timer(_settleDelay, _settleBurst);
  }

  void _settleBurst() {
    _settleTimer = null;

    // A dialog or another route may have opened while the burst was arriving.
    if (_shouldCapture?.call() != true) {
      _discardBurst();
      return;
    }

    // Without a terminator be stricter, so fast human typing is not mistaken
    // for a scan.
    if (!_looksLikeScan(maxGap: _maxCharacterGap ~/ 2)) {
      _discardBurst();
      return;
    }

    _commitBurst();
  }

  /// Handles Enter/Tab. Returns true when the event was consumed as the end of
  /// a scan.
  bool _finishBurst() {
    _settleTimer?.cancel();
    _settleTimer = null;

    if (!_looksLikeScan(maxGap: _maxCharacterGap)) {
      _discardBurst();
      return false;
    }

    _commitBurst();
    return true;
  }

  bool _looksLikeScan({required Duration maxGap}) {
    if (_buffer.length < _minLength) return false;

    final start = _burstStartedAt;
    final last = _lastCharacterAt;

    if (start == null || last == null) return false;

    return last.difference(start) <= maxGap * (_buffer.length - 1);
  }

  void _commitBurst() {
    final value = _buffer.toString().trim();
    final controller = _focusedController;
    final previous = _focusedValue;

    _discardBurst();

    if (value.length < _minLength) return;

    // Undo the characters the scanner typed into the focused field, so they do
    // not pile up in a search box or a quantity field.
    if (controller != null && previous != null) {
      controller.value = previous;
    }

    if (!_isConnected) {
      _isConnected = true;
      notifyListeners();
    }

    _scans.add(value);
  }

  /// Remembers what the focused text field contained before the burst, so the
  /// scanner's characters can be removed afterwards.
  void _captureFocusedValue() {
    _focusedController = null;
    _focusedValue = null;

    final focusContext = FocusManager.instance.primaryFocus?.context;

    if (focusContext == null) return;

    final editable = focusContext.findAncestorWidgetOfExactType<EditableText>();

    if (editable == null) return;

    _focusedController = editable.controller;
    _focusedValue = editable.controller.value;
  }

  void _discardBurst() {
    _settleTimer?.cancel();
    _settleTimer = null;
    _buffer.clear();
    _burstStartedAt = null;
    _lastCharacterAt = null;
    _focusedController = null;
    _focusedValue = null;
  }
}
