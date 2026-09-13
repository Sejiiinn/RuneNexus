import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/domain/enemy/enemy_type.dart';
import 'package:rune_nexus/game/components/damage_number_component.dart';
import 'package:rune_nexus/game/components/death_burst_effect_component.dart';
import 'package:rune_nexus/game/components/diamond_reward_effect_component.dart';
import 'package:rune_nexus/game/components/gem_equip_effect_component.dart';
import 'package:rune_nexus/game/components/impact_effect_component.dart';
import 'package:rune_nexus/game/components/lightning_charge_component.dart';
import 'package:rune_nexus/game/rendering/stage1_3d/battlefield_effects.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const origin = Offset(20, 30);
  const tile = 40.0;
  test(
    'damage snapshots preserve current motion, feedback and simulation age',
    () {
      final cache = DamageNumberImageCache();
      final damage = DamageNumberComponent.cached(
        position: Vector2(100, 110),
        imageCache: cache,
        text: '약점 123',
        color: const Color(0xffabcdef),
        feedback: DamageNumberFeedback.weak,
        motion: DamageNumberMotion.fallArc,
      );
      final initial = damage.battlefieldEffect(7, origin, tile)!;
      expect(initial.position, const Offset(2, 2));
      expect(initial.text, '약점 123');
      expect(initial.feedback, 'weak');
      damage.update(0.1);
      final next = damage.battlefieldEffect(7, origin, tile)!;
      expect(next.id, initial.id);
      expect(next.age, 0.1);
      expect(
        (next.position + next.screenOffset / tile).dx,
        closeTo((damage.position.x - 20) / 40, 1e-9),
      );
      expect(
        (next.position + next.screenOffset / tile).dy,
        closeTo((damage.position.y - 30) / 40, 1e-9),
      );
      expect(damage.battlefieldEffect(7, origin, tile)!.age, next.age);
      cache.dispose();
    },
  );
  test('charge snapshot cannot execute its combat release callback', () {
    var released = 0;
    var active = true;
    final charge = LightningChargeComponent(
      chargePosition: () => Vector2(60, 70),
      isActive: () => active,
      onRelease: () => released++,
      color: const Color(0xffaabbcc),
    );
    expect(
      charge.battlefieldEffect(1, origin, tile)!.position,
      const Offset(1, 1),
    );
    expect(released, 0);
    charge.update(0.15);
    expect(charge.battlefieldEffect(1, origin, tile)!.age, 0.15);
    expect(released, 0);
    active = false;
    expect(charge.battlefieldEffect(1, origin, tile), isNull);
    expect(released, 0);
  });
  test(
    'existing native cannon blast excluded; remaining impact styles preserve lifetime',
    () {
      for (final style in ImpactEffectStyle.values) {
        final impact = ImpactEffectComponent(
          position: Vector2(60, 70),
          color: const Color(0xff123456),
          style: style,
          radius: 20,
        );
        final snapshot = impact.battlefieldEffect(2, origin, tile);
        if (style == ImpactEffectStyle.blast) {
          expect(snapshot, isNull);
        } else {
          expect(snapshot!.style, style.name);
          expect(snapshot.radius, 20);
          expect(
            snapshot.duration,
            style == ImpactEffectStyle.sniperBlast ||
                    style == ImpactEffectStyle.lightningBlast
                ? 0.36
                : 0.28,
          );
        }
      }
    },
  );
  test(
    'death, reward and equip effects retain type and independent lifetimes',
    () {
      final death = DeathBurstEffectComponent(
        position: Vector2(60, 70),
        color: const Color(0xff112233),
        type: EnemyType.shieldBoss,
        radius: 32,
      );
      final reward = DiamondRewardEffectComponent(
        position: Vector2(60, 70),
        reward: 12,
        diamondImage: null,
        visualScale: 0.5,
      );
      final equip = GemEquipEffectComponent(
        position: Vector2(60, 70),
        gemColor: const Color(0xff112233),
        visualScale: 0.5,
      );
      expect(death.battlefieldEffect(3, origin, tile)!.duration, 0.68);
      expect(
        death.battlefieldEffect(3, origin, tile)!.enemyTypeIndex,
        EnemyType.shieldBoss.index,
      );
      reward.update(0.1);
      expect(
        (reward.battlefieldEffect(4, origin, tile)!.position +
                reward.battlefieldEffect(4, origin, tile)!.screenOffset / tile)
            .dy,
        closeTo((70 - 1.2 - 30) / 40, 1e-6),
      );
      expect(reward.battlefieldEffect(4, origin, tile)!.text, '+12');
      expect(equip.battlefieldEffect(5, origin, tile)!.duration, 0.78);
    },
  );
  test(
    'presentation DTO owns immutable lists and serializes tile geometry',
    () {
      final points = [const Offset(1, 2)];
      final effect = BattlefieldEffect(
        id: 1,
        kind: 'chain',
        age: 0.1,
        duration: 0.2,
        position: Offset.zero,
        tileSize: 48,
        points: points,
      );
      points.clear();
      expect(effect.points, [const Offset(1, 2)]);
      expect(() => effect.points.clear(), throwsUnsupportedError);
      final items = [effect];
      final effects = BattlefieldEffects(items: items);
      items.clear();
      expect(effects.items, hasLength(1));
      expect(effect.toJson()['points'], [
        [1.0, 2.0],
      ]);
    },
  );
}
