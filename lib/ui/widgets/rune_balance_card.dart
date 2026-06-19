import 'package:flutter/material.dart';

import 'currency_icon.dart';
import 'non_truncating_text.dart';

class RuneBalanceCard extends StatelessWidget {
  const RuneBalanceCard({
    required this.runes,
    this.diamonds = 0,
    this.compact = false,
    this.frameless = false,
    super.key,
  });

  final int runes;
  final int diamonds;
  final bool compact;
  final bool frameless;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        minWidth: compact ? 42 : 50,
        minHeight: compact ? 30 : 34,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 4 : 6,
        vertical: compact ? 4 : 6,
      ),
      decoration: frameless
          ? null
          : BoxDecoration(
              color: const Color(0xAA07111D),
              border: Border.all(color: const Color(0x88E7C66A)),
              borderRadius: BorderRadius.circular(7),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _CurrencyRow(
            iconAsset: diamondCurrencyIconAsset,
            value: diamonds,
            compact: compact,
          ),
          SizedBox(height: compact ? 2 : 3),
          _CurrencyRow(
            iconAsset: runeCurrencyIconAsset,
            value: runes,
            compact: compact,
          ),
        ],
      ),
    );
  }
}

class _CurrencyRow extends StatelessWidget {
  const _CurrencyRow({
    required this.iconAsset,
    required this.value,
    required this.compact,
  });

  final String iconAsset;
  final int value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 13.0 : 14.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        CurrencyAssetIcon(asset: iconAsset, size: iconSize),
        SizedBox(width: compact ? 3 : 5),
        SizedBox(
          width: compact ? 42 : 58,
          child: ScaleDownText(
            '$value',
            textAlign: TextAlign.right,
            alignment: Alignment.centerRight,
            style: TextStyle(
              fontSize: compact ? 13 : 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}
