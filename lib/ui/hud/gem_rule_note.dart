import 'package:flutter/material.dart';

import '../../domain/gem/gem_type.dart';

/// 젬의 추가 효과와 분리해 표시하는 공통 공격 규칙.
class HudGemRuleNote extends StatelessWidget {
  const HudGemRuleNote({required this.type, super.key});

  final GemType type;

  @override
  Widget build(BuildContext context) {
    final text = switch (type) {
      GemType.chain => '(연쇄된 투사체는 피해 및 효과 범위가 50% 감폭됩니다.)',
      GemType.explosion => '(폭발은 직접 명중한 대상을 제외한 주변 적에게 명중 피해의 50%를 줍니다.)',
      _ => null,
    };
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF939AA4),
          fontSize: 10,
          fontWeight: FontWeight.w400,
          height: 1.4,
        ),
      ),
    );
  }
}
