import '../../domain/combat/game_phase.dart';
import '../../domain/gem/gem_equip_rules.dart';
import '../../domain/gem/gem_type.dart';
import '../../domain/map/grid_point.dart';
import '../../domain/turret/turret_trait_type.dart';
import '../components/enemy_component.dart';
import '../components/turret_component.dart';

class TurretActionController {
  const TurretActionController();

  TurretActionResult? selectGemSlot({
    required GridPoint? selectedPoint,
    required Map<GridPoint, TurretComponent> turrets,
    required int slotIndex,
    required int gold,
    required int gemShards,
    required GridPoint? levelUpPreviewPoint,
  }) {
    final turret = _selectedTurret(selectedPoint, turrets);
    if (turret == null || !turret.canEquipGemAt(slotIndex)) {
      return null;
    }
    return TurretActionResult(
      gold: gold,
      gemShards: gemShards,
      selectedTurretPoint: selectedPoint,
      selectedGemSlotIndex: slotIndex,
      levelUpPreviewPoint: levelUpPreviewPoint,
      saveImmediately: false,
    );
  }

  TurretActionResult? equipGem({
    required GamePhase phase,
    required GridPoint? selectedPoint,
    required int? selectedSlotIndex,
    required Map<GridPoint, TurretComponent> turrets,
    required Map<GemType, int> gemInventory,
    required GemType type,
    required int gold,
    required int gemShards,
    required GridPoint? levelUpPreviewPoint,
  }) {
    final canChangeGem =
        phase == GamePhase.preparation || phase == GamePhase.wave;
    if (!canChangeGem || (gemInventory[type] ?? 0) <= 0) {
      return null;
    }

    final turret = _selectedTurret(selectedPoint, turrets);
    if (turret == null) {
      return null;
    }

    final slotIndex = selectedSlotIndex == null
        ? _defaultGemSlotIndex(turret)
        : selectedSlotIndex.clamp(0, turret.slotLimit - 1).toInt();
    if (!canEquipGem(turret: turret, type: type, slotIndex: slotIndex)) {
      return null;
    }

    applyGemEquip(
      turret: turret,
      gemInventory: gemInventory,
      type: type,
      slotIndex: slotIndex,
    );

    return TurretActionResult(
      gold: gold,
      gemShards: gemShards,
      selectedTurretPoint: selectedPoint,
      selectedGemSlotIndex: slotIndex,
      levelUpPreviewPoint: levelUpPreviewPoint,
    );
  }

  bool canEquipGem({
    required TurretComponent turret,
    required GemType type,
    int? slotIndex,
  }) {
    return !turret.hasGem(type) &&
        canEquipGemOnTurret(type, turret.definition) &&
        (slotIndex == null || turret.canEquipGemAt(slotIndex));
  }

  // 장착 조건 확인·보상 지급 이후의 동기 교환. 저장과 화면 갱신은 호출자 책임.
  void applyGemEquip({
    required TurretComponent turret,
    required Map<GemType, int> gemInventory,
    required GemType type,
    required int slotIndex,
  }) {
    assert(canEquipGem(turret: turret, type: type, slotIndex: slotIndex));
    assert((gemInventory[type] ?? 0) > 0);
    final returnedGem = turret.equipGem(type, slotIndex);
    final remaining = gemInventory[type]! - 1;
    if (remaining <= 0) {
      gemInventory.remove(type);
    } else {
      gemInventory[type] = remaining;
    }
    if (returnedGem != null) {
      gemInventory[returnedGem] = (gemInventory[returnedGem] ?? 0) + 1;
    }
  }

