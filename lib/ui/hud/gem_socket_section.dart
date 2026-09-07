import 'package:flutter/material.dart';

import '../../data/definitions/game_gem_data.dart';
import '../../domain/gem/gem_definition.dart';
import '../../domain/gem/gem_type.dart';
import '../game/game_icons.dart';
import '../game/game_image_assets.dart';
import '../../domain/turret/attack_tag.dart';
import '../../domain/turret/damage_family.dart';
import '../../domain/turret/turret_definition.dart';
import '../../domain/turret/turret_type.dart';
import '../../game/game_snapshot.dart';

class HudTurretLinkSocketStrip extends StatelessWidget {
  const HudTurretLinkSocketStrip({
    required this.snapshot,
    required this.maxSlotLimit,
    required this.canInstallGems,
    required this.selectedSlotIndex,
    required this.onSelectSlot,
    required this.onUpgradeLink,
    super.key,
  });

  final GameSnapshot snapshot;
  final int maxSlotLimit;
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
    final lockedRequirement = snapshot.selectedTurretCanUpgradeLink
        ? '${snapshot.selectedTurretLinkUpgradeCost} 골드'
        : 'Lv.${snapshot.selectedTurretLinkUpgradeRequiredLevel} 필요';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '링크 홈',
          style: TextStyle(fontSize: 10, color: Color(0xFF8EE6FF)),
        ),
        const SizedBox(height: 4),
        LayoutBuilder(
          builder: (context, constraints) {
            // 여섯 홈과 사이 간격 다섯 칸을 기준으로 한 소켓 크기.
            final socketSize = ((constraints.maxWidth - 20) / 6).clamp(
              44.0,
              double.infinity,
            );
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Stack(
                children: [
                  // 소켓 뒤를 잇는 레일: 열린 홈 사이만 점등.
                  for (var index = 1; index < maxSlotLimit; index++)
                    Positioned(
                      left: (index - 1) * (socketSize + 4) + socketSize * 0.75,
                      top: socketSize / 2 - 6,
                      width: socketSize * 0.5 + 4,
                      height: 12,
                      child: Image.asset(
                        index < snapshot.selectedTurretSlotLimit
                            ? gemLinkActiveAsset
                            : gemLinkLockedAsset,
                        fit: BoxFit.fill,
                        excludeFromSemantics: true,
                      ),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 연구로 해금된 한도까지 표시하고 미구매 홈은 순차 개방.
                      for (var index = 0; index < maxSlotLimit; index++) ...[
                        if (index > 0) const SizedBox(width: 4),
                        _LinkSocketButton(
                          index: index,
                          size: socketSize,
                          type: index < snapshot.selectedTurretGems.length
                              ? snapshot.selectedTurretGems[index]
                              : null,
                          selected: selectedSlotIndex == index,
                          locked: index >= snapshot.selectedTurretSlotLimit,
                          lockedRequirement:
                              index == snapshot.selectedTurretSlotLimit
                              ? lockedRequirement
                              : '홈 $index 먼저 열기',
                          enabled: index < snapshot.selectedTurretSlotLimit
                              ? canInstallGems
                              : index == snapshot.selectedTurretSlotLimit &&
                                    canOpenLockedSocket,
                          onTap: index < snapshot.selectedTurretSlotLimit
                              ? () => onSelectSlot(index)
                              : onUpgradeLink,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            );
          },
        ),
        if (snapshot.selectedTurretHasLinkUpgrade) ...[
          const SizedBox(height: 4),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            children: [
              Text(
                '홈 ${snapshot.selectedTurretSlotLimit + 1} 열기',
                style: const TextStyle(fontSize: 10, color: Color(0xFF8AA6B8)),
              ),
              if (snapshot.selectedTurretCanUpgradeLink) ...[
                const GoldCurrencyIcon(size: 14),
                Text(
                  '${snapshot.selectedTurretLinkUpgradeCost}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFFE7C66A),
                  ),
                ),
              ] else
                Text(
                  lockedRequirement,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF8AA6B8),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _LinkSocketButton extends StatelessWidget {
  const _LinkSocketButton({
    required this.index,
    required this.size,
    required this.type,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.locked = false,
    this.lockedRequirement,
  });

  final int index;
  final double size;
  final GemType? type;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final bool locked;
  final String? lockedRequirement;

  @override
  Widget build(BuildContext context) {
    final gem = type == null ? null : gameGems[type]!;
    final tooltip = locked
        ? '${enabled ? '홈 열기' : '홈 잠김'} · $lockedRequirement'
        : gem?.name ?? '빈 홈';
    final asset = locked
        ? gemSocketLockedAsset
        : selected
        ? gemSocketSelectedAsset
        : gemSocketEmptyAsset;

    return Tooltip(
      message: tooltip,
      excludeFromSemantics: true,
      child: Semantics(
        label: '홈 ${index + 1}, $tooltip',
        button: true,
        enabled: enabled,
        selected: selected,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(
              width: size,
              height: size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.asset(
                    asset,
                    width: size,
                    height: size,
                    excludeFromSemantics: true,
                  ),
                  if (gem != null)
                    ExcludeSemantics(child: GemIcon(gem.type, size: 24)),
                ],
              ),
            ),
          ),
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
        height: 34,
        child: OutlinedButton(
          onPressed: enabled ? onTap : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 34),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
            mainAxisSize: MainAxisSize.min,
            children: [
              GemIcon(gem.type, size: 15),
              const SizedBox(width: 5),
              Text(
                gem.name,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 5),
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
                  hudGemEffectText(type, turret),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFFC9DCE8),
                  ),
                ),
                if (blockReason != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    blockReason!,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFFFFA68A),
                    ),
                  ),
                ],
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
