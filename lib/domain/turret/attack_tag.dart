import 'dart:ui';

enum AttackTag { light, heavy, damageOverTime }

extension AttackTagLabel on AttackTag {
  String get label {
    return switch (this) {
      AttackTag.light => '경량화기',
      AttackTag.heavy => '중화기',
      AttackTag.damageOverTime => '지속피해',
    };
  }

  Color get color {
    return switch (this) {
      AttackTag.light => const Color(0xFFE7C66A),
      AttackTag.heavy => const Color(0xFFFF8A2A),
      AttackTag.damageOverTime => const Color(0xFF9DFF4A),
    };
  }
}
