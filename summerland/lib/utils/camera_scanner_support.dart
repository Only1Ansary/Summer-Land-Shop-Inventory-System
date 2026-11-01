import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;

/// Whether the camera can be used to scan barcodes on this platform.
///
/// Camera scanning is only supported on Android. Windows (and the other
/// desktop targets) cannot open a camera for the scanner, so screens hide the
/// camera action there instead of offering a button that fails.
bool get supportsCameraBarcodeScanning =>
    defaultTargetPlatform == TargetPlatform.android;
