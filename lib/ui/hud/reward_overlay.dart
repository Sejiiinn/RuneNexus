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
  bool _selectedGemShards = false;

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot;
    final isPurchase = snapshot.isPurchasedGemReward;
    final selectedGem =
        _selectedGem != null && snapshot.rewardOptions.contains(_selectedGem)
        ? _selectedGem
        : null;

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
              Text(
                isPurchase ? '젬 구매 선택' : '젬 보상 선택',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (!isPurchase) ...[
                const SizedBox(height: 4),
                Text(
                  '${snapshot.completedRounds}웨이브 클리어 보상',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFB9D6E4),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: [
                  ...snapshot.rewardOptions.map((type) {
                    return _RewardCard(
                      type: type,
                      selected: selectedGem == type,
                      onPressed: () {
                        setState(() {
                          _selectedGem = type;
                          _selectedGemShards = false;
                        });
                      },
                      onConfirm: () => widget.game.selectRewardGem(type),
                    );
                  }),
                ],
              ),
              if (!isPurchase) ...[
                const SizedBox(height: 10),
                _GemShardRewardBar(
                  ownedCount: snapshot.gemShards,
                  selected: _selectedGemShards,
                  onPressed: () {
                    setState(() {
                      _selectedGem = null;
                      _selectedGemShards = true;
                    });
                  },
                  onConfirm: widget.game.selectRewardGemShards,
                ),
              ],
              _OwnedGemSummary(collection: snapshot.gemCollection),
            ],
          ),
        ),
      ),
    );
  }
}

class _GemShardRewardBar extends StatelessWidget {
  const _GemShardRewardBar({
    required this.ownedCount,
    required this.selected,
    required this.onPressed,
    required this.onConfirm,
  });

  final int ownedCount;
  final bool selected;
  final VoidCallback onPressed;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0x3328D66F) : const Color(0xAA07111D),
            border: Border.all(
              color: selected
                  ? const Color(0xFF28D66F)
                  : const Color(0xAA28D66F),
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const _GemShardIcon(),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '젬 대신 파편 획득',
                      style: TextStyle(
                        color: Color(0xFFE8F8FF),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '파편 +${RuneNexusGame.gemShardRewardFallbackAmount} · 현재 보유 $ownedCount',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF9FB7C8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 8),
                SizedBox(
                  height: 30,
                  child: FilledButton(
                    onPressed: onConfirm,
                    child: const Text('파편 받기', style: TextStyle(fontSize: 12)),
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

class _OwnedGemSummary extends StatelessWidget {
  const _OwnedGemSummary({required this.collection});

  final Map<GemType, int> collection;

  @override
  Widget build(BuildContext context) {
    final ownedTypes = GemType.values
        .where((type) => (collection[type] ?? 0) > 0)
        .toList();
    if (ownedTypes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 7),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0x7707111D),
        border: Border.all(color: const Color(0x3333D8FF)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '획득 젬',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Color(0xFF8AA6B8),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: ownedTypes.map((type) {
              return _OwnedGemChip(type: type, count: collection[type] ?? 0);
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _OwnedGemChip extends StatelessWidget {
  const _OwnedGemChip({required this.type, required this.count});

  final GemType type;
  final int count;

  @override
  Widget build(BuildContext context) {
    final gem = demoGems[type]!;
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: gem.color.withValues(alpha: 0.1),
        border: Border.all(color: gem.color.withValues(alpha: 0.58)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(gem.icon, size: 13, color: gem.color),
          const SizedBox(width: 4),
          Text(
            gem.name,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Color(0xFFE8F8FF),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'x$count',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: Color(0xFFB9D6E4),
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardCard extends StatelessWidget {
  const _RewardCard({
    required this.type,
    required this.selected,
    required this.onPressed,
    required this.onConfirm,
  });

  final GemType type;
  final bool selected;
  final VoidCallback onPressed;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final gem = demoGems[type]!;
    return SizedBox(
      width: 96,
      height: 156,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? gem.color.withValues(alpha: 0.12) : null,
              border: Border.all(
                color: selected ? gem.color : gem.color.withValues(alpha: 0.62),
                width: selected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Icon(gem.icon, color: gem.color, size: 26),
                const SizedBox(height: 7),
                Text(
                  gem.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 30,
                  child: Text(
                    gem.shortText,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFFC9DCE8),
                      height: 1.18,
                    ),
                  ),
                ),
                const Spacer(),
                if (selected)
                  SizedBox(
                    height: 26,
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onConfirm,
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: gem.color,
                        foregroundColor: const Color(0xFF07111D),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: const Text(
                        '선택',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