  TurretActionResult? removeGem({
    required GamePhase phase,
    required GridPoint? selectedPoint,
    required int? selectedSlotIndex,
    required Map<GridPoint, TurretComponent> turrets,
    required Map<GemType, int> gemInventory,
    required int gold,
    required int gemShards,
    required GridPoint? levelUpPreviewPoint,
  }) {
    final canChangeGem =
        phase == GamePhase.preparation || phase == GamePhase.wave;
    if (!canChangeGem || selectedSlotIndex == null) {
      return null;
    }

    final turret = _selectedTurret(selectedPoint, turrets);
    if (turret == null) {
      return null;
    }

    final removedGem = turret.removeGemAt(selectedSlotIndex);
    if (removedGem == null) {
      return null;
    }

    gemInventory[removedGem] = (gemInventory[removedGem] ?? 0) + 1;
    return TurretActionResult(
      gold: gold,
      gemShards: gemShards,
      selectedTurretPoint: selectedPoint,
      selectedGemSlotIndex: selectedSlotIndex
          .clamp(0, turret.slotLimit - 1)
          .toInt(),
      levelUpPreviewPoint: levelUpPreviewPoint,
    );
  }

  TurretActionResult? levelUp({
    required bool canEditBoard,
    required GridPoint? selectedPoint,
    required Map<GridPoint, TurretComponent> turrets,
    required int gold,
    required int gemShards,
    required int? selectedGemSlotIndex,
    required GridPoint? levelUpPreviewPoint,
  }) {
    if (!canEditBoard) {
      return null;
    }

    final turret = _selectedTurret(selectedPoint, turrets);
    if (turret == null || !turret.canLevelUp || gold < turret.levelUpCost) {
      return null;
    }

    final levelUpCost = turret.levelUpCost;
    final nextGold = gold - levelUpCost;
    turret.upgradeLevel(paidGold: levelUpCost);
    final nextPreviewPoint =
        levelUpPreviewPoint == selectedPoint &&
            (!turret.canLevelUp || nextGold < turret.levelUpCost)
        ? null
        : levelUpPreviewPoint;

    return TurretActionResult(
      gold: nextGold,
      gemShards: gemShards,
      selectedTurretPoint: selectedPoint,
      selectedGemSlotIndex: selectedGemSlotIndex,
      levelUpPreviewPoint: nextPreviewPoint,
    );
  }

  TurretActionResult? previewOrLevelUp({
    required bool canEditBoard,
    required GridPoint? selectedPoint,
    required Map<GridPoint, TurretComponent> turrets,
    required int gold,
    required int gemShards,
    required int? selectedGemSlotIndex,
    required GridPoint? levelUpPreviewPoint,
  }) {
    if (!canEditBoard) {
      return null;
    }

    final turret = _selectedTurret(selectedPoint, turrets);
    if (turret == null || !turret.canLevelUp || gold < turret.levelUpCost) {
      return null;
    }

    if (levelUpPreviewPoint == selectedPoint) {
      return levelUp(
        canEditBoard: canEditBoard,
        selectedPoint: selectedPoint,
        turrets: turrets,
        gold: gold,
        gemShards: gemShards,
        selectedGemSlotIndex: selectedGemSlotIndex,
        levelUpPreviewPoint: levelUpPreviewPoint,
      );
    }

    return TurretActionResult(
      gold: gold,
      gemShards: gemShards,
      selectedTurretPoint: selectedPoint,
      selectedGemSlotIndex: selectedGemSlotIndex,
      levelUpPreviewPoint: selectedPoint,
      saveImmediately: false,
    );
  }

  TurretActionResult? upgradeLink({
    required GamePhase phase,
    required GridPoint? selectedPoint,
    required Map<GridPoint, TurretComponent> turrets,
    required int gold,
    required int gemShards,
    required GridPoint? levelUpPreviewPoint,
  }) {
    if (phase != GamePhase.preparation && phase != GamePhase.wave) {
      return null;
    }

    final turret = _selectedTurret(selectedPoint, turrets);
    if (turret == null ||
        !turret.canUpgradeLink ||
        gold < turret.linkUpgradeCost) {
      return null;
    }

    final linkUpgradeCost = turret.linkUpgradeCost;
    final nextGold = gold - linkUpgradeCost;
    turret.upgradeLink(paidGold: linkUpgradeCost);
    return TurretActionResult(
      gold: nextGold,
      gemShards: gemShards,
      selectedTurretPoint: selectedPoint,
      selectedGemSlotIndex: _defaultGemSlotIndex(turret),
      levelUpPreviewPoint: levelUpPreviewPoint,
    );
  }

