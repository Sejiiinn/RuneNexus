import 'package:flutter/material.dart';

import '../../data/definitions/game_enemy_data.dart';
import '../../data/definitions/game_gem_data.dart';
import '../../domain/combat/game_phase.dart';
import '../../domain/enemy/enemy_type.dart';
import '../../domain/gem/gem_type.dart';
import '../../game/game_snapshot.dart';
import '../../game/rune_nexus_game.dart';
import '../game/game_ui.dart';
import 'hud_common.dart';
import 'portal_summary_panel.dart';

class HudTopBar extends StatelessWidget {
  const HudTopBar({
    required this.snapshot,
    this.topInset = 0,
    this.onOpenMainMenu,
    super.key,
  });

  final GameSnapshot snapshot;
  final double topInset;
  final VoidCallback? onOpenMainMenu;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 12 + topInset, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ResourceTabStrip(snapshot: snapshot),
            const SizedBox(width: 6),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 214),
                  child: _RunStatusPanel(snapshot: snapshot),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _TopIconButton(
                      tooltip: '스테이지 메뉴',
                      icon: Icons.home_outlined,
                      onPressed: onOpenMainMenu,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ResourceTabStrip extends StatelessWidget {
  const _ResourceTabStrip({required this.snapshot});

  final GameSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 86,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ResourceTab(
            icon: const GoldCurrencyIcon(size: 12),
            value: _GoldValue(snapshot: snapshot),
          ),
          const SizedBox(height: 4),
          _ResourceTab(
            icon: const SizedBox(
              width: 12,
              height: 12,
              child: HudGemShardIcon(),
            ),
            valueText: '${snapshot.gemShards}',
          ),
          const SizedBox(height: 4),
          _ResourceTab(
            icon: const Icon(
              Icons.flash_on_outlined,
              size: 12,
              color: Color(0xFF5CF9E9),
            ),
            label: '전투력',
            valueText: hudFormatDamageValue(snapshot.totalTurretDps),
            tooltip: '배치 포탑 전체 DPS',
          ),
        ],
      ),
    );
  }
}

class _ResourceTab extends StatelessWidget {
  const _ResourceTab({
    required this.icon,
    this.label,
    this.value,
    this.valueText,
    this.tooltip,
  }) : assert(value != null || valueText != null);

  final Widget icon;
  final String? label;
  final Widget? value;
  final String? valueText;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final label = this.label;
    final tab = SizedBox(
      height: 18,
      child: Row(
        children: [
          icon,
          const SizedBox(width: 4),
          if (label != null) ...[
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF8FA8BA),
                fontSize: 8,
                fontWeight: FontWeight.w800,
                height: 1,
                shadows: GameTextStyles.textShadow,
              ),
            ),
            const SizedBox(width: 3),
          ],
          Expanded(
            child: DefaultTextStyle(
              style: const TextStyle(
                color: Color(0xFFE8FBFF),
                fontSize: 11,
                fontWeight: FontWeight.w900,
                height: 1,
                shadows: GameTextStyles.textShadow,
              ),
              maxLines: 1,
              child: value == null
                  ? ScaleDownText(valueText!, alignment: Alignment.centerLeft)
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: value,
                    ),
            ),
          ),
        ],
      ),
    );

    if (tooltip == null) {
      return tab;
    }
    return Tooltip(message: tooltip!, child: tab);
  }
}

class _GoldValue extends StatelessWidget {
  const _GoldValue({required this.snapshot});

  final GameSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final fractionDigit = (snapshot.killGoldFractionWallet * 10).floor();
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: Color(0xFFE8FBFF),
          height: 1,
          shadows: GameTextStyles.textShadow,
        ),
        children: [
          TextSpan(text: '${snapshot.gold}'),
          if (fractionDigit > 0)
            TextSpan(
              text: '.$fractionDigit',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF8FA8BA),
                fontWeight: FontWeight.w800,
                shadows: GameTextStyles.textShadow,
              ),
            ),
        ],
      ),
    );
  }
}

class _RunStatusPanel extends StatelessWidget {
  const _RunStatusPanel({required this.snapshot});

  final GameSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final hpRatio = snapshot.maxNexusHp <= 0
        ? 0.0
        : (snapshot.nexusHp / snapshot.maxNexusHp).clamp(0.0, 1.0);
    final danger = hpRatio <= 0.35;
    final hpColor = danger ? const Color(0xFFFF7043) : const Color(0xFF6EF6A5);

