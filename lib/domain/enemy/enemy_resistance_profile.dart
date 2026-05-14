import '../turret/attack_tag.dart';
import '../turret/damage_family.dart';

class EnemyResistanceProfile {
  const EnemyResistanceProfile({
    this.familyResistances = const {},
    this.tagResistances = const {},
  });

  static const neutral = EnemyResistanceProfile();
  static const maxResistance = 0.9;

  final Map<DamageFamily, double> familyResistances;
  final Map<AttackTag, double> tagResistances;

  double familyResistance(DamageFamily family) {
    return familyResistances[family] ?? 0;
  }

  double tagResistance(AttackTag tag) {
    return tagResistances[tag] ?? 0;
  }

  bool get hasResistance {
    return familyResistances.values.any((value) => value > 0) ||
        tagResistances.values.any((value) => value > 0);
  }

  bool get hasWeakness {
    return familyResistances.values.any((value) => value < 0) ||
        tagResistances.values.any((value) => value < 0);
  }

  double multiplierFor({
    required DamageFamily family,
    required Set<AttackTag> tags,
  }) {
    var multiplier = multiplierForResistance(familyResistance(family));
    for (final tag in tags) {
      multiplier *= multiplierForResistance(tagResistance(tag));
    }
    return multiplier;
  }

  static double multiplierForResistance(double resistance) {
    final cappedResistance = resistance > maxResistance
        ? maxResistance
        : resistance;
    return 1 - cappedResistance;
  }
}
