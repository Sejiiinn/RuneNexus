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
    if (turret == null ||
        turret.equippedGems.contains(type) ||
        !canEquipGemOnTurret(type, turret.definition)) {
      return null;
    }

    final slotIndex = selectedSlotIndex == null
        ? _defaultGemSlotIndex(turret)
        : selectedSlotIndex.clamp(0, turret.slotLimit - 1).toInt();
    final isOccupied =
        slotIndex < turret.equippedGemSlots.length &&
        turret.equippedGemSlots[slotIndex] != null;
    if (!turret.canEquipGemAt(slotIndex) ||
        (phase == GamePhase.wave && isOccupied)) {
      return null;
    }

    final returnedGem = turret.equipGem(type, slotIndex);
    gemInventory[type] = (gemInventory[type] ?? 0) - 1;
    if ((gemInventory[type] ?? 0) <= 0) {
      gemInventory.remove(type);
    }
    if (returnedGem != null) {
      gemInventory[returnedGem] = (gemInventory[returnedGem] ?? 0) + 1;
    }

    return TurretActionResult(
      gold: gold,
      gemShards: gemShards,
      selectedTurretPoint: selectedPoint,
      selectedGemSlotIndex: slotIndex,
      levelUpPreviewPoint: levelUpPreviewPoint,
    );
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
    if (phase != GamePhase.preparation || selectedSlotIndex == null) {
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

    final nextGold = gold - turret.levelUpCost;
    turret.upgradeLevel();
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

    final nextGold = gold - turret.linkUpgradeCost;
    turret.upgradeLink();
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