  TurretActionResult? choosePrimaryTrait({
    required bool canEditBoard,
    required GridPoint? selectedPoint,
    required Map<GridPoint, TurretComponent> turrets,
    required int gold,
    required int gemShards,
    required int? selectedGemSlotIndex,
    required GridPoint? levelUpPreviewPoint,
    required int primaryTraitCost,
    required TurretTraitType trait,
  }) {
    if (!canEditBoard || gemShards < primaryTraitCost) {
      return null;
    }

    final turret = _selectedTurret(selectedPoint, turrets);
    if (turret == null ||
        !turret.canChoosePrimaryTrait ||
        !turret.choosePrimaryTrait(trait)) {
      return null;
    }

    return TurretActionResult(
      gold: gold,
      gemShards: gemShards - primaryTraitCost,
      selectedTurretPoint: selectedPoint,
      selectedGemSlotIndex: selectedGemSlotIndex,
      levelUpPreviewPoint: levelUpPreviewPoint,
    );
  }

  TurretActionResult? chooseSecondaryTrait({
    required bool canEditBoard,
    required GridPoint? selectedPoint,
    required Map<GridPoint, TurretComponent> turrets,
    required int gold,
    required int gemShards,
    required int? selectedGemSlotIndex,
    required GridPoint? levelUpPreviewPoint,
    required int secondaryTraitCost,
    required TurretTraitType trait,
  }) {
    if (!canEditBoard || gemShards < secondaryTraitCost) {
      return null;
    }

    final turret = _selectedTurret(selectedPoint, turrets);
    if (turret == null ||
        !turret.canChooseSecondaryTrait ||
        !turret.chooseSecondaryTrait(trait)) {
      return null;
    }

    return TurretActionResult(
      gold: gold,
      gemShards: gemShards - secondaryTraitCost,
      selectedTurretPoint: selectedPoint,
      selectedGemSlotIndex: selectedGemSlotIndex,
      levelUpPreviewPoint: levelUpPreviewPoint,
    );
  }

  TurretActionResult? refund({
    required bool canEditBoard,
    required GridPoint? selectedPoint,
    required Map<GridPoint, TurretComponent> turrets,
    required List<EnemyComponent> enemies,
    required Map<GemType, int> gemInventory,
    required int gold,
    required int gemShards,
    required GridPoint? levelUpPreviewPoint,
  }) {
    if (!canEditBoard) {
      return null;
    }

    final turret = _selectedTurret(selectedPoint, turrets);
    if (selectedPoint == null || turret == null) {
      return null;
    }

    for (final gem in turret.equippedGems) {
      gemInventory[gem] = (gemInventory[gem] ?? 0) + 1;
    }
    for (final enemy in enemies) {
      enemy.clearBurnSource(selectedPoint);
    }
    turrets.remove(selectedPoint);
    turret.removeFromParent();

    return TurretActionResult(
      gold: gold + turret.refundGold,
      gemShards: gemShards,
      selectedTurretPoint: null,
      selectedGemSlotIndex: null,
      levelUpPreviewPoint: levelUpPreviewPoint == selectedPoint
          ? null
          : levelUpPreviewPoint,
    );
  }

  TurretComponent? _selectedTurret(
    GridPoint? selectedPoint,
    Map<GridPoint, TurretComponent> turrets,
  ) {
    return selectedPoint == null ? null : turrets[selectedPoint];
  }

  int _defaultGemSlotIndex(TurretComponent turret) {
    final slots = turret.equippedGemSlots;
    for (var index = 0; index < turret.slotLimit; index++) {
      if (index >= slots.length || slots[index] == null) {
        return index;
      }
    }
    return 0;
  }
}

class TurretActionResult {
  const TurretActionResult({
    required this.gold,
    required this.gemShards,
    required this.selectedTurretPoint,
    required this.selectedGemSlotIndex,
    required this.levelUpPreviewPoint,
    this.saveImmediately = true,
  });

  final int gold;
  final int gemShards;
  final GridPoint? selectedTurretPoint;
  final int? selectedGemSlotIndex;
  final GridPoint? levelUpPreviewPoint;
  final bool saveImmediately;
}
