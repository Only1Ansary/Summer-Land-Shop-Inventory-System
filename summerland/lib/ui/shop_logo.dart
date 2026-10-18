import 'package:flutter/material.dart';

import '../services/shop_profile_service.dart';

/// Renders the shop's uploaded logo, or a default storefront icon when none
/// has been chosen. Rebuilds automatically when the logo changes.
class ShopLogo extends StatelessWidget {
  const ShopLogo({super.key, this.size = 44, this.radius = 10});

  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return ValueListenableBuilder<ShopProfile>(
      valueListenable: ShopProfileService.instance.profile,
      builder: (context, profile, _) {
        if (profile.hasLogo) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Image.memory(
              profile.logo!,
              fit: BoxFit.contain,
              alignment: Alignment.center,
              gaplessPlayback: true,
            ),
          );
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
