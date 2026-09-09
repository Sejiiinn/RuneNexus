import 'package:flutter/rendering.dart';
import 'package:rune_nexus/data/definitions/game_turret_data.dart';
import 'package:rune_nexus/domain/gem/gem_equip_rules.dart';
import 'package:rune_nexus/ui/hud/gem_socket_section.dart';

import 'helpers/widget_test_helpers.dart';

void main() {
  test('global gem descriptions do not change with the turret', () {
    for (final type in [
      GemType.explosion,
      GemType.chain,
      GemType.heavyWeapon,
      GemType.multipleProjectiles,
    ]) {
      final descriptions = gameTurrets.values
          .map((turret) => hudGemEffectText(type, turret))
          .toSet();
      expect(descriptions, hasLength(1));
    }
  });

  test('multiple projectiles only equips on projectile turrets', () {
    for (final turret in gameTurrets.values) {
      expect(
        canEquipGemOnTurret(GemType.multipleProjectiles, turret),
        turret.firesProjectile,
        reason: turret.name,
      );
    }
  });

  for (final size in [const Size(320, 800), const Size(640, 360)]) {
    for (final thirdGem in [GemType.heavyWeapon, GemType.multipleProjectiles]) {
      testWidgets(
        'global gem reward rules remain readable at $size with $thirdGem',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });
          final game = RuneNexusGame(saveRepository: MemorySaveRepository());
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: HudRewardOverlay(
                  game: game,
                  snapshot: resultSnapshot(
                    phase: GamePhase.reward,
                    currentStageNumber: 1,
                    completedRounds: 5,
                    rewardOptions: [GemType.explosion, GemType.chain, thirdGem],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          for (final text in [
            '범위 피해 부여\n효과 범위 25% 증가',
            '(폭발은 직접 명중한 대상을 제외한 주변 적에게 명중 피해의 50%를 줍니다.)',
            '연쇄 횟수 +2',
            '(연쇄된 투사체는 피해 및 효과 범위가 50% 감폭됩니다.)',
            if (thirdGem == GemType.heavyWeapon)
              '피해 30% 증폭\n효과 범위 20% 증가\n중화기 전용'
            else
              '투사체 +2\n피해 50% 감폭',
          ]) {
            final finder = find.text(text);
            expect(finder, findsOneWidget);
            final paragraph = tester.renderObject<RenderParagraph>(finder);
            expect(paragraph.didExceedMaxLines, isFalse);
            final painter = TextPainter(
              text: paragraph.text,
              textDirection: TextDirection.ltr,
              textScaler: paragraph.textScaler,
            )..layout(maxWidth: paragraph.size.width);
            expect(
              painter.height,
              lessThanOrEqualTo(paragraph.size.height + 0.1),
            );
            painter.dispose();
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
