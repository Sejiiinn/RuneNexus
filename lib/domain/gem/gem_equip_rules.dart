import '../turret/attack_tag.dart';
import '../turret/turret_definition.dart';
import '../turret/turret_type.dart';
import 'gem_type.dart';

bool canEquipGemOnTurret(GemType type, TurretDefinition turret) {
  return gemEquipBlockReason(type, turret) == null;
}

String? gemEquipBlockReason(GemType type, TurretDefinition turret) {
  if (type == GemType.chain &&
      turret.attackTags.contains(AttackTag.heavy) &&
      turret.type != TurretType.lightning) {
    return '중화기 포탑에는 장착 불가';
  }
  if (type == GemType.aimSpeed &&
      (!turret.instantHit || turret.aimDuration <= 0)) {
    return '조준 속도 적용 포탑에만 장착 가능';
  }
  return null;
}
