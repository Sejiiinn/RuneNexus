part of '../run_progression.dart';

mixin _PermanentUpgradeProgression {
  abstract int runes;

  int startingGoldUpgradeLevel = 0;
  int nexusHpUpgradeLevel = 0;
  int supplyUpgradeLevel = 0;
  int fireTrainingUpgradeLevel = 0;
  int physicalDamageTrainingUpgradeLevel = 0;
  int elementalDamageTrainingUpgradeLevel = 0;
  int criticalChanceUpgradeLevel = 0;
  int criticalDamageUpgradeLevel = 0;
  int killGoldUpgradeLevel = 0;
  int emergencySaleUpgradeLevel = 0;

  int get initialGold =>
      RunProgression.baseInitialGold +
      _cappedStartingGoldUpgradeLevel *
          RunProgression.startingGoldPerUpgradeLevel;
  int get maxNexusHp => RunProgression.baseNexusHp + _cappedNexusHpUpgradeLevel;
  int get startingGoldUpgradeCost => RunProgression._hybridUpgradeCost(
    baseCost: RunProgression.startingGoldUpgradeBaseCost,
    costPerLevel: RunProgression.startingGoldUpgradeCostPerLevel,
    multiplier: RunProgression.startingGoldUpgradeCostMultiplier,
    level: _cappedStartingGoldUpgradeLevel,
  );
  int get nexusHpUpgradeCost => RunProgression._hybridUpgradeCost(
    baseCost: RunProgression.nexusHpUpgradeBaseCost,
    costPerLevel: RunProgression.nexusHpUpgradeCostPerLevel,
    multiplier: RunProgression.nexusHpUpgradeCostMultiplier,
    level: _cappedNexusHpUpgradeLevel,
  );
  int get supplyUpgradeCost => RunProgression._hybridUpgradeCost(
    baseCost: RunProgression.supplyUpgradeBaseCost,
    costPerLevel: RunProgression.supplyUpgradeCostPerLevel,
    multiplier: RunProgression.supplyUpgradeCostMultiplier,
    level: _cappedSupplyUpgradeLevel,
  );
  int get fireTrainingUpgradeCost => RunProgression._hybridUpgradeCost(
    baseCost: RunProgression.fireTrainingUpgradeBaseCost,
    costPerLevel: RunProgression.fireTrainingUpgradeCostPerLevel,
    multiplier: RunProgression.fireTrainingUpgradeCostMultiplier,
    level: _cappedFireTrainingUpgradeLevel,
  );
  int get physicalDamageTrainingUpgradeCost =>
      RunProgression._hybridUpgradeCost(
        baseCost: RunProgression.familyDamageTrainingUpgradeBaseCost,
        costPerLevel: RunProgression.familyDamageTrainingUpgradeCostPerLevel,
        multiplier: RunProgression.familyDamageTrainingUpgradeCostMultiplier,
        level: _cappedPhysicalDamageTrainingUpgradeLevel,
      );
  int get elementalDamageTrainingUpgradeCost =>
      RunProgression._hybridUpgradeCost(
        baseCost: RunProgression.familyDamageTrainingUpgradeBaseCost,
        costPerLevel: RunProgression.familyDamageTrainingUpgradeCostPerLevel,
        multiplier: RunProgression.familyDamageTrainingUpgradeCostMultiplier,
        level: _cappedElementalDamageTrainingUpgradeLevel,
      );
  int get criticalChanceUpgradeCost =>
      (RunProgression.criticalChanceUpgradeBaseCost *
              math.pow(
                RunProgression.criticalChanceUpgradeCostMultiplier,
                _cappedCriticalChanceUpgradeLevel,
              ))
          .round();
  int get criticalDamageUpgradeCost =>
      (RunProgression.criticalDamageUpgradeBaseCost *
              math.pow(
                RunProgression.criticalDamageUpgradeCostMultiplier,
                _cappedCriticalDamageUpgradeLevel,
              ))
          .round();
  int get killGoldUpgradeCost => RunProgression._hybridUpgradeCost(
    baseCost: RunProgression.killGoldUpgradeBaseCost,
    costPerLevel: RunProgression.killGoldUpgradeCostPerLevel,
    multiplier: RunProgression.killGoldUpgradeCostMultiplier,
    level: _cappedKillGoldUpgradeLevel,
  );
  int get emergencySaleUpgradeCost =>
      RunProgression.emergencySaleUpgradeCosts[math.min(
        _cappedEmergencySaleUpgradeLevel,
        RunProgression.emergencySaleUpgradeCosts.length - 1,
      )];
  int get waveClearGoldBonus =>
      _cappedSupplyUpgradeLevel * RunProgression.supplyGoldPerUpgradeLevel;
  double get fireTrainingDamageBonusRate =>
      _cappedFireTrainingUpgradeLevel *
      RunProgression.fireTrainingDamagePerUpgradeLevel;
  double get physicalDamageTrainingBonusRate =>
      _cappedPhysicalDamageTrainingUpgradeLevel *
      RunProgression.familyDamageTrainingBonusPerUpgradeLevel;
  double get elementalDamageTrainingBonusRate =>
      _cappedElementalDamageTrainingUpgradeLevel *
      RunProgression.familyDamageTrainingBonusPerUpgradeLevel;
  double get criticalChanceBonusRate =>
      _cappedCriticalChanceUpgradeLevel *
      RunProgression.criticalChanceBonusPerUpgradeLevel;
  double get criticalDamageBonusRate =>
      _cappedCriticalDamageUpgradeLevel *
      RunProgression.criticalDamageBonusPerUpgradeLevel;
  double get killGoldBonusRate =>
      _cappedKillGoldUpgradeLevel * RunProgression.killGoldBonusPerUpgradeLevel;
  int get turretRefundPercent =>
      RunProgression.baseTurretRefundPercent +
      _cappedEmergencySaleUpgradeLevel *
          RunProgression.emergencySaleRefundPercentPerLevel;

  bool get canUpgradeStartingGold =>
      _cappedStartingGoldUpgradeLevel <
          RunProgression.maxStartingGoldUpgradeLevel &&
      runes >= startingGoldUpgradeCost;
  bool get canUpgradeNexusHp =>
      _cappedNexusHpUpgradeLevel < RunProgression.maxNexusHpUpgradeLevel &&
      runes >= nexusHpUpgradeCost;
  bool get canUpgradeSupply =>
      _cappedSupplyUpgradeLevel < RunProgression.maxSupplyUpgradeLevel &&
      runes >= supplyUpgradeCost;
  bool get canUpgradeFireTraining =>
      _cappedFireTrainingUpgradeLevel <
          RunProgression.maxFireTrainingUpgradeLevel &&
      runes >= fireTrainingUpgradeCost;
  bool get canUpgradePhysicalDamageTraining =>
      _cappedPhysicalDamageTrainingUpgradeLevel <
          RunProgression.maxPhysicalDamageTrainingUpgradeLevel &&
      runes >= physicalDamageTrainingUpgradeCost;
  bool get canUpgradeElementalDamageTraining =>
      _cappedElementalDamageTrainingUpgradeLevel <
          RunProgression.maxElementalDamageTrainingUpgradeLevel &&
      runes >= elementalDamageTrainingUpgradeCost;
  bool get canUpgradeCriticalChance =>
      _cappedCriticalChanceUpgradeLevel <
          RunProgression.maxCriticalChanceUpgradeLevel &&
      runes >= criticalChanceUpgradeCost;
  bool get canUpgradeCriticalDamage =>
      _cappedCriticalDamageUpgradeLevel <
          RunProgression.maxCriticalDamageUpgradeLevel &&
      runes >= criticalDamageUpgradeCost;
  bool get canUpgradeKillGold =>
      _cappedKillGoldUpgradeLevel < RunProgression.maxKillGoldUpgradeLevel &&
      runes >= killGoldUpgradeCost;
  bool get canUpgradeEmergencySale =>
      _cappedEmergencySaleUpgradeLevel <
          RunProgression.maxEmergencySaleUpgradeLevel &&
      runes >= emergencySaleUpgradeCost;

  int get _cappedStartingGoldUpgradeLevel => startingGoldUpgradeLevel
      .clamp(0, RunProgression.maxStartingGoldUpgradeLevel)
      .toInt();
  int get _cappedNexusHpUpgradeLevel => nexusHpUpgradeLevel
      .clamp(0, RunProgression.maxNexusHpUpgradeLevel)
      .toInt();
  int get _cappedSupplyUpgradeLevel =>
      supplyUpgradeLevel.clamp(0, RunProgression.maxSupplyUpgradeLevel).toInt();
  int get _cappedFireTrainingUpgradeLevel => fireTrainingUpgradeLevel
      .clamp(0, RunProgression.maxFireTrainingUpgradeLevel)
      .toInt();
  int get _cappedPhysicalDamageTrainingUpgradeLevel =>
      physicalDamageTrainingUpgradeLevel
          .clamp(0, RunProgression.maxPhysicalDamageTrainingUpgradeLevel)
          .toInt();
  int get _cappedElementalDamageTrainingUpgradeLevel =>
      elementalDamageTrainingUpgradeLevel
          .clamp(0, RunProgression.maxElementalDamageTrainingUpgradeLevel)
          .toInt();
  int get _cappedCriticalChanceUpgradeLevel => criticalChanceUpgradeLevel
      .clamp(0, RunProgression.maxCriticalChanceUpgradeLevel)
      .toInt();
  int get _cappedCriticalDamageUpgradeLevel => criticalDamageUpgradeLevel
      .clamp(0, RunProgression.maxCriticalDamageUpgradeLevel)
      .toInt();
  int get _cappedKillGoldUpgradeLevel => killGoldUpgradeLevel
      .clamp(0, RunProgression.maxKillGoldUpgradeLevel)
      .toInt();
  int get _cappedEmergencySaleUpgradeLevel => emergencySaleUpgradeLevel
      .clamp(0, RunProgression.maxEmergencySaleUpgradeLevel)
      .toInt();

  bool upgradeStartingGold() {
    if (!canUpgradeStartingGold) {
      return false;
    }
    runes -= startingGoldUpgradeCost;
    startingGoldUpgradeLevel++;
    return true;
  }

  bool upgradeNexusHp() {
    if (!canUpgradeNexusHp) {
      return false;
    }
    runes -= nexusHpUpgradeCost;
    nexusHpUpgradeLevel++;
    return true;
  }

  bool upgradeSupply() {
    if (!canUpgradeSupply) {
      return false;
    }
    runes -= supplyUpgradeCost;
    supplyUpgradeLevel++;
    return true;
  }

  bool upgradeFireTraining() {
    if (!canUpgradeFireTraining) {
      return false;
    }
    runes -= fireTrainingUpgradeCost;
    fireTrainingUpgradeLevel++;
    return true;
  }

  bool upgradePhysicalDamageTraining() {
    if (!canUpgradePhysicalDamageTraining) {
      return false;
    }
    runes -= physicalDamageTrainingUpgradeCost;
    physicalDamageTrainingUpgradeLevel++;
    return true;
  }

  bool upgradeElementalDamageTraining() {
    if (!canUpgradeElementalDamageTraining) {
      return false;
    }
    runes -= elementalDamageTrainingUpgradeCost;
    elementalDamageTrainingUpgradeLevel++;
    return true;
  }

  bool upgradeCriticalChance() {
    if (!canUpgradeCriticalChance) {
      return false;
    }
    runes -= criticalChanceUpgradeCost;
    criticalChanceUpgradeLevel++;
    return true;
  }

  bool upgradeCriticalDamage() {
    if (!canUpgradeCriticalDamage) {
      return false;
    }
    runes -= criticalDamageUpgradeCost;
    criticalDamageUpgradeLevel++;
    return true;
  }

  bool upgradeKillGold() {
    if (!canUpgradeKillGold) {
      return false;
    }
    runes -= killGoldUpgradeCost;
    killGoldUpgradeLevel++;
    return true;
  }

  bool upgradeEmergencySale() {
    if (!canUpgradeEmergencySale) {
      return false;
    }
    runes -= emergencySaleUpgradeCost;
    emergencySaleUpgradeLevel++;
    return true;
  }
}
