part of 'game_hud.dart';

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.game,
    required this.snapshot,
    required this.showGemDebugPanel,
    required this.onToggleGemDebugPanel,
    this.onOpenMainMenu,
  });

  final RuneNexusGame game;
  final GameSnapshot snapshot;
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
            const SizedBox(width: 14),
            _SpeedControl(snapshot: snapshot, game: game),
            const SizedBox(width: 6),
            SizedBox(
              width: 30,
              height: 28,
              child: IconButton(
                onPressed: snapshot.phase == GamePhase.preparation
                    ? onOpenMainMenu
                    : null,
                style: IconButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: Colors.transparent,
                  disabledForegroundColor: const Color(0xFF506170),
                  side: BorderSide(
                    color: snapshot.phase == GamePhase.preparation
                        ? const Color(0x5533D8FF)
                        : const Color(0x33485B68),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                icon: const Icon(Icons.home_outlined, size: 17),
              ),
            ),
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

class _SpeedControl extends StatelessWidget {
  const _SpeedControl({required this.snapshot, required this.game});

  final GameSnapshot snapshot;
  final RuneNexusGame game;

  @override
  Widget build(BuildContext context) {
    const speeds = [1.0, 2.0, 4.0];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: speeds.map((speed) {
        final selected = snapshot.speedMultiplier == speed;
        return Padding(
          padding: const EdgeInsets.only(left: 3),
          child: SizedBox(
            width: 30,
            height: 28,
            child: OutlinedButton(
              onPressed: () => game.setSpeedMultiplier(speed),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                foregroundColor: selected
                    ? const Color(0xFF07111D)
                    : Colors.white,
                backgroundColor: selected
                    ? const Color(0xFF8EE6FF)
                    : Colors.transparent,
                side: BorderSide(
                  color: selected
                      ? const Color(0xFF8EE6FF)
                      : const Color(0x5533D8FF),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: Text(
                '${speed.toInt()}x',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
