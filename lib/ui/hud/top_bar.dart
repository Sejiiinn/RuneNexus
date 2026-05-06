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
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xDD091624),
          border: Border.all(color: const Color(0x8833D8FF)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Metric(label: '골드', value: '${snapshot.gold}'),
            const SizedBox(width: 14),
            _Metric(
              label: 'Nexus',
              value: '${snapshot.nexusHp}/${snapshot.maxNexusHp}',
            ),
            const SizedBox(width: 14),
            _Metric(
              label: '라운드',
              value: '${snapshot.round}/${snapshot.maxRound}',
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 30,
              height: 28,
              child: IconButton(
                onPressed: onOpenMainMenu,
                style: IconButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: Colors.transparent,
                  side: const BorderSide(color: Color(0x5533D8FF)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                icon: const Icon(Icons.home_outlined, size: 17),
              ),
            ),
            if (showDebugButton) ...[
              const SizedBox(width: 6),
              SizedBox(
                width: 30,
                height: 28,
                child: IconButton(
                  onPressed: onToggleGemDebugPanel,
                  style: IconButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: showGemDebugPanel
                        ? const Color(0xFF8EE6FF)
                        : Colors.transparent,
                    side: BorderSide(
                      color: showGemDebugPanel
                          ? const Color(0xFF8EE6FF)
                          : const Color(0x5533D8FF),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  icon: Icon(
                    Icons.diamond_outlined,
                    size: 17,
                    color: showGemDebugPanel
                        ? const Color(0xFF07111D)
                        : Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
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
                        canEndStage ? '$completedRounds라운드 기준' : '종료할 진행 상황 없음',
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StageDialogActionButton(
                icon: Icons.flag_outlined,
                label: '스테이지 종료',
                style: _StageDialogActionStyle.danger,
                onPressed: canEndStage
                    ? () => Navigator.of(context).pop(_StageMenuAction.endStage)
                    : null,
              ),
              _StageDialogActionButton(
                icon: Icons.home_outlined,
                label: '메인화면으로 이동',
                style: _StageDialogActionStyle.primary,
                onPressed: () =>
                    Navigator.of(context).pop(_StageMenuAction.openMainMenu),
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 17,
                color: enabled ? colors.foreground : const Color(0xFF627384),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: enabled ? colors.foreground : const Color(0xFF627384),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
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
            '테스트 라운드',
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
