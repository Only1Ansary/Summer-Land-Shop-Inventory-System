import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';

/// Renders the numbers a product variant stores as a real, scannable
/// Code 128 barcode.
///
/// Entry is unchanged - the user still types the barcode as numbers -
/// but every stored value (manufacturer digits like `201781` or internal
/// codes like `SHOP-00000012`) is drawn as a proper 1D barcode that any
/// scanner or phone camera can read. Code 128 accepts digits of any
/// length, so no fixed-length format or check digit is required.
class BarcodeView extends StatelessWidget {
  const BarcodeView(
    this.code, {
    super.key,
    this.width = 200,
    this.height = 56,
    this.showText = true,
  });

  /// The stored barcode, e.g. `201781` or `SHOP-00000012`.
  final String code;

  final double width;

  final double height;

  /// Whether to repeat the barcode as text under the bars. Set to false
  /// where the screen already shows the barcode as text.
  final bool showText;

  @override
  Widget build(BuildContext context) {
    final trimmed = code.trim();

    if (trimmed.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        BarcodeWidget(
          barcode: Barcode.code128(),
          data: trimmed,
          width: width,
          height: height,
          drawText: false,
          color: Colors.black,
          backgroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          errorBuilder: (context, error) => Text(
            'Barcode could not be generated for $trimmed.',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
        if (showText) ...[
          const SizedBox(height: 4),
          Text(trimmed, style: const TextStyle(fontSize: 12, letterSpacing: 1)),
        ],
      ],
    );
  }
}
