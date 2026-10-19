import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/home_screen.dart';
import 'services/cache_store.dart';
import 'services/connectivity_service.dart';
import 'services/prefetch_service.dart';
import 'services/shop_profile_service.dart';
import 'services/theme_service.dart';
import 'ui/app_theme.dart';
import 'utils/api_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiConfig.load();
  await CacheStore.instance.load();
  ThemeService.instance.load();
  ShopProfileService.instance.load();
  ConnectivityService.instance.start();
  PrefetchService.instance.start();

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

    return AnimatedBuilder(
      animation: Listenable.merge([
        ThemeService.instance.mode,
        ShopProfileService.instance.profile,
      ]),
      builder: (context, _) => MaterialApp(
        title: ShopProfileService.instance.profile.value.name,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeService.instance.mode.value,
        navigatorKey: key,
        home: const HomeScreen(),
        builder: (context, child) =>
            BackspaceBackShortcuts(navigatorKey: key, child: child!),
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
  State<BackspaceBackShortcuts> createState() => _BackspaceBackShortcutsState();
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
