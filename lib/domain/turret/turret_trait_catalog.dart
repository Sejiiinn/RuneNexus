import 'turret_trait_type.dart';
import 'turret_type.dart';

class TurretTraitSet {
  const TurretTraitSet({required this.primary, required this.secondary});

  final List<TurretTraitType> primary;
  final List<TurretTraitType> secondary;

  bool get hasChoices => primary.isNotEmpty || secondary.isNotEmpty;
}

const _emptyTurretTraitSet = TurretTraitSet(primary: [], secondary: []);

const turretTraitCatalog = <TurretType, TurretTraitSet>{
  TurretType.arrow: TurretTraitSet(
    primary: [
      TurretTraitType.overheatMagazine,
      TurretTraitType.lightweightBarrel,
    ],
    secondary: [TurretTraitType.suppressiveFire, TurretTraitType.chainCleanup],
  ),
  TurretType.cannon: TurretTraitSet(
    primary: [TurretTraitType.shrapnelShell, TurretTraitType.compressedCharge],
    secondary: [],
  ),
  TurretType.magic: TurretTraitSet(
    primary: [TurretTraitType.highHeatBurn, TurretTraitType.lingeringEmbers],
    secondary: [],
  ),
  TurretType.frost: TurretTraitSet(
    primary: [TurretTraitType.rapidCooling, TurretTraitType.spreadingChill],
    secondary: [TurretTraitType.frostCrack, TurretTraitType.coolingCycle],
  ),
};

TurretTraitSet turretTraitSetFor(TurretType type) {
  return turretTraitCatalog[type] ?? _emptyTurretTraitSet;
}
