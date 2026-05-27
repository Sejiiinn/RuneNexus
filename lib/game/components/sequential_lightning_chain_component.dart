import 'package:flame/components.dart';

import '../rune_nexus_game.dart';
import 'enemy_component.dart';
import 'turret_component.dart';

class SequentialLightningChainComponent extends Component {
  SequentialLightningChainComponent({
    required this.owner,
    required this.attack,
    required EnemyComponent source,
    required Set<EnemyComponent> excluded,
    required this.game,
    required this.maxJumps,
    this.jumpDelay = 0.07,
  }) : _sourcePosition = source.position.clone(),
       _timer = jumpDelay,
       _excluded = {...excluded};

  final TurretComponent owner;
  final TurretAttackSnapshot attack;
  final RuneNexusGame game;
  final int maxJumps;
  final double jumpDelay;
  final Set<EnemyComponent> _excluded;
  Vector2 _sourcePosition;
  double _timer;
  int _usedJumps = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _timer -= dt;
    if (_timer > 0) {
      return;
    }

    final target = game.nextLightningChainTarget(
      sourcePosition: _sourcePosition,
      excluded: _excluded,
      attack: attack,
    );
    if (target == null) {
      owner.recordLightningChainCompletion(
        usedJumps: _usedJumps,
        maxJumps: maxJumps,
      );
      removeFromParent();
      return;
    }

    final hitPosition = target.position.clone();
    game.resolveLightningChainJump(
      owner: owner,
      attack: attack,
      sourcePosition: _sourcePosition,
      target: target,
    );
    _excluded.add(target);
    _sourcePosition = hitPosition;
    _usedJumps++;

    if (_usedJumps >= maxJumps) {
      owner.recordLightningChainCompletion(
        usedJumps: _usedJumps,
        maxJumps: maxJumps,
      );
      removeFromParent();
      return;
    }

    _timer += jumpDelay;
  }
}
