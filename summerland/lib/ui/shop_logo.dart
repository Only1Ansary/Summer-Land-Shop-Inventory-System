import 'package:flutter/material.dart';

import '../services/shop_profile_service.dart';

/// Renders the shop's uploaded logo, or a default storefront icon when none
/// has been chosen. Rebuilds automatically when the logo changes.
class ShopLogo extends StatelessWidget {
  const ShopLogo({
    super.key,
    this.size = 44,
    this.radius = 10,
    this.constrain = true,
  });

  final double size;
  final double radius;

  /// When true the logo is boxed into a [size] x [size] area (aspect ratio is
  /// preserved with [BoxFit.contain], so it never stretches). Set to false
  /// where the parent already provides sensible bounds, e.g. the nav header.
  final bool constrain;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return ValueListenableBuilder<ShopProfile>(
      valueListenable: ShopProfileService.instance.profile,
      builder: (context, profile, _) {
        if (profile.hasLogo) {
          final Widget image = ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Image.memory(
              profile.logo!,
              fit: BoxFit.contain,
              alignment: Alignment.center,
              gaplessPlayback: true,
            ),
          );

          if (!constrain) return image;

          // Box it so a big logo can never overflow a list tile or chip.
          return SizedBox(width: size, height: size, child: image);
        }

        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Icon(
            Icons.storefront_rounded,
            color: scheme.onPrimary,
            size: size * 0.5,
          ),
        );
      },
    );
  }
}