    return GamePanel(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      variant: GamePanelVariant.inset,
      accentColor: hpColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.favorite_outline, size: 12, color: hpColor),
              const SizedBox(width: 3),
              Text(
                '${hudFormatNexusHp(snapshot.nexusHp)}/'
                '${hudFormatNexusHp(snapshot.maxNexusHp)}',
                style: const TextStyle(
                  color: Color(0xFFE8FBFF),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: hpRatio,
                    minHeight: 3,
                    color: hpColor,
                    backgroundColor: const Color(0xFF1A2A39),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                height: 20,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF10243A),
                  border: Border.all(color: const Color(0x6633D8FF)),
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${snapshot.round}/${snapshot.maxRound}',
                  style: const TextStyle(
                    color: Color(0xFFE8FBFF),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _WaveIntelRow(snapshot: snapshot),
        ],
      ),
    );
  }
}

class _WaveIntelRow extends StatelessWidget {
  const _WaveIntelRow({required this.snapshot});

  final GameSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final types = snapshot.nextWaveEnemyTypes.take(3).toList();
    final hiddenCount = snapshot.nextWaveEnemyTypes.length - types.length;

    return Row(
      children: [
        _EnemyIntelButton(
          snapshot: snapshot,
          types: types,
          hiddenCount: hiddenCount,
        ),
        const Spacer(),
        _WaveRewardSummary(snapshot: snapshot),
      ],
    );
  }
}

class _EnemyIntelButton extends StatelessWidget {
  const _EnemyIntelButton({
    required this.snapshot,
    required this.types,
    required this.hiddenCount,
  });

  final GameSnapshot snapshot;
  final List<EnemyType> types;
  final int hiddenCount;

  @override
  Widget build(BuildContext context) {
    final width = 10.0 + types.length * 20 + (hiddenCount > 0 ? 16 : 0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => showGameBottomSheet<void>(
          context: context,
          builder: (context) => HudPortalWaveDetailSheet(snapshot: snapshot),
        ),
        borderRadius: BorderRadius.circular(5),
        child: Container(
          height: 24,
          width: width.clamp(28.0, 82.0),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF10243A),
            border: Border.all(color: const Color(0x5533D8FF)),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Row(
            children: [
              ...types.map(
                (type) => Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CustomPaint(
                      painter: HudEnemyIconPainter(
                        color: gameEnemies[type]!.color,
                        type: type,
                      ),
                    ),
                  ),
                ),
              ),
              if (hiddenCount > 0)
                Text(
                  '+$hiddenCount',
                  style: const TextStyle(
                    color: Color(0xFF8EE6FF),
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WaveRewardSummary extends StatelessWidget {
  const _WaveRewardSummary({required this.snapshot});

  final GameSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '웨이브 클리어 보상',
      child: Container(
        height: 20,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          color: const Color(0x661A2A39),
          border: Border.all(color: const Color(0x44E7C66A)),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.flag_outlined, size: 10, color: Color(0xFFFFD166)),
            _RewardValue(value: snapshot.nextWaveClearRewardGold),
            const SizedBox(width: 4),
            const SizedBox(width: 10, height: 10, child: HudGemShardIcon()),
            _RewardValue(value: snapshot.nextWaveClearRewardGemShards),
          ],
        ),
      ),
    );
  }
}

class _RewardValue extends StatelessWidget {
  const _RewardValue({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    return Text(
      '+$value',
      style: const TextStyle(
        color: Color(0xFFE8FBFF),
        fontSize: 9,
        fontWeight: FontWeight.w900,
        height: 1,
      ),
    );
  }
}

class _TopIconButton extends StatelessWidget {
  const _TopIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: GameButton(
        tooltip: tooltip,
        onPressed: onPressed,
        compact: true,
        variant: GameButtonVariant.ghost,
        accentColor: GamePalette.cyan,
        padding: EdgeInsets.zero,
        child: Center(
          child: Icon(icon, size: 18, color: GamePalette.textPrimary),
        ),
      ),
    );
  }
}

enum HudStageMenuAction { openMainMenu, endStage }

class HudStageMenuDialog extends StatelessWidget {
  const HudStageMenuDialog({required this.snapshot, super.key});

