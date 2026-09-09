import 'helpers/game_balance_test_helpers.dart';

class _SlowModuleGame extends RuneNexusGame {
  _SlowModuleGame(this.bonus);
  final double bonus;

  @override
  TurretModuleEffect turretModuleEffectFor(TurretType type) =>
      TurretModuleEffect(slowStrengthBonusRate: bonus);
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
    'frost slow grows from 12 to 30 percent with matching attack snapshots',
    () {
      final turret = _frost(RuneNexusGame());
      for (var level = 1; level <= 10; level++) {
        final expected = 0.88 - (level - 1) * 0.02;
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
    // 7레벨 24% + 특성 8%p + 모듈 5%p = 37%
    expect(turret.slowMultiplier, closeTo(0.63, 1e-8));
    for (var level = 7; level < 10; level++) {
      turret.upgradeLevel();
    }
    expect(turret.slowMultiplier, closeTo(0.57, 1e-8));
    expect(turret.slowDuration, 1);
  });

  test('combined slow bonuses preserve the 90 percent slow cap', () {
    final turret = _frost(_SlowModuleGame(1));
    expect(turret.slowMultiplier, 0.1);
    expect(turret.slowMultiplierAtLevel(10), 0.1);
  });
}
