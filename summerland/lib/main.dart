import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/home_screen.dart';
import 'ui/app_theme.dart';

void main() {
  runApp(const SummerlandApp());
}

class SummerlandApp extends StatelessWidget {
  const SummerlandApp({super.key, this.navigatorKey});

  static final GlobalKey<NavigatorState> _defaultNavigatorKey =
      GlobalKey<NavigatorState>();

  final GlobalKey<NavigatorState>? navigatorKey;

  GlobalKey<NavigatorState> get _effectiveNavigatorKey =>
      navigatorKey ?? _defaultNavigatorKey;

  @override
  Widget build(BuildContext context) {
    final key = _effectiveNavigatorKey;

    return MaterialApp(
      title: 'Summerland',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      navigatorKey: key,
      home: const HomeScreen(),
      builder: (context, child) => BackspaceBackShortcuts(
        navigatorKey: key,
        child: child!,
      ),
    );
  }
}

/// Lets the Backspace key go back to the previous screen.
///
/// Deliberately uses a raw [HardwareKeyboard] handler instead of shortcuts:
/// while a text field has focus (an [EditableText] holds the primary focus)
/// the handler returns [KeyEventResult.ignored] so the key still deletes
/// characters, and only otherwise pops back to the previous screen.
class BackspaceBackShortcuts extends StatefulWidget {
  const BackspaceBackShortcuts({
    super.key,
    required this.navigatorKey,
    required this.child,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  State<BackspaceBackShortcuts> createState() =>
      _BackspaceBackShortcutsState();
}

class _BackspaceBackShortcutsState extends State<BackspaceBackShortcuts> {
  KeyEventCallback? _handler;

  @override
  void initState() {
    super.initState();

    _handler = _handleKeyEvent;
    HardwareKeyboard.instance.addHandler(_handler!);
  }

  @override
  void dispose() {
    final handler = _handler;

    if (handler != null) {
      HardwareKeyboard.instance.removeHandler(handler);
    }

    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return false;
    }

    if (event.logicalKey != LogicalKeyboardKey.backspace) {
      return false;
    }

    // While the user is editing any input field, leave the key alone so it
    // deletes characters; never navigate in that case.
    if (isTextEditingFocused()) {
      return false;
    }

    final navigator = widget.navigatorKey.currentState;

    if (navigator == null) {
      return false;
    }

    navigator.maybePop();

    return true;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Whether the primary focus currently sits inside a text input field.
bool isTextEditingFocused() {
  final context = FocusManager.instance.primaryFocus?.context;

  if (context == null) return false;

  return context.findAncestorWidgetOfExactType<EditableText>() != null;
}