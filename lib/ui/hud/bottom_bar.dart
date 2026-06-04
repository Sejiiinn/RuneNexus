import 'package:flutter/material.dart';

import '../../domain/combat/auto_start_mode.dart';
import '../../domain/combat/game_phase.dart';
import '../../domain/combat/run_panel_tab.dart';
import '../../game/game_snapshot.dart';
import '../../game/rune_nexus_game.dart';
import '../game/game_ui.dart';
import 'build_selection_panel.dart';
import 'core_info_panel.dart';
import 'gem_equip_panel.dart';
import 'gem_inventory_panel.dart';
import 'portal_summary_panel.dart';
import 'run_upgrade_panel.dart';

class HudBottomBar extends StatelessWidget {
  const HudBottomBar({required this.game, required this.snapshot, super.key});

  final RuneNexusGame game;
  final GameSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final canPrepare = snapshot.phase == GamePhase.preparation;
    final canEditBoard =
        snapshot.phase == GamePhase.preparation ||
        snapshot.phase == GamePhase.wave;
    final statusText = switch (snapshot.phase) {
      GamePhase.preparation => '다음 웨이브',
      GamePhase.wave => '전투 진행 중',
      GamePhase.reward => '젬 보상 선택 대기',
      GamePhase.success => '방어 성공',
      GamePhase.failure => '방어 실패',
      GamePhase.restored => '저장된 진행 대기',
    };

    return Align(
      alignment: Alignment.bottomCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 12, right: 12),
            child: GamePanel(
              padding: const EdgeInsets.all(10),
              accentColor: GamePalette.cyan,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      _BottomSpeedControl(snapshot: snapshot, game: game),
                      const Spacer(),
                      _AutoStartModeButton(game: game, snapshot: snapshot),
                      const SizedBox(width: 6),
                      _StartWaveButton(
                        enabled: canPrepare,
                        onPressed: game.startNextWave,
                      ),
                    ],
                  ),
                  if (snapshot.selectedRunPanelTab != RunPanelTab.closed) ...[
                    const SizedBox(height: 8),
                    if (snapshot.selectedCorePoint != null &&
                        snapshot.selectedRunPanelTab ==
                            RunPanelTab.turrets) ...[
                      HudCoreInfoPanel(snapshot: snapshot),
                      const SizedBox(height: 8),
                    ],
                    if (snapshot.selectedPortalPoint != null) ...[
                      HudPortalSummaryCard(
                        snapshot: snapshot,
                        statusText: statusText,
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (snapshot.selectedRunPanelTab ==
                        RunPanelTab.upgrades) ...[
                      HudRunUpgradePanel(game: game, snapshot: snapshot),
                    ] else if (snapshot.selectedRunPanelTab ==
                        RunPanelTab.gems) ...[
                      HudGemInventoryPanel(game: game, snapshot: snapshot),
                    ] else if (snapshot.selectedRunPanelTab ==
                        RunPanelTab.turrets) ...[
                      if (snapshot.selectedTurretPoint != null &&
                          canEditBoard) ...[
                        HudGemEquipPanel(game: game, snapshot: snapshot),
                      ] else if ((snapshot.selectedBuildPoint != null ||
                              snapshot.selectedBuildTurretType != null) &&
                          canEditBoard) ...[
                        HudBuildSelectionPanel(game: game, snapshot: snapshot),
                      ],
                      if (snapshot.selectedTurretPoint == null &&
                          snapshot.selectedCorePoint == null) ...[
                        const SizedBox(height: 8),
                        HudTurretBuildPicker(
                          game: game,
                          snapshot: snapshot,
                          enabled: canEditBoard,
                        ),
                      ],
                    ],
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          _RunPanelTabs(game: game, snapshot: snapshot),
        ],
      ),
    );
  }
}

class _RunPanelTabs extends StatelessWidget {
  const _RunPanelTabs({required this.game, required this.snapshot});

  final RuneNexusGame game;
  final GameSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return GamePanel(
      height: 50,
      padding: const EdgeInsets.all(4),
      variant: GamePanelVariant.inset,
      accentColor: GamePalette.metalDim,
      child: Row(
        children: [
          _RunPanelTabButton(
            icon: Icons.account_tree_outlined,
            label: '포탑',
            selected: snapshot.selectedRunPanelTab == RunPanelTab.turrets,
            onPressed: () => game.selectRunPanelTab(RunPanelTab.turrets),
          ),
          const SizedBox(width: 5),
          _RunPanelTabButton(
            icon: Icons.trending_up_rounded,
            label: '업그레이드',
            selected: snapshot.selectedRunPanelTab == RunPanelTab.upgrades,
            onPressed: () => game.selectRunPanelTab(RunPanelTab.upgrades),
          ),
          const SizedBox(width: 5),
          _RunPanelTabButton(
            icon: Icons.diamond_outlined,
            label: '젬',
            selected: snapshot.selectedRunPanelTab == RunPanelTab.gems,
            onPressed: () => game.selectRunPanelTab(RunPanelTab.gems),
          ),
        ],
      ),
    );
  }
}

