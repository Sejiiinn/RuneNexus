import '../turret/attack_tag.dart';
import '../turret/damage_family.dart';

class EnemyResistanceProfile {
  const EnemyResistanceProfile({
    this.familyMultipliers = const {},
    this.tagMultipliers = const {},
  });

  static const neutral = EnemyResistanceProfile();
  static const minMultiplier = 0.35;
  static const maxMultiplier = 1.75;

  final Map<DamageFamily, double> familyMultipliers;
  final Map<AttackTag, double> tagMultipliers;

  double familyMultiplier(DamageFamily family) {
    return familyMultipliers[family] ?? 1;
  }

  double tagMultiplier(AttackTag tag) {
    return tagMultipliers[tag] ?? 1;
  }

  bool get hasResistance {
    return familyMultipliers.values.any((value) => value < 1) ||
        tagMultipliers.values.any((value) => value < 1);
  }

  bool get hasWeakness {
    return familyMultipliers.values.any((value) => value > 1) ||
        tagMultipliers.values.any((value) => value > 1);
  }

  double multiplierFor({
    required DamageFamily family,
    required Set<AttackTag> tags,
  }) {
    var multiplier = familyMultiplier(family);
    for (final tag in tags) {
      multiplier *= tagMultiplier(tag);
    }
    return multiplier.clamp(minMultiplier, maxMultiplier).toDouble();
  }
}
