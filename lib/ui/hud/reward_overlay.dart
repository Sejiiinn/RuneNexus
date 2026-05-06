part of 'game_hud.dart';

class _RewardOverlay extends StatefulWidget {
  const _RewardOverlay({required this.game, required this.snapshot});

  final RuneNexusGame game;
  final GameSnapshot snapshot;

  @override
  State<_RewardOverlay> createState() => _RewardOverlayState();
}

class _RewardOverlayState extends State<_RewardOverlay> {
  GemType? _selectedGem;

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot;
    final selectedGem =
        _selectedGem != null && snapshot.rewardOptions.contains(_selectedGem)
        ? _selectedGem
        : null;
    final selectedGemDefinition = selectedGem == null
        ? null
        : demoGems[selectedGem]!;

    return Container(
      color: const Color(0x9902070D),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xF0091624),
            border: Border.all(color: const Color(0xAA33D8FF)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '젬 보상 선택',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                '${snapshot.completedRounds}라운드 클리어 보상',
                style: const TextStyle(fontSize: 12, color: Color(0xFFB9D6E4)),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: snapshot.rewardOptions.map((type) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _RewardCard(
                      type: type,
                      ownedCount: snapshot.gemInventory[type] ?? 0,
                      selected: selectedGem == type,
                      onPressed: () {
                        setState(() {
                          _selectedGem = type;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
              if (selectedGem != null && selectedGemDefinition != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xAA07111D),
                    border: Border.all(
                      color: selectedGemDefinition.color.withValues(alpha: 0.5),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        selectedGemDefinition.icon,
                        color: selectedGemDefinition.color,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              selectedGemDefinition.name,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _rewardGemEffectText(selectedGem),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFFC9DCE8),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 30,
                        child: FilledButton(
                          onPressed: () =>
                              widget.game.selectRewardGem(selectedGem),
                          child: const Text(
                            '선택',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RewardCard extends StatelessWidget {
  const _RewardCard({
    required this.type,
    required this.ownedCount,
    required this.selected,
    required this.onPressed,
  });

  final GemType type;
  final int ownedCount;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final gem = demoGems[type]!;
    return SizedBox(
      width: 96,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(
            color: selected ? gem.color : gem.color.withValues(alpha: 0.62),
            width: selected ? 2 : 1,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(gem.icon, color: gem.color, size: 28),
            const SizedBox(height: 8),
            Text(gem.name, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              gem.shortText,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Color(0xFFC9DCE8)),
            ),
            const SizedBox(height: 6),
            Text(
              '보유 x$ownedCount',
              style: const TextStyle(fontSize: 10, color: Color(0xFF8AA6B8)),
            ),
          ],
        ),
      ),
    );
  }
}

String _rewardGemEffectText(GemType type) {
  return switch (type) {
    GemType.attackSpeed => '장착 포탑의 초당 발사 수 40% 증폭',
    GemType.range => '장착 포탑의 사거리 20% 증폭',
    GemType.physicalDamage => '물리 피해 40% 증폭',
    GemType.magicalDamage => '마법 피해 40% 증폭',
    GemType.lightWeapon => '경량화기 피해와 연사 강화',
    GemType.heavyWeapon => '중화기 피해와 효과 범위 강화',
    GemType.damageOverTime => '지속피해와 지속시간 강화',
    GemType.explosion => '타격 지점 주변에 폭발 피해 추가',
    GemType.chain => '주변 최대 2명에게 50% 피해 투사체 발사',
  };
}
