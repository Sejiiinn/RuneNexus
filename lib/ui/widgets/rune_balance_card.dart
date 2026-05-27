import 'package:flutter/material.dart';

import 'non_truncating_text.dart';

class RuneBalanceCard extends StatelessWidget {
  const RuneBalanceCard({
    required this.runes,
    this.compact = false,
    this.frameless = false,
    super.key,
  });

  final int runes;
  final bool compact;
  final bool frameless;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        minWidth: compact ? 58 : 70,
        minHeight: compact ? 34 : 38,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 6 : 8,
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.diamond,
            size: compact ? 14 : 16,
            color: const Color(0xFFE7C66A),
          ),
          SizedBox(width: compact ? 5 : 7),
          Flexible(
            child: ScaleDownText(
              '$runes',
              style: TextStyle(
                fontSize: compact ? 13 : 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
