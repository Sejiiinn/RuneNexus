import 'package:flutter/material.dart';

import '../../data/definitions/game_gem_data.dart';
import '../../domain/gem/gem_definition.dart';
import '../../domain/gem/gem_type.dart';
import '../game/game_icons.dart';
import '../../domain/turret/attack_tag.dart';
import '../../domain/turret/damage_family.dart';
import '../../domain/turret/turret_definition.dart';
import '../../domain/turret/turret_type.dart';
import '../../game/game_snapshot.dart';

class HudTurretLinkSocketStrip extends StatelessWidget {
  const HudTurretLinkSocketStrip({
    required this.snapshot,
    required this.canInstallGems,
    required this.selectedSlotIndex,
    required this.onSelectSlot,
    required this.onUpgradeLink,
    super.key,
  });

  final GameSnapshot snapshot;
  final bool canInstallGems;
  final int? selectedSlotIndex;
  final ValueChanged<int> onSelectSlot;
  final VoidCallback onUpgradeLink;

  @override
  Widget build(BuildContext context) {
    final canOpenLockedSocket =
        canInstallGems &&
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
                      enabled: canInstallGems,
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
                      GemIcon(gem.type, size: 17),
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
              overflow: TextOverflow.clip,
            ),
          ],
        ),
      ),
    );
  }
}

class HudInventoryGemChip extends StatelessWidget {
  const HudInventoryGemChip({
    required this.gem,
    required this.count,
    required this.selected,
    required this.equipped,
    required this.blocked,
    required this.enabled,
    required this.onTap,
    super.key,
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
              GemIcon(gem.type, size: 15),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  gem.name,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.clip,
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

class HudSelectedInventoryGemActions extends StatelessWidget {
  const HudSelectedInventoryGemActions({
    required this.type,
    required this.turret,
    required this.gem,
    required this.blockReason,
    required this.canInstall,
    required this.enabled,
    required this.onInstall,
    super.key,
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
          GemIcon(gem.type, size: 15),
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
                  overflow: TextOverflow.clip,
                ),
                const SizedBox(height: 2),
                Text(
                  blockReason ?? hudGemEffectText(type, turret),
                  style: TextStyle(
                    fontSize: 10,
                    color: blockReason == null
                        ? const Color(0xFFC9DCE8)
                        : const Color(0xFFFFA68A),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.clip,
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

class HudSelectedSlotGemActions extends StatelessWidget {
  const HudSelectedSlotGemActions({
    required this.type,
    required this.turret,
    required this.onRemove,
    super.key,
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
          GemIcon(gem.type, size: 14),
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
                  overflow: TextOverflow.clip,
                ),
                const SizedBox(height: 2),
                Text(
                  hudGemEffectText(type, turret),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFFD6ECF6),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.clip,
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

String hudGemEffectText(GemType type, TurretDefinition turret) {
  return switch (type) {
    GemType.attackSpeed => '공격 속도 40% 증폭',
    GemType.range => '사거리 20% 증폭',
    GemType.physicalDamage =>
      turret.damageFamily == DamageFamily.physical
          ? '물리 피해 40% 증폭'
          : '현재 적용되는 물리 피해 없음',
    GemType.elementalDamage =>
      turret.damageFamily == DamageFamily.elemental
          ? '원소 피해 40% 증폭'
          : '현재 적용되는 원소 피해 없음',
    GemType.lightWeapon =>
      turret.attackTags.contains(AttackTag.light)
          ? '경량화기 피해 20% 증폭, 초당 발사 20% 증폭'
          : '현재 적용되는 경량화기 피해 없음',
    GemType.heavyWeapon =>
      turret.attackTags.contains(AttackTag.heavy)
          ? '중화기 피해 30% 증폭, 효과 범위 20% 증가'
          : '현재 적용되는 중화기 피해 없음',
    GemType.damageOverTime =>
      turret.attackTags.contains(AttackTag.damageOverTime)
          ? '지속피해 30% 증가, 지속시간 30% 증가'
          : '현재 적용되는 지속피해 없음',
    GemType.explosion =>
      turret.type == TurretType.lightning
          ? '첫 대상 전기 충격파'
          : turret.splashRadius > 0
          ? '폭발 반경 25% 증폭'
          : '반경 34 폭발',
    GemType.chain =>
      turret.type == TurretType.lightning
          ? '후속 연쇄 대상 +2'
          : turret.splashRadius > 0
          ? '폭발 미적중 최대 2명에게 50% 연쇄'
          : '주변 최대 2명에게 50% 연쇄',
    GemType.criticalChance => '치명 확률 +20%p',
    GemType.aimSpeed =>
      turret.instantHit && turret.aimDuration > 0
          ? '조준 속도 75% 증가'
          : '현재 적용되는 조준 속도 없음',
    GemType.damageAmplifier => '타격 피해 25% 증폭',
    GemType.armorPiercing => '방어구 감쇄 무시',
  };
}
