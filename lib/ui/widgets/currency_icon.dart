import 'package:flutter/material.dart';

const String runeCurrencyIconAsset = 'assets/images/currency/currency_rune.png';
const String diamondCurrencyIconAsset =
    'assets/images/currency/currency_diamond.png';
const String goldCurrencyIconAsset = 'assets/images/currency/currency_gold.png';

class CurrencyAssetIcon extends StatelessWidget {
  const CurrencyAssetIcon({
    required this.asset,
    required this.size,
    this.opacity = 1,
    super.key,
  });

  const CurrencyAssetIcon.rune({required double size, double opacity = 1})
    : this(asset: runeCurrencyIconAsset, size: size, opacity: opacity);

  const CurrencyAssetIcon.diamond({required double size, double opacity = 1})
    : this(asset: diamondCurrencyIconAsset, size: size, opacity: opacity);

  const CurrencyAssetIcon.gold({required double size, double opacity = 1})
    : this(asset: goldCurrencyIconAsset, size: size, opacity: opacity);

  final String asset;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}
