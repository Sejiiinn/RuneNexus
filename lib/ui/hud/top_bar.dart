part of 'game_hud.dart';

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.snapshot,
    required this.showDebugButton,
    required this.showGemDebugPanel,
    required this.onToggleGemDebugPanel,
    this.onOpenMainMenu,
  });

  final GameSnapshot snapshot;
  final bool showDebugButton;
  final bool showGemDebugPanel;
  final VoidCallback onToggleGemDebugPanel;
  final VoidCallback? onOpenMainMenu;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ResourceStrip(snapshot: snapshot),
            const SizedBox(width: 8),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: showDebugButton ? 190 : 214,
                  ),
                  child: _RunStatusPanel(snapshot: snapshot),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _TopIconButton(
              tooltip: '스테이지 메뉴',
              icon: Icons.home_outlined,
              onPressed: onOpenMainMenu,
            ),
            if (showDebugButton) ...[
              const SizedBox(width: 6),
              _TopIconButton(
                tooltip: '테스트 젬 패널',
                icon: Icons.diamond_outlined,
                selected: showGemDebugPanel,
                onPressed: onToggleGemDebugPanel,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResourceStrip extends StatelessWidget {
  const _ResourceStrip({required this.snapshot});

  final GameSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ResourceValue(
            icon: Icons.paid_outlined,
            iconColor: const Color(0xFFFFD166),
            valueChild: _GoldValue(snapshot: snapshot),
          ),
          const SizedBox(height: 5),
          _ResourceValue(
            iconWidget: const _GemShardIcon(),
            valueText: '${snapshot.gemShards}',
          ),
        ],
      ),
    );
  }
}

class _ResourceValue extends StatelessWidget {
  const _ResourceValue({
    this.icon,
    this.iconColor,
    this.iconWidget,
    this.valueText,
    this.valueChild,
  });

  final IconData? icon;
  final Color? iconColor;
  final Widget? iconWidget;
  final String? valueText;
  final Widget? valueChild;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        iconWidget ??
            Icon(icon, size: 16, color: iconColor ?? const Color(0xFFE8FBFF)),
        const SizedBox(width: 3),
        DefaultTextStyle(
          style: const TextStyle(
            color: Color(0xFFE8FBFF),
            fontSize: 13,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
          child: valueChild ?? Text(valueText ?? '0'),
        ),
      ],
    );
  }
}

class _GemShardIcon extends StatelessWidget {
  const _GemShardIcon();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 16,
      height: 16,
      child: CustomPaint(painter: _GemShardPainter()),
    );
  }
}

class _GemShardPainter extends CustomPainter {
  const _GemShardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final shard = Path()
      ..moveTo(size.width * 0.48, size.height * 0.08)
      ..lineTo(size.width * 0.88, size.height * 0.26)
      ..lineTo(size.width * 0.78, size.height * 0.62)
      ..lineTo(size.width * 0.36, size.height * 0.94)
      ..lineTo(size.width * 0.08, size.height * 0.5)
      ..close();
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFA8FFB8), Color(0xFF28D66F), Color(0xFF0E7F47)],
      ).createShader(Offset.zero & size);
    canvas.drawPath(shard, paint);

    final edgePaint = Paint()
      ..color = const Color(0xFFBFFFF0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(shard, edgePaint);

    final facetPaint = Paint()
      ..color = const Color(0x665CFFAA)
      ..style = PaintingStyle.fill;
    final facet = Path()
      ..moveTo(size.width * 0.48, size.height * 0.08)
      ..lineTo(size.width * 0.88, size.height * 0.26)
      ..lineTo(size.width * 0.52, size.height * 0.38)
      ..close();
    canvas.drawPath(facet, facetPaint);

    final glintPaint = Paint()
      ..color = const Color(0xDDFFFFFF)
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.3, size.height * 0.32),
      Offset(size.width * 0.5, size.height * 0.16),
      glintPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GemShardPainter oldDelegate) => false;
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

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xD6091624),
        border: Border.all(color: const Color(0x554A6172)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.favorite_outline, size: 12, color: hpColor),
              const SizedBox(width: 3),
              Text(
                '${snapshot.nexusHp}/${snapshot.maxNexusHp}',
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
        onTap: () => showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (context) => _PortalWaveDetailSheet(snapshot: snapshot),
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
                      painter: _EnemyIconPainter(
                        color: demoEnemies[type]!.color,
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
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF15293A),
          border: Border.all(color: const Color(0x444A6172)),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.flag_outlined, size: 12, color: Color(0xFFFFD166)),
            _RewardValue(value: snapshot.nextWaveClearRewardGold),
            const SizedBox(width: 5),
            const SizedBox(width: 12, height: 12, child: _GemShardIcon()),
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
        fontSize: 10,
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
    this.selected = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          padding: EdgeInsets.zero,
          foregroundColor: selected
              ? const Color(0xFF07111D)
              : const Color(0xFFE8FBFF),
          backgroundColor: selected
              ? const Color(0xFF8EE6FF)
              : const Color(0xE607111D),
          side: BorderSide(
            color: selected ? const Color(0xFF8EE6FF) : const Color(0x6650E6FF),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: Icon(icon, size: 18),
      ),
    );
  }
}

