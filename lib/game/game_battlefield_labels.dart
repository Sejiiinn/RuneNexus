part of 'rune_nexus_game.dart';

extension _BattlefieldLabelsPresentation on RuneNexusGame {
  BattlefieldLabels _buildBattlefieldLabels() {
    Offset grid(Vector2 point) => Offset(
      (point.x - _origin.x) / _tileSize,
      (point.y - _origin.y) / _tileSize,
    );
    BattlefieldCoreLabel? core;
    if (_phase == GamePhase.wave &&
        _worldPath.isNotEmpty &&
        nexusCoreBeamAvailable) {
      core = BattlefieldCoreLabel(
        position: grid(_nexusCorePosition()),
        progress: _coreCombatSkillController.cooldownProgress(
          cooldownRecoveryMultiplier:
              _coreCombatSkillCooldownRecoveryMultiplier,
        ),
        accent: _coreCombatSkillController.runSkill == CoreCombatSkill.riftMark
            ? RuneNexusGame._riftMarkColor
            : RuneNexusGame._nexusCoreBeamColor,
        active: nexusCoreBeamActive,
      );
    }
    return BattlefieldLabels(
      logicalTileSize: _tileSize,
      core: core,
      enemies: [
        for (final enemy in enemies)
          if (!enemy.isDead)
            _enemyLabel(
              enemy,
              grid(enemy.position),
              _battlefieldIds[enemy] ??= _nextBattlefieldId++,
            ),
      ],
    );
  }

  BattlefieldEnemyLabel _enemyLabel(
    EnemyComponent enemy,
    Offset position,
    int id,
  ) {
    final visual = enemy.visualRenderState;
    return BattlefieldEnemyLabel(
      id: id,
      position: position + visual.visualOffset / _tileSize,
      size: visual.size,
      hp: visual.hp,
      maxHp: visual.maxHp,
      armor: visual.armor,
      maxArmor: visual.maxArmor,
      shield: visual.shield,
      maxShield: visual.maxShield,
      effectTime: visual.effectTime,
      enemyCount: visual.enemyCount,
      burning: visual.isBurning,
      slowed: visual.isSlowed,
      poisoned: visual.isPoisoned,
      riftMarked: visual.hasRiftMark,
      diamondCarrier: visual.isDiamondCarrier,
    );
  }
}
