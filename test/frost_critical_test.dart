import 'package:flame/components.dart' show Component;
import 'package:rune_nexus/game/components/damage_number_component.dart';

import 'helpers/game_balance_test_helpers.dart';

class _FrostGame extends RuneNexusGame {
  _FrostGame() : super(saveRepository: MemorySaveRepository());

  final feedbackMultipliers = <double>[];

  @override
  bool get isWaveRunning => true;

  @override
  double get criticalDamageProgressionBonusRate => 0.15;

  @override
  Future<void> add(Component component) async {}

  @override
  void showDamageNumber({
    required Vector2 position,
    required double damage,
    required Color color,
    DamageNumberMotion motion = DamageNumberMotion.rise,
    double damageMultiplier = 1,
    Vector2? sourcePosition,
  }) => feedbackMultipliers.add(damageMultiplier);
}

class _FrostTurret extends TurretComponent {
  _FrostTurret(_FrostGame game, this.critical)
    : super(
        definition: gameTurrets[TurretType.frost]!,
        gridPoint: const GridPoint(0, 0),
        center: Vector2.zero(),
        tileSize: 48,
        game: game,
      );

  final bool critical;
  int rolls = 0;

  @override
  bool rollCriticalHit() {
    rolls++;
    return critical;
  }
}

EnemyComponent _enemy(_FrostGame game, double x) {
  final enemy = EnemyComponent(
    definition: gameEnemies[EnemyType.normal]!,
    maxHp: 1000,
    path: [Vector2(x, 0), Vector2(x + 500, 0)],
    game: game,
  );
  game.enemies.add(enemy);
  return enemy;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final critical in [false, true]) {
    test('frost attack shares one critical roll across targets: $critical', () {
      final game = _FrostGame();
      final turret = _FrostTurret(game, critical);
      final first = _enemy(game, 10);
      final second = _enemy(game, 20);
      final outside = _enemy(game, 10000);
      turret.update(0.01);

      final multiplier = critical ? 1.65 : 1.0;
      expect(turret.rolls, 1);
      for (final enemy in [first, second]) {
        expect(enemy.hp, closeTo(1000 - turret.damage * multiplier, 1e-8));
        expect(enemy.slowMultiplier, turret.slowMultiplier);
        expect(enemy.slowRemaining, turret.slowDuration);
      }
      expect(outside.hp, 1000);
      expect(game.feedbackMultipliers, [multiplier, multiplier]);
    });
  }

  test('centered area preserves supplied critical snapshot without reroll', () {
    final game = _FrostGame();
    final turret = _FrostTurret(game, false);
    final enemy = _enemy(game, 10);
    final attack = turret.createAttackSnapshot(criticalMultiplier: 1.8);
    game.resolveCenteredAreaAttack(
      owner: turret,
      attack: attack,
      targets: [enemy],
    );
    expect(turret.rolls, 0);
    expect(enemy.hp, closeTo(1000 - attack.damage * 1.8, 1e-8));
    expect(game.feedbackMultipliers, [1.8]);
  });

  test('centered area without a snapshot rolls critical once', () {
    final game = _FrostGame();
    final turret = _FrostTurret(game, true);
    final enemy = _enemy(game, 10);
    game.resolveCenteredAreaAttack(owner: turret, targets: [enemy]);
    expect(turret.rolls, 1);
    expect(enemy.hp, closeTo(1000 - turret.damage * 1.65, 1e-8));
  });
}
