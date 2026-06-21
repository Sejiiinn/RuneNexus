import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/definitions/game_gem_data.dart';
import '../../domain/gem/gem_type.dart';
import '../../game/game_snapshot.dart';
import '../../game/rune_nexus_game.dart';
import '../game/game_ui.dart';
import 'hud_common.dart';

class HudRewardOverlay extends StatefulWidget {
  const HudRewardOverlay({
    required this.game,
    required this.snapshot,
    super.key,
  });

  final RuneNexusGame game;
  final GameSnapshot snapshot;

  @override
  State<HudRewardOverlay> createState() => _RewardOverlayState();
}

class _RewardOverlayState extends State<HudRewardOverlay> {
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
        child: GamePanel(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(14),
          variant: GamePanelVariant.reward,
          accentColor: GamePalette.green,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isPurchase ? '젬 구매 선택' : '젬 보상 선택',
                style: GameTextStyles.title,
              ),
              if (!isPurchase) ...[
                const SizedBox(height: 4),
                Text(
                  '${snapshot.completedRounds}웨이브 클리어 보상',
                  style: GameTextStyles.body,
                ),
              ],
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final optionCount = snapshot.rewardOptions.length;
                  const spacing = 8.0;
                  final availableWidth =
                      constraints.maxWidth - spacing * (optionCount - 1);
                  final cardWidth = optionCount <= 1
                      ? math.min(112.0, constraints.maxWidth)
                      : math.min(110.0, availableWidth / optionCount);
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (
                        var i = 0;
                        i < snapshot.rewardOptions.length;
                        i++
                      ) ...[
                        if (i > 0) const SizedBox(width: spacing),
                        _RewardCard(
                          type: snapshot.rewardOptions[i],
                          width: cardWidth,
                          ownedCount:
                              snapshot.gemCollection[snapshot
                                  .rewardOptions[i]] ??
                              0,
                          selected: selectedGem == snapshot.rewardOptions[i],
                          onPressed: () {
                            setState(() {
                              _selectedGem = snapshot.rewardOptions[i];
                              _selectedGemShards = false;
                            });
                          },
                          onConfirm: () => widget.game.selectRewardGem(
                            snapshot.rewardOptions[i],
                          ),
                        ),
                      ],
                    ],
                  );
                },
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
              const HudGemShardIcon(),
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
                      overflow: TextOverflow.clip,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '파편 +${RuneNexusGame.gemShardRewardFallbackAmount} · 현재 보유 $ownedCount',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF9FB7C8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                    ),
                  ],
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 8),
                SizedBox(
                  height: 30,
                  child: GameButton(
                    onPressed: onConfirm,
                    label: '파편 받기',
                    compact: true,
                    variant: GameButtonVariant.confirm,
                    accentColor: GamePalette.green,
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
    final gem = gameGems[type]!;
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
          GemIcon(gem.type, size: 13),
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
    required this.width,
    required this.ownedCount,
    required this.selected,
    required this.onPressed,
    required this.onConfirm,
  });

  final GemType type;
  final double width;
  final int ownedCount;
  final bool selected;
  final VoidCallback onPressed;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final gem = gameGems[type]!;
    final compact = width < 96;
    final dense = width < 88;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: width,
          height: compact ? 204 : 216,
          padding: EdgeInsets.fromLTRB(6, compact ? 8 : 10, 6, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: gem.color, width: selected ? 2 : 1),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                gem.color.withValues(alpha: selected ? 0.22 : 0.14),
                const Color(0xF007111D),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xAA000000),
                blurRadius: selected ? 16 : 10,
                offset: const Offset(0, 6),
              ),
              if (selected)
                BoxShadow(
                  color: gem.color.withValues(alpha: 0.22),
                  blurRadius: 18,
                ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: compact ? 34 : 38,
                height: compact ? 34 : 38,
                decoration: BoxDecoration(
                  color: gem.color.withValues(alpha: 0.18),
                  border: Border.all(color: gem.color.withValues(alpha: 0.78)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: GemIcon(gem.type, size: compact ? 19 : 21),
              ),
              SizedBox(height: compact ? 6 : 8),
              SizedBox(
                height: compact ? 32 : 36,
                child: Center(
                  child: Text(
                    gem.name,
                    maxLines: 2,
                    overflow: TextOverflow.clip,
                    textAlign: TextAlign.center,
                    style: GameTextStyles.sectionTitle.copyWith(
                      fontSize: dense ? 11 : 13,
                      height: 1.12,
                    ),
                  ),
                ),
              ),
              SizedBox(height: compact ? 4 : 6),
              SizedBox(
                height: compact ? 36 : 32,
                child: Center(
                  child: Text(
                    _rewardCardEffectText(type),
                    maxLines: 2,
                    overflow: TextOverflow.clip,
                    textAlign: TextAlign.center,
                    style: GameTextStyles.caption.copyWith(
                      color: GamePalette.textSecondary,
                      fontSize: dense ? 9 : 10.5,
                      height: 1.18,
                    ),
                  ),
                ),
              ),
              SizedBox(height: compact ? 5 : 7),
              Container(
                height: 22,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: const Color(0x8802070D),
                  border: Border.all(color: const Color(0x5533D8FF)),
                  borderRadius: BorderRadius.circular(999),
                ),
                alignment: Alignment.center,
                child: Text(
                  '보유 $ownedCount',
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: GameTextStyles.chip.copyWith(fontSize: dense ? 9 : 10),
                ),
              ),
              SizedBox(height: compact ? 6 : 8),
              _RewardConfirmArea(selected: selected, onConfirm: onConfirm),
            ],
          ),
        ),
      ),
    );
  }
}

class _RewardConfirmArea extends StatelessWidget {
  const _RewardConfirmArea({required this.selected, required this.onConfirm});

  final bool selected;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      width: double.infinity,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 120),
        opacity: selected ? 1 : 0,
        child: IgnorePointer(
          ignoring: !selected,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: GamePalette.goldBright.withValues(alpha: 0.72),
              ),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF223543), Color(0xFF07111D)],
              ),
              boxShadow: [
                BoxShadow(
                  color: GamePalette.goldBright.withValues(alpha: 0.18),
                  blurRadius: 12,
                ),
              ],
            ),
            child: GameButton(
              onPressed: onConfirm,
              label: '획득 확정',
              height: 36,
              variant: GameButtonVariant.confirm,
              accentColor: GamePalette.goldBright,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
        ),
      ),
    );
  }
}

String _rewardCardEffectText(GemType type) {
  return switch (type) {
    GemType.attackSpeed => '공격 속도 40% 증가',
    GemType.range => '사거리 20% 증가',
    GemType.physicalDamage => '물리 포탑 피해 40% 증가',
    GemType.elementalDamage => '원소 포탑 피해 40% 증가',
    GemType.lightWeapon => '경량화기 피해와 연사 강화',
    GemType.heavyWeapon => '중화기 피해와 범위 강화',
    GemType.damageOverTime => '지속피해와 시간 강화',
    GemType.explosion => '범위 피해 추가',
    GemType.chain => '추가 타격 발생',
    GemType.criticalChance => '치명 확률 +20%p',
    GemType.aimSpeed => '조준 속도 75% 증가',
    GemType.damageAmplifier => '타격 피해 25% 증가',
    GemType.armorPiercing => '방어구 감쇄 무시',
  };
}