class _RunPanelTabButton extends StatelessWidget {
  const _RunPanelTabButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? GamePalette.textPrimary
        : GamePalette.textSecondary;
    final accentColor = selected ? GamePalette.cyan : GamePalette.metalDim;
    return Expanded(
      child: GameButton(
        onPressed: onPressed,
        selected: selected,
        compact: true,
        variant: GameButtonVariant.secondary,
        accentColor: accentColor,
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: foreground),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: GameTextStyles.withColor(
                  GameTextStyles.button,
                  foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomSpeedControl extends StatelessWidget {
  const _BottomSpeedControl({required this.snapshot, required this.game});

  final GameSnapshot snapshot;
  final RuneNexusGame game;

  @override
  Widget build(BuildContext context) {
    const speeds = [1.0, 2.0, 4.0];
    return GamePanel(
      height: 40,
      padding: const EdgeInsets.all(3),
      variant: GamePanelVariant.inset,
      accentColor: GamePalette.cyan,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: speeds.map((speed) {
          final selected = snapshot.speedMultiplier == speed;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: SizedBox(
              width: 30,
              height: 32,
              child: GameButton(
                onPressed: () => game.setSpeedMultiplier(speed),
                selected: selected,
                compact: true,
                variant: selected
                    ? GameButtonVariant.primary
                    : GameButtonVariant.ghost,
                accentColor: GamePalette.cyan,
                padding: EdgeInsets.zero,
                child: Center(
                  child: Text(
                    '${speed.toInt()}x',
                    style: GameTextStyles.withColor(
                      GameTextStyles.buttonSmall,
                      selected
                          ? GamePalette.voidBlack
                          : GamePalette.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _AutoStartModeButton extends StatelessWidget {
  const _AutoStartModeButton({required this.game, required this.snapshot});

  final RuneNexusGame game;
  final GameSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<AutoStartMode>(
      tooltip: _autoStartModeLabel(snapshot.autoStartMode),
      color: const Color(0xFF0B1827),
      offset: const Offset(0, -142),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0x8833D8FF)),
        borderRadius: BorderRadius.circular(8),
      ),
      onSelected: game.setAutoStartMode,
      itemBuilder: (context) {
        return AutoStartMode.values.map((mode) {
          final selected = snapshot.autoStartMode == mode;
          return PopupMenuItem(
            value: mode,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _autoStartModeIcon(mode),
                  size: 18,
                  color: selected
                      ? const Color(0xFF8EE6FF)
                      : const Color(0xFFB7C8D8),
                ),
                const SizedBox(width: 8),
                Text(
                  _autoStartModeLabel(mode),
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFF8EE6FF)
                        : const Color(0xFFE8F8FF),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          );
        }).toList();
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0x2207111D),
          border: Border.all(color: const Color(0x8833D8FF)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          _autoStartModeIcon(snapshot.autoStartMode),
          size: 22,
          color: const Color(0xFF8EE6FF),
        ),
      ),
    );
  }
}

IconData _autoStartModeIcon(AutoStartMode mode) {
  return switch (mode) {
    AutoStartMode.pauseEachRound => Icons.pause_rounded,
    AutoStartMode.skipBossRounds => Icons.auto_mode_rounded,
    AutoStartMode.fullAuto => Icons.all_inclusive,
  };
}

String _autoStartModeLabel(AutoStartMode mode) {
  return switch (mode) {
    AutoStartMode.pauseEachRound => '웨이브마다 정지',
    AutoStartMode.skipBossRounds => '보스 제외 자동',
    AutoStartMode.fullAuto => '전부 자동',
  };
}

class _StartWaveButton extends StatelessWidget {
  const _StartWaveButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GameButton(
      onPressed: enabled ? onPressed : null,
      variant: GameButtonVariant.primary,
      accentColor: GamePalette.cyan,
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.play_arrow_rounded,
            size: 20,
            color: enabled ? GamePalette.voidBlack : GamePalette.textDisabled,
          ),
          const SizedBox(width: 4),
          Text(
            '시작',
            style: GameTextStyles.withColor(
              GameTextStyles.button,
              enabled ? GamePalette.voidBlack : GamePalette.textDisabled,
            ),
          ),
        ],
      ),
    );
  }
}
