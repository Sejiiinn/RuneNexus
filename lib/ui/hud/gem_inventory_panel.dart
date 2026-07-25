import 'package:flutter/material.dart';

import '../../data/definitions/game_gem_data.dart';
import '../../domain/combat/game_phase.dart';
import '../../domain/gem/gem_type.dart';
import '../../game/game_snapshot.dart';
import '../../game/rune_nexus_game.dart';
import '../game/game_ui.dart';
import 'hud_common.dart';

class HudGemInventoryPanel extends StatelessWidget {
  const HudGemInventoryPanel({
    required this.game,
    required this.snapshot,
    super.key,
  });

  final RuneNexusGame game;
  final GameSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final ownedGems = GemType.values
        .where((type) => (snapshot.gemInventory[type] ?? 0) > 0)
        .toList();
    final canPurchase =
        (snapshot.phase == GamePhase.preparation ||
            snapshot.phase == GamePhase.wave) &&
        snapshot.gemShards >= RuneNexusGame.gemChoicePurchaseCost;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xAA0B1B2B),
        border: Border.all(color: const Color(0x5533D8FF)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const HudGemShardIcon(),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '젬 파편 ${snapshot.gemShards}',
                  style: const TextStyle(
                    color: Color(0xFFE8F8FF),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              SizedBox(
                height: 32,
                child: GameButton(
                  onPressed: canPurchase
                      ? () {
                          final pauseCombat = snapshot.phase == GamePhase.wave;
                          if (pauseCombat) {
                            game.pauseEngine();
                          }
                          final purchased = game.purchaseGemChoice();
                          if (pauseCombat && !purchased) {
                            game.resumeEngine();
                          }
                        }
                      : null,
                  compact: true,
                  variant: GameButtonVariant.confirm,
                  accentColor: GamePalette.green,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '젬 구매',
                        style: GameTextStyles.withColor(
                          GameTextStyles.buttonSmall,
                          canPurchase
                              ? GamePalette.textPrimary
                              : GamePalette.textDisabled,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: HudGemShardIcon(),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${RuneNexusGame.gemChoicePurchaseCost}',
                        style: GameTextStyles.withColor(
                          GameTextStyles.buttonSmall,
                          canPurchase
                              ? GamePalette.green
                              : GamePalette.textDisabled,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (ownedGems.isEmpty)
            const Text(
              '보유한 젬이 없습니다. 5라운드 보상 또는 파편 구매로 젬을 획득하세요.',
              style: TextStyle(fontSize: 11, color: Color(0xFF8FA8BA)),
            )
          else ...[
            const _GemInventorySectionHeader(),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: ownedGems.map((type) {
                return _GemInventoryChip(
                  type: type,
                  count: snapshot.gemInventory[type] ?? 0,
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _GemInventorySectionHeader extends StatelessWidget {
  const _GemInventorySectionHeader();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: Divider(height: 1, thickness: 1, color: Color(0x334D6577)),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            '보유 젬',
            style: TextStyle(
              color: Color(0xFF5F788A),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
              height: 1,
            ),
          ),
        ),
        Expanded(
          child: Divider(height: 1, thickness: 1, color: Color(0x334D6577)),
        ),
      ],
    );
  }
}

class _GemInventoryChip extends StatelessWidget {
  const _GemInventoryChip({required this.type, required this.count});

  final GemType type;
  final int count;

  @override
  Widget build(BuildContext context) {
    final gem = gameGems[type]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: gem.color.withValues(alpha: 0.12),
        border: Border.all(color: gem.color.withValues(alpha: 0.55)),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GemIcon(gem.type, size: 14),
              const SizedBox(width: 4),
              Text(
                '${gem.name} x$count',
                style: const TextStyle(
                  color: Color(0xFFE8F8FF),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            _gemInventoryEffectText(type),
            style: const TextStyle(fontSize: 10, color: Color(0xFF9FB7C8)),
            maxLines: 1,
            overflow: TextOverflow.clip,
          ),
        ],
      ),
    );
  }
}

String _gemInventoryEffectText(GemType type) {
  return switch (type) {
    GemType.attackSpeed => '초당 발사 +40%',
    GemType.range => '사거리 +20%',
    GemType.physicalDamage => '물리 피해 +40%',
    GemType.elementalDamage => '원소 피해 +40%',
    GemType.lightWeapon => '경량화기 강화',
    GemType.heavyWeapon => '중화기 강화',
    GemType.damageOverTime => '지속피해 증가',
    GemType.explosion => '폭발 피해 추가',
    GemType.chain => '연쇄 투사체 추가',
    GemType.criticalChance => '치명 확률 +20%p',
    GemType.aimSpeed => '조준 속도 +75%',
    GemType.damageAmplifier => '타격 피해 +25%',
    GemType.armorPiercing => '방어구 감쇄 무시',
  };
}
