part of 'main_menu_screen.dart';

class _MenuDebugShortcuts extends StatelessWidget {
  const _MenuDebugShortcuts({
    required this.testPanelOpen,
    required this.onToggleTestPanel,
    required this.onOpenMapEditor,
  });

  final bool testPanelOpen;
  final VoidCallback onToggleTestPanel;
  final VoidCallback? onOpenMapEditor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: const BoxDecoration(
        color: Color(0xF203070E),
        border: Border(bottom: BorderSide(color: Color(0x66FFB55E))),
      ),
      child: Row(
        children: [
          _DebugShortcutButton(
            label: '테스트 패널',
            icon: Icons.tune,
            selected: testPanelOpen,
            onPressed: onToggleTestPanel,
          ),
          const SizedBox(width: 7),
          _DebugShortcutButton(
            label: '맵 에디터',
            icon: Icons.map_outlined,
            selected: false,
            onPressed: onOpenMapEditor,
          ),
        ],
      ),
    );
  }
}

class _DebugShortcutButton extends StatelessWidget {
  const _DebugShortcutButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 102,
      child: GameButton(
        onPressed: onPressed,
        label: label,
        icon: Icon(icon, size: 15),
        compact: true,
        selected: selected,
        variant: GameButtonVariant.ghost,
        accentColor: const Color(0xFFFFB55E),
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      ),
    );
  }
}

class _MainMenuDebugPanel extends StatelessWidget {
  const _MainMenuDebugPanel({
    required this.game,
    required this.snapshot,
    required this.onClose,
  });

  final RuneNexusGame game;
  final GameSnapshot snapshot;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return GamePanel(
      padding: const EdgeInsets.all(10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 430),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.tune, color: Color(0xFF8EE6FF), size: 18),
                  const SizedBox(width: 7),
                  const Expanded(
                    child: Text(
                      '메뉴 테스트 패널',
                      style: TextStyle(
                        color: Color(0xFFE8FBFF),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 30,
                    height: 30,
                    child: IconButton(
                      tooltip: '닫기',
                      onPressed: onClose,
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.close, size: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 5,
                runSpacing: 5,
                children: [
                  _DebugStatusChip(
                    icon: Icons.diamond_outlined,
                    label: '룬',
                    value: '${snapshot.runes}',
                  ),
                  _DebugStatusChip(
                    icon: Icons.diamond,
                    label: '다이아',
                    value: '${snapshot.diamonds}',
                  ),
                  _DebugStatusChip(
                    icon: Icons.flag_outlined,
                    label: '해금',
                    value: '${snapshot.unlockedStageCount}',
                  ),
                  _DebugStatusChip(
                    icon: Icons.check_circle_outline,
                    label: '클리어',
                    value: '${snapshot.clearedStageNumbers.length}',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _DebugControlSection(
                title: '룬',
                children: [
                  _DebugActionButton(
                    label: '+100',
                    onPressed: () => game.debugAddRunes(100),
                  ),
                  _DebugActionButton(
                    label: '+1,000',
                    onPressed: () => game.debugAddRunes(1000),
                  ),
                  _DebugActionButton(
                    label: '+10,000',
                    onPressed: () => game.debugAddRunes(10000),
                  ),
                  _DebugActionButton(
                    label: '0으로',
                    onPressed: () => game.debugSetRunes(0),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _DebugControlSection(
                title: '다이아',
                children: [
                  _DebugActionButton(
                    label: '+10',
                    onPressed: () => game.debugAddDiamonds(10),
                  ),
                  _DebugActionButton(
                    label: '+100',
                    onPressed: () => game.debugAddDiamonds(100),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _DebugControlSection(
                title: '클리어 스테이지',
                children: [
                  for (final count in const [0, 1, 2, 5, 10])
                    _DebugActionButton(
                      label: count == 0 ? '초기' : '$count까지',
                      selected: snapshot.clearedStageNumbers.length == count,
                      onPressed: () => game.debugSetClearedStageCount(count),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              _DebugControlSection(
                title: '강화',
                children: [
                  _DebugActionButton(
                    label: '강화 초기화',
                    danger: true,
                    onPressed: game.debugResetUpgradeProgress,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _DebugControlSection(
                title: '코어',
                children: [
                  _DebugActionButton(
                    label: '패시브 초기화',
                    danger: true,
                    onPressed: game.debugResetCorePassiveProgress,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _DebugControlSection(
                title: '연구',
                children: [
                  _DebugActionButton(
                    label: game.debugInstantResearchCompletion
                        ? '즉시 완료 ON'
                        : '즉시 완료 OFF',
                    selected: game.debugInstantResearchCompletion,
                    onPressed: () => game.debugSetInstantResearchCompletion(
                      !game.debugInstantResearchCompletion,
                    ),
                  ),
                  _DebugActionButton(
                    label: '연구 초기화',
                    danger: true,
                    onPressed: game.debugResetResearchProgress,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DebugStatusChip extends StatelessWidget {
  const _DebugStatusChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0x3315283A),
        border: Border.all(color: const Color(0x5533D8FF)),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF8EE6FF), size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF9EB3BF),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFE8FBFF),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _DebugControlSection extends StatelessWidget {
  const _DebugControlSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0x4415283A),
        border: Border.all(color: const Color(0x33485B68)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFE8FBFF),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(spacing: 5, runSpacing: 5, children: children),
        ],
      ),
    );
  }
}

class _DebugActionButton extends StatelessWidget {
  const _DebugActionButton({
    required this.label,
    required this.onPressed,
    this.selected = false,
    this.danger = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool selected;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final accent = danger
        ? const Color(0xFFFF9A7A)
        : selected
        ? const Color(0xFFE7C66A)
        : const Color(0xFF8EE6FF);
    return SizedBox(
      height: 30,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: selected ? const Color(0xFF07111D) : Colors.white,
          backgroundColor: selected ? accent : null,
          side: BorderSide(color: accent.withValues(alpha: 0.74)),
          padding: const EdgeInsets.symmetric(horizontal: 9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
