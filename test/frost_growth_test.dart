import 'helpers/game_balance_test_helpers.dart';

class _SlowModuleGame extends RuneNexusGame {
  _SlowModuleGame(this.bonus, {this.durationBonus = 0});
  final double durationBonus;
  final double bonus;

  @override
  TurretModuleEffect turretModuleEffectFor(TurretType type) =>
      TurretModuleEffect(
        slowStrengthBonusRate: bonus,
        slowDurationIncreaseRate: durationBonus,
      );
}

TurretComponent _frost(RuneNexusGame game) => TurretComponent(
  definition: gameTurrets[TurretType.frost]!,
  gridPoint: const GridPoint(0, 0),
  center: Vector2.zero(),
  tileSize: 48,
  game: game,
);

void main() {
  test(
    'frost slow grows from 20 to 38 percent with matching attack snapshots',
    () {
      final turret = _frost(RuneNexusGame());
      for (var level = 1; level <= 10; level++) {
        final expected = 0.8 - (level - 1) * 0.02;
        expect(turret.level, level);
        expect(turret.slowMultiplier, closeTo(expected, 1e-8));
        expect(
          turret.createAttackSnapshot().slowMultiplier,
          closeTo(expected, 1e-8),
        );
        expect(turret.slowDuration, 1);
        if (level < 10) {
          final preview = turret.slowMultiplierAtLevel(level + 1);
          turret.upgradeLevel();
          expect(turret.slowMultiplier, preview);
        }
      }
      expect(turret.slowMultiplierAtLevel(11), turret.slowMultiplier);
    },
  );

  test('rapid cooling and module add percentage points after level growth', () {
    final turret = _frost(_SlowModuleGame(0.05));
    for (var level = 1; level < 7; level++) {
      turret.upgradeLevel();
    }
    turret.choosePrimaryTrait(TurretTraitType.spreadingChill);
    expect(turret.chooseSecondaryTrait(TurretTraitType.rapidCooling), isTrue);
    // 7레벨 32% + 특성 8%p + 모듈 5%p = 45%
    expect(turret.slowMultiplier, closeTo(0.55, 1e-8));
    for (var level = 7; level < 10; level++) {
      turret.upgradeLevel();
    }
    expect(turret.slowMultiplier, closeTo(0.49, 1e-8));
    expect(turret.slowDuration, 1);
  });

  test('level ten with rapid cooling and max unique reaches 54 percent', () {
    final turret = _frost(_SlowModuleGame(0.08, durationBonus: 0.34));
    for (var level = 1; level < 10; level++) {
      turret.upgradeLevel();
    }
    turret.choosePrimaryTrait(TurretTraitType.spreadingChill);
    turret.chooseSecondaryTrait(TurretTraitType.rapidCooling);
    expect(turret.slowMultiplier, closeTo(0.46, 1e-8));
    expect(turret.slowDuration, closeTo(1.34, 1e-8));
  });

  test('combined slow bonuses preserve the 90 percent slow cap', () {
    final turret = _frost(_SlowModuleGame(1));
    expect(turret.slowMultiplier, 0.1);
    expect(turret.slowMultiplierAtLevel(10), 0.1);
  });
}
