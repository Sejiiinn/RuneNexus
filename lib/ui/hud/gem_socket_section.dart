part of 'game_hud.dart';

class _TurretLinkSocketStrip extends StatelessWidget {
  const _TurretLinkSocketStrip({
    required this.snapshot,
    required this.canManageGems,
    required this.selectedSlotIndex,
    required this.onSelectSlot,
    required this.onUpgradeLink,
  });

  final GameSnapshot snapshot;
  final bool canManageGems;
  final int? selectedSlotIndex;
  final ValueChanged<int> onSelectSlot;
  final VoidCallback onUpgradeLink;

  @override
  Widget build(BuildContext context) {
    final canOpenLockedSocket =
        canManageGems &&
        snapshot.selectedTurretCanUpgradeLink &&
        snapshot.gold >= snapshot.selectedTurretLinkUpgradeCost;
    final lockedLabel = snapshot.selectedTurretCanUpgradeLink
        ? '${snapshot.selectedTurretLinkUpgradeCost}G'
        : 'Lv.${snapshot.selectedTurretLinkUpgradeRequiredLevel}';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 7),
          decoration: BoxDecoration(
            color: const Color(0x9907111D),
            border: Border.all(color: const Color(0x4433D8FF)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (
                  var index = 0;
                  index < snapshot.selectedTurretSlotLimit;
                  index++
                )
                  Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: _LinkSocketButton(
                      index: index,
                      type: index < snapshot.selectedTurretGems.length
                          ? snapshot.selectedTurretGems[index]
                          : null,
                      selected: selectedSlotIndex == index,
                      enabled: canManageGems,
                      onTap: () => onSelectSlot(index),
                    ),
                  ),
                if (snapshot.selectedTurretHasLinkUpgrade)
                  _LinkSocketButton(
                    index: snapshot.selectedTurretSlotLimit,
                    type: null,
                    selected: false,
                    enabled: canOpenLockedSocket,
                    locked: true,
                    lockedLabel: lockedLabel,
                    onTap: onUpgradeLink,
                  ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 10,
          top: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            color: const Color(0xFF0B1B2B),
            child: const Text(
              '링크 홈',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Color(0xFF8EE6FF),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LinkSocketButton extends StatelessWidget {
  const _LinkSocketButton({
    required this.index,
    required this.type,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.locked = false,
    this.lockedLabel,
  });

  final int index;
  final GemType? type;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final bool locked;
  final String? lockedLabel;

  @override
  Widget build(BuildContext context) {
    final gem = type == null ? null : gameGems[type]!;
    final accent = locked
        ? (enabled ? const Color(0xFFE7C66A) : const Color(0xFF607587))
        : gem?.color ?? const Color(0xFF8AA6B8);
    final tooltip = locked ? (enabled ? '홈 열기' : '홈 잠김') : gem?.name ?? '빈 홈';

    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 44,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 38,
              height: 38,
              child: OutlinedButton(
                onPressed: enabled ? onTap : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: accent,
                  disabledForegroundColor: const Color(0xFF607587),
                  backgroundColor: selected
                      ? accent.withValues(alpha: 0.2)
                      : const Color(0xFF07111D),
                  side: BorderSide(
                    color: selected ? accent : accent.withValues(alpha: 0.62),
                    width: selected ? 2 : 1,
                  ),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(38, 38),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: const CircleBorder(),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 25,
                      height: 25,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: accent.withValues(alpha: 0.36),
                        ),
                      ),
                    ),
                    if (locked)
                      Icon(Icons.lock_outline, size: 15, color: accent)
                    else if (gem == null)
                      Icon(Icons.add, size: 17, color: accent)
                    else
                      Icon(gem.icon, size: 17, color: gem.color),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              locked ? (lockedLabel ?? '잠김') : '홈 ${index + 1}',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: selected ? accent : const Color(0xFF8AA6B8),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _InventoryGemChip extends StatelessWidget {
  const _InventoryGemChip({
    required this.gem,
    required this.count,
    required this.selected,
    required this.equipped,
    required this.blocked,
    required this.enabled,
    required this.onTap,
  });

  final GemDefinition gem;
  final int count;
  final bool selected;
  final bool equipped;
  final bool blocked;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dimmed = equipped || blocked;
    return Opacity(
      opacity: dimmed && !selected ? 0.48 : 1,
      child: SizedBox(
        width: 106,
        height: 34,
        child: OutlinedButton(
          onPressed: enabled ? onTap : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: BorderSide(
              color: selected ? gem.color : gem.color.withValues(alpha: 0.58),
              width: selected ? 2 : 1,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 7),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Row(
            children: [
              Icon(gem.icon, color: gem.color, size: 15),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  gem.name,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                'x$count',
                style: const TextStyle(fontSize: 10, color: Color(0xFFB9D6E4)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedInventoryGemActions extends StatelessWidget {
  const _SelectedInventoryGemActions({
    required this.type,
    required this.turret,
    required this.gem,
    required this.blockReason,
    required this.canInstall,
    required this.enabled,
    required this.onInstall,
  });

  final GemType type;
  final TurretDefinition turret;
  final GemDefinition gem;
  final String? blockReason;
  final bool canInstall;
  final bool enabled;
  final VoidCallback onInstall;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x9907111D),
        border: Border.all(color: gem.color.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        children: [
          Icon(gem.icon, color: gem.color, size: 15),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  gem.name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFE8F8FF),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  blockReason ?? _gemEffectText(type, turret),
                  style: TextStyle(
                    fontSize: 10,
                    color: blockReason == null
                        ? const Color(0xFFC9DCE8)
                        : const Color(0xFFFFA68A),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 28,
            child: OutlinedButton(
              onPressed: enabled && canInstall ? onInstall : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                disabledForegroundColor: const Color(0xFF6D7F8F),
                side: BorderSide(
                  color: canInstall ? gem.color : const Color(0x55485B68),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
              child: const Text('장착', style: TextStyle(fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedSlotGemActions extends StatelessWidget {
  const _SelectedSlotGemActions({
    required this.type,
    required this.turret,
    required this.onRemove,
  });

  final GemType type;
  final TurretDefinition turret;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final gem = gameGems[type]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x9907111D),
        border: Border.all(color: gem.color.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        children: [
          Icon(gem.icon, color: gem.color, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  gem.name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFE8F8FF),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _gemEffectText(type, turret),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFFD6ECF6),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 28,
            child: OutlinedButton(
              onPressed: onRemove,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFF8AA6B8)),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
              child: const Text('해제', style: TextStyle(fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }
}
