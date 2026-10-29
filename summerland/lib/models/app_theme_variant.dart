import 'package:flutter/material.dart';

/// The selectable colour palettes for the app.
///
/// Each variant only supplies the seed colour; [AppTheme] builds the full
/// Material 3 scheme (and any surface overrides) from it.
enum AppThemeVariant {
  classic('Classic', Color(0xFF00275B)),
  emeraldDepth('Emerald Depth', Color(0xFF0B6B4F));

  const AppThemeVariant(this.label, this.seed);

  /// English display name, also used as the localization key.
  final String label;

  /// Seed colour used to build the Material 3 colour scheme.
  final Color seed;
}
