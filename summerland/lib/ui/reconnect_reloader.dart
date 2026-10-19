import 'package:flutter/widgets.dart';

import '../services/connectivity_service.dart';

/// Reloads a screen whenever the backend becomes reachable again.
///
/// Screens otherwise only load in `initState`, so data pulled while offline
/// would stay stale after the wifi/server comes back. Mixing this in wires
/// the screen's own loader to [ConnectivityService.reconnected], so the
/// newest data replaces the cached copy automatically.
///
/// The class using it must implement [onReconnected] - usually by calling
/// its existing `_load` method.
mixin ReconnectReloader<T extends StatefulWidget> on State<T> {
  /// Called once each time the server comes back. Runs only while mounted.
  void onReconnected();

  @override
  void initState() {
    super.initState();
    ConnectivityService.instance.reconnected.addListener(_handleReconnected);
  }

  @override
  void dispose() {
    ConnectivityService.instance.reconnected.removeListener(_handleReconnected);
    super.dispose();
  }

  void _handleReconnected() {
    if (!mounted) return;

    onReconnected();
  }
}
