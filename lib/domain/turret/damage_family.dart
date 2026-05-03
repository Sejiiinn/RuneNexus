import 'dart:ui';

enum DamageFamily { physical, magical }

extension DamageFamilyLabel on DamageFamily {
  String get label {
    return switch (this) {
      DamageFamily.physical => '물리',
      DamageFamily.magical => '마법',
    };
  }

  Color get color {
    return switch (this) {
      DamageFamily.physical => const Color(0xFFF4F7FA),
      DamageFamily.magical => const Color(0xFF64D8FF),
    };
  }
}
