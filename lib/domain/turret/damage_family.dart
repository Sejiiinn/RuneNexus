import 'dart:ui';

enum DamageFamily { physical, elemental }

extension DamageFamilyLabel on DamageFamily {
  String get label {
    return switch (this) {
      DamageFamily.physical => '물리',
      DamageFamily.elemental => '원소',
    };
  }

  Color get color {
    return switch (this) {
      DamageFamily.physical => const Color(0xFFF4F7FA),
      DamageFamily.elemental => const Color(0xFF9FFFE8),
    };
  }
}