  final GameSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final canEndStage =
        snapshot.hasStageProgress &&
        snapshot.phase != GamePhase.success &&
        snapshot.phase != GamePhase.failure;
    return GameModalFrame(
      maxWidth: 390,
      accentColor: GamePalette.cyan,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.home_outlined,
                color: Color(0xFF8EE6FF),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('스테이지 메뉴', style: GameTextStyles.title),
              ),
              GameModalCloseButton(
                tooltip: '취소',
                onPressed: () => Navigator.of(context).pop(),
                accentColor: GamePalette.cyan,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                flex: 5,
                child: _StageDialogActionButton(
                  icon: Icons.flag_outlined,
                  label: '스테이지 종료',
                  style: _StageDialogActionStyle.danger,
                  onPressed: canEndStage
                      ? () => Navigator.of(
                          context,
                        ).pop(HudStageMenuAction.endStage)
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 6,
                child: _StageDialogActionButton(
                  icon: Icons.home_outlined,
                  label: '메인화면으로 이동',
                  style: _StageDialogActionStyle.primary,
                  onPressed: () => Navigator.of(
                    context,
                  ).pop(HudStageMenuAction.openMainMenu),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StageRewardPreviewCard extends StatelessWidget {
  const _StageRewardPreviewCard({
    required this.completedRounds,
    required this.reward,
  });

  final int completedRounds;
  final int reward;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xF0221D12), Color(0xF0091624)],
        ),
        border: Border.all(color: const Color(0x88E7C66A)),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const _RuneRewardIcon(size: 24),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '종료 시 보상',
                  style: TextStyle(
                    color: Color(0xFF8FA8BA),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x661A2A39),
                  border: Border.all(color: const Color(0x55E7C66A)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('정산 예상', style: GameTextStyles.caption),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  '$completedRounds웨이브 기준',
                  style: const TextStyle(
                    color: Color(0xFFB7C8D8),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(right: 5, bottom: 1),
                    child: _RuneRewardIcon(size: 22),
                  ),
                  Text(
                    '+$reward 룬',
                    style: const TextStyle(
                      color: GamePalette.goldBright,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      shadows: GameTextStyles.textShadow,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RuneRewardIcon extends StatelessWidget {
  const _RuneRewardIcon({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0x33221D12),
        border: Border.all(color: const Color(0x88E7C66A)),
        shape: BoxShape.circle,
      ),
      child: RuneCurrencyIcon(size: size * 0.62),
    );
  }
}

class HudStageEndConfirmDialog extends StatelessWidget {
  const HudStageEndConfirmDialog({required this.snapshot, super.key});

  final GameSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return GameModalFrame(
      maxWidth: 340,
      tone: GameModalTone.danger,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.flag_outlined, color: GamePalette.danger, size: 20),
              SizedBox(width: 8),
              Expanded(child: Text('정말 종료할까요?', style: GameTextStyles.title)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '스테이지 ${snapshot.currentStageNumber} 진행을 종료하고 '
            '+${snapshot.projectedFailureRuneReward} 룬을 정산합니다.',
            style: GameTextStyles.body,
          ),
          const SizedBox(height: 12),
          _StageRewardPreviewCard(
            completedRounds: snapshot.completedRounds,
            reward: snapshot.projectedFailureRuneReward,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StageDialogActionButton(
                  icon: Icons.arrow_back,
                  label: '계속 진행',
                  style: _StageDialogActionStyle.neutral,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StageDialogActionButton(
                  icon: Icons.flag_outlined,
                  label: '종료',
                  style: _StageDialogActionStyle.danger,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _StageDialogActionStyle { neutral, primary, danger }

class _StageDialogActionButton extends StatelessWidget {
  const _StageDialogActionButton({
    required this.icon,
    required this.label,
    required this.style,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final _StageDialogActionStyle style;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final variant = switch (style) {
      _StageDialogActionStyle.neutral => GameButtonVariant.ghost,
      _StageDialogActionStyle.primary => GameButtonVariant.primary,
      _StageDialogActionStyle.danger => GameButtonVariant.danger,
    };
    final accentColor = switch (style) {
      _StageDialogActionStyle.neutral => GamePalette.metal,
      _StageDialogActionStyle.primary => GamePalette.cyan,
      _StageDialogActionStyle.danger => GamePalette.danger,
    };

    return GameButton(
      onPressed: onPressed,
      label: label,
      icon: Icon(icon, size: 17),
      variant: variant,
      accentColor: accentColor,
      height: 38,
    );
  }
}

class HudGemDebugPanel extends StatelessWidget {
  const HudGemDebugPanel({
    required this.game,
    required this.snapshot,
    super.key,
  });

  final RuneNexusGame game;
  final GameSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 206,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xF0091624),
        border: Border.all(color: const Color(0xAA33D8FF)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 430),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '테스트 시나리오',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: _DebugRoundButton(
                  label: '포탑 레벨 1~10',
                  enabled: true,
                  onPressed: game.debugShowTurretLevels,
                ),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  _DebugRoundButton(
                    label: '보상 UI',
                    enabled: true,
                    onPressed: game.debugOpenGemReward,
                  ),
                  const SizedBox(width: 5),
                  _DebugRoundButton(
                    label: '1차 특성',
                    enabled: true,
                    onPressed: game.debugPreparePrimaryTrait,
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  _DebugRoundButton(
                    label: '2차 특성',
                    enabled: true,
                    onPressed: game.debugPrepareSecondaryTrait,
                  ),
                  const SizedBox(width: 5),
                  _DebugRoundButton(
                    label: '보스 웨이브',
                    enabled: true,
                    onPressed: game.debugPrepareBossWave,
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  _DebugRoundButton(
                    label: '강제 승리',
                    enabled:
                        snapshot.phase != GamePhase.success &&
                        snapshot.phase != GamePhase.failure &&
                        snapshot.phase != GamePhase.coreDestruction,
                    onPressed: game.debugForceVictory,
                  ),
                  const SizedBox(width: 5),
                  _DebugRoundButton(
                    label: '강제 패배',
                    enabled:
                        snapshot.phase != GamePhase.success &&
                        snapshot.phase != GamePhase.failure &&
                        snapshot.phase != GamePhase.coreDestruction,
                    onPressed: game.debugForceDefeat,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                '테스트 웨이브',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _DebugRoundButton(
                    label: '-1',
                    enabled: snapshot.round > 1,
                    onPressed: () => game.debugSetRound(snapshot.round - 1),
                  ),
                  const SizedBox(width: 5),
                  _DebugRoundButton(
                    label: '+1',
                    enabled: snapshot.round < snapshot.maxRound,
                    onPressed: () => game.debugSetRound(snapshot.round + 1),
                  ),
                  const SizedBox(width: 5),
                  _DebugRoundButton(
                    label: '+5',
                    enabled: snapshot.round < snapshot.maxRound,
                    onPressed: () => game.debugSetRound(snapshot.round + 5),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  _DebugRoundButton(
                    label: '10R',
                    enabled: snapshot.round != 10,
                    onPressed: () => game.debugSetRound(10),
                  ),
                  const SizedBox(width: 5),
                  _DebugRoundButton(
                    label: '25R',
                    enabled: snapshot.round != 25,
                    onPressed: () => game.debugSetRound(25),
                  ),
                  const SizedBox(width: 5),
                  _DebugRoundButton(
                    label: '${snapshot.maxRound}R',
                    enabled: snapshot.round != snapshot.maxRound,
                    onPressed: () => game.debugSetRound(snapshot.maxRound),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  _DebugRoundButton(
                    label: '스테이지 초기화',
                    enabled: true,
                    onPressed: game.restartRun,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                '테스트 재화',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _DebugRoundButton(
                    label: '+500G',
                    enabled: true,
                    onPressed: () => game.debugAddGold(500),
                  ),
                  const SizedBox(width: 5),
                  _DebugRoundButton(
                    label: '+50 파편',
                    enabled: true,
                    onPressed: () => game.debugAddGemShards(50),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                '테스트 몹',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                height: 34,
                child: OutlinedButton.icon(
                  onPressed: game.debugSpawnDiamondCarrier,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEAFBFF),
                    side: const BorderSide(color: Color(0xFF8EE6FF)),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                  icon: const DiamondCurrencyIcon(size: 17),
                  label: const Text('다이아 운반체', style: TextStyle(fontSize: 11)),
                ),
              ),
              const SizedBox(height: 5),
              Wrap(
                spacing: 5,
                runSpacing: 5,
                children: EnemyType.values.map((type) {
                  final enemy = gameEnemies[type]!;
                  return SizedBox(
                    width: 88,
                    height: 34,
                    child: OutlinedButton.icon(
                      onPressed: () => game.debugSpawnEnemy(type),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: enemy.color),
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                      icon: HudEnemyIcon(type: type, selected: false, size: 17),
                      label: Text(
                        enemy.name,
                        style: const TextStyle(fontSize: 11),
                        overflow: TextOverflow.clip,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              const Text(
                '테스트 젬',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 5,
                runSpacing: 5,
                children: GemType.values.map((type) {
                  final gem = gameGems[type]!;
                  return SizedBox(
                    width: 88,
                    height: 34,
                    child: OutlinedButton.icon(
                      onPressed: () => game.grantGem(type),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: gem.color),
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                      icon: GemIcon(gem.type, size: 14),
                      label: Text(
                        gem.name,
                        style: const TextStyle(fontSize: 11),
                        overflow: TextOverflow.clip,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DebugRoundButton extends StatelessWidget {
  const _DebugRoundButton({
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SizedBox(
        height: 28,
        child: OutlinedButton(
          onPressed: enabled ? onPressed : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Color(0x7733D8FF)),
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(7),
            ),
          ),
          child: Text(label, style: const TextStyle(fontSize: 11)),
        ),
      ),
    );
  }
}
