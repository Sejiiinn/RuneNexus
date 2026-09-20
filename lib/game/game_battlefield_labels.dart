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
      // Enemy labels come from the authoritative Godot actors.
      enemies: const [],
    );
  }
}