enum _StageMenuAction { openMainMenu, endStage }

class _StageMenuDialog extends StatelessWidget {
  const _StageMenuDialog({required this.snapshot});

  final GameSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final canEndStage =
        snapshot.hasStageProgress &&
        snapshot.phase != GamePhase.success &&
        snapshot.phase != GamePhase.failure;
    final completedRounds = canEndStage ? snapshot.completedRounds : 0;
    final reward = canEndStage ? snapshot.projectedFailureRuneReward : 0;

    return AlertDialog(
      backgroundColor: const Color(0xFF0B1827),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0x8833D8FF)),
        borderRadius: BorderRadius.circular(10),
      ),
      title: Row(
        children: [
          const Expanded(child: Text('스테이지 메뉴')),
          SizedBox(
            width: 32,
            height: 32,
            child: IconButton(
              tooltip: '취소',
              onPressed: () => Navigator.of(context).pop(),
              style: IconButton.styleFrom(
                padding: EdgeInsets.zero,
                foregroundColor: const Color(0xFFC6D6E4),
                backgroundColor: Colors.transparent,
                side: const BorderSide(color: Color(0x664A6172)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.close, size: 17),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('메인화면으로 이동해도 현재 진행 상황은 저장됩니다.'),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF07111D),
              border: Border.all(color: const Color(0x7733D8FF)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.diamond_outlined,
                  color: Color(0xFF8EE6FF),
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '종료 시 보상',
                        style: TextStyle(
                          color: Color(0xFF8FA8BA),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        canEndStage ? '$completedRounds웨이브 기준' : '종료할 진행 상황 없음',
                        style: const TextStyle(
                          color: Color(0xFFB7C8D8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '+$reward 룬',
                  style: TextStyle(
                    color: canEndStage
                        ? const Color(0xFF8EE6FF)
                        : const Color(0xFF627384),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 5,
                child: _StageDialogActionButton(
                  icon: Icons.flag_outlined,
                  label: '스테이지 종료',
                  style: _StageDialogActionStyle.danger,
                  onPressed: canEndStage
                      ? () =>
                            Navigator.of(context).pop(_StageMenuAction.endStage)
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
                  onPressed: () =>
                      Navigator.of(context).pop(_StageMenuAction.openMainMenu),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StageEndConfirmDialog extends StatelessWidget {
  const _StageEndConfirmDialog({required this.snapshot});

  final GameSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF0B1827),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0x99FF7043)),
        borderRadius: BorderRadius.circular(10),
      ),
      title: const Text('정말 종료할까요?'),
      content: Text(
        '스테이지 ${snapshot.currentStageNumber} 진행을 종료하고 '
        '+${snapshot.projectedFailureRuneReward} 룬을 정산합니다.',
      ),
      actions: [
        _StageDialogActionButton(
          icon: Icons.arrow_back,
          label: '계속 진행',
          style: _StageDialogActionStyle.neutral,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        _StageDialogActionButton(
          icon: Icons.flag_outlined,
          label: '종료',
          style: _StageDialogActionStyle.danger,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
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
    final enabled = onPressed != null;
    final colors = switch (style) {
      _StageDialogActionStyle.neutral => (
        background: Colors.transparent,
        border: const Color(0x664A6172),
        foreground: const Color(0xFFC6D6E4),
      ),
      _StageDialogActionStyle.primary => (
        background: const Color(0xFF8EE6FF),
        border: const Color(0xFF8EE6FF),
        foreground: const Color(0xFF07111D),
      ),
      _StageDialogActionStyle.danger => (
        background: const Color(0xFFFF7043),
        border: const Color(0xFFFF9B72),
        foreground: const Color(0xFF07111D),
      ),
    };

    return Material(
      color: enabled ? colors.background : const Color(0xFF182433),
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: enabled ? colors.border : const Color(0x334A6172),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: [
              Icon(
                icon,
                size: 17,
                color: enabled ? colors.foreground : const Color(0xFF627384),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: enabled
                        ? colors.foreground
                        : const Color(0xFF627384),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GemDebugPanel extends StatelessWidget {
  const _GemDebugPanel({required this.game, required this.snapshot});

  final RuneNexusGame game;
  final GameSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xF0091624),
        border: Border.all(color: const Color(0xAA33D8FF)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                label: '50R',
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
                onPressed: game.restartDemo,
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            '테스트 골드',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _DebugRoundButton(
                label: '+100',
                enabled: true,
                onPressed: () => game.debugAddGold(100),
              ),
              const SizedBox(width: 5),
              _DebugRoundButton(
                label: '+500',
                enabled: true,
                onPressed: () => game.debugAddGold(500),
              ),
              const SizedBox(width: 5),
              _DebugRoundButton(
                label: '+1000',
                enabled: true,
                onPressed: () => game.debugAddGold(1000),
              ),
            ],
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
              final gem = demoGems[type]!;
              return SizedBox(
                width: 70,
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
                  icon: Icon(gem.icon, color: gem.color, size: 14),
                  label: Text(
                    gem.name,
                    style: const TextStyle(fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
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
