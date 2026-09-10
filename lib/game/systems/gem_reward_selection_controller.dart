import '../../domain/combat/game_phase.dart';
import '../../domain/gem/gem_reward_target_status.dart';
import '../../domain/gem/gem_type.dart';
import '../../domain/map/grid_point.dart';
import '../components/turret_component.dart';
import 'gem_reward_controller.dart';
import 'turret_action_controller.dart';

/// 저장하지 않는 보상 선택 상태와 지급·장착의 동기 확정.
class GemRewardSelectionController {
  GemRewardSelectionController({
    required GemRewardController rewards,
    required TurretActionController turretActions,
  }) : _rewards = rewards,
       _turretActions = turretActions;

  final GemRewardController _rewards;
  final TurretActionController _turretActions;
  GemType? _pendingGem;
  GridPoint? _replacementPoint;

  GemType? get pendingGem => _pendingGem;
  GridPoint? get replacementPoint => _replacementPoint;

  bool preview({
    required GamePhase phase,
    required List<GemType> rewardOptions,
    required GemType type,
  }) {
    if (phase != GamePhase.reward || !rewardOptions.contains(type)) {
      return false;
    }
    _pendingGem = type;
    _replacementPoint = null;
    return true;
  }

  void clear() {
    _pendingGem = null;
    _replacementPoint = null;
  }

  GemRewardTargetStatus targetStatus({
    required GamePhase phase,
    required TurretComponent? turret,
  }) {
    final type = _pendingGem;
    if (phase != GamePhase.reward ||
        type == null ||
        turret == null ||
        !_turretActions.canEquipGem(turret: turret, type: type)) {
      return GemRewardTargetStatus.unavailable;
    }
    return turret.equippedGemSlots.any((gem) => gem == null)
        ? GemRewardTargetStatus.available
        : GemRewardTargetStatus.replacement;
  }

  GemRewardTargetStatus selectTarget({
    required GamePhase phase,
    required TurretComponent? turret,
  }) {
    if (_replacementPoint != null) {
      return GemRewardTargetStatus.unavailable;
    }
    final status = targetStatus(phase: phase, turret: turret);
    if (status == GemRewardTargetStatus.replacement) {
      _replacementPoint = turret!.gridPoint;
    }
    return status;
  }

  bool cancelReplacement({required GamePhase phase}) {
    if (phase != GamePhase.reward ||
        _pendingGem == null ||
        _replacementPoint == null) {
      return false;
    }
    _replacementPoint = null;
    return true;
  }

  bool confirm({
    required GamePhase phase,
    required List<GemType> rewardOptions,
    required Map<GemType, int> gemInventory,
    required Map<GridPoint, TurretComponent> turrets,
    required GemType type,
    TurretComponent? turret,
    int? slotIndex,
  }) {
    if (turret != null &&
        (slotIndex == null ||
            !_turretActions.canEquipGem(
              turret: turret,
              type: type,
              slotIndex: slotIndex,
            ) ||
            turrets[turret.gridPoint] != turret)) {
      return false;
    }
    if (!_rewards.selectRewardGem(
      phase: phase,
      rewardOptions: rewardOptions,
      gemInventory: gemInventory,
      type: type,
    )) {
      return false;
    }
    // 지급·장착·기존 젬 반환 사이에는 저장이나 화면 갱신이 끼지 않음.
    if (turret != null) {
      _turretActions.applyGemEquip(
        turret: turret,
        gemInventory: gemInventory,
        type: type,
        slotIndex: slotIndex!,
      );
    }
    return true;
  }
}
