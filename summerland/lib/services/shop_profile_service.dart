import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The shop's display name and optional logo, as shown on the brand header.
@immutable
class ShopProfile {
  const ShopProfile({required this.name, this.logo});

  static const String defaultName = 'Summerland';
  static const ShopProfile defaults = ShopProfile(name: defaultName);

  final String name;
  final Uint8List? logo;

  bool get hasLogo => logo != null && logo!.isNotEmpty;

  ShopProfile copyWith({
    String? name,
    Uint8List? logo,
    bool clearLogo = false,
  }) {
    return ShopProfile(
      name: name ?? this.name,
      logo: clearLogo ? null : (logo ?? this.logo),
    );
  }
}

/// Persists and broadcasts the shop name and logo.
///
/// Uses a shared [ValueNotifier] so the brand header (and anywhere else) can
/// rebuild as soon as the owner edits the details in Settings.
class ShopProfileService {
  ShopProfileService._();

  static final ShopProfileService instance = ShopProfileService._();

  static const String _nameKey = 'shop.name';
  static const String _logoKey = 'shop.logo';

  final ValueNotifier<ShopProfile> profile = ValueNotifier(
    ShopProfile.defaults,
  );

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final String rawName = prefs.getString(_nameKey)?.trim() ?? '';

    profile.value = ShopProfile(
      name: rawName.isEmpty ? ShopProfile.defaultName : rawName,
      logo: _decode(prefs.getString(_logoKey)),
    );
  }

  Future<void> setName(String name) async {
    final String trimmed = name.trim();

    profile.value = profile.value.copyWith(
      name: trimmed.isEmpty ? ShopProfile.defaultName : trimmed,
    );

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_nameKey, trimmed);
  }

  Future<void> setLogo(Uint8List? bytes) async {
    final prefs = await SharedPreferences.getInstance();

    if (bytes == null || bytes.isEmpty) {
      profile.value = profile.value.copyWith(clearLogo: true);
      await prefs.remove(_logoKey);
      return;
    }

    profile.value = profile.value.copyWith(logo: bytes);
    await prefs.setString(_logoKey, base64Encode(bytes));
  }

  static Uint8List? _decode(String? value) {
    if (value == null || value.isEmpty) return null;

    try {
      return base64Decode(value);
    } catch (_) {
      return null;
    }
  }
}
