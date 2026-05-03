import '../turret/attack_tag.dart';
import '../turret/turret_definition.dart';
import 'gem_type.dart';

bool canEquipGemOnTurret(GemType type, TurretDefinition turret) {
  return gemEquipBlockReason(type, turret) == null;
}

String? gemEquipBlockReason(GemType type, TurretDefinition turret) {
  if (type == GemType.chain && turret.attackTags.contains(AttackTag.heavy)) {
    return '중화기 포탑에는 장착 불가';
  }
  return null;
}
